#!/bin/zsh
################################################################################
# Script Name:       share-qr
# Description:       Instantly share local files over a public URL using 
#                    Python, ngrok, and QR code generation for mobile access.
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      zsh, python3, ngrok, jq, qrencode, feh, sudo
# Hardware:          Requires active internet connection for ngrok tunneling
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# 1. Starts a Python HTTP server on privileged port 80 to serve current directory.
# 2. Initializes an ngrok tunnel to expose port 80 to the public internet.
# 3. Extracts the ephemeral public URL from the ngrok local API using jq.
# 4. Generates a QR code of the URL and displays it via feh for quick scanning.
# 5. Implements a cleanup trap to ensure all background processes are killed
#    upon script termination (CTRL+C or exit).
# ==============================================================================

# Start Python HTTP server in the background on port 80
# Requires sudo to bind to a privileged port (<1024)
sudo python3 -m http.server 80 >/dev/null &
pid_server=$!

# Start ngrok tunnel in the background
ngrok http 80 --log=stdout >/dev/null &
pid_ngrok=$!

# Wait for ngrok to establish connection and initialize local API
sleep 2

# Query ngrok local API to retrieve the dynamically assigned public URL
ngrok_url=$(curl "[http://127.0.0.1:4040/api/tunnels](http://127.0.0.1:4040/api/tunnels)" -s | jq -r '.tunnels[0].public_url')
echo "Cloud URL: $ngrok_url"

# Generate QR code and pipe directly to feh image viewer for display
qrencode -o - -s 16 "$ngrok_url" | feh - >/dev/null &
pid_feh=$!

# Function: cleanup_exit
# Ensures system hygiene by terminating all background PIDs started by the script
cleanup_exit() {
    sudo kill $pid_server 2>/dev/null
    kill $pid_ngrok 2>/dev/null
    kill $pid_feh 2>/dev/null
    echo "Exiting.."
    exit
}

# Trap signals (Interrupt, Termination, Exit) to trigger the cleanup function
trap 'cleanup_exit' INT TERM EXIT

# Keep-alive loop to prevent script exit while services are running
while true; do
    sleep .5
done

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. UNPROTECTED DIRECTORY LISTING: Python's http.server exposes the entire 
#    current directory. Sensitive files in the path are accessible to anyone 
#    with the ngrok URL.
# 2. PRIVILEGE ESCALATION: Script requires sudo for port 80. Risk of command 
#    injection if variables were user-controlled. Recommended: use port >1024.
# 3. PUBLIC EXPOSURE: ngrok tunnels bypass firewalls. Without --basic-auth 
#    configured in ngrok, the data is indexed and reachable by third parties.
# 4. API TRUST: The script trusts the local ngrok API response. In a multi-user 
#    environment, port 4040 could be intercepted by another local process.
# 5. SIGNAL HANDLING: The trap ensures that no "zombie" processes or open 
#    tunnels remain active after the terminal is closed.
# ==============================================================================