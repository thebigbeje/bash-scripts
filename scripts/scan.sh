#!/bin/bash
################################################################################
# Script Name:       scan.sh
# Description:       Parallel network scanning utility with mode-based operation
#                    for concurrent discovery across multiple interfaces
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      bash, nmap, netstat, ripgrep (rg), ifconfig, awk, sed
# Privileges:        Requires nmap execution capabilities
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# Implements parallel network scanning mode (Mode 1):
#   1. Enumerate all connected network interfaces (eth*, wlan*)
#   2. Launch concurrent nmap ARP ping scans on each interface's subnet
#   3. Collect results in associative array
#   4. Display results per-interface with colored highlighting
#
# Key Feature: Background job processing with 'wait' ensures all scans
# complete before displaying results, enabling true parallel operation.
#
# Interface Detection:
#   - Wireless: wlan* (WiFi interfaces)
#   - Ethernet: eth* (Wired interfaces)
#   - Ignored: veth* (virtual), zt* (ZeroTier - placeholder)
# ==============================================================================

# ANSI Color codes
set_colors(){
    # Reset
    NC='\033[0m'         # Text Reset

    # Regular Colors
    Green='\033[0;32m'   # Green
    Yellow='\033[0;33m'  # Yellow
    Red='\033[0;31m'     # Red
}
set_colors

# Function: scan_local() - Scan network segment on interface
# Arguments:
#   $1 = interface name (eth0, wlan0, etc.)
#   $2 = variable name to store results (for bash associative array assignment)
#
# Returns: Populates passed variable with colored list of discovered IPs
scan_local() {
    local interface="$1"
    local result_var="$2"

    if [ -n "$interface" ]; then
        # Extract local IP using regex pattern:
        # inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}
        #   inet         : Literal keyword preceding IPv4 address
        #   (?:...)      : Non-capturing group for efficient matching
        #   [0-9]{1,3}   : 1-3 digits per octet
        #   \.           : Escaped literal dot
        #   (?:...){3}   : Repeat octet pattern 3 times
        # Matches: 192.168.1.50 from output like "inet 192.168.1.50 netmask..."
        local local_ip=$(ifconfig $interface|rg -o -e "inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}"|sed 's/inet //g')
        
        if [ -n "$local_ip" ]; then
            # Extract gateway IP from routing table
            # netstat -r -n outputs routing table in numeric form
            # rg $interface: Filter rows for this interface
            # head -1: Select first matching route (default route)
            # awk -F ' ' '{print $2}': Extract 2nd column (gateway IP)
            local gateway_ip=$(netstat -r -n|rg $interface|head -1|awk -F ' ' '{print $2}')
            
            # Calculate subnet CIDR notation
            # awk -F. : Split on dots
            # $1"."$2"."$3".0/24" : First 3 octets + .0/24
            # Converts 192.168.1.50 -> 192.168.1.0/24
            local scan_domain=$(echo $local_ip | awk -F. '{print $1"."$2"."$3".0/24"}')

            echo -e "Scanning on $scan_domain for $interface..\n"
            
            # NMAP Parameters:
            #   -sn              : Ping scan (no port scans)
            #   -T3              : Normal timing (moderate speed/resource usage)
            #   -PR              : ARP ping protocol (most reliable for local networks)
            #   --min-parallelism 16 : Minimum concurrent probe threads
            #   --min-hostgroup  : Process hosts in groups of 16
            #   --max-retries 2  : Retry failed probes up to 2 times
            #   --host-timeout 500 : Timeout each host after 500ms
            #
            # Output filtering:
            #   2>/dev/null      : Suppress stderr and progress output
            #   rg -o "(?:[0-9]{1,3}\.){3}[0-9]{1,3}" : Extract all IPv4 addresses
            local scan_result=$(nmap -sn -T3 -PR --min-parallelism 16 --min-hostgroup 16 --max-retries 2 --host-timeout 500 $scan_domain 2>/dev/null|rg -o "(?:[0-9]{1,3}\.){3}[0-9]{1,3}")

            # Color local and gateway IPs for visual identification
            # sed "s/PATTERN/REPLACEMENT/" : Substitution command
            # Each sed call replaces first occurrence of IP with colored version
            scan_result=$(echo "$scan_result" | sed "s/$local_ip/${Green}$local_ip${NC}/")
            scan_result=$(echo "$scan_result" | sed "s/$gateway_ip/${Yellow}$gateway_ip${NC}/")

            # Store result in variable passed by name
            # eval command allows storing in variable whose name is in $result_var
            eval "$result_var=\"$scan_result\""
        else
            echo -e "Interface ${Red}$interface${NC} not connected properly."
        fi
    fi
}

# Function: mode1_scan() - Parallel scanning mode
# Enumerate interfaces, launch background scans, wait for completion, display results
mode1_scan() {
    # Extract network interface names from netstat interface listing
    # netstat -i        : Show interface statistics
    # rg 'BMRU'         : Find lines with flags (active interfaces)
    # awk -F ' ' '{print $1}' : Extract first column (interface name)
    # rg '^e|^w'        : Filter for ethernet (^e) or wireless (^w) interfaces
    local interfaces=$(netstat -i|rg 'BMRU'|awk -F ' ' '{print $1}'|rg '^e|^w')
    
    echo $interfaces
    
    # Declare associative array to store results per interface
    # Syntax: declare -A variable_name
    declare -A results

    # Launch background scan jobs (parallel execution)
    # & : Runs process in background
    # Each scan_local call runs concurrently
    for interface in "${interfaces[@]}"; do
        scan_local "$interface" "results[$interface]" &
        echo "scanning on interface $interface.."
    done
    
    echo "done loop scan start"
    
    # Block until all background jobs complete
    # wait command without arguments waits for all child processes
    wait
    echo "done waiting"
    
    # Display collected results
    # ${!array[@]} : Get all keys (interface names) from array
    for interface in "${!results[@]}"; do
        echo "showing results for $interface"
        echo -e "\nResults for $interface:\n"
        echo -e "${results[$interface]}\n"
    done
}

# Execute main scanning mode
mode1_scan

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. NMAP SCANNING: ARP pings are non-intrusive but may trigger network
#    monitoring/alerting systems. Ensure proper authorization before use.
# 2. PRIVILEGE REQUIREMENTS: Nmap requires elevated privileges for ARP ping
#    (-PR requires libpcap/raw socket access).
# 3. PARALLEL RESOURCE USAGE: --min-parallelism 16 can consume significant
#    network bandwidth and CPU. Monitor on resource-constrained systems.
# 4. INFORMATION DISCLOSURE: Results reveal complete network topology.
#    Restrict script output visibility on multi-user systems.
# 5. REGEX PATTERN: IPv4 regex doesn't validate octet ranges (0-255).
#    May incorrectly match malformed addresses like 999.999.999.999.
# 6. TIMING PARAMETERS: --host-timeout 500ms is aggressive and may miss
#    slow/distant hosts. Adjust for unstable networks.
# 7. BACKGROUND JOBS: Race conditions possible if interface configuration
#    changes during scan. Consider adding interface validation.
# ==============================================================================

