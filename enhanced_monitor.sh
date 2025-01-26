# System Monitoring and Alert Script. This script can monitor system resources (CPU, memory, disk usage) and send alerts if any resource exceeds a specified threshold. This is practical for keeping an eye on your VM's health and performance.
# Made by Dmitrii Levitskii https://github.com/levitskydv/
# The script uses bc to compare floating-point numbers (e.g., CPU usage, memory usage, so you need bc package to be installed.

#!/bin/bash

# Thresholds (adjust as needed)
CPU_THRESHOLD=80         # CPU usage in %
MEMORY_THRESHOLD=80      # Memory usage in %
SWAP_THRESHOLD=50        # Swap usage in %
DISK_THRESHOLD=90        # Disk usage in %
NETWORK_THRESHOLD=100000 # Network usage in KB (100MB)
PROCESS_NAME="nginx"     # Process to monitor

# Telegram settings
TELEGRAM_BOT_TOKEN="your-telegram-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
TELEGRAM_API_URL="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"

# Log file
LOG_FILE="/var/log/enhanced_monitor.log"
touch "$LOG_FILE"

# SAR report directory
SAR_DIR="/var/log/sar_reports"
mkdir -p "$SAR_DIR"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to send Telegram alerts
send_telegram_alert() {
    local message="$1"
    curl -s -X POST "$TELEGRAM_API_URL" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" \
        -d parse_mode="Markdown" >> /dev/null
}

# Function to generate SAR report
generate_sar_report() {
    local report_file="$SAR_DIR/sar_report_$(date +%Y%m%d_%H%M%S).txt"
    sar -A > "$report_file"
    log_message "SAR report generated: $report_file"
}

# Get CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

# Get swap usage
SWAP_USAGE=$(free | grep Swap | awk '{print $3/$2 * 100.0}')

# Get disk usage
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

# Get network usage (bytes sent/received)
NETWORK_USAGE=$(sar -n DEV 1 1 | grep "Average:" | grep -v "lo" | awk '{print $5 + $6}')

# Get process usage (CPU and memory for a specific process)
PROCESS_USAGE=$(ps aux | grep "$PROCESS_NAME" | grep -v grep | awk '{cpu+=$3; mem+=$4} END {print cpu, mem}')
PROCESS_CPU=$(echo "$PROCESS_USAGE" | awk '{print $1}')
PROCESS_MEM=$(echo "$PROCESS_USAGE" | awk '{print $2}')

# Check CPU usage
if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 *CPU usage is high:* $CPU_USAGE%"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Check memory usage
if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 *Memory usage is high:* $MEMORY_USAGE%"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Check swap usage
if (( $(echo "$SWAP_USAGE > $SWAP_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 *Swap usage is high:* $SWAP_USAGE%"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Check disk usage
if (( $(echo "$DISK_USAGE > $DISK_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 *Disk usage is high:* $DISK_USAGE%"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Check network usage
if (( $(echo "$NETWORK_USAGE > $NETWORK_THRESHOLD" | bc -l) )); then
    MESSAGE="🚨 *Network usage is high:* $NETWORK_USAGE KB"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Check process usage
if (( $(echo "$PROCESS_CPU > 0" | bc -l) )); then
    MESSAGE="ℹ️ *Process $PROCESS_NAME usage:* CPU=$PROCESS_CPU%, MEM=$PROCESS_MEM%"
    log_message "$MESSAGE"
    send_telegram_alert "$MESSAGE"
fi

# Generate SAR report
generate_sar_report
