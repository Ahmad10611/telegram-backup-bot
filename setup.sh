#!/bin/bash
# setup.sh - نصب پیشرفته ربات

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1" >&2; }
echo_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

INSTALL_DIR="${1:-$(pwd)}"
PYTHON_MIN_VERSION="3.7"

show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   نصب ربات پشتیبان‌گیری تلگرام           ║"
    echo "║   Telegram Backup Bot Installer           ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_VERSION=$(cat /etc/redhat-release | grep -oP '\d+' | head -1)
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        OS_VERSION=$(cat /etc/debian_version)
    else
        OS=$(uname -s)
    fi
    
    echo_info "سیستم عامل: $OS $OS_VERSION"
}

find_python() {
    for py in python3.11 python3.10 python3.9 python3.8 python3.7 python3; do
        if command -v "$py" &>/dev/null; then
            version=$($py -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
            if awk -v ver="$version" -v min="$PYTHON_MIN_VERSION" 'BEGIN{exit(ver<min)}' 2>/dev/null; then
                echo "$py"
                return 0
            fi
        fi
    done
    return 1
}

install_python_centos7() {
    echo_info "نصب IUS Repository برای CentOS 7..."
    
    # حذف repo قدیمی اگر وجود داره
    yum remove -y ius-release 2>/dev/null || true
    
    # نصب IUS
    yum install -y https://repo.ius.io/ius-release-el7.rpm || {
        echo_warning "نصب از IUS ناموفق، تلاش با روش دیگر..."
        
        # روش دوم: نصب از EPEL + SCL
        yum install -y centos-release-scl
        yum install -y rh-python38 rh-python38-python-pip rh-python38-python-devel
        
        if [ -f /opt/rh/rh-python38/enable ]; then
            echo_success "Python 3.8 از SCL نصب شد"
            
            # ایجاد wrapper
            cat > /usr/local/bin/python3.8 <<'EOF'
#!/bin/bash
source /opt/rh/rh-python38/enable
exec python3 "$@"
EOF
            chmod +x /usr/local/bin/python3.8
            
            cat > /usr/local/bin/pip3.8 <<'EOF'
#!/bin/bash
source /opt/rh/rh-python38/enable
exec pip3 "$@"
EOF
            chmod +x /usr/local/bin/pip3.8
            
            return 0
        fi
        
        return 1
    }
    
    # پاک کردن cache
    yum clean all
    yum makecache
    
    # تلاش برای نصب python39
    if yum install -y python39 python39-pip python39-devel 2>/dev/null; then
        echo_success "Python 3.9 از IUS نصب شد"
        return 0
    fi
    
    # تلاش برای نصب python38
    if yum install -y python38 python38-pip python38-devel 2>/dev/null; then
        echo_success "Python 3.8 از IUS نصب شد"
        return 0
    fi
    
    # تلاش برای نصب python36
    if yum install -y python36 python36-pip python36-devel 2>/dev/null; then
        echo_warning "Python 3.6 نصب شد (حداقل نسخه)"
        return 0
    fi
    
    return 1
}

