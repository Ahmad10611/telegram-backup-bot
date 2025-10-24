#!/bin/bash
# setup.sh - نسخه نهایی برای CentOS 7

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

show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   نصب ربات پشتیبان‌گیری تلگرام           ║"
    echo "║   Telegram Backup Bot v2.0                ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

main() {
    show_banner
    
    INSTALL_DIR="/root/telegram-backup-bot"
    
    echo_info "CentOS 7 شناسایی شد"
    echo_warning "شروع نصب Python 3.8 از Software Collections..."
    
    # نصب SCL
    yum install -y centos-release-scl
    yum install -y rh-python38 rh-python38-python-pip rh-python38-python-devel
    
    # ساخت wrapper
    cat > /usr/local/bin/python3.8 <<'EOFPY'
#!/bin/bash
source /opt/rh/rh-python38/enable
exec python3 "$@"
EOFPY
    chmod +x /usr/local/bin/python3.8
    
    echo_success "Python 3.8 نصب شد"
    /usr/local/bin/python3.8 --version
    
    # نصب پیش‌نیازها (بدون mysql-devel)
    echo_info "نصب پیش‌نیازها..."
    yum install -y curl git gcc gcc-c++ make
    
    # ساخت دایرکتوری
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # ساخت venv
    echo_info "ساخت virtual environment..."
    /usr/local/bin/python3.8 -m venv venv
    source venv/bin/activate
    
    # آپگرید pip
    pip install --upgrade pip setuptools wheel
    
    # نصب packages (بدون mysqlclient، فقط mysql-connector-python)
    echo_info "نصب کتابخانه‌های Python..."
    cat > requirements.txt <<'EOF'
python-telegram-bot>=20.0,<21.0
apscheduler>=3.10.0,<4.0
mysql-connector-python>=8.0.33,<9.0
EOF
    
    pip install -r requirements.txt
    
    echo_success "کتابخانه‌ها نصب شدند"
    
    # گرفتن اطلاعات
    echo ""
    echo_info "اطلاعات ربات را وارد کنید:"
    echo ""
    
    read -p "🤖 Telegram Bot Token: " BOT_TOKEN
    read -p "👤 User ID (عددی): " USER_ID
    read -p "🗄 MySQL Username: " DB_USER
    read -sp "🔑 MySQL Password: " DB_PASS
    echo
    read -p "📊 Database Name: " DB_NAME
    read -p "🌐 MySQL Host [localhost]: " DB_HOST
    DB_HOST=${DB_HOST:-localhost}
    
    # ساخت config
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
    echo_info "دانلود فایل‌های ربات..."
    
    cat > main.py <<'EOFMAIN'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import subprocess
import os
import sys
from datetime import datetime
import zipfile
import configparser
from pathlib import Path

if sys.version_info < (3, 7):
    print("❌ Python 3.7+ لازم است")
    sys.exit(1)

try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    from apscheduler.triggers.interval import IntervalTrigger
except ImportError as e:
    print(f"❌ خطا: {e}")
    print("pip install -r requirements.txt")
    sys.exit(1)

config = configparser.ConfigParser()
config.read('config.cfg', encoding='utf-8')

try:
    TELEGRAM_TOKEN = config['DEFAULT']['BOT_TOKEN']
    AUTHORIZED_USER_ID = int(config['DEFAULT']['AUTHORIZED_USER_ID'])
    BACKUP_DIR = config['DEFAULT'].get('BACKUP_DIR', '/root/backups')
    
    db_config = {
        'host': config['DEFAULT']['DB_HOST'],
        'user': config['DEFAULT']['DB_USER'],
        'password': config['DEFAULT']['DB_PASSWORD'],
        'database': config['DEFAULT']['DB_NAME']
    }
except Exception as e:
    print(f"❌ خطا در خواندن config: {e}")
    sys.exit(1)

log_dir = Path(BACKUP_DIR) / "logs"
log_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
log_file = log_dir / f"bot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)
scheduler = AsyncIOScheduler()

def is_authorized(update: Update) -> bool:
    try:
        user_id = update.message.chat_id if update.message else update.callback_query.message.chat_id
        return user_id == AUTHORIZED_USER_ID
    except:
        return False

def find_mysqldump():
    paths = [
        'mysqldump',
        '/usr/bin/mysqldump',
        '/usr/local/mysql/bin/mysqldump',
        '/www/server/mysql/bin/mysqldump'  # BaoTa path
    ]
    
    for path in paths:
        try:
            result = subprocess.run([path, '--version'], capture_output=True, timeout=5)
            if result.returncode == 0:
                logger.info(f"mysqldump: {path}")
                return path
        except:
            continue
    return None

def backup_database():
    try:
        backup_path = Path(BACKUP_DIR)
        backup_path.mkdir(parents=True, mode=0o700, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = backup_path / f"backup_{timestamp}.sql"
        zip_file = backup_path / f"backup_{timestamp}.zip"
        temp_cnf = backup_path / ".my.cnf.tmp"
        
        with open(temp_cnf, 'w') as f:
            f.write(f"[client]\nuser={db_config['user']}\npassword={db_config['password']}\nhost={db_config['host']}\n")
        os.chmod(temp_cnf, 0o600)
        
        mysqldump_cmd = find_mysqldump()
        if not mysqldump_cmd:
            logger.error("mysqldump یافت نشد")
            return None
        
        cmd = [
            mysqldump_cmd,
            f"--defaults-extra-file={temp_cnf}",
            "--single-transaction",
            "--quick",
            db_config['database']
        ]
        
        logger.info(f"Backup: {db_config['database']}")
        
        with open(backup_file, 'w') as f:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True, timeout=300)
        
        if result.returncode != 0:
            logger.error(f"خطا: {result.stderr}")
            temp_cnf.unlink(missing_ok=True)
            backup_file.unlink(missing_ok=True)
            return None
        
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(backup_file, arcname=backup_file.name)
        
        temp_cnf.unlink(missing_ok=True)
        backup_file.unlink(missing_ok=True)
        
        size = zip_file.stat().st_size / (1024 * 1024)
        logger.info(f"✅ موفق: {zip_file.name} ({size:.2f} MB)")
        
        return str(zip_file)
        
    except Exception as e:
        logger.error(f"خطا: {e}")
        return None

async def send_backup(context: ContextTypes.DEFAULT_TYPE, chat_id: int = None):
    target_id = chat_id or AUTHORIZED_USER_ID
    
    try:
        backup_file = backup_database()
        
        if backup_file and os.path.exists(backup_file):
            size = os.path.getsize(backup_file) / (1024 * 1024)
            
            with open(backup_file, 'rb') as f:
                await context.bot.send_document(
                    chat_id=target_id,
                    document=f,
                    caption=f"📦 Backup\n🗓 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n💾 {size:.2f} MB"
                )
            
            logger.info(f"ارسال شد به {target_id}")
        else:
            await context.bot.send_message(target_id, "❌ خطا در backup")
            
    except Exception as e:
        logger.error(f"خطا: {e}")

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update):
        await update.message.reply_text('⛔️ دسترسی ندارید')
        return
    
    keyboard = [
        [InlineKeyboardButton("📦 Backup فوری", callback_data='backup')],
        [InlineKeyboardButton("⏰ زمانبندی", callback_data='schedule')],
        [InlineKeyboardButton("📊 وضعیت", callback_data='status')],
        [InlineKeyboardButton("🗑 حذف", callback_data='clear')]
    ]
    
    await update.message.reply_text(
        "👋 خوش آمدید\n\n"
        "📦 Backup فوری\n"
        "⏰ زمانبندی خودکار\n"
        "📊 وضعیت\n"
        "🗑 حذف زمانبندی",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    if not is_authorized(update):
        return
    
    if query.data == 'backup':
        await query.message.reply_text('⏳ در حال backup...')
        await send_backup(context, query.message.chat_id)
        
    elif query.data == 'schedule':
        await query.message.reply_text('⏰ تعداد دقایق:')
        context.user_data['waiting'] = True
        
    elif query.data == 'status':
        jobs = scheduler.get_jobs()
        if jobs:
            minutes = jobs[0].trigger.interval.total_seconds() / 60
            text = f"✅ فعال\n⏱ هر {minutes:.0f} دقیقه"
        else:
            text = "❌ غیرفعال"
        await query.message.reply_text(text)
        
    elif query.data == 'clear':
        scheduler.remove_all_jobs()
        await query.message.reply_text('✅ حذف شد')

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update) or not context.user_data.get('waiting'):
        return
    
    try:
        minutes = int(update.message.text)
        if minutes < 5:
            await update.message.reply_text('⚠️ حداقل 5 دقیقه')
            return
        
        scheduler.remove_all_jobs()
        scheduler.add_job(send_backup, IntervalTrigger(minutes=minutes), args=(context,), id='job')
        
        await update.message.reply_text(f"✅ تنظیم شد: هر {minutes} دقیقه")
        context.user_data['waiting'] = False
        
    except:
        await update.message.reply_text('❌ عدد وارد کنید')

def main():
    logger.info("شروع ربات")
    
    app = Application.builder().token(TELEGRAM_TOKEN).build()
    
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CallbackQueryHandler(button))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    
    scheduler.start()
    
    logger.info("✅ آماده")
    app.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
EOFMAIN
    
    chmod +x main.py
    
    # ساخت سرویس
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
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       نصب موفق! ✅                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "شروع ربات الان? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl start telegram-backup-bot
        sleep 3
        
        if systemctl is-active --quiet telegram-backup-bot; then
            echo_success "✅ ربات فعال است"
            echo ""
            echo "دستورات:"
            echo "  systemctl status telegram-backup-bot"
            echo "  journalctl -u telegram-backup-bot -f"
        else
            echo_error "خطا"
            journalctl -u telegram-backup-bot -n 20
        fi
    fi
}

main "$@"
