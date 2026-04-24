#!/bin/zsh
################################################################################
# Script Name:       bilet-renderer
# Description:       CLI-based viewer for digital transit tickets. Fetches 
#                    raw HTML from the transit provider's portal and renders 
#                    it in the terminal for rapid verification.
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      zsh, curl, w3m
# Hardware:          Requires network access to 89.36.133.118
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# 1. Accepts a unique Ticket ID as a command-line argument.
# 2. Constructs the targeted URL for the vulnerable ASPX endpoint.
# 3. Uses 'curl' with the '-k' (insecure) flag to bypass SSL certificate 
#    verification issues (common on legacy IP-based endpoints).
# 4. Downloads the ticket HTML to a temporary local file.
# 5. Utilizes 'w3m' (text-based web browser) to parse the HTML and render the 
#    ticket content directly into the shell for human readability.
# 6. Ensures local hygiene by removing the temporary file immediately after.
# ==============================================================================

# Check if the Ticket ID argument was provided
if [[ $1 = "" ]];then
    echo "No code"
    exit
fi

# Construct the full endpoint URL using the provided Ticket ID
url="[https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$1](https://89.36.133.118:8451/Tran.aspx?Id=BiletArad_$1)"

# Download the ticket data
# -s: Silent mode (hides progress bar)
# -k: Insecure mode (allows self-signed/invalid SSL certificates)
curl -sk "$url" > /tmp/bilet.html

# Render the HTML to text and output to terminal
# w3m is an excellent choice for converting complex HTML tables to readable text
echo $(w3m /tmp/bilet.html)

# Clean up temporary storage
rm /tmp/bilet.html

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. SSL/TLS VULNERABILITY: The use of 'curl -k' indicates that the server 
#    is likely using an untrusted or expired certificate, exposing the 
#    connection to Potential Man-in-the-Middle (MitM) attacks.
# 2. DATA INGESTION RISK: The script pipes external HTML content into /tmp/ 
#    and then into w3m. While w3m is generally safe, malicious HTML/JS 
#    patterns could theoretically exploit terminal emulators or the browser.
# 3. PII EXPOSURE: The rendered output may contain sensitive user data (names, 
#    payment details, or trip history) which is now stored temporarily in /tmp/.
# 4. PREDICTABLE TEMP FILENAMES: Using a static name like '/tmp/bilet.html' 
#    is susceptible to Symlink attacks. Recommendation: Use 'mktemp' for 
#    creating secure temporary files.
# 5. UNENCRYPTED IP ACCESS: Accessing a server directly via IP instead of a 
#    domain name bypasses certain SNI protections and makes the traffic 
#    easier to profile on the network level.
# ==============================================================================