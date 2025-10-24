#!/bin/bash
# setup.sh - نصب خودکار ربات پشتیبان‌گیری تلگرام

set -e

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# توابع کمکی
echo_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
echo_success() { echo -e "${GREEN}✓${NC} $1"; }
echo_error() { echo -e "${RED}✗${NC} $1" >&2; }
echo_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# متغیرهای پیش‌فرض
INSTALL_DIR="${1:-$(pwd)}"
PYTHON_MIN_VERSION="3.7"
REQUIRED_PACKAGES=("curl" "git")

# تابع نمایش banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   نصب ربات پشتیبان‌گیری تلگرام           ║"
    echo "║   Telegram Backup Bot Installer           ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# تشخیص سیستم عامل
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_LIKE=$ID_LIKE
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        OS_VERSION=$(cat /etc/redhat-release | grep -oP '\d+\.\d+' | head -1)
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        OS_VERSION=$(cat /etc/debian_version)
    else
        OS=$(uname -s)
    fi
    
    echo_info "سیستم عامل: $OS $OS_VERSION"
}

# بررسی دسترسی root
check_root() {
    if [ "$EUID" -ne 0 ] && [ "$OS" != "Darwin" ]; then
        echo_warning "برای نصب کامل، اجرا با sudo توصیه می‌شود"
        read -p "ادامه می‌دهید? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# پیدا کردن Python مناسب
find_python() {
    local python_commands=("python3.11" "python3.10" "python3.9" "python3.8" "python3.7" "python3")
    
    for py_cmd in "${python_commands[@]}"; do
        if command -v "$py_cmd" &>/dev/null; then
            local version=$($py_cmd -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null || echo "0.0")
            if awk -v ver="$version" -v min="$PYTHON_MIN_VERSION" 'BEGIN{exit(ver<min)}' 2>/dev/null; then
                echo "$py_cmd"
                return 0
            fi
        fi
    done
    
    return 1
}

# نصب Python
install_python() {
    echo_info "نصب Python 3.8+..."
    
    case $OS in
        ubuntu|debian|linuxmint)
            apt-get update -qq
            apt-get install -y software-properties-common
            
            # اضافه کردن PPA برای نسخه‌های جدید
            if command -v add-apt-repository &>/dev/null; then
                add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null || true
                apt-get update -qq
            fi
            
            apt-get install -y python3.9 python3.9-venv python3.9-dev python3-pip || \
            apt-get install -y python3.8 python3.8-venv python3.8-dev python3-pip || \
            apt-get install -y python3 python3-venv python3-dev python3-pip
            ;;
            
        centos|rhel|rocky|almalinux|fedora)
            local ver_major=$(echo $OS_VERSION | cut -d. -f1)
            
            if [ "$ver_major" -le 7 ]; then
                # CentOS/RHEL 7
                yum install -y epel-release
                yum install -y https://repo.ius.io/ius-release-el7.rpm 2>/dev/null || true
                yum install -y python39 python39-pip python39-devel || \
                yum install -y python38 python38-pip python38-devel
            else
                # CentOS/RHEL 8+
                dnf install -y python39 python39-pip python39-devel || \
                dnf install -y python38 python38-pip python38-devel
            fi
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
            
        Darwin) # macOS
            if command -v brew &>/dev/null; then
                brew install python@3.9 || brew install python@3.8
            else
                echo_error "Homebrew یافت نشد. لطفاً Python 3.8+ را دستی نصب کنید"
                echo_info "https://www.python.org/downloads/"
                exit 1
            fi
            ;;
            
        *)
            echo_error "سیستم عامل پشتیبانی نمی‌شود: $OS"
            echo_info "لطفاً Python 3.8+ را دستی نصب کنید"
            exit 1
            ;;
    esac
    
    echo_success "Python نصب شد"
}

