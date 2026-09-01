#!/bin/bash

# =======================================
# Retroarch Manager v1.1
# by djparent
# =======================================

# Copyright (c) 2026 djparent
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# =======================================================
# Root privileges check
# =======================================================
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# =======================================================
# Initialization
# =======================================================
export TERM=linux

# =======================================================
# Variables
# =======================================================
GPTOKEYB_PID=""
CURR_TTY="/dev/tty1"
TMP_KEYS="/tmp/keys.gptk.$$"
ES_SYSTEMS="/etc/emulationstation/es_systems.cfg"
CRD_FILE="/home/ark/.config/savesync.crd"
SYNC_SCRIPT="/usr/local/bin/savesync.sh"
FLAG_FILE="/home/ark/.savesync"
GAMEEND_HOOK="/home/ark/.emulationstation/scripts/game-end/savesync.sh"
SERVICE_FILE="/etc/systemd/system/savesync.service"
RA64="/home/ark/.config/retroarch"
RA32="/home/ark/.config/retroarch32"
RA64_CFG="$RA64/retroarch.cfg"
LOG_FILE="/home/ark/.config/savesync.log"


T_BACKTITLE="Retroarch Manager v1.1"
T_STARTING="Starting $T_BACKTITLE please wait..."
T_MAIN_TITLE="Main Menu"
T_SAVE_LOCATION="Save Location"
T_LOCATION="Current location:"
T_STATUS="Choose new location for game saves:"
T_WAIT="Please wait..."
T_EXIT="Exit"
T_SAVE_LOC="content folders"
T_FOLDER_LOC="saves folder"
T_SAVE="Retroarch Folder (/retroarch/saves)"
T_FOLDER="Game Content Folders (/roms/gb)"
T_COPY="Copying files..."
T_SSYNC="SaveSync"
T_CRED="Enter Credentials"
T_MANUAL="Synchronize Now"
T_LOG="View Log"
T_IP="NetBIOS or IP"
T_NAME="Username"
T_PASS="Password"
T_PATH="Network Path"
T_SELECT="Please make a selection:"

