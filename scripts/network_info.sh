#!/bin/bash
################################################################################
# Script Name:       netinfo
# Description:       Comprehensive network diagnostic tool that enumerates 
#                    interfaces, identifies connection types (WiFi/Ethernet), 
#                    and extracts Gateway, DNS, and Hardware (MAC) details.
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      bash, iproute2, iw, net-tools, nmcli, macchanger, jq, rg
# Hardware:          Works with standard Linux networking stacks (wlan/eth)
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# 1. Scans active network interfaces using netstat and filters for operational links.
# 2. Heuristically determines interface types based on naming conventions (w*, e*).
# 3. Extracts Wireless-specific telemetry (SSID, Frequency, Channel, RSSI).
# 4. Maps Network Layer details (Local IP, Gateway IP, DNS servers).
# 5. Audits Link Layer identity (MAC address) using macchanger.
# 6. Provides stylized CLI output via a dynamic banner generator.
# ==============================================================================

# Reset
NC='\033[0m'            # Text Reset

# Regular Colors
Black='\033[0;30m'      # Black
Red='\033[0;31m'        # Red
Green='\033[0;32m'      # Green
Yellow='\033[0;33m'     # Yellow
Blue='\033[0;34m'       # Blue
Purple='\033[0;35m'     # Purple
Cyan='\033[0;36m'       # Cyan
White='\033[0;37m'      # White

# Bold
BBlack='\033[1;30m'     # Black
BRed='\033[1;31m'       # Red
BGreen='\033[1;32m'     # Green
BYellow='\033[1;33m'    # Yellow
BBlue='\033[1;34m'      # Blue
BPurple='\033[1;35m'    # Purple
BCyan='\033[1;36m'      # Cyan
BWhite='\033[1;37m'     # White

# Function: is_wifi_connected
# Checks if the wlan0 interface is active in the ARP table
is_wifi_connected() {
    if [[ -n $(arp -n|rg 'wlan0') ]]; then
        return 0
    else
        return 1
    fi
}

# Function: is_ethernet_connected
# Checks if the eth0 interface is active in the ARP table
is_ethernet_connected() {
    if [[ -n $(arp -n|rg 'eth0') ]]; then
        return 0
    else
        return 1
    fi
}

# Function: get_bfcr_info
# Collects L1/L2 WiFi metrics: SSID, Frequency, Channel, and Signal Strength (RSSI)
get_bfcr_info() {
    local interface="$1"
    local freq=$(iwgetid -f|awk -F 'Frequency:' '{print $2}')
    local channel=$(iwgetid -c|awk -F 'Channel:' '{print $2}')
    local ssid=$(iwgetid -r)
    local rssi=$(iw dev $interface link|rg signal|awk -F ' ' '{print $2$3}')

    echo -e "SSID:\t\t ${ssid}"
    echo -e "Freq:\t\t ${freq}"
    echo -e "Channel:\t ${channel}"
    echo -e "RSSI:\t\t ${rssi}"
}

# Function: get_gateway_info
# Resolves the default gateway IP and MAC address for a specific interface
get_gateway_info() {
    local interface="$1"
    if [ -n "$interface" ]; then
        local gateway_ip=$(netstat -r -n|rg $interface|head -1|awk -F ' ' '{print $2}')
        local gateway_mac=$(arp -n|rg 'ether'|rg $interface|rg -e "${gateway_ip}\s+"|awk -F ' ' '{print $3}')
        echo -e "Gateway IP:\t ${gateway_ip}"
        echo -e "Gateway MAC:\t ${gateway_mac}"
    else
        return 0
    fi
}

# Function: get_dns_info
# Queries NetworkManager for the IPv4 DNS resolvers associated with the interface
get_dns_info() {
    local interface="$1"
    local dns_list=$(nmcli dev show $interface|rg IP4.DNS)
    while read -r line; do
        local dns_server=$(echo $line|cut -d ':' -f2|awk '{$1=$1;print}')
        local dns_index=$(echo $line|cut -d '[' -f2|cut -d ']' -f1)
        echo -e "DNS ${dns_index}:\t\t ${dns_server}"
    done <<< $dns_list
}

