#!/bin/bash

# Setup script for Backup and Monitoring System
# Author    : Omar El-Azab
# Script ver: 1.0.0

echo "Setting up Backup and Monitoring System..."

# ======================== Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Error: This script should not be run as root" 
   exit 1
fi

# ======================== Create necessary directories
echo "Creating directories..."
sudo mkdir -p /etc
sudo mkdir -p /var/log
sudo mkdir -p /home/pi/backups

# ============================================== Copy main script
echo "Installing main script..."
sudo cp sys_bm.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/sys_bm.sh

# ============================================== Copy configuration file
echo "Installing configuration file..."
sudo cp bmon.conf /etc/

# ============================================== Create log file
echo "Setting up log file..."
sudo touch /var/log/bmon.log
sudo chown pi:pi /var/log/bmon.log

# ============================================== Install msmtp for email notifications
read -p "Install msmtp for email notifications? (y/n): " install_msmtp
if [[ $install_msmtp == "y" ]]; then
    sudo apt update
    sudo apt install -y msmtp msmtp-mta
    echo "Please configure msmtp separately if needed."
fi

# ============================================== Set up cron jobs
echo "Setting up automated cron jobs..."
(crontab -l 2>/dev/null; echo "# Backup and Monitoring System") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/sys_bm.sh --auto-backup") | crontab -
(crontab -l 2>/dev/null; echo "0 6 * * * /usr/local/bin/sys_bm.sh --monitor-disk") | crontab -
(crontab -l 2>/dev/null; echo "0 0 * * 0 /usr/local/bin/sys_bm.sh --manage-logs") | crontab -

echo "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Edit /etc/bmon.conf with your settings"
echo "2. Test the system with: sys_bm.sh --backup daily"
echo "3. Monitor logs at: /var/log/bmon.log"