#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║         Velora OS — Pure-Bash ANSI TUI Library                  ║
# ║         No whiptail. No dialog. Just terminal art.              ║
# ╚══════════════════════════════════════════════════════════════════╝

# ─── Color & Style Constants ─────────────────────────────────────────────────
# True-color sequences (Velora OS palette)
C_BG='\e[48;2;26;26;26m'          # #1a1a1a  background
C_BORDER='\e[38;2;170;12;20m'     # #aa0c14  border / accent
C_ACTIVE='\e[38;2;229;91;91m'     # #e55b5b  active/highlight
C_TEXT='\e[38;2;224;224;224m'     # #e0e0e0  normal text
C_DIM='\e[38;2;100;100;100m'      # dim text
C_GREEN='\e[38;2;80;200;90m'      # success green
C_WHITE='\e[97m'                  # bright white
C_BLINK='\e[5m'
C_BOLD='\e[1m'
C_DIM_STYLE='\e[2m'
C_REVERSE='\e[7m'
C_RESET='\e[0m'

# Row highlight: red bg + white text for selected menu items
SEL_BG='\e[48;2;170;12;20m'
SEL_FG='\e[38;2;255;255;255m'

# ─── Terminal Helpers ─────────────────────────────────────────────────────────
_term_size () {
    COLS=$(tput cols 2>/dev/null || echo 80)
    ROWS=$(tput lines 2>/dev/null || echo 24)
}

ui_goto () {
    # ui_goto row col
    printf '\e[%d;%dH' "$1" "$2"
}

ui_clear () {
    printf '\e[2J\e[H'
}

_save_cursor ()    { printf '\e[s'; }
_restore_cursor () { printf '\e[u'; }

# ─── Terminal Init / Cleanup ──────────────────────────────────────────────────
_UI_OLD_STTY=""
ui_init () {
    _UI_OLD_STTY=$(stty -g 2>/dev/null)
    stty -echo 2>/dev/null
    printf '\e[?25l'   # hide cursor
    trap ui_cleanup EXIT INT TERM
    _term_size
    ui_clear
}

ui_cleanup () {
    stty "$_UI_OLD_STTY" 2>/dev/null || stty echo 2>/dev/null
    printf '\e[?25h'   # show cursor
    printf '\e[0m'     # reset colors
    printf '\n'
}

