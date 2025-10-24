#!/bin/bash
# setup.sh - نصب قدرتمند برای همه سیستم‌ها

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
    else
        OS=$(uname -s)
    fi
    echo_info "سیستم عامل: $OS $OS_VERSION"
}

find_python() {
    for py in python3.11 python3.10 python3.9 python3.8 python3.7 python3.6 python3; do
        if command -v "$py" &>/dev/null; then
            version=$($py -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
            if awk -v ver="$version" -v min="3.6" 'BEGIN{exit(ver<min)}' 2>/dev/null; then
                echo "$py"
                return 0
            fi
        fi
    done
    return 1
}

install_python_centos7() {
    echo_info "نصب Python برای CentOS 7..."
    
    # روش 1: نصب از SCL (ساده‌ترین و مطمئن‌ترین)
    echo_info "تلاش 1: نصب از Software Collections (SCL)..."
    yum install -y centos-release-scl 2>/dev/null || true
    
    if yum install -y rh-python38 rh-python38-python-pip rh-python38-python-devel 2>/dev/null; then
        echo_success "Python 3.8 از SCL نصب شد"
        
        # ایجاد symlink
        cat > /usr/local/bin/python3.8 <<'EOFPY'
#!/bin/bash
source /opt/rh/rh-python38/enable
exec python3 "$@"
EOFPY
        chmod +x /usr/local/bin/python3.8
        
        cat > /usr/local/bin/pip3.8 <<'EOFPIP'
#!/bin/bash
source /opt/rh/rh-python38/enable
exec pip3 "$@"
EOFPIP
        chmod +x /usr/local/bin/pip3.8
        
        return 0
    fi
    
    # روش 2: نصب از IUS
    echo_info "تلاش 2: نصب از IUS Repository..."
    yum remove -y ius-release 2>/dev/null || true
    
    if curl -fsSL https://repo.ius.io/ius-release-el7.rpm -o /tmp/ius-release.rpm 2>/dev/null; then
        yum install -y /tmp/ius-release.rpm
        rm -f /tmp/ius-release.rpm
        yum clean all
        yum makecache fast
        
        if yum install -y python39 python39-pip python39-devel 2>/dev/null; then
            echo_success "Python 3.9 از IUS نصب شد"
            return 0
        fi
        
        if yum install -y python38 python38-pip python38-devel 2>/dev/null; then
            echo_success "Python 3.8 از IUS نصب شد"
            return 0
        fi
    fi
    
    # روش 3: نصب Python 3.6 (حداقل)
    echo_info "تلاش 3: نصب Python 3.6 (نسخه پایه)..."
    if yum install -y python3 python3-pip python3-devel 2>/dev/null; then
        echo_warning "Python 3.6 نصب شد (نسخه پایه - ممکن است محدودیت داشته باشد)"
        return 0
    fi
    
    # روش 4: Compile از Source
    echo_info "تلاش 4: Compile Python از source..."
    yum groupinstall -y "Development Tools" 2>/dev/null || true
    yum install -y openssl-devel bzip2-devel libffi-devel zlib-devel wget
    
    cd /tmp
    wget -q https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz
    tar xzf Python-3.9.18.tgz
    cd Python-3.9.18
    ./configure --enable-optimizations --prefix=/usr/local
    make -j$(nproc)
    make altinstall
    
    if [ -f /usr/local/bin/python3.9 ]; then
        echo_success "Python 3.9 compile شد"
        return 0
    fi
    
    return 1
}

install_python() {
    case $OS in
        centos|rhel)
            local ver=$(echo $OS_VERSION | cut -d. -f1)
            if [ "$ver" -eq 7 ]; then
                install_python_centos7 || {
                    echo_error "نصب Python ناموفق"
                    exit 1
                }
            else
                dnf install -y python39 python39-pip python39-devel || \
                dnf install -y python38 python38-pip python38-devel
            fi
            ;;
            
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y software-properties-common
            add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
            apt-get update -qq
            apt-get install -y python3.9 python3.9-venv python3.9-dev python3-pip || \
            apt-get install -y python3.8 python3.8-venv python3.8-dev python3-pip
            ;;
            
        *)
            echo_error "OS پشتیبانی نمی‌شود"
            exit 1
            ;;
    esac
}

install_system_deps() {
    echo_info "نصب dependencies..."
    
    case $OS in
        centos|rhel)
            yum groupinstall -y "Development Tools" 2>/dev/null || true
            yum install -y curl git gcc gcc-c++ make mariadb mysql-devel
            ;;
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y curl git build-essential mysql-client libmysqlclient-dev
            ;;
    esac
}

main() {
    show_banner
    detect_os
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo_info "دایرکتوری: $INSTALL_DIR"
    
    echo_info "بررسی Python..."
    PYTHON_CMD=$(find_python) || {
        install_python
        PYTHON_CMD=$(find_python) || {
            echo_error "Python یافت نشد"
            exit 1
        }
    }
    
    echo_success "Python: $($PYTHON_CMD --version)"
    
    install_system_deps
    
    echo_info "ساخت virtual environment..."
    $PYTHON_CMD -m venv venv 2>/dev/null || $PYTHON_CMD -m pip install --user virtualenv && $PYTHON_CMD -m virtualenv venv
    
    source venv/bin/activate
    
    pip install --upgrade pip -q
    
    cat > requirements.txt <<'EOF'
python-telegram-bot==13.15
apscheduler>=3.10.0
mysql-connector-python>=8.0.33
EOF
    
    echo_info "نصب packages..."
    pip install -r requirements.txt
    
    echo ""
    read -p "🤖 Bot Token: " BOT_TOKEN
    read -p "👤 User ID: " USER_ID
    read -p "🗄 MySQL User: " DB_USER
    read -sp "🔑 MySQL Pass: " DB_PASS
    echo
    read -p "📊 Database: " DB_NAME
    read -p "🌐 Host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}
    
    cat > config.cfg <<EOF
[DEFAULT]
BOT_TOKEN=$BOT_TOKEN
AUTHORIZED_USER_ID=$USER_ID
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_NAME=$DB_NAME
DB_HOST=$DB_HOST
BACKUP_DIR=/root/backups
EOF
    
    chmod 600 config.cfg
    mkdir -p /root/backups
    
    # دانلود main.py
    curl -fsSL https://raw.githubusercontent.com/Ahmad10611/telegram-backup-bot/main/main.py -o main.py
    
    # سرویس
    cat > /etc/systemd/system/telegram-backup-bot.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable telegram-backup-bot
    systemctl start telegram-backup-bot
    
    sleep 2
    
    if systemctl is-active --quiet telegram-backup-bot; then
        echo_success "✅ نصب موفق!"
        echo_info "لاگ: journalctl -u telegram-backup-bot -f"
    else
        echo_error "خطا در شروع"
        journalctl -u telegram-backup-bot -n 30
    fi
}

main "$@"