# =======================================================
# Start gamepad input
# =======================================================
Start_GPTKeyb() {
    pkill -9 -f gptokeyb 2>/dev/null || true
    if [ -n "${GPTOKEYB_PID:-}" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
    fi
    sleep 0.1
	/opt/inttools/gptokeyb -1 "$0" -c "$TMP_KEYS" > /dev/null 2>&1 &
    GPTOKEYB_PID=$!
}

# =======================================================
# Stop gamepad input
# =======================================================
Stop_GPTKeyb() {
    if [ -n "$GPTOKEYB_PID" ]; then
        kill "$GPTOKEYB_PID" 2>/dev/null
        GPTOKEYB_PID=""
    fi
}

# =======================================================
# Font Selection
# =======================================================
ORIGINAL_FONT=$(setfont -v 2>&1 | grep -o '/.*\.psf.*')
setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

# =======================================================
# Display Management
# =======================================================
printf "\e[?25l" > "$CURR_TTY"
dialog --clear
Stop_GPTKeyb
pgrep -f osk.py | xargs kill -9
printf "\033[H\033[2J" > "$CURR_TTY"
printf "$T_STARTING" > "$CURR_TTY"
sleep 0.5

# =======================================================
# Exit the script
# =======================================================
Exit_Menu() {
	trap - EXIT
    printf "\033[H\033[2J" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
	Stop_GPTKeyb
    rm -f "$TMP_KEYS"
    if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        [ -n "$ORIGINAL_FONT" ] && setfont "$ORIGINAL_FONT"
    fi

    exit 0
}

# =======================================================
# Saves Folder
# =======================================================
Saves_Folder() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

	sed -i \
	  -e 's|^[[:space:]]*savefiles_in_content_dir[[:space:]]*=.*|savefiles_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*savestates_in_content_dir[[:space:]]*=.*|savestates_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*screenshots_in_content_dir[[:space:]]*=.*|screenshots_in_content_dir = "false"|' \
	  -e 's|^[[:space:]]*sort_savefiles_by_content_enable[[:space:]]*=.*|sort_savefiles_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_savestates_by_content_enable[[:space:]]*=.*|sort_savestates_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_screenshots_by_content_enable[[:space:]]*=.*|sort_screenshots_by_content_enable = "true"|' \
	  "$RA64_CFG"

    mkdir -p "$RA64/saves" "$RA64/states"
    mkdir -p "$RA32/saves" "$RA32/states"

    awk '
        /<system>/ {
            name=""
            path=""
            ra64=0
            ra32=0
            in_emulators=0
        }

        /<name>/ && name=="" {
            name=$0
            sub(/.*<name>/, "", name)
            sub(/<\/name>.*/, "", name)
        }

        /<path>/ && path=="" {
            path=$0
            sub(/.*<path>/, "", path)
            sub(/<\/path>.*/, "", path)
        }

        /<emulators>/ {
            in_emulators=1
        }

        /<emulator name="retroarch">/ && in_emulators {
            ra64=1
        }

        /<emulator name="retroarch32">/ && in_emulators {
            ra32=1
        }

        /<\/emulators>/ {
            in_emulators=0
        }

        /<\/system>/ {
            if (name != "" && path != "") {

                if (path ~ /^\/roms2\//)
                    location="/roms2"
                else if (path ~ /^\/roms\//)
                    location="/roms"
                else
                    location=""

                if (location != "")
                    print name "|" location "|" ra64 "|" ra32
            }
        }
    ' "$ES_SYSTEMS" |
    while IFS='|' read -r SYSTEM LOCATION RA64_ENABLED RA32_ENABLED; do

        SYSTEM_DIR="$LOCATION/$SYSTEM/$SYSTEM"

        [ -d "$SYSTEM_DIR" ] || continue

		dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_COPY" 5 40 2>&1 > "$CURR_TTY"
		# sleep 0.05
		
        # RA64
        if [ "$RA64_ENABLED" = "1" ]; then
            for FILE in "$SYSTEM_DIR"/*.srm; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA64/saves/$SYSTEM"
                cp -au "$FILE" "$RA64/saves/$SYSTEM/"
            done
            for FILE in "$SYSTEM_DIR"/*.state "$SYSTEM_DIR"/*.state.auto; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA64/states/$SYSTEM"
                cp -au "$FILE" "$RA64/states/$SYSTEM/"
            done
        fi

        # RA32
        if [ "$RA32_ENABLED" = "1" ]; then
            for FILE in "$SYSTEM_DIR"/*.srm; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA32/saves/$SYSTEM"
                cp -au "$FILE" "$RA32/saves/$SYSTEM/"
            done
            for FILE in "$SYSTEM_DIR"/*.state "$SYSTEM_DIR"/*.state.auto; do
                [ -f "$FILE" ] || continue
                mkdir -p "$RA32/states/$SYSTEM"
                cp -au "$FILE" "$RA32/states/$SYSTEM/"
            done
        fi
    done
}

# =======================================================
# Content Folder
# =======================================================
Content_Folders() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"
	  
	sed -i \
	  -e 's|^[[:space:]]*savefiles_in_content_dir[[:space:]]*=.*|savefiles_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*savestates_in_content_dir[[:space:]]*=.*|savestates_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*screenshots_in_content_dir[[:space:]]*=.*|screenshots_in_content_dir = "true"|' \
	  -e 's|^[[:space:]]*sort_savefiles_by_content_enable[[:space:]]*=.*|sort_savefiles_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_savestates_by_content_enable[[:space:]]*=.*|sort_savestates_by_content_enable = "true"|' \
	  -e 's|^[[:space:]]*sort_screenshots_by_content_enable[[:space:]]*=.*|sort_screenshots_by_content_enable = "true"|' \
	  "$RA64_CFG"

    for RA_DIR in "$RA64" "$RA32"; do
        for TYPE in saves states; do

            [ -d "$RA_DIR/$TYPE" ] || continue

            for SYSTEM_DIR in "$RA_DIR/$TYPE"/*; do
                [ -d "$SYSTEM_DIR" ] || continue

                SYSTEM="$(basename "$SYSTEM_DIR")"

				LOCATION=$(awk -v sys="$SYSTEM" '
					/<path>/ {
						path=$0
						sub(/.*<path>/, "", path)
						sub(/<\/path>.*/, "", path)

						gsub(/\/+$/, "", path)

						if (tolower(path) ~ "/roms2/" tolower(sys) "$") {
							print "/roms2"
							exit
						}

						if (tolower(path) ~ "/roms/" tolower(sys) "$") {
							print "/roms"
							exit
						}
					}
				' "$ES_SYSTEMS")

                [ -n "$LOCATION" ] || continue
				
				dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_COPY" 5 40 2>&1 > "$CURR_TTY"
				# sleep 0.05
				
				DEST="$LOCATION/$SYSTEM/$SYSTEM"
				mkdir -p "$DEST"
                cp -au "$SYSTEM_DIR/." "$DEST/"
				
            done
        done
    done
}

