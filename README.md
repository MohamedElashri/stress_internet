
# Internet Stress Test Script

This repository contains a script that stress tests your internet connection by downloading ISO files from different mirrors. The script runs between 3 AM and 6 AM daily using `systemd`, without relying on cron jobs.

## Script Overview

### `stress_internet.sh`
This is the main script that:
- Downloads Linux ISO files from multiple mirrors.
- Logs download speed, latency, and system usage to a CSV file in the user's home directory.
- Automatically runs between 3 AM and 6 AM.

### Usage
To run the script manually:

```bash
bash ./stress_internet.sh -m
```

This will execute the script in manual mode and output detailed logs.

## Setting Up the `systemd` Service

To run the script automatically between 3 AM and 6 AM every day, you can set up a `systemd` service and timer.

### 1. Create the Service File

Create a service file at `/etc/systemd/system/iso_stress_test.service`:

```bash
sudo nano /etc/systemd/system/iso_stress_test.service
```

Add the following content, replacing `your_username` with your actual username and adjusting the path to your script:

```ini
[Unit]
Description=ISO Stress Test Service
After=network.target

[Service]
Type=simple
ExecStart=/home/your_username/network/stress_internet.sh
User=your_username
WorkingDirectory=/home/your_username
StandardOutput=journal
StandardError=journal
Restart=on-failure
```

### 2. Create the Timer File

Next, create a timer file at `/etc/systemd/system/iso_stress_test.timer`:

```bash
sudo nano /etc/systemd/system/iso_stress_test.timer
```

Add the following content:

```ini
[Unit]
Description=Run ISO Stress Test Daily from 3AM to 6AM

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
Unit=iso_stress_test.service
WakeSystem=true

[Install]
WantedBy=timers.target
```

### 3. Enable and Start the Timer

After creating both the service and the timer, reload the systemd configuration and enable the timer:

```bash
# Reload systemd to recognize the new service and timer
sudo systemctl daemon-reload

# Enable the timer so it starts automatically at boot
sudo systemctl enable iso_stress_test.timer

# Start the timer now
sudo systemctl start iso_stress_test.timer
```

### 4. Control the Timer and Service

You can control the service and timer with the following commands:

- **Check the status** of the timer:
```bash
sudo systemctl status iso_stress_test.timer
```

- **Check the next scheduled run** of the timer:
```bash
systemctl list-timers --all
```

- **Stop the timer** from running:
```bash
sudo systemctl stop iso_stress_test.timer
```

- **Disable the timer** to prevent it from starting on boot:
```bash
sudo systemctl disable iso_stress_test.timer
```

- **Check the logs** for the service:
```bash
journalctl -u iso_stress_test.service
```

### 5. Removing the Service and Timer

If you no longer want to use the service and timer, you can remove them with the following steps:

1. Stop the timer and disable it:
 ```bash
 sudo systemctl stop iso_stress_test.timer
 sudo systemctl disable iso_stress_test.timer
 ```

2. Remove the service and timer files:
 ```bash
 sudo rm /etc/systemd/system/iso_stress_test.service
 sudo rm /etc/systemd/system/iso_stress_test.timer
 ```

3. Reload the systemd daemon to apply changes:
 ```bash
 sudo systemctl daemon-reload
 ```

## Logs and Data

- **Logs**: All logs are stored in `$HOME/logs/iso_stress_test` with separate logs for each run.
- **CSV Data**: The script stores performance metrics such as CPU usage, memory usage, and download speed in a CSV file for each day.

### Log File Location
- Logs are stored in:
```
~/logs/iso_stress_test/
```

- Example of a CSV log:
```csv
timestamp,iso_name,start_time,end_time,download_speed_MB,latency_sec,iso_size_MB,cpu_usage,mem_usage,disk_usage
1633017600,Ubuntu_22.04,1633017600,1633018200,10.5,600,2500,20.5,30.0,15
```

## License
This project is licensed under the MIT License.

