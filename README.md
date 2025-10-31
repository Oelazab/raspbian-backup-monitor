# Raspbian Backup & Monitoring System

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Compatible-red)

Backup and monitoring solution designed and tested for Raspbian systems. Provides automated data protection, system health monitoring, and proactive alerting.

##  Features

### Automated Backups

- **Multi-tier retention** (daily, weekly, monthly)
- **Configurable backup sources** and destinations
- **Compressed archives** with integrity verification
- **Smart rotation policies** to manage storage usage

### System Monitoring

- **Real-time disk usage monitoring** with configurable thresholds
- **Multi-point filesystem monitoring**
- **Historical trend tracking** and reporting
- **Proactive alerting** before critical issues occur

### Log Management

- **Automatic log rotation** with size-based triggers
- **Compressed archiving** of historical logs
- **Configurable retention policies**
- **Structured logging** with multiple severity levels

### Notifications

- **Email alerts** for backup status, disk usage, and system events
- **SMTP integration** with support for major providers
- **Customizable notification templates**
- **Condition-based alerting**

## Quick Start

### Prerequisites

- Raspberry Pi OS (or any Debian-based Linux)
- Bash 4.0 or higher
- Basic utilities: `tar`, `gzip`, `cron`

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/raspbian-backup-monitor.git
cd raspbian-backup-monitor

# Run the setup script (non-root user)
chmod +x scripts/setup_backup_system.sh
./scripts/setup_backup_system.sh
```
