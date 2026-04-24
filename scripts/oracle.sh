#!/bin/zsh
################################################################################
# Script Name:       oracle-exam-helper
# Description:       Automated examination assistant. Captures highlighted text, 
#                    sanitizes it for fuzzy regex matching, and queries a local 
#                    database of previously scraped Oracle exam answers.
# Author:            Stefan
# Version:           1.0
# Last Modified:     2026-04-24
# Dependencies:      zsh, xdotool, xsel, ripgrep (rg), sed, libnotify-bin
# Hardware:          Requires X11 environment for xdotool/xsel interaction
################################################################################

# ==============================================================================
# FUNCTIONALITY OVERVIEW
# ==============================================================================
# 1. Mode 1 (Automated Search):
#    - Triggers 'Ctrl+C' via xdotool to copy highlighted question text.
#    - Sanitizes the clipboard content: replaces problematic characters and 
#      newlines with whitespace/regex wildcards to handle varying HTML formats.
#    - Performs a multi-line regex search (-U) across local knowledge base files 
#      (big*.txt) to find the question block and the associated correct answer 
#      marked with (*).
#    - Displays the result via a system notification (notify-send).
# 2. Mode 2 (Visual Bridge):
#    - Copies text, switches windows (Alt+Tab), and automatically invokes the 
#      browser's 'Find' (Ctrl+F) function, typing the query for the user.
# ==============================================================================

if [[ $1 = "" ]]; then exit; fi

# --- Mode 1: Automated Knowledge Base Query ---
if [[ $1 = "1" ]]
then
    # Force copy highlighted text to clipboard
    xdotool keydown ctrl
    xdotool key c
    xdotool keyup ctrl


    # Previous attempts at sanitization involved multiple nested 'sed' and 'rg' calls, which were inefficient and produced too many results. The final approach uses a single complex pipeline to:
	# 1. Replace special characters with '.' to create a more flexible regex pattern.
	# 2. Replace newlines with '\s+' to allow matching across multiple lines in the source files.
	# 3. Use ripgrep's multi-line search (-U) to find the relevant
	#    question block and extract the correct answer marked with (*).
	# 4. Sort results by frequency to prioritize the most likely correct answer.

#	txt=$(w3m "$(rg -A 16 -Ul "$(xsel -ob|sed 's/ /\\s+/g')"|head -1)"|grep "$(xsel -ob)" -A 25|grep -B5 "(\*)"|sed 's/^[ \t]*//;s/[ \t]*$//')	#SLOW AF
#	txt=$(w3m $(rg -A16 -Ul "$(xsel -ob|sed 's/ /\\s+/g')"|sort -u)|grep "$(xsel -ob)" -A25|grep "(\*)" -B3|sed 's/^[ \t]*//;s/[ \t]*$//')		#HIGHLY INEFFICIENT
#	txt=$(export clp=$(xsel -ob|sed 's/ /\\s+/g'|sed 's/[!#$%&()*,-.:]/./g'|sed ':a;N;$!ba;s/\n/\\s+/g');cat ~/websites/oracle/big.txt|rg -A25 -U "$clp"|grep "(\*)" -A 25|awk -F "--" '!x[$0]++'|grep "(\*)" -B5;unset clp)	#TOO MANY RESULTS
#	txt=$(export clp=$(xsel -ob|sed 's/ /\\s+/g'|sed 's/[!#$%&()*,-.:]/./g'|sed ':a;N;$!ba;s/\n/\\s+/g');cat ~/websites/oracle/big.txt|rg -A25 -U "$clp"|rg -UA10 "~answer((.|\n)*)~question"|rg "!.*\(\*\)"|sort|uniq -c|sort -nr;unset clp)
#	txt=$(export clp=$(xsel -ob|sed 's/ /\\s+/g'|sed 's/[\?!#$%&()*,-.:]/./g'|sed ':a;N;$!ba;s/\n/\\s+/g');cat ~/websites/oracle/big.txt|rg -A25 -U "$clp"|rg "!.*\(\*\)"|sort|uniq -c|sort -nr;unset clp)
#	txt=$(export clp=$(xsel -ob|sed 's/[\?!#$%&()*,-.:~]/./g'|sed ':a;N;$!ba;s/\n/\\s+/g'|sed 's/ /\\s+/g');cat ~/websites/oracle/big.txt|rg -UA25 "($clp)"|rg "\(\*\)"|sort|uniq -c|sort -rn;unset clp)


    # Complex Sanitization Pipeline:
    # 1. Replace special symbols with '.' for fuzzy matching.
    # 2. Replace newlines and spaces with '\s+' to handle multi-line question text.
    # 3. Use ripgrep (-U) to find the text block between specific answer/question delimiters.
    # 4. Filter for the correct answer marker '(*)' and sort by frequency.
    txt=$(export clp=$(xsel -ob | sed 's/[\?!#$%&()*,-.:~]/./g' | sed ':a;N;$!ba;s/\n/\\s+/g' | sed 's/ /\\s+/g'); \
          cat ~/big*.txt | rg -UA30 "$clp" | rg -U "(~answer)((.|\n)+?)(~answer)" | \
          sed -r 's/(~question)|(~answer)//g' | rg "\(\*\)" | sort | uniq -c | sort -n; unset clp)
    
    echo $txt
    
    # Feedback loop: Notify user of success or failure
    if [[ $txt = "" ]]
    then
        notify-send -a "Oracle Helper" -t 2000 "Can't find anything"
    else
        notify-send -a "Oracle Helper" -t 6000 $txt
    fi
fi

# --- Mode 2: Quick Search Bridge ---
if [[ $1 = "2" ]]
then
    # Copy selected text
    xdotool keydown ctrl
    xdotool key c
    xdotool keyup ctrl
    query=$(xsel -ob)
    
    # Context switch: Move to next window (browser) and initiate search
    xdotool key alt+Tab
    xdotool keydown ctrl
    xdotool key f
    xdotool keyup ctrl
    sleep .1
    xdotool type $query
fi

# ==============================================================================
# SECURITY CONSIDERATIONS
# ==============================================================================
# 1. INPUT SANITIZATION: The script uses complex nested 'sed' and 'rg' calls. 
#    Maliciously crafted question text (if copied from a compromised source) 
#    could potentially exploit regex engine vulnerabilities or cause DoS.
# 2. UI HIJACKING: 'xdotool' simulates hardware input. If the window focus 
#    changes unexpectedly during execution, the script could type the query 
#    into a sensitive terminal or chat window instead of the intended target.
# 3. PII & DATA PROTECTION: The 'big*.txt' files contain scraped exam data. 
#    Storing this locally without encryption may violate terms of service or 
#    corporate policies regarding internal exam materials.
# 4. CLIPBOARD MONITORING: Using 'xsel -ob' exposes the script to whatever is 
#    currently in the clipboard. Sensitive data (passwords) copied previously 
#    could be inadvertently processed or displayed in notifications.
# 5. AUTOMATION DETECTION: Use of xdotool for rapid input can be detected 
#    by exam proctoring software. From a security standpoint, this tool 
#    demonstrates how client-side automation can bypass simple web constraints.
# ==============================================================================