# ─── Box Drawing ─────────────────────────────────────────────────────────────
# draw_box row col width height [title]
draw_box () {
    local row=$1 col=$2 w=$3 h=$4 title="${5:-}"
    local inner=$((w - 2))
    local r c

    # Top border
    ui_goto "$row" "$col"
    printf "${C_BORDER}${C_BOLD}╔"
    if [[ -n "$title" ]]; then
        local tlen=${#title}
        local pad=$(( (inner - tlen - 2) / 2 ))
        local rpad=$(( inner - tlen - 2 - pad ))
        printf '%*s' "$pad" '' | tr ' ' '═'
        printf "[ ${C_ACTIVE}${title}${C_BORDER} ]"
        printf '%*s' "$rpad" '' | tr ' ' '═'
    else
        printf '%*s' "$inner" '' | tr ' ' '═'
    fi
    printf "╗${C_RESET}\n"

    # Side borders
    for ((r = row + 1; r < row + h - 1; r++)); do
        ui_goto "$r" "$col"
        printf "${C_BORDER}${C_BOLD}║${C_RESET}"
        printf '%*s' "$inner" ''
        ui_goto "$r" "$((col + w - 1))"
        printf "${C_BORDER}${C_BOLD}║${C_RESET}"
    done

    # Bottom border
    ui_goto "$((row + h - 1))" "$col"
    printf "${C_BORDER}${C_BOLD}╚"
    printf '%*s' "$inner" '' | tr ' ' '═'
    printf "╝${C_RESET}"
}

# ─── Header / Logo ───────────────────────────────────────────────────────────
draw_header () {
    _term_size
    local logo_lines=(
        "                      ░██                                "
        "                      ░██                                "
        "░██    ░██  ░███████  ░██  ░███████  ░██░████  ░██████   "
        "░██    ░██ ░██    ░██ ░██ ░██    ░██ ░███           ░██  "
        " ░██  ░██  ░█████████ ░██ ░██    ░██ ░██       ░███████  "
        "  ░██░██   ░██        ░██ ░██    ░██ ░██      ░██   ░██  "
        "   ░███     ░███████  ░██  ░███████  ░██       ░█████░██ "
    )
    local sub="  Velora OS — Operating System Installer  "
    local logo_w=58
    local lpad=$(( (COLS - logo_w) / 2 ))
    [[ $lpad -lt 0 ]] && lpad=0

    ui_goto 1 1
    # Animated character-by-character logo reveal
    for line in "${logo_lines[@]}"; do
        ui_goto $((HEADER_ROW++)) "$lpad"
        printf "${C_BORDER}${C_BOLD}"
        local i
        for ((i=0; i<${#line}; i++)); do
            printf '%s' "${line:$i:1}"
            # Fast reveal — only sleep on certain chars for a sweep effect
            [[ $((i % 6)) -eq 0 ]] && sleep 0.005
        done
        printf "${C_RESET}"
    done

    # Subtitle
    local spad=$(( (COLS - ${#sub}) / 2 ))
    [[ $spad -lt 0 ]] && spad=0
    ui_goto $((HEADER_ROW)) "$spad"
    printf "${C_DIM}${C_DIM_STYLE}%s${C_RESET}" "$sub"
    ((HEADER_ROW++))

    # Horizontal separator
    ui_goto $((HEADER_ROW)) 1
    printf "${C_BORDER}"
    printf '%*s' "$COLS" '' | tr ' ' '─'
    printf "${C_RESET}"
    ((HEADER_ROW++))
}

# ─── Stage Progress Bar ───────────────────────────────────────────────────────
# Stages: 1=Input 2=Disk 3=Install 4=Config 5=Users 6=Post
_STAGE_NAMES=("Input" "Disk" "Install" "Config" "Users" "Post")
_STAGE_BAR_ROW=0   # set by draw_stage_bar after header

draw_stage_bar () {
    local current=$1   # 1-based current stage
    _term_size
    local bar_row=$_STAGE_BAR_ROW
    [[ $bar_row -eq 0 ]] && bar_row=$((HEADER_ROW + 1))

    # Build the inner content
    local inner=""
    local i
    for ((i=0; i<6; i++)); do
        local snum=$((i+1))
        local name="${_STAGE_NAMES[$i]}"
        if [[ $snum -lt $current ]]; then
            # Completed
            inner+=" ${C_GREEN}${C_BOLD}[●] ${name}${C_RESET}${C_DIM} ·${C_RESET}"
        elif [[ $snum -eq $current ]]; then
            # Current — blinking dot
            inner+=" ${C_ACTIVE}${C_BOLD}${C_BLINK}[◉]${C_RESET}${C_ACTIVE}${C_BOLD} ${name}${C_RESET}${C_DIM} ·${C_RESET}"
        else
            # Pending
            inner+=" ${C_DIM}[○] ${name}${C_RESET}${C_DIM} ·${C_RESET}"
        fi
    done

    # Top border of progress bar box
    ui_goto "$bar_row" 1
    printf "${C_BORDER}${C_BOLD}╠"
    printf '%*s' $((COLS - 2)) '' | tr ' ' '═'
    printf "╣${C_RESET}"

    # Content row
    ui_goto $((bar_row + 1)) 1
    printf "${C_BORDER}${C_BOLD}║${C_RESET}"
    # Print centered stages
    printf " STAGES: "
    printf "%b" "$inner"
    # Pad to right border
    ui_goto $((bar_row + 1)) $((COLS))
    printf "${C_BORDER}${C_BOLD}║${C_RESET}"

    # Bottom border
    ui_goto $((bar_row + 2)) 1
    printf "${C_BORDER}${C_BOLD}╠"
    printf '%*s' $((COLS - 2)) '' | tr ' ' '═'
    printf "╣${C_RESET}"

    CONTENT_ROW=$((bar_row + 4))
}

# ─── Stage Transition Animation ───────────────────────────────────────────────
stage_transition () {
    local title="$1"
    _term_size
    local start_row=${CONTENT_ROW:-8}

    # Sweep: draw a solid red line across the content area rows
    local r
    for ((r = start_row; r <= ROWS - 1; r++)); do
        ui_goto "$r" 1
        printf '\e[2K'   # erase line
    done

    # Horizontal wipe animation — left to right red bar
    local sweep_row=$(( (ROWS - start_row) / 2 + start_row ))
    ui_goto "$sweep_row" 1
    printf "${C_BORDER}${C_BOLD}"
    local c
    for ((c=1; c<=COLS; c+=3)); do
        printf '═══'
        sleep 0.004
    done
    printf "${C_RESET}"
    sleep 0.05

    # Erase sweep line
    ui_goto "$sweep_row" 1
    printf '\e[2K'

    # Reveal stage title
    local tpad=$(( (COLS - ${#title}) / 2 ))
    [[ $tpad -lt 0 ]] && tpad=0
    ui_goto "$sweep_row" "$tpad"
    printf "${C_ACTIVE}${C_BOLD}"
    for ((i=0; i<${#title}; i++)); do
        printf '%s' "${title:$i:1}"
        sleep 0.015
    done
    printf "${C_RESET}"
    sleep 0.12

    # One more clear of content area
    for ((r = start_row; r <= ROWS - 1; r++)); do
        ui_goto "$r" 1
        printf '\e[2K'
    done
}

# ─── Content area top row (below stage bar) ───────────────────────────────────
_content_top () {
    echo "${CONTENT_ROW:-8}"
}

# ─── Menu Widget ─────────────────────────────────────────────────────────────
# ui_menu "Title" "label1|desc1" "label2|desc2" ...
# Sets $REPLY to selected label, returns 0 on select, 1 on Esc
ui_menu () {
    local title="$1"; shift
    local items=("$@")
    local n=${#items[@]}
    local labels=() descs=()
    local i

    for item in "${items[@]}"; do
        labels+=("${item%%|*}")
        descs+=("${item#*|}")
    done

    # Size the box
    _term_size
    local max_lbl=0
    for l in "${labels[@]}"; do
        [[ ${#l} -gt $max_lbl ]] && max_lbl=${#l}
    done
    local max_desc=0
    for d in "${descs[@]}"; do
        [[ ${#d} -gt $max_desc ]] && max_desc=${#d}
    done

    local inner_w=$(( max_lbl + max_desc + 7 ))
    [[ $inner_w -lt 50 ]] && inner_w=50
    [[ $inner_w -gt $((COLS - 4)) ]] && inner_w=$((COLS - 4))
    local box_w=$(( inner_w + 2 ))
    local box_h=$(( n + 4 ))   # title row + 1 blank + items + 1 blank + bottom

    local ctop=$(_content_top)
    local box_row=$(( ctop + 1 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1

    local sel=0

    _draw_menu_body () {
        draw_box "$box_row" "$box_col" "$box_w" "$box_h" "$title"
        # Hint line
        ui_goto $((box_row + 1)) $((box_col + 2))
        printf "${C_DIM}  ↑↓ Navigate   Enter Select   Esc Cancel${C_RESET}"
        # Items
        for ((i=0; i<n; i++)); do
            ui_goto $((box_row + 2 + i)) $((box_col + 2))
            if [[ $i -eq $sel ]]; then
                printf "${SEL_BG}${SEL_FG}${C_BOLD} ▶ %-*s  %s ${C_RESET}" \
                    "$max_lbl" "${labels[$i]}" "${descs[$i]}"
            else
                printf "${C_TEXT}   %-*s  ${C_DIM}%s${C_RESET}" \
                    "$max_lbl" "${labels[$i]}" "${descs[$i]}"
            fi
            # Pad to inner_w
            local printed=$(( 3 + max_lbl + 2 + ${#descs[$i]} ))
            local rem=$(( inner_w - printed - 1 ))
            [[ $rem -gt 0 ]] && printf '%*s' "$rem" ''
        done
    }

    _draw_menu_body

    local key esc_seq
    while true; do
        # Read one keypress (including escape sequences for arrows)
        IFS= read -r -s -n1 key
        if [[ "$key" == $'\e' ]]; then
            read -r -s -n2 -t 0.1 esc_seq || true
            case "$esc_seq" in
                '[A') # Up
                    sel=$(( (sel - 1 + n) % n ))
                    _draw_menu_body ;;
                '[B') # Down
                    sel=$(( (sel + 1) % n ))
                    _draw_menu_body ;;
                *) # Plain Esc
                    if [[ -z "$esc_seq" ]]; then
                        REPLY=""
                        return 1
                    fi ;;
            esac
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            REPLY="${labels[$sel]}"
            return 0
        elif [[ "$key" == 'q' || "$key" == 'Q' ]]; then
            REPLY=""
            return 1
        fi
    done
}

# ─── Input Widget ─────────────────────────────────────────────────────────────
# ui_input "Title" "Prompt" [default]
# Sets $REPLY, returns 0 on Enter, 1 on Esc
ui_input () {
    local title="$1" prompt="$2" default="${3:-}"
    local value="$default"

    _term_size
    local box_w=60
    [[ $box_w -gt $((COLS - 4)) ]] && box_w=$((COLS - 4))
    local box_h=7
    local ctop=$(_content_top)
    local box_row=$(( ctop + 2 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1
    local field_w=$(( box_w - 6 ))
    local field_col=$(( box_col + 3 ))
    local field_row=$(( box_row + 4 ))

    _draw_input_body () {
        draw_box "$box_row" "$box_col" "$box_w" "$box_h" "$title"
        ui_goto $((box_row + 2)) $((box_col + 3))
        printf "${C_TEXT}${C_BOLD}%s${C_RESET}" "$prompt"
        ui_goto $((box_row + 3)) $((box_col + 2))
        printf "${C_DIM}%s${C_RESET}" "$(printf '%*s' $((box_w-4)) '' | tr ' ' '─')"
        # Input field box
        ui_goto "$field_row" $((box_col + 2))
        printf "${C_ACTIVE}▸${C_RESET} "
        printf "${C_TEXT}%-*s${C_RESET}" "$field_w" "$value"
        # Cursor hint
        ui_goto $((box_row + 6)) $((box_col + 2))
        printf "${C_DIM}Enter confirm  Esc cancel  Backspace delete${C_RESET}"
    }

    _draw_input_body

    # Enable echo to see cursor blinking in input field; use stty
    stty echo 2>/dev/null
    printf '\e[?25h'  # show cursor

    local key esc_seq
    while true; do
        ui_goto "$field_row" $((box_col + 4))
        printf "${C_TEXT}%-*s${C_RESET}" "$field_w" "$value"
        ui_goto "$field_row" $((box_col + 4 + ${#value}))

        IFS= read -r -s -n1 key
        if [[ "$key" == $'\e' ]]; then
            read -r -s -n2 -t 0.1 esc_seq || true
            if [[ -z "$esc_seq" ]]; then
                stty -echo 2>/dev/null; printf '\e[?25l'
                REPLY=""; return 1
            fi
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            stty -echo 2>/dev/null; printf '\e[?25l'
            REPLY="$value"; return 0
        elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
            # Backspace
            [[ ${#value} -gt 0 ]] && value="${value%?}"
        elif [[ "$key" =~ ^[[:print:]]$ ]]; then
            [[ ${#value} -lt $field_w ]] && value+="$key"
        fi
    done
}

# ─── Password Widget ─────────────────────────────────────────────────────────
# ui_password "Title" "Prompt"
# Sets $REPLY, returns 0 on Enter, 1 on Esc
ui_password () {
    local title="$1" prompt="$2"
    local value=""

    _term_size
    local box_w=60
    [[ $box_w -gt $((COLS - 4)) ]] && box_w=$((COLS - 4))
    local box_h=7
    local ctop=$(_content_top)
    local box_row=$(( ctop + 2 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1
    local field_w=$(( box_w - 6 ))
    local field_row=$(( box_row + 4 ))
    local mask=""

    _draw_pass_body () {
        draw_box "$box_row" "$box_col" "$box_w" "$box_h" "$title"
        ui_goto $((box_row + 2)) $((box_col + 3))
        printf "${C_TEXT}${C_BOLD}%s${C_RESET}" "$prompt"
        ui_goto $((box_row + 3)) $((box_col + 2))
        printf "${C_DIM}%s${C_RESET}" "$(printf '%*s' $((box_w-4)) '' | tr ' ' '─')"
        ui_goto "$field_row" $((box_col + 2))
        printf "${C_ACTIVE}▸${C_RESET} "
        # Build mask string
        mask=""; local j
        for ((j=0; j<${#value}; j++)); do mask+="•"; done
        printf "${C_TEXT}%-*s${C_RESET}" "$field_w" "$mask"
        ui_goto $((box_row + 6)) $((box_col + 2))
        printf "${C_DIM}Enter confirm  Esc cancel  Backspace delete${C_RESET}"
    }

    _draw_pass_body

    stty echo 2>/dev/null
    printf '\e[?25h'

    local key esc_seq
    while true; do
        # Rebuild mask
        mask=""; local j
        for ((j=0; j<${#value}; j++)); do mask+="•"; done
        ui_goto "$field_row" $((box_col + 4))
        printf "${C_TEXT}%-*s${C_RESET}" "$field_w" "$mask"
        ui_goto "$field_row" $((box_col + 4 + ${#value}))

        IFS= read -r -s -n1 key
        if [[ "$key" == $'\e' ]]; then
            read -r -s -n2 -t 0.1 esc_seq || true
            if [[ -z "$esc_seq" ]]; then
                stty -echo 2>/dev/null; printf '\e[?25l'
                REPLY=""; return 1
            fi
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            stty -echo 2>/dev/null; printf '\e[?25l'
            REPLY="$value"; return 0
        elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
            [[ ${#value} -gt 0 ]] && value="${value%?}"
        elif [[ "$key" =~ ^[[:print:]]$ ]]; then
            [[ ${#value} -lt $field_w ]] && value+="$key"
        fi
    done
}

# ─── Confirm Widget ───────────────────────────────────────────────────────────
# ui_confirm "Title" "Message"
# Returns 0 for Yes, 1 for No/Esc
ui_confirm () {
    local title="$1" message="$2"

    _term_size
    local box_w=62
    [[ $box_w -gt $((COLS - 4)) ]] && box_w=$((COLS - 4))
    local box_h=8
    local ctop=$(_content_top)
    local box_row=$(( ctop + 3 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1

    local choice=1   # 0=Yes, 1=No

    _draw_confirm_body () {
        draw_box "$box_row" "$box_col" "$box_w" "$box_h" "$title"
        # Warning icon + message
        ui_goto $((box_row + 2)) $((box_col + 3))
        printf "${C_ACTIVE}${C_BOLD}⚠  ${C_TEXT}%s${C_RESET}" "$message"
        ui_goto $((box_row + 3)) $((box_col + 2))
        printf "${C_DIM}%s${C_RESET}" "$(printf '%*s' $((box_w-4)) '' | tr ' ' '─')"
        # Buttons
        ui_goto $((box_row + 5)) $((box_col + 3))
        if [[ $choice -eq 0 ]]; then
            printf "${SEL_BG}${SEL_FG}${C_BOLD}  [ YES ]  ${C_RESET}   ${C_DIM}[ NO ]${C_RESET}"
        else
            printf "${C_DIM}  [ YES ]${C_RESET}   ${SEL_BG}${SEL_FG}${C_BOLD}  [ NO ]  ${C_RESET}"
        fi
        ui_goto $((box_row + 6)) $((box_col + 2))
        printf "${C_DIM}← → Tab to switch   Enter to confirm   Esc = No${C_RESET}"
    }

    _draw_confirm_body

    local key esc_seq
    while true; do
        IFS= read -r -s -n1 key
        if [[ "$key" == $'\e' ]]; then
            read -r -s -n2 -t 0.1 esc_seq || true
            case "$esc_seq" in
                '[C'|'[D')  # Right / Left
                    choice=$(( 1 - choice ))
                    _draw_confirm_body ;;
                *) [[ -z "$esc_seq" ]] && return 1 ;;
            esac
        elif [[ "$key" == $'\t' ]]; then
            choice=$(( 1 - choice ))
            _draw_confirm_body
        elif [[ "$key" == '' || "$key" == $'\n' ]]; then
            return "$choice"
        elif [[ "$key" == 'y' || "$key" == 'Y' ]]; then
            return 0
        elif [[ "$key" == 'n' || "$key" == 'N' ]]; then
            return 1
        fi
    done
}

# ─── Message Widget ───────────────────────────────────────────────────────────
# ui_message "Title" "Message"
ui_message () {
    local title="$1" message="$2"

    _term_size
    local box_w=64
    [[ $box_w -gt $((COLS - 4)) ]] && box_w=$((COLS - 4))
    local box_h=8
    local ctop=$(_content_top)
    local box_row=$(( ctop + 3 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1

    draw_box "$box_row" "$box_col" "$box_w" "$box_h" "$title"
    ui_goto $((box_row + 2)) $((box_col + 3))
    printf "${C_TEXT}%s${C_RESET}" "$message"
    ui_goto $((box_row + 5)) $((box_col + 3))
    printf "${C_DIM}Press Enter or any key to continue...${C_RESET}"

    IFS= read -r -s -n1 _key
}

# ─── Error Widget ─────────────────────────────────────────────────────────────
# ui_error "Title" "Message"
ui_error () {
    local title="$1" message="$2"

    _term_size
    local box_w=64
    [[ $box_w -gt $((COLS - 4)) ]] && box_w=$((COLS - 4))
    local box_h=8
    local ctop=$(_content_top)
    local box_row=$(( ctop + 3 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1

    # Use active red for error box border by temporarily overriding output
    local orig_border="$C_BORDER"
    C_BORDER="${C_ACTIVE}"
    draw_box "$box_row" "$box_col" "$box_w" "$box_h" "✖ Error: $title"
    C_BORDER="$orig_border"

    ui_goto $((box_row + 2)) $((box_col + 3))
    printf "${C_ACTIVE}${C_BOLD}%s${C_RESET}" "$message"
    ui_goto $((box_row + 5)) $((box_col + 3))
    printf "${C_DIM}Press Enter to retry...${C_RESET}"

    IFS= read -r -s -n1 _key
}

# ─── Progress Gauge Widget ────────────────────────────────────────────────────
_GAUGE_ROW=0
_GAUGE_COL=0
_GAUGE_W=0
_GAUGE_TITLE=""

# ui_gauge_start "Title"
ui_gauge_start () {
    _GAUGE_TITLE="$1"
    _term_size
    _GAUGE_W=66
    [[ $_GAUGE_W -gt $((COLS - 4)) ]] && _GAUGE_W=$((COLS - 4))
    local box_h=8
    local ctop=$(_content_top)
    _GAUGE_ROW=$(( ctop + 3 ))
    _GAUGE_COL=$(( (COLS - _GAUGE_W) / 2 ))
    [[ $_GAUGE_COL -lt 1 ]] && _GAUGE_COL=1

    draw_box "$_GAUGE_ROW" "$_GAUGE_COL" "$_GAUGE_W" "$box_h" "$_GAUGE_TITLE"

    # Empty bar
    local bar_w=$(( _GAUGE_W - 8 ))
    ui_goto $(( _GAUGE_ROW + 3 )) $(( _GAUGE_COL + 3 ))
    printf "${C_DIM}[%*s]${C_RESET}" "$bar_w" ''
    # 0% label
    ui_goto $(( _GAUGE_ROW + 4 )) $(( _GAUGE_COL + 3 ))
    printf "${C_DIM}  0%%${C_RESET}"
}

# ui_gauge_update pct "status text"
ui_gauge_update () {
    local pct=$1 status="${2:-}"
    local bar_w=$(( _GAUGE_W - 8 ))
    local filled=$(( pct * bar_w / 100 ))
    local empty=$(( bar_w - filled ))

    ui_goto $(( _GAUGE_ROW + 3 )) $(( _GAUGE_COL + 3 ))
    printf "${C_BORDER}[${C_RESET}"
    printf "${C_ACTIVE}%*s${C_RESET}" "$filled" '' | tr ' ' '█'
    printf "${C_DIM}%*s${C_RESET}" "$empty" ''
    printf "${C_BORDER}]${C_RESET}"

    # Percentage + status
    ui_goto $(( _GAUGE_ROW + 4 )) $(( _GAUGE_COL + 3 ))
    printf "${C_TEXT}${C_BOLD}%3d%%${C_RESET}  ${C_DIM}%-*s${C_RESET}" \
        "$pct" "$(( _GAUGE_W - 14 ))" "$status"
}

# ui_gauge_end
ui_gauge_end () {
    ui_gauge_update 100 "Done."
    sleep 0.4
    # Clear the gauge area
    local r
    local ctop=$(_content_top)
    for ((r = ctop; r <= _GAUGE_ROW + 9; r++)); do
        ui_goto "$r" 1
        printf '\e[2K'
    done
}

# ─── Status Line Helpers ──────────────────────────────────────────────────────
# These print a status line at the current cursor position (or at CONTENT_ROW)
_STATUS_LINE=${CONTENT_ROW:-8}

ui_status_info () {
    local msg="$1"
    _term_size
    ui_goto "$_STATUS_LINE" 2
    printf '\e[2K'
    printf "${C_BORDER}${C_BOLD}  ●  ${C_TEXT}%s${C_RESET}\n" "$msg"
    (( _STATUS_LINE++ ))
}

ui_status_ok () {
    local msg="$1"
    _term_size
    ui_goto "$_STATUS_LINE" 2
    printf '\e[2K'
    printf "${C_GREEN}${C_BOLD}  ✔  ${C_TEXT}%s${C_RESET}\n" "$msg"
    (( _STATUS_LINE++ ))
}

ui_status_err () {
    local msg="$1"
    _term_size
    ui_goto "$_STATUS_LINE" 2
    printf '\e[2K'
    printf "${C_ACTIVE}${C_BOLD}  ✖  ${C_TEXT}%s${C_RESET}\n" "$msg"
    (( _STATUS_LINE++ ))
}

# ─── Full-screen completion panel ────────────────────────────────────────────
ui_completion_screen () {
    _term_size
    ui_clear

    # Re-draw header without animation
    HEADER_ROW=1
    local logo_lines=(
        "                      ░██                                "
        "                      ░██                                "
        "░██    ░██  ░███████  ░██  ░███████  ░██░████  ░██████   "
        "░██    ░██ ░██    ░██ ░██ ░██    ░██ ░███           ░██  "
        " ░██  ░██  ░█████████ ░██ ░██    ░██ ░██       ░███████  "
        "  ░██░██   ░██        ░██ ░██    ░██ ░██      ░██   ░██  "
        "   ░███     ░███████  ░██  ░███████  ░██       ░█████░██ "
    )
    local logo_w=58
    local lpad=$(( (COLS - logo_w) / 2 ))
    for line in "${logo_lines[@]}"; do
        ui_goto $((HEADER_ROW++)) "$lpad"
        printf "${C_BORDER}${C_BOLD}%s${C_RESET}" "$line"
    done

    # Big green checkmark box
    local box_w=58 box_h=14
    local box_row=$(( (ROWS - box_h) / 2 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_row -lt 7 ]] && box_row=7
    [[ $box_col -lt 1 ]] && box_col=1

    draw_box "$box_row" "$box_col" "$box_w" "$box_h" "Installation Complete"

    # Animated checkmarks
    local checks=("✔" "✔" "✔")
    local msgs=("Base system installed" "Services configured" "Ready to reboot")
    local r=$(( box_row + 2 ))
    for ((i=0; i<3; i++)); do
        sleep 0.3
        ui_goto $((r + i)) $((box_col + 4))
        printf "${C_GREEN}${C_BOLD}  %s  ${C_TEXT}%s${C_RESET}" \
            "${checks[$i]}" "${msgs[$i]}"
    done

    sleep 0.5
    ui_goto $((box_row + 7)) $((box_col + 4))
    printf "${C_DIM}%s${C_RESET}" "$(printf '%*s' $((box_w - 8)) '' | tr ' ' '─')"
    ui_goto $((box_row + 8)) $((box_col + 4))
    printf "${C_TEXT}Your easy-install script is at:${C_RESET}"
    ui_goto $((box_row + 9)) $((box_col + 6))
    printf "${C_ACTIVE}${C_BOLD}~/easy-install/install.sh${C_RESET}"
    ui_goto $((box_row + 10)) $((box_col + 4))
    printf "${C_TEXT}Run it after rebooting to set up your software stack.${C_RESET}"

    ui_goto $((box_row + 12)) $((box_col + 4))
    printf "${C_DIM}Press any key to exit the installer...${C_RESET}"

    IFS= read -r -s -n1 _key
}

# ─── Compact status progress panel (checkpoint resume display) ────────────────
ui_checkpoint_panel () {
    local -n _stages=$1   # nameref to array of stage keys
    local -n _names=$2    # nameref to array of stage display names
    _term_size
    local n=${#_stages[@]}
    local box_w=48
    local box_h=$(( n + 4 ))
    local ctop=$(_content_top)
    local box_row=$(( ctop + 1 ))
    local box_col=$(( (COLS - box_w) / 2 ))
    [[ $box_col -lt 1 ]] && box_col=1

    draw_box "$box_row" "$box_col" "$box_w" "$box_h" "Installation Progress"

    local i
    for ((i=0; i<n; i++)); do
        ui_goto $((box_row + 2 + i)) $((box_col + 4))
        if done_check "${_stages[$i]}"; then
            printf "${C_GREEN}${C_BOLD}  ✔  ${C_TEXT}%s${C_RESET}" "${_names[$i]}"
        else
            printf "${C_DIM}  ○  %s${C_RESET}" "${_names[$i]}"
        fi
    done
    sleep 1.2
}

# ─── Globals for header row tracking ─────────────────────────────────────────
HEADER_ROW=1
CONTENT_ROW=8