# =======================================================
# Install SaveSync
# =======================================================
Install_SaveSync() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

	# --- Check Dependencies ---
	if ! command -v mount.cifs >/dev/null 2>&1; then
		if ! apt update >/tmp/savesync_apt.log 2>&1 ||
		   ! apt -y install cifs-utils >>/tmp/savesync_apt.log 2>&1; then
			dialog \
				--backtitle "$T_BACKTITLE" \
				--title "$T_SSYNC" \
				--msgbox "\nUnable to install required CIFS support." \
				8 45 \
				2>&1 > "$CURR_TTY"
			return
		fi
	fi
	
	# --- Credential file ---
	if [[ ! -f "$CRD_FILE" ]]; then
		mkdir -p "$(dirname "$CRD_FILE")"
		cat > "$CRD_FILE" <<-EOF
NETBIOS=
USERNAME=
PASSWORD=
NETWORKPATH=
		EOF
		chmod 600 "$CRD_FILE"
	fi

	# --- Sync script (placeholder) ---
	if [[ ! -f "$FLAG_FILE" ]]; then
		cat >  "$SYNC_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

# --- Self-background ---
if [ "${1:-}" != "--bg" ]; then
    nohup "$0" --bg >/dev/null 2>&1 &
    disown
    exit 0
fi

# --- Constants ---
CRD_FILE="/home/ark/.config/savesync.crd"
LOG_FILE="/home/ark/.config/savesync.log"
ES_SYSTEMS="/etc/emulationstation/es_systems.cfg"
RA_CFG="/home/ark/.config/retroarch/retroarch.cfg"
RA64_SAVES="/home/ark/.config/retroarch/saves"
RA32_SAVES="/home/ark/.config/retroarch32/saves"
MOUNT_POINT="/mnt/savesync"
PC_CFG_NAME="savesync.cfg"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

# --- Network check ---
if ! ip route show default 2>/dev/null | grep -q default; then
    log "ERROR: no network connection detected (no default route)"
    exit 1
fi

# --- Load console credentials ---
if [ ! -f "$CRD_FILE" ]; then
    log "ERROR: credential file not found at $CRD_FILE"
    exit 1
fi
# shellcheck source=/dev/null
source "$CRD_FILE"

if [ -z "${NETBIOS:-}" ] || [ -z "${USERNAME:-}" ] || [ -z "${PASSWORD:-}" ] || [ -z "${NETWORKPATH:-}" ]; then
    log "ERROR: missing required field(s) in $CRD_FILE"
    exit 1
fi

