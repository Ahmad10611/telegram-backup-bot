### Telegram Backup Bot - Detailed Instructions

**Description:**
A Telegram bot for automating the backup of MySQL databases and delivering the backup files directly via Telegram. The bot is designed to schedule regular backups and ensure files are delivered securely using Telegram’s bot API. It supports PM2 to keep the bot running persistently on your Linux server.

### Key Features:
- Backup MySQL databases on a regular schedule.
- Automate file delivery through Telegram.
- Persistent process management with PM2.
- Compatible with major Linux distributions (Debian, Ubuntu, CentOS).

---

### Requirements:
1. A Linux server running **Debian/Ubuntu** or **RHEL/CentOS**.
2. **MySQL** installed and configured.
3. **Python 3.8** or higher.
4. **Node.js** version 16 or higher for managing the bot using **PM2**.
5. Telegram bot token and authorized user ID.

---

### Installation Instructions

#### 1. Clone the Repository
First, clone the bot repository to your server:

```bash
git clone https://github.com/Ahmad10611/telegram-backup-bot.git
cd telegram-backup-bot
```

#### 2. Run the Setup Script
The setup script will install all required dependencies, prompt you for necessary configuration details, and start the bot using **PM2**.

```bash
chmod +x setup.sh
./setup.sh
```

During the setup process, the script will prompt for the following inputs:

- **Telegram bot token**: Get it from [BotFather](https://t.me/BotFather).
- **Authorized user ID**: This is your Telegram numeric user ID. You can find it via Telegram user ID bots like [userinfobot](https://t.me/userinfobot).
- **MySQL username**: The username to access your MySQL database.
- **MySQL password**: The password for the MySQL user.
- **MySQL database name**: The name of the database you want to back up.
- **MySQL database host**: Typically `localhost`.

---

### Example Setup Flow:

```bash
Please enter your Telegram bot token: <YOUR_BOT_TOKEN>
Please enter the authorized user ID (your Telegram numeric ID): <YOUR_USER_ID>
Please enter your MySQL username: <MYSQL_USER>
Please enter your MySQL password: <MYSQL_PASSWORD>
Please enter your MySQL database name: <MYSQL_DATABASE>
Please enter your MySQL database host (e.g., localhost): localhost
```

After providing the necessary details, the script will:

1. Install system dependencies (`Python3.8`, `MySQL client`, `Node.js`, etc.).
2. Install Python libraries (like `mysql-connector-python`, `apscheduler`, `python-telegram-bot`, etc.).
3. Install and configure **PM2** to manage the bot as a persistent process.
4. Start the bot with **PM2**.

---

### Usage

#### Viewing Bot Logs:
To check the logs of the bot (for monitoring or debugging purposes), use the following command:

```bash
pm2 logs telegram-backup-bot
```

#### Stopping the Bot:
To stop the bot at any time:

```bash
pm2 stop telegram-backup-bot
```

#### Restarting the Bot:
To restart the bot:

```bash
pm2 restart telegram-backup-bot
```

#### Viewing Running Processes:
You can check the list of processes managed by **PM2**:

```bash
pm2 list
```

---

### Manual Installation (if setup script is not used):

#### 1. Install System Dependencies
For **Debian/Ubuntu**:
```bash
sudo apt update
sudo apt install -y python3.8 python3.8-venv python3.8-dev python3-pip mariadb-client libmariadb-dev curl nodejs npm
```

For **RHEL/CentOS**:
```bash
sudo yum install -y python3.8 python3.8-venv python3.8-dev python3-pip mariadb curl nodejs npm
```

#### 2. Install Python Libraries
Install the required Python libraries using `pip`:

```bash
pip3 install -r requirements.txt
```

#### 3. Install PM2 and Run the Bot
Install **PM2** globally:

```bash
npm install pm2@latest -g
```

Start the bot using **PM2**:

```bash
pm2 start telegram_bot.py --name telegram-backup-bot
```

Ensure **PM2** starts on system reboot:

```bash
pm2 save
pm2 startup
```

---

### Troubleshooting

- **PM2 logs indicate a syntax error**: Ensure you are using Python 3.8 or higher. Some modern Python syntax (like `f-strings`) may not be compatible with older versions of Python.
- **Bot not sending messages**: Ensure that the Telegram bot token and authorized user ID are correct. You can validate your bot token by checking [BotFather](https://t.me/BotFather).
- **Database connection issues**: Double-check that your MySQL credentials are correct and that the MySQL server is running.

---

### Contribution
Feel free to contribute to the project by submitting issues or pull requests on GitHub. For any questions, refer to the repository documentation or reach out via the issues section.

---

This is how you can set up, run, and manage your Telegram backup bot on a Linux server with automated scheduling and backup delivery.