# نصب پیش‌نیازهای سیستمی
install_system_deps() {
    echo_info "نصب پیش‌نیازهای سیستمی..."
    
    case $OS in
        ubuntu|debian|linuxmint)
            apt-get update -qq
            apt-get install -y \
                curl \
                git \
                build-essential \
                default-mysql-client \
                default-libmysqlclient-dev \
                pkg-config \
                2>/dev/null || \
            apt-get install -y \
                curl \
                git \
                build-essential \
                mysql-client \
                libmysqlclient-dev \
                pkg-config
            ;;
            
        centos|rhel|rocky|almalinux|fedora)
            local ver_major=$(echo $OS_VERSION | cut -d. -f1)
            
            if [ "$ver_major" -le 7 ]; then
                yum groupinstall -y "Development Tools"
                yum install -y \
                    curl \
                    git \
                    mariadb \
                    mysql-devel \
                    gcc \
                    gcc-c++ \
                    make
            else
                dnf groupinstall -y "Development Tools"
                dnf install -y \
                    curl \
                    git \
                    mariadb \
                    mysql-devel \
                    gcc \
                    gcc-c++ \
                    make
            fi
            ;;
            
        arch|manjaro)
            pacman -Sy --noconfirm \
                base-devel \
                curl \
                git \
                mariadb-clients \
                mariadb-libs
            ;;
            
        opensuse*|sles)
            zypper install -y \
                curl \
                git \
                gcc \
                gcc-c++ \
                make \
                mariadb-client \
                libmariadb-devel
            ;;
            
        alpine)
            apk add --no-cache \
                curl \
                git \
                build-base \
                mariadb-client \
                mariadb-dev
            ;;
            
        Darwin)
            if command -v brew &>/dev/null; then
                brew install mysql-client pkg-config
            fi
            ;;
    esac
    
    echo_success "پیش‌نیازها نصب شدند"
}

# تابع اصلی نصب
main() {
    show_banner
    
    # تشخیص سیستم عامل
    detect_os
    
    # بررسی root
    check_root
    
    # جابجایی به دایرکتوری نصب
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    echo_info "دایرکتوری نصب: $INSTALL_DIR"
    
    # پیدا کردن یا نصب Python
    echo_info "بررسی Python..."
    PYTHON_CMD=$(find_python) || {
        install_python
        PYTHON_CMD=$(find_python) || {
            echo_error "نصب Python ناموفق بود"
            exit 1
        }
    }
    
    local python_version=$($PYTHON_CMD --version 2>&1)
    echo_success "Python یافت شد: $python_version"
    
    # نصب پیش‌نیازها
    install_system_deps
    
    # ایجاد virtual environment
    echo_info "ایجاد محیط مجازی Python..."
    if [ -d "venv" ]; then
        echo_warning "محیط مجازی از قبل وجود دارد، در حال استفاده مجدد..."
    else
        $PYTHON_CMD -m venv venv
        echo_success "محیط مجازی ایجاد شد"
    fi
    
    # فعال‌سازی venv
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
    elif [ -f "venv/Scripts/activate" ]; then
        source venv/Scripts/activate
    else
        echo_error "فایل activate یافت نشد"
        exit 1
    fi
    
    # آپگرید pip
    echo_info "آپگرید pip..."
    pip install --upgrade pip setuptools wheel -q
    
    # نصب کتابخانه‌های Python
    echo_info "نصب کتابخانه‌های Python..."
    
    if [ ! -f "requirements.txt" ]; then
        cat > requirements.txt <<EOF
python-telegram-bot>=20.0
apscheduler>=3.10.0
mysql-connector-python>=8.0.33
EOF
    fi
    
    pip install -r requirements.txt
    echo_success "کتابخانه‌ها نصب شدند"
    
    # دریافت اطلاعات از کاربر
    echo ""
    echo_info "لطفاً اطلاعات زیر را وارد کنید:"
    echo ""
    
    read -p "🤖 Telegram Bot Token: " BOT_TOKEN
    while [ -z "$BOT_TOKEN" ]; do
        echo_error "Token نمی‌تواند خالی باشد"
        read -p "🤖 Telegram Bot Token: " BOT_TOKEN
    done
    
    read -p "👤 User ID تلگرام شما: " AUTHORIZED_USER_ID
    while [ -z "$AUTHORIZED_USER_ID" ]; do
        echo_error "User ID نمی‌تواند خالی باشد"
        read -p "👤 User ID تلگرام شما: " AUTHORIZED_USER_ID
    done
    
    read -p "🗄 نام کاربری MySQL: " MYSQL_USER
    while [ -z "$MYSQL_USER" ]; do
        echo_error "نام کاربری نمی‌تواند خالی باشد"
        read -p "🗄 نام کاربری MySQL: " MYSQL_USER
    done
    
    read -sp "🔑 رمز عبور MySQL: " MYSQL_PASSWORD
    echo
    while [ -z "$MYSQL_PASSWORD" ]; do
        echo_error "رمز عبور نمی‌تواند خالی باشد"
        read -sp "🔑 رمز عبور MySQL: " MYSQL_PASSWORD
        echo
    done
    
    read -p "📊 نام دیتابیس: " MYSQL_DB
    while [ -z "$MYSQL_DB" ]; do
        echo_error "نام دیتابیس نمی‌تواند خالی باشد"
        read -p "📊 نام دیتابیس: " MYSQL_DB
    done
    
    read -p "🌐 MySQL Host [localhost]: " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-localhost}
    
    read -p "💾 مسیر ذخیره backup [/root/backups]: " BACKUP_DIR
    BACKUP_DIR=${BACKUP_DIR:-/root/backups}
    
    # ایجاد فایل تنظیمات
    echo_info "ایجاد فایل تنظیمات..."
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
    echo_success "فایل تنظیمات ایجاد شد"
    
    # ایجاد دایرکتوری backup
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    
    # تست اتصال (اختیاری)
    echo_info "تست اتصال به MySQL..."
    if command -v mysql &>/dev/null; then
        if mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "USE $MYSQL_DB" 2>/dev/null; then
            echo_success "اتصال به MySQL موفق"
        else
            echo_warning "اتصال به MySQL ناموفق - لطفاً اطلاعات را بررسی کنید"
        fi
    fi
    
    # ایجاد سرویس systemd (Linux)
    if [ "$OS" != "Darwin" ] && command -v systemctl &>/dev/null && [ "$EUID" -eq 0 ]; then
        echo_info "ایجاد سرویس systemd..."
        
        cat > /etc/systemd/system/telegram-backup-bot.service <<EOF
