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
    LOG_FILE="/var/log/bmon.log"
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

# ======================== Email notification function
send_email() {
    local subject=$1
    local body=$2
    
    if [[ $EMAIL_ENABLED -eq 0 ]]; then
        return 0
    fi
    
    if ! command -v msmtp &> /dev/null; then
        log "ERROR" "msmtp not installed. Cannot send email."
        return 1
    fi
    
    {
        echo "To: $EMAIL_RECIPIENT"
        echo "From: $SMTP_USER"
        echo "Subject: $subject"
        echo ""
        echo "$body"
    } | msmtp --from="$SMTP_USER" --host="$SMTP_SERVER" --port="$SMTP_PORT" \
              --auth=on --user="$SMTP_USER" --passwordeval="echo $SMTP_PASSWORD" \
              "$EMAIL_RECIPIENT"
    
    if [[ $? -eq 0 ]]; then
        log "INFO" "Email sent successfully: $subject"
    else
        log "ERROR" "Failed to send email: $subject"
    fi
}
# ======================== Disk usage monitoring
monitor_disk_usage() {
    log "INFO" "Starting disk usage monitoring"
    
    local alert_triggered=0
    local disk_info=""
    
    for point in "${DISK_MONITOR_POINTS[@]}"; do
        if [[ -d "$point" ]]; then
            local usage=$(df "$point" | awk 'NR==2 {print $5}' | sed 's/%//')
            local available=$(df -h "$point" | awk 'NR==2 {print $4}')
            
            disk_info+="Mount point: $point - Usage: $usage% - Available: $available\n"
            
            if [[ $usage -ge $DISK_THRESHOLD ]]; then
                alert_triggered=1
                log "WARNING" "High disk usage on $point: $usage% (threshold: $DISK_THRESHOLD%)"
            fi
        else
            log "WARNING" "Mount point $point does not exist"
        fi
    done
    
    # ----------------- Log disk usage statistics
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Disk Usage Report:" >> "${BACKUP_DEST}/disk_usage.log"
    df -h >> "${BACKUP_DEST}/disk_usage.log"
    echo "----------------------------------------" >> "${BACKUP_DEST}/disk_usage.log"
    
    if [[ $alert_triggered -eq 1 ]]; then
        local subject="Disk Usage Alert - $(hostname)"
        local body="High disk usage detected on your system:\n\n$disk_info\n\nPlease take appropriate action."
        send_email "$subject" "$body"
    fi
    
    log "INFO" "Disk usage monitoring completed"
}

