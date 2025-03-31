#!/bin/bash

# Function to read user input for test duration
read_duration() {
    read -p "Enter the duration for tests in seconds (default is 60s): " duration
    # Set default duration if no input is provided
    if [[ -z "$duration" ]]; then
        duration=60
    fi
}

# Collect user-defined duration for tests
read_duration

# Collect all block devices
BLOCK_DEVICES=$(lsblk -o NAME,TYPE | grep '^nvme\|^sd' | awk '$2=="disk" {print $1}')

# Set the mount point
MOUNT_POINT="/"

# Temporary files to hold the collected data
IOSTAT_TEMP_FILE="iostat_data.tmp"
RAM_TEMP_FILE="ram_usage.tmp"
CPU_TEMP_FILE="cpu_usage.tmp"
SWAP_TEMP_FILE="swap_usage.tmp"
LOAD_TEMP_FILE="load_average.tmp"
NET_RX_TEMP_FILE="net_rx_data.tmp"
NET_TX_TEMP_FILE="net_tx_data.tmp"
SPEEDTEST_TEMP_FILE="speedtest_data.tmp"

# Clear temporary data files
> "$IOSTAT_TEMP_FILE"
> "$RAM_TEMP_FILE"
> "$CPU_TEMP_FILE"
> "$SWAP_TEMP_FILE"
> "$LOAD_TEMP_FILE"
> "$NET_RX_TEMP_FILE"
> "$NET_TX_TEMP_FILE"
> "$SPEEDTEST_TEMP_FILE"