install_python() {
    echo_info "نصب Python 3.8+..."
    
    case $OS in
        ubuntu|debian|linuxmint)
            apt-get update -qq
            apt-get install -y software-properties-common
            
            if command -v add-apt-repository &>/dev/null; then
                add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
                apt-get update -qq
            fi
            
            apt-get install -y python3.9 python3.9-venv python3.9-dev python3-pip || \
            apt-get install -y python3.8 python3.8-venv python3.8-dev python3-pip || \
            apt-get install -y python3 python3-venv python3-dev python3-pip
            ;;
            
        centos|rhel)
            local ver_major=$(echo $OS_VERSION | cut -d. -f1)
            
            if [ "$ver_major" -eq 7 ]; then
                install_python_centos7 || {
                    echo_error "نصب Python ناموفق"
                    echo_info "لطفاً دستی Python 3.7+ نصب کنید:"
                    echo "  yum install -y centos-release-scl"
                    echo "  yum install -y rh-python38"
                    exit 1
                }
            else
                dnf install -y python39 python39-pip python39-devel || \
                dnf install -y python38 python38-pip python38-devel || \
                dnf install -y python3 python3-pip python3-devel
            fi
            ;;
            
        rocky|almalinux|fedora)
            dnf install -y python39 python39-pip python39-devel || \
            dnf install -y python38 python38-pip python38-devel || \
            dnf install -y python3 python3-pip python3-devel
            ;;
            
        arch|manjaro)
            pacman -Sy --noconfirm python python-pip
            ;;
            
        opensuse*|sles)
            zypper install -y python3 python3-pip python3-devel
            ;;
            
        alpine)
            apk add --no-cache python3 py3-pip python3-dev
            ;;
            
        *)
            echo_error "سیستم عامل پشتیبانی نمی‌شود: $OS"
            exit 1
            ;;
    esac
    
    echo_success "Python نصب شد"
}

install_system_deps() {
    echo_info "نصب پیش‌نیازهای سیستمی..."
    
    case $OS in
        ubuntu|debian|linuxmint)
            apt-get update -qq
            apt-get install -y curl git build-essential \
                default-mysql-client default-libmysqlclient-dev pkg-config 2>/dev/null || \
            apt-get install -y curl git build-essential \
                mysql-client libmysqlclient-dev pkg-config
            ;;
            
        centos|rhel)
            local ver_major=$(echo $OS_VERSION | cut -d. -f1)
            
            if [ "$ver_major" -eq 7 ]; then
                yum groupinstall -y "Development Tools" 2>/dev/null || true
                yum install -y curl git gcc gcc-c++ make mariadb mysql-devel
            else
                dnf groupinstall -y "Development Tools" 2>/dev/null || true
                dnf install -y curl git gcc gcc-c++ make mariadb mysql-devel
            fi
            ;;
            
        rocky|almalinux|fedora)
            dnf groupinstall -y "Development Tools" 2>/dev/null || true
            dnf install -y curl git gcc gcc-c++ make mariadb mysql-devel
            ;;
            
        arch|manjaro)
            pacman -Sy --noconfirm base-devel curl git mariadb-clients mariadb-libs
            ;;
            
        opensuse*|sles)
            zypper install -y curl git gcc gcc-c++ make mariadb-client libmariadb-devel
            ;;
            
        alpine)
            apk add --no-cache curl git build-base mariadb-client mariadb-dev
            ;;
    esac
    
    echo_success "پیش‌نیازها نصب شدند"
}

