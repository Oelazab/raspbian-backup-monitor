#!/bin/bash

# Backup and Monitoring System
# Author    : Omar El-Azab   
# Conf. file: /etc/bmon.conf
# Script ver: 1.0.0

VERSION="1.0.0"
CONFIG_FILE="/etc/bmon.conf"

# ======================== Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo "Error: Configuration file $CONFIG_FILE not found!"
        echo "Please create configuration file first."
        exit 1
    fi
}


# ======================== init default values
init_defaults() {
    # -------------------------------- Backup settings
    BACKUP_DIRS=("/home/pi" "/etc")
    BACKUP_DEST="/backups"
    BACKUP_PREFIX="backup"
    KEEP_DAILY=7
    KEEP_WEEKLY=4
    KEEP_MONTHLY=12
    
    # -------------------------------- Disk monitoring
    DISK_THRESHOLD=80
    DISK_MONITOR_POINTS=("/" "/home")
    
    # -------------------------------- Log settings
    LOG_FILE="/var/log/backup_monitor.log"
    # 10MB
    MAX_LOG_SIZE=10485760  
    LOG_RETENTION_DAYS=30
    
    # -------------------------------- Email settings
    EMAIL_ENABLED=0
    EMAIL_RECIPIENT=""
    SMTP_SERVER=""
    SMTP_PORT="587"
    SMTP_USER=""
    SMTP_PASSWORD=""
}

# ======================== Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}