# ======================== Backup rotation function
rotate_backups() {
    local backup_type=$1
    local keep_count=$2
    local pattern=$3
    
    log "INFO" "Rotating $backup_type backups, keeping $keep_count"
    
    cd "$BACKUP_DEST" || return 1
    
    # ----------------- List backups matching pattern, sort by date, and remove oldest beyond keep_count
    local backups=($(ls -t ${BACKUP_PREFIX}_${pattern} 2>/dev/null))
    local count=${#backups[@]}
    
    if [[ $count -gt $keep_count ]]; then
        local to_delete=$((count - keep_count))
        log "INFO" "Removing $to_delete old $backup_type backups"
        
        for ((i=keep_count; i<count; i++)); do
            log "INFO" "Removing old backup: ${backups[i]}"
            rm -f "${backups[i]}"
        done
    fi
}

# ======================== Perform backup
perform_backup() {
    local backup_type=$1
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${BACKUP_PREFIX}_${backup_type}_${timestamp}.tar.gz"
    
    log "INFO" "Starting $backup_type backup"
    
    # ----------------- Create backup destination if it doesn't exist
    mkdir -p "$BACKUP_DEST"
    
    # ----------------- Create temporary file list
    local file_list=$(mktemp)
    
    # ----------------- Build list of files to backup
    for dir in "${BACKUP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir" >> "$file_list"
        else
            log "WARNING" "Backup directory $dir does not exist"
        fi
    done
    
    # ----------------- Perform backup
    log "INFO" "Creating backup archive: $backup_file"
    if tar -czf "${BACKUP_DEST}/$backup_file" -T "$file_list" 2>/dev/null; then
        log "INFO" "Backup completed successfully: $backup_file"
        
        # ----------------- Update latest backup symlink
        cd "$BACKUP_DEST"
        ln -sf "$backup_file" "${BACKUP_PREFIX}_latest.tar.gz"
        
        # ----------------- Send success notification
        local backup_size=$(du -h "${BACKUP_DEST}/$backup_file" | cut -f1)
        local subject="Backup Completed - $(hostname)"
        local body="$backup_type backup completed successfully.\n\nBackup file: $backup_file\nSize: $backup_size\nTimestamp: $(date)"
        send_email "$subject" "$body"
    else
        log "ERROR" "Backup creation failed"
        local subject="Backup Failed - $(hostname)"
        local body="$backup_type backup failed. Please check the logs for details."
        send_email "$subject" "$body"
    fi
    
    # ----------------- Cleanup
    rm -f "$file_list"
    
    log "INFO" "$backup_type backup process completed" 
}

# ======================== Log file management
manage_logs() {
    log "INFO" "Starting log file management"
    
    # ----------------- Rotate log file if it exceeds maximum size
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        
        if [[ $log_size -gt $MAX_LOG_SIZE ]]; then
            log "INFO" "Rotating log file (size: $log_size bytes)"
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            mv "$LOG_FILE" "${LOG_FILE}.${timestamp}"
            touch "$LOG_FILE"
            gzip "${LOG_FILE}.${timestamp}"
            
            local subject="Log File Rotated - $(hostname)"
            local body="Log file has been rotated. Old log archived as: ${LOG_FILE}.${timestamp}.gz"
            send_email "$subject" "$body"
        fi
    fi
    
    # ----------------- Clean up old log archives
    find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE").*" -type f -mtime +$LOG_RETENTION_DAYS -delete
    
    log "INFO" "Log file management completed"   
}

# ======================== Automated backup scheduling
automated_backup() {
    local day_of_week=$(date '+%u')  # 1-7
    local day_of_month=$(date '+%d') # 01-31
    
    log "INFO" "Starting automated backup process"
    
    # ----------------- Always perform daily backup
    perform_backup "daily"
    
    # ----------------- Weekly backup on Sundays (day 7)
    if [[ $day_of_week -eq 7 ]]; then
        perform_backup "weekly"
    fi
    
    # ----------------- Monthly backup on 1st of month
    if [[ $day_of_month -eq "01" ]]; then
        perform_backup "monthly"
    fi
    
    # ----------------- Rotate backups
    rotate_backups "daily" "$KEEP_DAILY" "daily_*.tar.gz"
    rotate_backups "weekly" "$KEEP_WEEKLY" "weekly_*.tar.gz"
    rotate_backups "monthly" "$KEEP_MONTHLY" "monthly_*.tar.gz"
    
    log "INFO" "Automated backup process completed"
}

# ======================== Show usage information
show_usage() {
    echo "System Backup and Monitoring Script v$VERSION"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --backup [daily|weekly|monthly]  Perform specific backup"
    echo "  --auto-backup                    Run automated backup (with rotation)"
    echo "  --monitor-disk                   Check disk usage and send alerts"
    echo "  --manage-logs                    Rotate and clean up log files"
    echo "  --all                            Run all tasks (backup, monitor, logs)"
    echo "  --help                           Show this help message"
    echo ""
    echo "Configuration: $CONFIG_FILE"
}


# ======================== Main function
main() {
    # Init defaults and load usr conf
    init_defaults
    load_config
    
    mkdir -p "$(dirname "$LOG_FILE")" # Create if it doesn't exist
    
    case "${1:-}" in
        --backup)
            case "${2:-}" in
                daily|weekly|monthly)
                    perform_backup "$2"
                    ;;
                *)
                    echo "Error: Please specify backup type (daily, weekly, monthly)"
                    exit 1
                    ;;
            esac
            ;;
        --auto-backup)
            automated_backup
            ;;
        --monitor-disk)
            monitor_disk_usage
            ;;
        --manage-logs)
            manage_logs
            ;;
        --all)
            automated_backup
            monitor_disk_usage
            manage_logs
            ;;
        --help)
            show_usage
            ;;
        *)
            echo "Error: No option specified"
            show_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"