# --- Resolve NetBIOS name or IP ---
if [[ "$NETBIOS" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    NETWORK_IP="$NETBIOS"
else
    NETWORK_IP=$(nmblookup "$NETBIOS" 2>/dev/null |
        grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' |
        head -n 1)
fi

if [[ -z "$NETWORK_IP" ]]; then
    log "ERROR: could not resolve NetBIOS name: $NETBIOS"
    exit 1
fi

# --- Mount PC share ---
mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
    MOUNT_FAILED=0

    MOUNT_ERR=$(mount -t cifs "//$NETWORK_IP/$NETWORKPATH" "$MOUNT_POINT" \
        -o username="$USERNAME",password="$PASSWORD",vers=3.0,uid=$(id -u),gid=$(id -g) \
        2>&1 1>/dev/null) || MOUNT_FAILED=1

    if [ "$MOUNT_FAILED" = "1" ]; then
        case "$MOUNT_ERR" in
            *"error(13)"*)
                log "ERROR: authentication failed for //$NETBIOS/$NETWORKPATH — check USERNAME/PASSWORD in $CRD_FILE"
                ;;
            *"error(2)"*)
                log "ERROR: share or path not found at //$NETBIOS/$NETWORKPATH — check NETWORKPATH in $CRD_FILE"
                ;;
            *"error(101)"*)
                log "ERROR: network unreachable — check NETBIOS/IP and console network connection"
                ;;
            *"error(110)"*)
                log "ERROR: connection timed out reaching //$NETBIOS — PC may be off or unreachable"
                ;;
            *"error(111)"*)
                log "ERROR: connection refused by //$NETBIOS — check SMB/file sharing is enabled on PC"
                ;;
            *)
                log "ERROR: mount failed for //$NETBIOS/$NETWORKPATH — $MOUNT_ERR"
                ;;
        esac
        exit 1
    fi

    log "Mounted //$NETBIOS/$NETWORKPATH at $MOUNT_POINT"
fi

# --- Read PC-side config ---
PC_CFG="$MOUNT_POINT/$PC_CFG_NAME"

if [ ! -f "$PC_CFG" ]; then
    log "ERROR: PC config not found at $PC_CFG"
    umount "$MOUNT_POINT"
    exit 1
fi

USECONTENTFOLDER=$(grep -E '^USECONTENTFOLDER=' "$PC_CFG" | cut -d'=' -f2 | tr -d '[:space:]')

if [[ "$USECONTENTFOLDER" != "true" && "$USECONTENTFOLDER" != "false" ]]; then
    log "ERROR: invalid or missing UseContentFolder in $PC_CFG — expected true or false"
    umount "$MOUNT_POINT"
    exit 1
fi

# --- Determine console's current active save mode ---
CONTENT_MODE=$(grep '^savefiles_in_content_dir' "$RA_CFG" | grep -o 'true\|false')

# --- Sync every system listed in es_systems.cfg ---
while IFS='|' read -r SYSTEM LOCATION RA64_ENABLED RA32_ENABLED; do
    [ -n "$SYSTEM" ] || continue

    # Resolve console source dir
    if [ "$CONTENT_MODE" = "true" ]; then
        [ -n "$LOCATION" ] || continue
        SRC_DIR="$LOCATION/$SYSTEM/$SYSTEM"
    else
        if [ "$RA64_ENABLED" = "1" ]; then
            SRC_DIR="$RA64_SAVES/$SYSTEM"
        elif [ "$RA32_ENABLED" = "1" ]; then
            SRC_DIR="$RA32_SAVES/$SYSTEM"
        else
            continue
        fi
    fi

    # Resolve PC target dir
    if [ "$USECONTENTFOLDER" = "true" ]; then
        DST_DIR="$MOUNT_POINT/$SYSTEM/$SYSTEM"
    else
        DST_DIR="$MOUNT_POINT/$SYSTEM"
    fi

    # Skip if neither side has anything yet
    if [ ! -d "$SRC_DIR" ] && [ ! -d "$DST_DIR" ]; then
        continue
    fi

    mkdir -p "$SRC_DIR" "$DST_DIR"

    log "Syncing $SYSTEM: $SRC_DIR <-> $DST_DIR"
	rsync -au --no-owner --no-group "$SRC_DIR/" "$DST_DIR/" >> "$LOG_FILE" 2>&1
	rsync -au --no-owner --no-group "$DST_DIR/" "$SRC_DIR/" >> "$LOG_FILE" 2>&1