[Unit]
Description=Telegram Backup Bot
After=network.target

[Service]
Type=simple
User=$(whoami)
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
        
        echo_success "سرویس systemd ایجاد شد"
        
        echo ""
        read -p "آیا می‌خواهید سرویس را الان شروع کنید? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            systemctl start telegram-backup-bot.service
            sleep 2
            
            if systemctl is-active --quiet telegram-backup-bot.service; then
                echo_success "سرویس با موفقیت شروع شد"
                echo_info "مشاهده لاگ: journalctl -u telegram-backup-bot -f"
            else
                echo_error "خطا در شروع سرویس"
                echo_info "مشاهده خطا: journalctl -u telegram-backup-bot -n 50"
            fi
        fi
    else
        # ایجاد اسکریپت start
        cat > start.sh <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
source venv/bin/activate
python main.py
EOF
        chmod +x start.sh
        
        echo_success "اسکریپت start.sh ایجاد شد"
        echo_info "برای اجرا: ./start.sh"
    fi
    
    # نمایش اطلاعات نهایی
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         نصب با موفقیت انجام شد!          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo_info "📁 مسیر نصب: $INSTALL_DIR"
    echo_info "💾 مسیر backup: $BACKUP_DIR"
    echo_info "🐍 Python: $($PYTHON_CMD --version)"
    echo ""
    echo_info "دستورات مفید:"
    
    if [ "$OS" != "Darwin" ] && command -v systemctl &>/dev/null && [ "$EUID" -eq 0 ]; then
        echo "  • شروع سرویس:    systemctl start telegram-backup-bot"
        echo "  • توقف سرویس:     systemctl stop telegram-backup-bot"
        echo "  • وضعیت سرویس:    systemctl status telegram-backup-bot"
        echo "  • مشاهده لاگ:     journalctl -u telegram-backup-bot -f"
    else
        echo "  • اجرای ربات:     ./start.sh"
        echo "  • یا:             source venv/bin/activate && python main.py"
    fi
    
    echo ""
    echo_warning "نکات مهم:"
    echo "  • فایل config.cfg حاوی اطلاعات حساس است - از آن محافظت کنید"
    echo "  • برای دریافت User ID تلگرام، @userinfobot را استفاده کنید"
    echo "  • حتماً ربات را با /start در تلگرام فعال کنید"
    echo ""
}

# اجرای تابع اصلی
main "$@"
