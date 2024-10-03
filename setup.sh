#!/bin/bash
# Update package list and install dependencies
sudo apt update
sudo apt install -y python3 python3-pip

# Install required Python packages
pip3 install -r requirements.txt

# Setup complete message
echo "Setup complete. You can now run the Telegram bot."