done < <(awk '
    /<system>/ { name=""; path=""; ra64=0; ra32=0; in_emulators=0 }
    /<name>/ && name=="" {
        name=$0; sub(/.*<name>/, "", name); sub(/<\/name>.*/, "", name)
    }
    /<path>/ && path=="" {
        path=$0; sub(/.*<path>/, "", path); sub(/<\/path>.*/, "", path)
    }
    /<emulators>/ { in_emulators=1 }
    /<emulator name="retroarch">/ && in_emulators { ra64=1 }
    /<emulator name="retroarch32">/ && in_emulators { ra32=1 }
    /<\/emulators>/ { in_emulators=0 }
    /<\/system>/ {
        if (name != "" && path != "") {
            if (path ~ /^\/roms2\//) location="/roms2"
            else if (path ~ /^\/roms\//) location="/roms"
            else location=""
            print name "|" location "|" ra64 "|" ra32
        }
    }
' "$ES_SYSTEMS")

# --- Unmount ---
umount "$MOUNT_POINT"
log "Sync complete, unmounted $MOUNT_POINT"
EOF
		chmod +x "$SYNC_SCRIPT"
	fi

	# --- Game-end hook ---
	if [[ ! -f "$FLAG_FILE" ]]; then
		mkdir -p "$(dirname "$GAMEEND_HOOK")"
		cat > "$GAMEEND_HOOK" <<-EOF
#!/usr/bin/env bash
/usr/local/bin/savesync.sh
		EOF
		chmod +x "$GAMEEND_HOOK"
	fi

	# --- Boot service ---
	if [[ ! -f "$FLAG_FILE" ]]; then
		cat > "$SERVICE_FILE" <<-EOF
[Unit]
Description=SaveSync Boot Sync Service
Wants=NetworkManager-wait-online.service
After=NetworkManager-wait-online.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/savesync.sh --bg
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
		EOF
	fi
	systemctl daemon-reload
	systemctl enable savesync.service

	touch "$FLAG_FILE"

	dialog --backtitle "$T_BACKTITLE" --msgbox "\nSaveSync installed." 6 40 2>&1 > "$CURR_TTY"
}

# =======================================================
# Uninstall SaveSync
# =======================================================
Uninstall_SaveSync() {
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

	# --- Boot service ---
	if [[ -f "$SERVICE_FILE" ]]; then
		systemctl disable savesync.service 2>/dev/null
		rm -f "$SERVICE_FILE"
		systemctl daemon-reload
	fi

	# --- savesync.sh ---

	rm -f "$SYNC_SCRIPT"

	# --- Game-end hook ---
	rm -f "$GAMEEND_HOOK"

	# --- Flag ---
	rm -f "$FLAG_FILE"

	dialog --backtitle "$T_BACKTITLE" --msgbox "\nSaveSync uninstalled." 6 40 2>&1 > "$CURR_TTY"
}

# =======================================================
# NetBIOS or IP Entry
# =======================================================
NetBIOS() {
    local NETBIOS

    pkill -9 -f gptokeyb 2>/dev/null || true

    NETBIOS=$(osk "NetBIOS" | tail -n 1)

    Start_GPTKeyb
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

    # Don't modify the file if nothing was entered
    [[ -z "$NETBIOS" ]] && return

    mkdir -p "$(dirname "$CRD_FILE")"

    if [[ -f "$CRD_FILE" ]]; then
        awk -v value="$NETBIOS" '
            BEGIN { found=0 }
            /^NETBIOS=/ {
                print "NETBIOS=" value
                found=1
                next
            }
            { print }
            END {
                if (!found)
                    print "NETBIOS=" value
            }
        ' "$CRD_FILE" > "${CRD_FILE}.tmp" &&
        mv -f "${CRD_FILE}.tmp" "$CRD_FILE"
    else
        printf 'NETBIOS=%s\n' "$NETBIOS" > "$CRD_FILE"
    fi
}

# =======================================================
# Username Entry
# =======================================================
Username() {
    local USERNAME

    pkill -9 -f gptokeyb 2>/dev/null || true

    USERNAME=$(osk "Username" | tail -n 1)

    Start_GPTKeyb
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

    # Don't modify the file if nothing was entered
    [[ -z "$USERNAME" ]] && return

    awk -v value="$USERNAME" '
        /^USERNAME=/ {
            print "USERNAME=" value
            next
        }
        { print }
    ' "$CRD_FILE" > "${CRD_FILE}.tmp" &&
    mv -f "${CRD_FILE}.tmp" "$CRD_FILE"
}

# =======================================================
# Password Entry
# =======================================================
Password() {
    local PASSWORD

    pkill -9 -f gptokeyb 2>/dev/null || true

    PASSWORD=$(osk "Password" | tail -n 1)
    local OSK_STATUS=$?

    Start_GPTKeyb
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

    # Cancelled - leave existing password unchanged
    [[ $OSK_STATUS -ne 0 ]] && return

    awk -v value="$PASSWORD" '
        /^PASSWORD=/ {
            print "PASSWORD=" value
            next
        }
        { print }
    ' "$CRD_FILE" > "${CRD_FILE}.tmp" &&
    mv -f "${CRD_FILE}.tmp" "$CRD_FILE"
}

# =======================================================
# Network Path Entry
# =======================================================
NetworkPath() {
    local NETWORKPATH

    pkill -9 -f gptokeyb 2>/dev/null || true

    NETWORKPATH=$(osk "Network Path" | tail -n 1)

    Start_GPTKeyb
    setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz

    # Don't modify the file if nothing was entered
    [[ -z "$NETWORKPATH" ]] && return

    awk -v value="$NETWORKPATH" '
        /^NETWORKPATH=/ {
            print "NETWORKPATH=" value
            next
        }
        { print }
    ' "$CRD_FILE" > "${CRD_FILE}.tmp" &&
    mv -f "${CRD_FILE}.tmp" "$CRD_FILE"
}

# =======================================================
# Credentials Menu dialog
# =======================================================
Credentials_Menu() {
	while true; do
		# --- keep gptokeyb alive ---
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi
		
		local network_id=""
		local username=""
		local networkpath=""
		
		if [[ -f "$CRD_FILE" ]]; then
			network_id=$(sed -n 's/^NETBIOS=//p' "$CRD_FILE")
			username=$(sed -n 's/^USERNAME=//p' "$CRD_FILE")
			networkpath=$(sed -n 's/^NETWORKPATH=//p' "$CRD_FILE")
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_SSYNC" \
			--menu "NetBIOS=$network_id\nUsername=$username\nPath=$networkpath" \
			14 45 6 \
			"1" "$T_IP" \
			"2" "$T_NAME" \
			"3" "$T_PASS" \
			"4" "$T_PATH" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) NetBIOS ;;
				2) Username ;;
				3) Password ;;
				4) NetworkPath ;;
			esac
	done
}