# Function: get_local_info
# Retrieves system hostname, local IP (via ifconfig), and current MAC identity
get_local_info() {
    local interface="$1"
    if [ -n "$interface" ]; then
        local hostname=$(hostname)
        local local_ip=$(ifconfig $interface|rg -o -e "inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}"|sed 's/inet //g')
        local local_mac=$(macchanger -s $interface|sed 's/(unknown)//g'|sed -r 's/MAC:\s*/MAC:\t /g')
        echo -e "Hostname:\t ${hostname}"
        echo -e "Local IP:\t ${local_ip}"
        echo -e "${local_mac}"
    else
        return 0
    fi
}

# Function: get_zerotier_info
# (Placeholder/Incomplete) Parses ZeroTier JSON output for SDN network details
get_zerotier_info() {
    local interface="$1"
    if [ -n "$interface" ]; then
        local zt_full_info=$(sudo zerotier-cli -j listnetworks|jq -r --arg interface "$interface" '.[] | select(.portDeviceName == $interface)')
        # Further parsing logic...
    fi
}

# Function: generate_banner
# UI helper to create standardized, centered visual separators for the CLI output
generate_banner() {
    local string="$1"
    local length="$2"
    local symbol="$3"
    local color="$4"
    local symbol_length=${#symbol}
    local text_length=${#string}
    local remaining_length=$((length - symbol_length * 2 - text_length))
    local half_remaining_length=$((remaining_length / 2))
    local banner=""
    for ((i=0; i<half_remaining_length; i++)); do
        banner+="$symbol"
    done
    if [[ $color == "" ]]; then
        color=$NC
    fi
    banner+=" $color$string$NC "
    for ((i=0; i<half_remaining_length; i++)); do
        banner+="$symbol"
    done
    local total_length=${#banner}
    local remaining_chars=$((length - total_length))
    for ((i=0; i<remaining_chars; i++)); do
        banner+="$symbol"
    done
    echo -e "$banner"
}

# Main Execution Logic
con=0
interfaces=$(netstat -i | rg 'BMRU' | awk -F ' ' '{print $1}')

for interface in $interfaces; do
    first_letter="${interface:0:1}"
    if [ "$first_letter" = "w" ]; then          # Wireless
        generate_banner $interface 40 "=" "$BGreen"
        get_bfcr_info $interface
        get_gateway_info $interface
        get_dns_info $interface
        get_local_info $interface
        con=1
    elif [ "$first_letter" = "e" ]; then        # Ethernet
        generate_banner $interface 40 "=" "$BGreen"
        get_gateway_info $interface
        get_dns_info $interface
        get_local_info $interface
        con=1
    elif [ "${interface:0:2}" = "zt" ]; then    # ZeroTier
        :
    elif [ "$first_letter" = "v" ]; then        # Virtual
        :
    else
        echo "Unknown interface $interface"
    fi
done

if [ $con == 0 ]; then
    echo -e "No connection"
fi

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. ARP SPOOFING RISK: The script relies on 'arp -n' for gateway verification.
#    In an untrusted network, ARP poisoning could feed incorrect MAC data.
# 2. PRIVILEGE ESCALATION: Uses 'sudo' for zerotier-cli and implicit root-level
#    calls for macchanger. Misconfiguration of sudoers could lead to abuse.
# 3. INFORMATION LEAKAGE: Displays sensitive L2 (MAC) and L3 (Internal IP) info.
#    Output should not be redirected to public logs or shared screens.
# 4. TOOL DEPENDENCY: Relies on legacy 'net-tools' (ifconfig/netstat). 
#    Recommendation: Transition to 'iproute2' (ip addr/ip link) for better security.
# 5. INPUT SANITIZATION: Interface names are derived from system output, but
#    manual variable manipulation in the loop could lead to command injection.
# ==============================================================================