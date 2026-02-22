#!/usr/bin/env bash
# Robrum OS — Terminal colors

BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Whiptail red theme matching Robrum OS palette
export NEWT_COLORS='
root=,black
window=,black
border=red,black
title=red,black
button=black,red
actbutton=white,darkred
checkbox=red,black
actcheckbox=black,red
entry=white,black
label=red,black
listbox=white,black
actlistbox=black,red
textbox=white,black
acttextbox=black,red
'

info_print ()  { echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"; }
input_print () { echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"; }
error_print () { echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"; }