# =======================================================
# Manual Sync
# =======================================================
Manual_Sync() {
    local LOG_START=0
    local ERROR_MSG=""
	local RESULT
	
	dialog --backtitle "$T_BACKTITLE" --infobox "\n    $T_WAIT" 5 40 2>&1 > "$CURR_TTY"

    if [[ -f "$LOG_FILE" ]]; then
        LOG_START=$(wc -c < "$LOG_FILE")
    fi

    if "$SYNC_SCRIPT" --bg; then
        RESULT="SUCCESS"
    else
        RESULT="FAILED"
    fi

    if [[ -f "$LOG_FILE" ]]; then
        ERROR_MSG=$(tail -c +"$((LOG_START + 1))" "$LOG_FILE" |
            grep 'ERROR:' |
            tail -n 1)
    fi
	
    if [[ "$RESULT" == "SUCCESS" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SSYNC" \
            --msgbox "\n    Success!" \
            7 40 \
            2>&1 > "$CURR_TTY"
    else
		ERROR_MSG=$(printf '%s\n' "$ERROR_MSG" | fold -s -w 34)
        if [[ -n "$ERROR_MSG" ]]; then
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_SSYNC" \
                --msgbox "\nFailed\n\n$ERROR_MSG" \
                10 40 \
                2>&1 > "$CURR_TTY"
        else
            dialog \
                --backtitle "$T_BACKTITLE" \
                --title "$T_SSYNC" \
                --msgbox "\n    Failed\n\nNo error details were recorded." \
                10 40 \
                2>&1 > "$CURR_TTY"
        fi
    fi
}

# =======================================================
# View Log
# =======================================================
View_Log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        dialog \
            --backtitle "$T_BACKTITLE" \
            --title "$T_SSYNC" \
            --msgbox "\nNo log file found." \
            7 40 \
            2>&1 > "$CURR_TTY"
        return
    fi

    local VIEW_LOG="/tmp/savesync_view.$$"

    fold -s -w 36 "$LOG_FILE" > "$VIEW_LOG"

    dialog \
        --backtitle "$T_BACKTITLE" \
        --title "$T_SSYNC" \
        --textbox "$VIEW_LOG" \
        16 40 \
        2>&1 > "$CURR_TTY"

    rm -f "$VIEW_LOG"
}

# =======================================================
# SaveSync Menu dialog
# =======================================================
SaveSync_Menu() {
	while true; do
		# --- keep gptokeyb alive ---
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi
		
		local installed
		if [[ -f "$FLAG_FILE" ]]; then
			installed="Uninstall SaveSync"
		else
			installed="Install SaveSync"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_SSYNC" \
			--menu "" \
			14 45 6 \
			"1" "$installed" \
			"2" "$T_CRED" \
			"3" "$T_MANUAL" \
			"4" "$T_LOG" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) if [[ "$installed" == "Install SaveSync" ]]; then
						Install_SaveSync
					else
						Uninstall_SaveSync
					fi ;;
				2) Credentials_Menu ;;
				3) Manual_Sync ;;
				4) View_Log ;;
			esac
	done
}