# Function to compute statistics for given data
compute_statistics() {
    local data=("$@")
    local min=${data[0]}
    local max=${data[0]}
    local sum=0
    local count=${#data[@]}

    for value in "${data[@]}"; do
        if (( $(echo "$value < $min" | bc -l) )); then
            min=$value
        fi
        if (( $(echo "$value > $max" | bc -l) )); then
            max=$value
        fi
        sum=$(echo "$sum + $value" | bc)
    done

    mean=$(echo "scale=2; $sum / $count" | bc)
    last=${data[count-1]}

    # Return the statistics
    echo "$min $max $mean $last"
}

# Function to get disk usage percentage
get_disk_usage() {
    local usage=$(df "$MOUNT_POINT" --output=pcent | tail -n 1 | tr -d '% ')
    echo "$usage"
}

# Function to monitor CPU usage and collect data
monitor_cpu_usage() {
    echo "Collecting CPU usage..."
    local end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        echo "$cpu_usage" >> "$CPU_TEMP_FILE"
        sleep 1
    done
}

# Function to monitor RAM usage and collect data
monitor_ram_usage() {
    echo "Collecting RAM usage..."
    local end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do
        ram_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
        echo "$ram_usage" >> "$RAM_TEMP_FILE"
        sleep 1
    done
}

# Function to monitor swap usage and collect data
monitor_swap_usage() {
    echo "Collecting Swap usage..."
    local end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do
        swap_used=$(free | grep Swap | awk '{print $3}')
        swap_total=$(free | grep Swap | awk '{print $2}')

        if [[ "$swap_total" -gt 0 ]]; then
            swap_usage=$(echo "scale=2; ($swap_used/$swap_total) * 100.0" | bc)
        else
            swap_usage=0
        fi
        
        echo "$swap_usage" >> "$SWAP_TEMP_FILE"
        sleep 1
    done
}

# Function to monitor load average and collect data
monitor_load_average() {
    echo "Collecting Load Average..."
    local end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do
        load_avg=$(cat /proc/loadavg | awk '{print $1}')  # 1-minute load average
        echo "$load_avg" >> "$LOAD_TEMP_FILE"
        sleep 1
    done
}

# Function to monitor network usage dynamically using vnstat
monitor_network_usage() {
    echo "Collecting Network Usage..."
    # Get the active network interface
    interface=$(ip -o -4 route show to default | awk '{print $5}')
    
    if [ -z "$interface" ]; then
        echo "No active network interface found."
        return
    fi

    local end_time=$((SECONDS + duration))
    while [ $SECONDS -lt $end_time ]; do  # Collect data continuously for the duration
        vnstat_output=$(vnstat -tr 5 2>/dev/null)  # Run vnstat for 5 seconds 
        # Extract RX and TX values
        rx_mbit=$(echo "$vnstat_output" | grep "rx" | awk '{print $2}')  # Extract RX speed
        tx_mbit=$(echo "$vnstat_output" | grep "tx" | awk '{print $2}')  # Extract TX speed
        
        # Append the values to temporary files
        echo "$rx_mbit" >> "$NET_RX_TEMP_FILE"
        echo "$tx_mbit" >> "$NET_TX_TEMP_FILE"
    done
}

# Start collecting iostat data for each block device
for DEVICE in $BLOCK_DEVICES; do
    echo "Collecting I/O Utilization for /dev/$DEVICE..."
    iostat -x "/dev/$DEVICE" 1 "$duration" | while read -r line; do
        if [[ $line =~ ^$DEVICE ]]; then
            value=$(echo "$line" | awk '{print $23}')  # I/O wait percentage
            if [[ $value =~ ^[0-9]*\.?[0-9]+$ ]]; then
                if (( $(echo "$value > 0" | bc -l) )); then
                    echo "$value:$DEVICE" >> "$IOSTAT_TEMP_FILE"  # Append device info
                fi
            fi
        fi
    done
done &

# Start monitoring CPU usage first
monitor_cpu_usage &

# Start monitoring RAM, Swap, Load Average, and Network usage
monitor_ram_usage &
monitor_swap_usage &
monitor_load_average &
monitor_network_usage &

# Wait for the background processes to finish
wait

# Read the collected data into arrays
mapfile -t iostat_data < "$IOSTAT_TEMP_FILE"
mapfile -t ram_data < "$RAM_TEMP_FILE"
mapfile -t cpu_data < "$CPU_TEMP_FILE"
mapfile -t swap_data < "$SWAP_TEMP_FILE"
mapfile -t load_data < "$LOAD_TEMP_FILE"
mapfile -t net_rx_data < "$NET_RX_TEMP_FILE"
mapfile -t net_tx_data < "$NET_TX_TEMP_FILE"

# Compute disk usage
disk_usage=$(get_disk_usage)

# Function to determine status based on thresholds
determine_status_cpu() {
    local value=$1
    if (( $(echo "$value < 70" | bc -l) )); then
        echo "Good"
    elif (( $(echo "$value >= 70 && $value < 85" | bc -l) )); then
        echo "Warning"
    else
        echo "Critical"
    fi
}

determine_status_ram() {
    local value=$1
    if (( $(echo "$value < 70" | bc -l) )); then
        echo "Good"
    elif (( $(echo "$value >= 70 && $value < 85" | bc -l) )); then
        echo "Warning"
    else
        echo "Critical"
    fi
}

determine_status_swap() {
    local value=$1
    if (( $(echo "$value < 25" | bc -l) )); then
        echo "Good"
    elif (( $(echo "$value >= 25 && $value < 50" | bc -l) )); then
        echo "Warning"
    else
        echo "Critical"
    fi
}

determine_status_load() {
    local load_avg=$1
    local cores=$2
    
    if (( $(echo "$load_avg < $cores" | bc -l) )); then
        echo "Good"
    elif (( $(echo "$load_avg >= $cores && $load_avg <= $(echo "$cores * 1.5" | bc)" | bc -l) )); then
        echo "Warning"
    else
        echo "Critical"
    fi
}

determine_status_disk() {
    local value=$1
    if (( $(echo "$value < 70" | bc -l) )); then
        echo "Good"
    elif (( $(echo "$value >= 70 && $value < 85" | bc -l) )); then
        echo "Warning"
    else
        echo "Critical"
    fi
}

# Initialize performance report
echo "Performance Report"
echo "==================="

# Compute disk usage
disk_usage=$(get_disk_usage)

# Print disk usage
echo ""
echo "Disk Usage (Status: $(determine_status_disk $disk_usage))"
echo "----------"
echo "Usage Percentage: $disk_usage%"
echo ""

# Print RAM usage statistics
if [[ ${#ram_data[@]} -gt 0 ]]; then
    ram_stats=($(compute_statistics "${ram_data[@]}"))
    echo "RAM Usage (Status: $(determine_status_ram ${ram_stats[2]}))"
    echo "---------"
    echo "Min: ${ram_stats[0]}%"
    echo "Max: ${ram_stats[1]}%"
    echo "Mean: ${ram_stats[2]}%"
    echo "Last: ${ram_stats[3]}%"
    echo ""
else
    echo "No data collected for RAM usage."
fi

# Print CPU usage statistics
if [[ ${#cpu_data[@]} -gt 0 ]]; then
    cpu_stats=($(compute_statistics "${cpu_data[@]}"))
    echo "CPU Usage (Status: $(determine_status_cpu ${cpu_stats[2]}))"
    echo "---------"
    echo "Min: ${cpu_stats[0]}%"
    echo "Max: ${cpu_stats[1]}%"
    echo "Mean: ${cpu_stats[2]}%"
    echo "Last: ${cpu_stats[3]}%"
    echo ""
else
    echo "No data collected for CPU usage."
fi

# Print Swap usage statistics
if [[ ${#swap_data[@]} -gt 0 ]]; then
    swap_stats=($(compute_statistics "${swap_data[@]}"))
    echo "Swap Usage (Status: $(determine_status_swap ${swap_stats[2]}))"
    echo "----------"
    echo "Min: ${swap_stats[0]}%"
    echo "Max: ${swap_stats[1]}%"
    echo "Mean: ${swap_stats[2]}%"
    echo "Last: ${swap_stats[3]}%"
    echo ""
else
    echo "No data collected for Swap usage."
fi

# Print Load Average statistics
if [[ ${#load_data[@]} -gt 0 ]]; then
    load_stats=($(compute_statistics "${load_data[@]}"))
    cores=$(nproc)
    echo "Load Average (Status: $(determine_status_load ${load_stats[2]} $cores))"
    echo "------------"
    echo "Min: ${load_stats[0]}"
    echo "Max: ${load_stats[1]}"
    echo "Mean: ${load_stats[2]}"
    echo "Last: ${load_stats[3]}"
    echo ""
else
    echo "No data collected for Load Average."
fi

# Print Network RX statistics
if [[ ${#net_rx_data[@]} -gt 0 ]]; then
    net_rx_stats=($(compute_statistics "${net_rx_data[@]}"))
    echo "Network RX (Mbit/s)"
    echo "---------------------"
    echo "Min: ${net_rx_stats[0]} Mbit/s"
    echo "Max: ${net_rx_stats[1]} Mbit/s"
    echo "Mean: ${net_rx_stats[2]} Mbit/s"
    echo "Last: ${net_rx_stats[3]} Mbit/s"
    echo ""
else
    echo "No data collected for Network RX."
fi

# Print Network TX statistics
if [[ ${#net_tx_data[@]} -gt 0 ]]; then
    net_tx_stats=($(compute_statistics "${net_tx_data[@]}"))
    echo "Network TX (Mbit/s)"
    echo "---------------------"
    echo "Min: ${net_tx_stats[0]} Mbit/s"
    echo "Max: ${net_tx_stats[1]} Mbit/s"
    echo "Mean: ${net_tx_stats[2]} Mbit/s"
    echo "Last: ${net_tx_stats[3]} Mbit/s"
    echo ""
else
    echo "No data collected for Network TX."
fi

# Print iostat statistics if data exists (grouped by device)
if [[ ${#iostat_data[@]} -gt 0 ]]; then
    declare -A io_stats_map

    # Populate the associative array
    for entry in "${iostat_data[@]}"; do
        IFS=':' read -r value device <<< "$entry"
        if [[ -n "$device" ]]; then
            io_stats_map[$device]+="$value "
        fi
    done

    # Loop through devices and print individual statistics
    for device in "${!io_stats_map[@]}"; do
        values=(${io_stats_map[$device]})
        if [[ ${#values[@]} -gt 0 ]]; then
            io_stats=($(compute_statistics "${values[@]}"))
            echo "I/O Utilization for /dev/$device"
            echo "----------------------------------"
            echo "Min: ${io_stats[0]}%"
            echo "Max: ${io_stats[1]}%"
            echo "Mean: ${io_stats[2]}%"
            echo "Last: ${io_stats[3]}%"
            echo ""
        else
            echo "No data collected from iostat for /dev/$device."
        fi
    done
else
    echo "No data collected from iostat."
fi

# Measure download and upload speeds using speedtest-cli for the specified duration
echo "Measuring Bandwidth Speed for $duration seconds..."
end_time=$((SECONDS + duration))
while [ $SECONDS -lt $end_time ]; do
    speedtest_output=$(speedtest-cli --simple 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Unable to connect to Speedtest Host, Try again later."
        break
    else
        download_speed=$(echo "$speedtest_output" | grep 'Download' | awk '{print $2}')
        upload_speed=$(echo "$speedtest_output" | grep 'Upload' | awk '{print $2}')

        # Store results temporarily
        echo "$download_speed" >> "$SPEEDTEST_TEMP_FILE"
        echo "$upload_speed" >> "$SPEEDTEST_TEMP_FILE"
    fi

    # Wait for 10 seconds before the next test
    sleep 10
done

# Compute statistics for download and upload speeds
if [[ -s "$SPEEDTEST_TEMP_FILE" ]]; then
    speed_data=($(cat "$SPEEDTEST_TEMP_FILE"))

    # Separate download and upload statistics
    length=${#speed_data[@]}
    download_data=()
    upload_data=()

    for ((j=0; j<length; j++)); do
        if (( j % 2 == 0 )); then
            download_data+=("${speed_data[j]}")
        else
            upload_data+=("${speed_data[j]}")
        fi
    done

    download_stats=($(compute_statistics "${download_data[@]}"))
    upload_stats=($(compute_statistics "${upload_data[@]}"))

    # Print Download statistics
    echo "Download Speed"
    echo "--------------"
    echo "Min: ${download_stats[0]} Mbps"
    echo "Max: ${download_stats[1]} Mbps"
    echo "Mean: ${download_stats[2]} Mbps"
    echo "Last: ${download_stats[3]} Mbps"
    echo ""

    # Print Upload statistics
    echo "Upload Speed"
    echo "------------"
    echo "Min: ${upload_stats[0]} Mbps"
    echo "Max: ${upload_stats[1]} Mbps"
    echo "Mean: ${upload_stats[2]} Mbps"
    echo "Last: ${upload_stats[3]} Mbps"
    echo ""
else
    echo "No speedtest data collected."
fi

# Clean up temporary files
rm "$IOSTAT_TEMP_FILE" "$RAM_TEMP_FILE" "$CPU_TEMP_FILE" "$SWAP_TEMP_FILE" "$LOAD_TEMP_FILE" "$NET_RX_TEMP_FILE" "$NET_TX_TEMP_FILE" "$SPEEDTEST_TEMP_FILE"
