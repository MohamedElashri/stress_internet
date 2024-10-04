#!/bin/bash

# Default values
MANUAL_MODE=0

# ANSI color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
RESET='\e[0m'

# Check if -m flag is passed
while getopts "m" opt; do
  case $opt in
    m)
      MANUAL_MODE=1
      ;;
    \?)
      echo -e "${RED}Invalid option: -$OPTARG${RESET}" >&2
      exit 1
      ;;
  esac
done

# Associative array to map short names to URLs
declare -A iso_urls=(
    ["Debian_NetInst"]="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso"
    ["Ubuntu_22.04"]="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-desktop-amd64.iso"
    ["OpenBSD"]="https://ftp.openbsd.org/pub/OpenBSD/7.3/amd64/install73.iso"
    ["Fedora"]="https://d2lzkl7pfhq30w.cloudfront.net/pub/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-40-1.14.iso"
    ["OpenSUSE"]="https://download.opensuse.org/distribution/openSUSE-stable/iso/openSUSE-Leap-15.6-DVD-x86_64-Build710.3-Media.iso"
    ["ArchLinux"]="https://geo.mirror.pkgbuild.com/iso/2024.08.01/archlinux-2024.08.01-x86_64.iso"
    ["Xubuntu_24.04"]="https://cdimage.ubuntu.com/xubuntu/releases/24.04/release/xubuntu-24.04-desktop-amd64.iso"
    ["Debian_Live_Cinnamon"]="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.6.0-amd64-cinnamon.iso"
    ["Debian_Live_KDE"]="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.6.0-amd64-kde.iso"
    ["Debian_Live_Testing"]="https://cdimage.debian.org/cdimage/weekly-live-builds/amd64/iso-hybrid/debian-live-testing-amd64-cinnamon.iso"
)

# Directory to store ISOs temporarily (inside user's home)
iso_dir="$HOME/tmp/iso_downloads"
mkdir -p "$iso_dir"

# Directory to store logs (inside user's home)
log_dir="$HOME/logs/iso_stress_test"
mkdir -p "$log_dir"

# CSV file for logging
csv_file="$log_dir/iso_stress_test_$(date +'%d_%m_%Y').csv"
# Create CSV file and add header if it doesn't exist
if [ ! -f "$csv_file" ]; then
    echo "timestamp,iso_name,start_time,end_time,download_speed_MB,latency_sec,iso_size_MB,cpu_usage,mem_usage,disk_usage" > "$csv_file"
fi

# Max concurrent downloads
MAX_CONCURRENT=5

# Retry limit
RETRY_LIMIT=5

# Function to output log if manual mode is enabled
log_manual() {
    if (( MANUAL_MODE == 1 )); then
        echo -e "${CYAN}$1${RESET}"
    fi
}

# Function to print success messages
log_success() {
    echo -e "${GREEN}$1${RESET}"
}

# Function to print error messages
log_error() {
    echo -e "${RED}$1${RESET}"
}

# Function to print info messages
log_info() {
    echo -e "${YELLOW}$1${RESET}"
}

# Function to get current timestamp
get_timestamp() {
    date +"%s"
}

# Function to get system resource usage
get_system_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    local disk_usage=$(df "$HOME" | tail -1 | awk '{print $5}' | tr -d '%')
    echo "$cpu_usage,$mem_usage,$disk_usage"
}

# Retry logic function
retry_download() {
    local url=$1
    local dest=$2
    local retries=0
    local success=0
    local temp_log_file="$HOME/tmp/download_speed_$$.log"  # Unique temp log file for each process

    while (( retries < RETRY_LIMIT )); do
        log_info "Starting download for $url (attempt $((retries+1)))"
        curl -o "$dest" -L "$url" --silent --write-out "speed_download=%{speed_download}\n" > "$temp_log_file"
        if [[ $? -eq 0 ]]; then
            success=1
            log_success "Download successful for $url"
            break
        else
            log_error "Download failed for $url (attempt $((retries+1))), retrying in 10 seconds..."
            sleep 10
            (( retries++ ))
        fi
    done

    if [[ $success -eq 0 ]]; then
        log_error "Failed to download $url after $RETRY_LIMIT attempts."
        return 1
    fi

    return 0
}

# Function to log the download results
log_download_info() {
    local run_num=$1
    local iso_name=$2
    local start_time=$3
    local end_time=$4
    local temp_log_file="$HOME/tmp/download_speed_$$.log"

    # Parse download speed from curl output and convert to MB/s
    if [[ -f "$temp_log_file" ]]; then
        download_speed=$(grep "speed_download" "$temp_log_file" | awk -F'=' '{print $2}')
        download_speed_MB=$(echo "$download_speed / 1000000" | bc -l)
    else
        log_error "Download speed log file missing for $iso_name"
        download_speed_MB="N/A"
    fi

    local latency=$((end_time - start_time))

    # Get ISO size
    if [[ -f "$iso_file" ]]; then
        iso_size=$(du -m "$iso_file" | cut -f1)
    else
        log_error "ISO file missing for $iso_name"
        iso_size="N/A"
    fi

    local system_usage=$(get_system_usage)

    log_info "Logging download info for $iso_name"

    # Log download and system usage to CSV
    echo "$end_time,$iso_name,$start_time,$end_time,$download_speed_MB,$latency,$iso_size,$system_usage" >> "$csv_file"

    # Clean up temp file
    rm -f "$temp_log_file"
}

# Remove old ISO files before each run
if [ "$(ls -A $iso_dir)" ]; then
    rm -rf $iso_dir/*
    log_info "Old ISO files removed from $iso_dir"
fi

# Main download loop (no need for time window check, timer controls this)
run_num=1
active_downloads=0

for iso_name in "${!iso_urls[@]}"; do
    iso_url="${iso_urls[$iso_name]}"
    iso_file="$iso_dir/$(basename $iso_url)"
    start_time=$(get_timestamp)

    log_manual "Starting download for $iso_name"

    (
        start_download=$(date +%s)
        retry_download "$iso_url" "$iso_file"
        end_download=$(date +%s)
        end_time=$(get_timestamp)

        # Log the download information along with system usage
        log_download_info "$run_num" "$iso_name" "$start_time" "$end_time"

        # Delete the ISO after download
        if [[ -f "$iso_file" ]]; then
            rm -f "$iso_file"
        else
            log_error "ISO file not found: $iso_file"
        fi

        log_manual "Finished download for $iso_name, waiting for next one."

        # Randomized delay between downloads
        sleep $(( RANDOM % 50 + 10 ))

    ) &

    # Limit concurrent downloads
    ((active_downloads++))
    if ((active_downloads >= MAX_CONCURRENT)); then
        log_manual "Waiting for concurrent downloads to finish"
        wait
        active_downloads=0
    fi

    # Increment run number for the next log file
    ((run_num++))
done

# Wait for all remaining background processes to finish
log_manual "Waiting for remaining downloads to complete"
wait
