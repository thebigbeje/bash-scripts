#!/bin/bash
################################################################################
# Script Name:       lan-scan.sh
# Description:       Scan local network interfaces and identify connected hosts
#                    via ARP and NMAP service discovery
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      bash, ifconfig, netstat, nmap, ripgrep (rg), sed, awk
# Privileges:        Requires nmap (sn = no port scan, uses ARP)
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# Performs network reconnaissance to:
#   1. Enumerate all connected network interfaces (eth*, wlan*)
#   2. Extract local IP and calculate subnet (CIDR /24)
#   3. Query gateway IP from routing table
#   4. Launch nmap ARP-based host discovery
#   5. Highlight local and gateway IPs in colored output
#
# Supports:
#   - Wireless interfaces (wlan*): Full scanning
#   - Ethernet interfaces (eth*): Full scanning
#   - ZeroTier interfaces (zt*): Placeholder (commented out)
#   - Virtual interfaces (veth*): Skipped
#
# Output: Colored list of discovered hosts, highlighting local IP (green) and
#         gateway IP (yellow) for easy identification
# ==============================================================================

# ANSI Color codes for terminal output formatting
set_colors(){
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

    # Bold variants for emphasis
    BBlack='\033[1;30m'     # Bold Black
    BRed='\033[1;31m'       # Bold Red
    BGreen='\033[1;32m'     # Bold Green
    BYellow='\033[1;33m'    # Bold Yellow
    BBlue='\033[1;34m'      # Bold Blue
    BPurple='\033[1;35m'    # Bold Purple
    BCyan='\033[1;36m'      # Bold Cyan
    BWhite='\033[1;37m'     # Bold White
}
set_colors

# Function: scan_local() - Scan network segment for active hosts
# Arguments: $1 = network interface name (e.g., eth0, wlan0)
# Performs ARP ping scan on /24 subnet
scan_local() {
    local interface="$1"
    if [ -n "$interface" ]; then
        # Extract local IP from interface using regex pattern:
        # inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}
        #   inet         : Literal keyword (IPv4 address)
        #   (?:...)      : Non-capturing group for IPv4 octet pattern
        #   [0-9]{1,3}   : 1-3 digits (0-255 range, not validated)
        #   \.           : Literal dot (escaped)
        #   (?:...){3}   : Repeat pattern 3 times (3 octets + final octet)
        # Result: Extracts IP like "192.168.1.50"
        local local_ip=$(ifconfig $interface|rg -o -e "inet (?:[0-9]{1,3}\.){3}[0-9]{1,3}"|sed 's/inet //g')
        
        if [ -n "$local_ip" ]; then
            # Extract gateway IP from routing table output
            # netstat -r -n format: Destination Gateway Genmask Flags...
            # rg $interface: Filter lines containing interface name
            # head -1: Take first route entry
            # awk -F ' ' '{print $2}': Extract 2nd field (gateway column)
            local gateway_ip=$(netstat -r -n|rg $interface|head -1|awk -F ' ' '{print $2}')
            
            # Calculate subnet by replacing last octet with .0
            # awk -F. '{print $1"."$2"."$3".0/24"}'
            #   -F. : Set field separator to dot
            #   $1, $2, $3 : First three octets
            #   ".0/24" : Append .0/24 CIDR notation
            # Example: 192.168.1.50 -> 192.168.1.0/24
            scan_domain=$(echo $local_ip|awk -F. '{print $1"."$2"."$3".0/24"}')
            echo -e "scanning on $scan_domain..\n"
            
            # NMAP Ping Scan Parameters:
            #   -sn              : No port scan (ping only via ARP/ICMP)
            #   -T4              : Aggressive timing (faster scans)
            #   -PR              : ARP ping (most reliable on local networks)
            #   --min-parallelism : Minimum parallel probes (16 = reasonable balance)
            #   --min-hostgroup  : Minimum host group size for parallel ops
            #   --max-retries    : Retry failed probes max 2 times
            #   --host-timeout   : Kill scan for host after 500ms (aggressive)
            # Regex pattern for IP extraction: (?:[0-9]{1,3}\.){3}[0-9]{1,3}
            # Matches any IPv4 address in nmap output
            scan_result=$(nmap -sn -T4 -PR --min-parallelism 16 --min-hostgroup 16 --max-retries 2 --host-timeout 500 $scan_domain 2>/dev/null|rg -o "(?:[0-9]{1,3}\.){3}[0-9]{1,3}")
            
            # Color formatting using sed replacement:
            # sed "s/$local_ip$/..."  : Match local IP and replace with colored version
            # $(echo -e "${BGreen}$local_ip${NC}") : Green colored local IP
            # $ anchor ensures only the last IP match gets colored
            scan_result=$(echo -e "$scan_result"|sed "s/$local_ip$/$(echo -e "${BGreen}$local_ip${NC}")/")
            
            # Color gateway yellow for easy identification in results
            scan_result=$(echo -e "$scan_result"|sed "s/$gateway_ip$/$(echo -e "${BYellow}$gateway_ip${NC}")/")
            echo -e "$scan_result"
        else
            echo -e "interface ${BRed}$interface${NC} not connected properly"
        fi
    else
        return 0
    fi
}

# Function: generate_banner() - Create formatted section headers
# Arguments: $1=text, $2=width, $3=symbol, $4=color
# Generates centered text banner with repeated symbols
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

# Main Logic: Extract interfaces and scan each one
# netstat -i : Show network interface statistics
# rg 'BMRU' : Find lines with flag indicators (matching active interfaces)
# awk -F ' ' '{print $1}' : Extract interface name (first column)
interfaces=$(netstat -i|rg 'BMRU'|awk -F ' ' '{print $1}')

if [ -z "$interfaces" ]; then
    echo -e "No connection"
else
    # Iterate over each interface
    for interface in $interfaces; do
        # Extract first letter to determine interface type
        first_letter="${interface:0:1}"
        if [ "$first_letter" = "w" ]; then
            # Wireless interface (wlan*)
            generate_banner $interface 40 "=" "$BGreen"
            scan_local $interface
        elif [ "$first_letter" = "e" ]; then
            # Ethernet interface (eth*)
            generate_banner $interface 40 "=" "$BGreen"
            scan_local $interface
        elif [ "${interface:0:2}" = "zt" ]; then
            # ZeroTier VLAN interface (zt*) - placeholder for future implementation
            # generate_banner $interface 40 "=" "$BGreen"
            # get_zerotier_info $interface
            :
        elif [ "$first_letter" = "v" ]; then
            # Virtual interface (veth*) - skip as not user-relevant
            :
        else
            echo "Unknown interface $interface"
        fi
    done
fi

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. NMAP USAGE: ARP ping scans are non-intrusive but network administrators
#    may detect reconnaissance activity. Ensure authorization before scanning.
# 2. NETWORK ENUMERATION: Revealing all connected hosts can expose internal
#    network topology. Restrict output visibility on shared systems.
# 3. ARP SPOOFING: This script trusts ARP responses without validation.
#    Attacker-controlled ARP replies could provide false host information.
# 4. GATEWAY IP EXTRACTION: Uses netstat which reads /proc/net/route. Ensure
#    this interface is appropriately protected on multi-user systems.
# 5. REGEX FRAGILITY: IP regex pattern (?:[0-9]{1,3}\.){3}[0-9]{1,3}
#    doesn't validate octet ranges (0-255). May match malformed IPs.
# 6. INTERFACE FILTERING: Assumes interface naming conventions (w*, e*, zt*).
#    Custom interface names may not be detected.
# ==============================================================================