# =======================================================
# Location Menu dialog
# =======================================================
Location_Menu() {
	while true; do
		# --- keep gptokeyb alive ---
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi

		local state
		local location
		location=$(grep '^savefiles_in_content_dir' "$RA64_CFG" | grep -o 'true\|false')
		if [[ "$location" == "true" ]]; then
			location="$T_SAVE_LOC"
			save="$T_SAVE"
			state="content folders"
		else
			location="$T_FOLDER_LOC"
			save="$T_FOLDER"
			state="saves folder"
		fi
		
		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_SAVE_LOCATION" \
			--menu "$T_LOCATION \Z2$location\Zn\n$T_STATUS" \
			14 45 6 \
			"1" "$save" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && return

			case "$CHOICE" in
				1) if [[ "$state" == "content folders" ]]; then
						Saves_Folder
					else
						Content_Folders
					fi ;;
			esac
	done
}

# =======================================================
# Main Menu dialog
# =======================================================
Main_Menu() {
	while true; do
		# --- keep gptokeyb alive ---
		if [[ -z $(pgrep -f gptokeyb) ]]; then
			Start_GPTKeyb
		fi

		local CHOICE
		CHOICE=$(dialog \
			--clear \
			--colors \
			--no-collapse \
			--cancel-label "$T_EXIT" \
			--backtitle "$T_BACKTITLE" \
			--title "$T_MAIN_TITLE" \
			--menu "$T_SELECT" \
			14 45 6 \
			"1" "$T_SAVE_LOCATION" \
			"2" "$T_SSYNC" \
            2>&1 > "$CURR_TTY")
			
			[[ $? -ne 0 ]] && Exit_Menu

			case "$CHOICE" in
				1) Location_Menu ;;
				2) SaveSync_Menu ;;
			esac
	done
}

# =======================================================
# Gamepad Setup
# =======================================================
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
chmod 666 /dev/uinput
cp /opt/inttools/keys.gptk "$TMP_KEYS"
if grep -q '^b = backspace' "$TMP_KEYS"; then
    sed -i 's/^b = .*/b = esc/' "$TMP_KEYS"
    sed -i 's/^a = .*/a = enter/' "$TMP_KEYS"
fi
Start_GPTKeyb

# =======================================================
# Main Execution
# =======================================================
printf "\033[H\033[2J" > "$CURR_TTY"
dialog --clear
trap 'Exit_Menu' EXIT

Main_Menu