main() {
    show_banner
    detect_os
    
    if [ "$EUID" -ne 0 ] && [ "$OS" != "Darwin" ]; then
        echo_warning "برای نصب کامل، sudo لازم است"
    fi
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo_info "دایرکتوری نصب: $INSTALL_DIR"
    
    echo_info "بررسی Python..."
    PYTHON_CMD=$(find_python) || {
        install_python
        PYTHON_CMD=$(find_python) || {
            echo_error "نصب Python ناموفق"
            exit 1
        }
    }
    
    python_version=$($PYTHON_CMD --version 2>&1)
    echo_success "Python: $python_version"
    
    install_system_deps
    
    echo_info "ایجاد محیط مجازی..."
    if [ -d "venv" ]; then
        echo_warning "venv موجود است"
    else
        $PYTHON_CMD -m venv venv || {
            echo_error "ایجاد venv ناموفق"
            exit 1
        }
        echo_success "venv ایجاد شد"
    fi
    
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    else
        echo_error "فایل activate یافت نشد"
        exit 1
    fi
    
    echo_info "آپگرید pip..."
    pip install --upgrade pip setuptools wheel -q
    
    echo_info "نصب کتابخانه‌ها..."
    if [ ! -f "requirements.txt" ]; then
        cat > requirements.txt <<'EOF'
python-telegram-bot>=20.0,<21.0
apscheduler>=3.10.0,<4.0
mysql-connector-python>=8.0.33,<9.0
EOF
    fi
    
    pip install -r requirements.txt || {
        echo_error "نصب کتابخانه‌ها ناموفق"
        exit 1
    }
    echo_success "کتابخانه‌ها نصب شدند"
    
    echo ""
    echo_info "اطلاعات ربات:"
    
    read -p "🤖 Bot Token: " BOT_TOKEN
    while [ -z "$BOT_TOKEN" ]; do
        echo_error "Token خالی است"
        read -p "🤖 Bot Token: " BOT_TOKEN
    done
    
    read -p "👤 User ID: " AUTHORIZED_USER_ID
    while [ -z "$AUTHORIZED_USER_ID" ]; do
        echo_error "User ID خالی است"
        read -p "👤 User ID: " AUTHORIZED_USER_ID
    done
    
    read -p "🗄 MySQL User: " MYSQL_USER
    while [ -z "$MYSQL_USER" ]; do
        read -p "🗄 MySQL User: " MYSQL_USER
    done
    
    read -sp "🔑 MySQL Pass: " MYSQL_PASSWORD
    echo
    while [ -z "$MYSQL_PASSWORD" ]; do
        read -sp "🔑 MySQL Pass: " MYSQL_PASSWORD
        echo
    done
    
    read -p "📊 Database: " MYSQL_DB
    while [ -z "$MYSQL_DB" ]; do
        read -p "📊 Database: " MYSQL_DB
    done
    
    read -p "🌐 Host [localhost]: " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-localhost}
    
    read -p "💾 Backup Dir [/root/backups]: " BACKUP_DIR
    BACKUP_DIR=${BACKUP_DIR:-/root/backups}
    
    cat > config.cfg <<EOF
[DEFAULT]
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$AUTHORIZED_USER_ID
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_NAME=$MYSQL_DB
DB_HOST=$MYSQL_HOST
BACKUP_DIR=$BACKUP_DIR
EOF
    
    chmod 600 config.cfg
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    echo_success "تنظیمات ذخیره شد"
    
    # دانلود main.py
    if [ ! -f "main.py" ]; then
        echo_info "دانلود main.py..."
        curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/main.py -o main.py || {
            echo_error "دانلود main.py ناموفق"
            exit 1
        }
        chmod +x main.py
    fi
    
    if [ "$OS" != "Darwin" ] && command -v systemctl &>/dev/null; then
        echo_info "ایجاد سرویس systemd..."
        
        cat > /etc/systemd/system/telegram-backup-bot.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/main.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable telegram-backup-bot.service
        echo_success "سرویس ایجاد شد"
        
        echo ""
        read -p "شروع سرویس الان? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl start telegram-backup-bot.service
            sleep 2
            
            if systemctl is-active --quiet telegram-backup-bot.service; then
                echo_success "✅ سرویس فعال است"
                echo_info "لاگ: journalctl -u telegram-backup-bot -f"
            else
                echo_error "خطا در شروع"
                journalctl -u telegram-backup-bot -n 20
            fi
        fi
    else
        cat > start.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py
EOF
        chmod +x start.sh
        echo_success "start.sh ایجاد شد"
        echo_info "اجرا: ./start.sh"
    fi
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      نصب موفقیت‌آمیز بود!            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo_info "📁 مسیر: $INSTALL_DIR"
    echo_info "💾 Backup: $BACKUP_DIR"
    echo_info "🐍 $python_version"
    echo ""
    
    if command -v systemctl &>/dev/null; then
        echo "دستورات:"
        echo "  systemctl start telegram-backup-bot"
        echo "  systemctl status telegram-backup-bot"
        echo "  journalctl -u telegram-backup-bot -f"
    fi
}

main "$@"
