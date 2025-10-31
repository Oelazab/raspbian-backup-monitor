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
