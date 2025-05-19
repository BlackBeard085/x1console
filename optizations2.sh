#!/bin/bash

# Comprehensive Performance and System Tuning Script for Ubuntu
# Combines kernel tuning, network optimization, CPU/memory tuning, and advanced latency reduction
# Run as root or with sudo

# Check for root, or run with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# Helper function to safely add unique config lines
safe_add_config() {
  local file="$1"
  local config_line="$2"
  
  # Create file if doesn't exist
  [ ! -f "$file" ] && touch "$file"
  
  # Skip if config line already exists exactly
  grep -qxF "$config_line" "$file" && return
  
  # Remove any existing similar config lines
  config_key="${config_line%%=*}"
  grep -q "^$config_key" "$file" && \
    sed -i "/^$config_key/d" "$file"
  
  # Add new config line
  echo "$config_line" >> "$file"
}

# Function to remove duplicate lines from a config file
remove_duplicate_lines() {
  local file="$1"
  awk '!seen[$0]++' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Function to disable unneeded services
disable_unnecessary_services() {
  echo "Disabling unnecessary services for performance..."
  services=(
    "bluetooth"
    "cups"
    "smbd"
    "nmbd"
    "avahi-daemon"
    "apport"
    "ModemManager"
    "snapd"
  )

  for service in "${services[@]}"; do
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
      echo "Disabling and stopping $service..."
      systemctl disable "$service"
      systemctl stop "$service"
    else
      echo "$service is not enabled or already disabled."
    fi
  done
  echo "Unnecessary services disabled."
}

# Function to enable TCP BBR
enable_bbr() {
  echo "Checking if TCP BBR is enabled..."
  CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
  if [ "$CURRENT_CC" == "bbr" ]; then
    echo "TCP BBR is already enabled."
  else
    echo "Enabling TCP BBR..."
    if ! lsmod | grep -q tcp_bbr; then
      modprobe tcp_bbr
    fi
    sysctl -w net.ipv4.tcp_congestion_control=bbr
    # Persist
    grep -q "^net\.ipv4\.tcp_congestion_control" /etc/sysctl.conf && \
      sed -i "/^net\.ipv4\.tcp_congestion_control/d" /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    # Set default qdisc
    grep -q "^net\.core\.default_qdisc" /etc/sysctl.conf || \
      echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    sysctl -p
    echo "TCP BBR enabled and persistent."
  fi
}

# Function to enable Fair Queuing (FQ)
enable_fq() {
  echo "Enabling Fair Queuing (FQ) on network interfaces..."
  interfaces=$(ls /sys/class/net | grep -v lo)
  for iface in $interfaces; do
    echo "Configuring $iface..."
    tc qdisc replace dev "$iface" root fq 2>/dev/null || \
      echo "Failed to configure FQ on $iface (interface might be down)"
  done
  FQ_SCRIPT="/etc/network/if-up.d/enable-fq"
  cat <<EOF > "$FQ_SCRIPT"
#!/bin/sh
[ "\$IFACE" = "lo" ] && exit 0
for iface in \$(ls /sys/class/net | grep -v lo); do
  tc qdisc replace dev "\$iface" root fq 2>/dev/null
done
EOF
  chmod +x "$FQ_SCRIPT"
  echo "Fair Queuing configured and will persist on network restart."
}

# Function to enable TCP Fast Open
enable_tcp_fast_open() {
  echo "Enabling TCP Fast Open..."
  sysctl -w net.ipv4.tcp_fastopen=3
  # Persist
  grep -q "^net\.ipv4\.tcp_fastopen" /etc/sysctl.conf && \
    sed -i "/^net\.ipv4\.tcp_fastopen/d" /etc/sysctl.conf
  echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
  sysctl -p
  echo "TCP Fast Open enabled."
}

# Function to enable MTU probing
enable_mtu_probe() {
  echo "Enabling MTU path probing..."
  sysctl -w net.ipv4.tcp_mtu_probing=1
  # Persist
  grep -q "^net\.ipv4\.tcp_mtu_probing" /etc/sysctl.conf && \
    sed -i "/^net\.ipv4\.tcp_mtu_probing/d" /etc/sysctl.conf
  echo "net.ipv4.tcp_mtu_probing=1" >> /etc/sysctl.conf
  sysctl -p
  echo "MTU probing enabled."
}

# Function to optimize memory buffers and system tuning
optimize_memory_buffers() {
  echo "Applying memory and buffer tuning..."
  sysctl -w net.core.rmem_max=134217728
  sysctl -w net.core.wmem_max=134217728
  sysctl -w net.core.rmem_default=134217728
  sysctl -w net.core.wmem_default=134217728
  sysctl -w net.ipv4.tcp_rmem='10240 87380 16777216'
  sysctl -w net.ipv4.tcp_wmem='10240 87380 16777216'
  sysctl -w vm.dirty_ratio=15
  sysctl -w vm.dirty_background_ratio=5
  sysctl -w vm.swappiness=1
  sysctl -w vm.vfs_cache_pressure=50
  # Persist all
  cat <<EOF > /etc/sysctl.d/99-performance-tuning.conf
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_default=134217728
net.ipv4.tcp_rmem=10240 87380 16777216
net.ipv4.tcp_wmem=10240 87380 16777216
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.swappiness=1
vm.vfs_cache_pressure=50
EOF
  sysctl --system
  echo "Memory and buffer tuning applied."
}

# Function to set CPU governor to performance (and persist)
set_cpu_governor_performance() {
  echo "Setting CPU governor to performance for all CPUs..."
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    gov_path="$cpu/cpufreq/scaling_governor"
    if [ -f "$gov_path" ]; then
      echo "Setting $gov_path..."
      echo "performance" > "$gov_path" 2>/dev/null || \
        echo "Failed to set performance governor for $cpu (might be offline)"
    fi
  done
  # Make persistent: create a systemd service
  SYSTEMD_SERVICE="/etc/systemd/system/cpu-governor-performance.service"
  cat <<EOF > "$SYSTEMD_SERVICE"
[Unit]
Description=Set CPU governor to performance
After=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for cpu in /sys/devices/system/cpu/cpu[0-9]*; do if [ -f "\$cpu/cpufreq/scaling_governor" ]; then echo performance > "\$cpu/cpufreq/scaling_governor" 2>/dev/null; fi; done'

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now cpu-governor-performance.service
  echo "CPU governor set to performance and made persistent."
}

# Function to install low-latency kernel
install_kernel() {
  echo "Updating package list..."
  apt update -q
  echo "Installing low-latency kernel..."
  apt install -y linux-lowlatency
  if [ $? -ne 0 ]; then
    echo "Failed to install low-latency kernel."
    exit 1
  fi
  echo "Kernel installed, updating GRUB..."
  update-grub
}

# Function to automatically set low-latency kernel as default
set_lowlatency_kernel_default() {
  echo "Setting low-latency kernel as default boot option..."
  
  # Get all menu entries
  menu_entries=$(grep -n -A1 menuentry /boot/grub/grub.cfg | grep -E '^[0-9]+:menuentry|--class')
  
  # Find the low-latency kernel entry
  lowlatency_entry=$(echo "$menu_entries" | grep -i -m1 "lowlatency" -B1)
  
  if [ -z "$lowlatency_entry" ]; then
    echo "Warning: Could not find low-latency kernel in GRUB entries."
    return 1
  fi
  
  # Extract the line number of the menuentry line
  entry_line=$(echo "$lowlatency_entry" | head -n1 | cut -d: -f1)
  
  if [[ "$entry_line" =~ ^[0-9]+$ ]]; then
    # Calculate the GRUB_DEFAULT index (0-based for first level, 1> for submenu)
    grub_index=$((entry_line - 1))
    
    # Check if the entry is in a submenu (contains --class)
    if echo "$lowlatency_entry" | grep -q -- "--class"; then
      # Find the parent menu entry line number
      parent_line=$(grep -n -B$((entry_line+2)) "menuentry" /boot/grub/grub.cfg | grep -v "submenu" | head -n1 | cut -d: -f1)
      if [[ "$parent_line" =~ ^[0-9]+$ ]]; then
        parent_index=$((parent_line - 1))
        grub_index="1>$parent_index>$((entry_line - parent_line - 1))"
      fi
    fi
    
    echo "Setting GRUB_DEFAULT to: $grub_index"
    sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"$grub_index\"/" /etc/default/grub
    update-grub
    echo "Default boot set to low-latency kernel (GRUB_DEFAULT=$grub_index)."
  else
    echo "Warning: Could not determine correct GRUB entry for low-latency kernel."
    return 1
  fi
}

# 1. IRQ Affinity Tuning (Non-overlapping)
tune_irq_affinity() {
  echo "Optimizing IRQ affinity..."
  
  # Systemd service remains independent
  if [ ! -f /etc/systemd/system/set-irq-affinity.service ]; then
    cat <<EOF > /etc/systemd/system/set-irq-affinity.service
[Unit]
Description=Set IRQ Affinity
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for irq in \$(grep -E "eth|enp|ens" /proc/interrupts | awk '\''{print \$1}'\'' | sed '\''s/://'\''); do echo 1 > /proc/irq/\$irq/smp_affinity; done'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now set-irq-affinity.service
  fi

  # Disable irqbalance only if needed
  if systemctl is-enabled irqbalance 2>/dev/null | grep -q enabled; then
    systemctl stop irqbalance
    systemctl disable irqbalance
  fi
}

# 2. Disk I/O Tuning (Non-overlapping)
tune_disk_io() {
  echo "Optimizing disk I/O..."
  
  # udev rules remain independent
  if [ ! -f /etc/udev/rules.d/60-io-scheduler.rules ]; then
    cat <<EOF > /etc/udev/rules.d/60-io-scheduler.rules
# Set none/deadline scheduler for non-rotational disks
ACTION=="add|change", KERNEL=="sd[a-z]|nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
# Set BFQ for rotational disks
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    udevadm control --reload
  fi

  # Only add disk-related settings not present in first script
  safe_add_config "/etc/sysctl.d/99-performance-tuning.conf" "vm.dirty_expire_centisecs = 1000"
  safe_add_config "/etc/sysctl.d/99-performance-tuning.conf" "vm.dirty_writeback_centisecs = 1000"
  
  # Apply settings
  sysctl --system
}

# 3. Network Stack Tuning (Non-overlapping)
tune_network_stack() {
  echo "Optimizing network stack..."
  
  # Systemd service for NIC offloading
  if [ ! -f /etc/systemd/system/disable-nic-offloading.service ]; then
    cat <<EOF > /etc/systemd/system/disable-nic-offloading.service
[Unit]
Description=Disable NIC Offloading Features
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for iface in \$(ls /sys/class/net | grep -v lo); do \
ethtool -K \$iface gro off 2>/dev/null; \
ethtool -K \$iface lro off 2>/dev/null; \
ethtool -K \$iface gso off 2>/dev/null; \
ethtool -K \$iface tso off 2>/dev/null; \
done'

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now disable-nic-offloading.service
  fi

  # Only add network settings not present in first script
  local net_configs=(
    "net.ipv4.tcp_slow_start_after_idle = 0"
    "net.ipv4.tcp_adv_win_scale = 1"
    "net.ipv4.tcp_low_latency = 1"
    "net.ipv4.tcp_sack = 0"
    "net.ipv4.tcp_dsack = 0"
    "net.ipv4.tcp_tw_reuse = 1"
    "net.ipv4.tcp_fin_timeout = 10"
    "net.ipv4.ip_local_port_range = 1024 65535"
  )
  
  for config in "${net_configs[@]}"; do
    safe_add_config "/etc/sysctl.d/99-performance-tuning.conf" "$config"
  done
  sysctl --system
}

# 4. Timer Tuning (Non-overlapping)
tune_timers() {
  echo "Optimizing timers..."
  
  # Clock source configuration (independent)
  if [ -f /sys/devices/system/clocksource/clocksource0/available_clocksource ] && \
     grep -q tsc /sys/devices/system/clocksource/clocksource0/available_clocksource && \
     ! grep -q "clocksource=tsc" /boot/grub/grub.cfg; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&clocksource=tsc /' /etc/default/grub
    update-grub
    echo "tsc" > /sys/devices/system/clocksource/clocksource0/current_clocksource
  fi

  # Only add timer settings not present in first script
  safe_add_config "/etc/sysctl.d/99-performance-tuning.conf" "kernel.hpet = 0"
  safe_add_config "/etc/sysctl.d/99-performance-tuning.conf" "kernel.timer_migration = 0"
  
  sysctl --system
}

# 5. USB Autosuspend Disable (Independent)
disable_usb_autosuspend() {
  echo "Disabling USB autosuspend..."
  
  if [ ! -f /etc/udev/rules.d/80-disable-usb-autosuspend.rules ]; then
    cat <<EOF > /etc/udev/rules.d/80-disable-usb-autosuspend.rules
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
EOF
    udevadm control --reload
    for dev in /sys/bus/usb/devices/*/power/control; do
      echo on > $dev 2>/dev/null
    done
  fi
}

# Main execution
echo "Starting comprehensive system performance tuning..."

# Kernel installation and configuration
install_kernel
set_lowlatency_kernel_default

# Basic system optimizations
enable_bbr
enable_fq
enable_tcp_fast_open
enable_mtu_probe
optimize_memory_buffers
set_cpu_governor_performance
disable_unnecessary_services

# Advanced latency reduction optimizations
tune_irq_affinity
tune_disk_io
tune_network_stack
tune_timers
disable_usb_autosuspend

echo "All optimizations applied successfully."
echo "System requires a reboot to activate all changes."
