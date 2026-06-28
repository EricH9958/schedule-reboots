#!/bin/bash
set -euo pipefail

DEFAULT_DATE_LABEL="tomorrow"
DEFAULT_HOUR="1"
DEFAULT_MINUTE="00"
DEFAULT_AMPM="AM"
DEFAULT_GAP_MINUTES=15
PRIMARY_HOSTNAME="primary-server"
S2_HOST="secondary-server.example.lan"
S2_PORT="22"
S2_USER="remoteadmin"
S2_KEY="/root/.ssh/secondary_server_key"
AT_BIN="/usr/bin/at"
ATQ_BIN="/usr/bin/atq"
ATRM_BIN="/usr/bin/atrm"
DATE_BIN="/usr/bin/date"
SSH_BIN="/usr/bin/ssh"
SYSTEMCTL_BIN="/usr/bin/systemctl"
HOSTNAME_BIN="/usr/bin/hostname"

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Required command not found: $1" >&2
        exit 1
    }
}

for cmd in "$AT_BIN" "$ATQ_BIN" "$ATRM_BIN" "$DATE_BIN" "$SSH_BIN" "$SYSTEMCTL_BIN" "$HOSTNAME_BIN"; do
    require_cmd "$cmd"
done

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root on the primary server."
    exit 1
fi

if [[ "$($HOSTNAME_BIN)" != "$PRIMARY_HOSTNAME" ]]; then
    echo "This script is intended to be run from the primary server."
    exit 1
fi

if [[ ! -f "$S2_KEY" ]]; then
    echo "SSH key not found: $S2_KEY"
    exit 1
fi

remote_ssh() {
    "$SSH_BIN" -i "$S2_KEY" -p "$S2_PORT" -o StrictHostKeyChecking=yes -o BatchMode=yes \
        "${S2_USER}@${S2_HOST}" "$1"
}

show_jobs() {
    echo
    echo "Primary server queued jobs:"
    if ! "$ATQ_BIN"; then
        true
    fi

    echo
    echo "Secondary server queued jobs:"
    if ! remote_ssh "$ATQ_BIN"; then
        true
    fi
}

cancel_all_jobs() {
    local local_jobs remote_jobs confirm

    show_jobs

    local_jobs="$($ATQ_BIN | awk '{print $1}')"
    remote_jobs="$(remote_ssh "$ATQ_BIN | awk '{print \$1}')"

    if [[ -z "$local_jobs" && -z "$remote_jobs" ]]; then
        echo
        echo "No queued at jobs found on either server."
        exit 0
    fi

    echo
    echo "This will cancel ALL queued at jobs on the primary and secondary server."
    read -rp "Continue? [Y/n]: " confirm
    confirm=${confirm:-Y}
    if [[ "${confirm,,}" != "y" && "${confirm,,}" != "yes" ]]; then
        echo "Cancel operation aborted."
        exit 0
    fi

    if [[ -n "$local_jobs" ]]; then
        while read -r jobid; do
            [[ -n "$jobid" ]] && "$ATRM_BIN" "$jobid"
        done <<< "$local_jobs"
    fi

    if [[ -n "$remote_jobs" ]]; then
        remote_ssh "for j in $remote_jobs; do $ATRM_BIN \"\$j\"; done"
    fi

    echo
    echo "All queued at jobs were removed from both servers."
    show_jobs
}

schedule_jobs() {
    local USE_DEFAULT_DATE REBOOT_DATE USE_DEFAULT_HOUR REBOOT_HOUR
    local USE_DEFAULT_MINUTE REBOOT_MINUTE USE_DEFAULT_AMPM REBOOT_AMPM
    local AMPM_CHOICE GAP_MINUTES REBOOT_TIME S1_INPUT S2_INPUT
    local S1_DISPLAY S2_DISPLAY S1_AT_TIME S2_AT_TIME S1_EPOCH NOW_EPOCH CONFIRM

    cat <<'INTRO'
This script schedules staged reboots for a primary server and a secondary server.
- Default date is tomorrow.
- Default time is 1:00 AM.
- The primary server is scheduled first, then the secondary server.
- Default gap between servers is 15 minutes.
INTRO

    echo
    read -rp "Use default date (${DEFAULT_DATE_LABEL})? [Y/n]: " USE_DEFAULT_DATE
    USE_DEFAULT_DATE=${USE_DEFAULT_DATE:-Y}
    if [[ "${USE_DEFAULT_DATE,,}" == "y" || "${USE_DEFAULT_DATE,,}" == "yes" ]]; then
        REBOOT_DATE="$($DATE_BIN -d 'tomorrow' +%F)"
    else
        read -rp "Enter reboot date (example: 2026-07-01): " REBOOT_DATE
        $DATE_BIN -d "$REBOOT_DATE" >/dev/null 2>&1 || {
            echo "Invalid date: $REBOOT_DATE"
            exit 1
        }
    fi

    read -rp "Use default hour (${DEFAULT_HOUR})? [Y/n]: " USE_DEFAULT_HOUR
    USE_DEFAULT_HOUR=${USE_DEFAULT_HOUR:-Y}
    if [[ "${USE_DEFAULT_HOUR,,}" == "y" || "${USE_DEFAULT_HOUR,,}" == "yes" ]]; then
        REBOOT_HOUR="$DEFAULT_HOUR"
    else
        read -rp "Enter reboot hour (1-12): " REBOOT_HOUR
        if ! [[ "$REBOOT_HOUR" =~ ^([1-9]|1[0-2])$ ]]; then
            echo "Invalid hour: $REBOOT_HOUR"
            exit 1
        fi
    fi

    read -rp "Use default minute (${DEFAULT_MINUTE})? [Y/n]: " USE_DEFAULT_MINUTE
    USE_DEFAULT_MINUTE=${USE_DEFAULT_MINUTE:-Y}
    if [[ "${USE_DEFAULT_MINUTE,,}" == "y" || "${USE_DEFAULT_MINUTE,,}" == "yes" ]]; then
        REBOOT_MINUTE="$DEFAULT_MINUTE"
    else
        read -rp "Enter reboot minute (00-59): " REBOOT_MINUTE
        if ! [[ "$REBOOT_MINUTE" =~ ^([0-5][0-9])$ ]]; then
            echo "Invalid minute: $REBOOT_MINUTE"
            exit 1
        fi
    fi

    echo
    if [[ "$DEFAULT_AMPM" == "AM" ]]; then
        echo "Default AM/PM is: 1) AM"
    else
        echo "Default AM/PM is: 2) PM"
    fi
    read -rp "Use default AM/PM? [Y/n]: " USE_DEFAULT_AMPM
    USE_DEFAULT_AMPM=${USE_DEFAULT_AMPM:-Y}
    if [[ "${USE_DEFAULT_AMPM,,}" == "y" || "${USE_DEFAULT_AMPM,,}" == "yes" ]]; then
        REBOOT_AMPM="$DEFAULT_AMPM"
    else
        echo "Select AM/PM:"
        echo "  1) AM"
        echo "  2) PM"
        read -rp "Enter 1 or 2: " AMPM_CHOICE
        case "$AMPM_CHOICE" in
            1) REBOOT_AMPM="AM" ;;
            2) REBOOT_AMPM="PM" ;;
            *)
                echo "Invalid selection: $AMPM_CHOICE"
                exit 1
                ;;
        esac
    fi

    read -rp "Minutes between primary and secondary reboot [${DEFAULT_GAP_MINUTES}]: " GAP_MINUTES
    GAP_MINUTES=${GAP_MINUTES:-$DEFAULT_GAP_MINUTES}
    if ! [[ "$GAP_MINUTES" =~ ^[0-9]+$ ]]; then
        echo "Gap must be a whole number of minutes."
        exit 1
    fi

    REBOOT_TIME="${REBOOT_HOUR}:${REBOOT_MINUTE} ${REBOOT_AMPM}"
    S1_INPUT="$REBOOT_DATE $REBOOT_TIME"
    S2_INPUT="$REBOOT_DATE $REBOOT_TIME + ${GAP_MINUTES} minutes"

    $DATE_BIN -d "$S1_INPUT" >/dev/null 2>&1 || {
        echo "Invalid scheduled time: $S1_INPUT"
        exit 1
    }

    S1_DISPLAY="$($DATE_BIN -d "$S1_INPUT" '+%m/%d/%Y %I:%M %p')"
    S2_DISPLAY="$($DATE_BIN -d "$S2_INPUT" '+%m/%d/%Y %I:%M %p')"

    S1_AT_TIME="$($DATE_BIN -d "$S1_INPUT" '+%H:%M %Y-%m-%d')"
    S2_AT_TIME="$($DATE_BIN -d "$S2_INPUT" '+%H:%M %Y-%m-%d')"

    S1_EPOCH="$($DATE_BIN -d "$S1_INPUT" +%s)"
    NOW_EPOCH="$($DATE_BIN +%s)"

    if (( S1_EPOCH <= NOW_EPOCH )); then
        echo "The primary server reboot time must be in the future: $S1_DISPLAY"
        exit 1
    fi

    cat <<SUMMARY

Schedule summary
----------------
Primary server reboot: $S1_DISPLAY
Secondary server reboot: $S2_DISPLAY
Gap: ${GAP_MINUTES} minute(s)
Remote target: ${S2_USER}@${S2_HOST}:${S2_PORT}
SSH key: ${S2_KEY}
SUMMARY

    echo
    read -rp "Queue these reboot jobs now? [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-Y}
    if [[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "$SYSTEMCTL_BIN reboot" | "$AT_BIN" "$S1_AT_TIME"
    remote_ssh "echo '$SYSTEMCTL_BIN reboot' | $AT_BIN '$S2_AT_TIME'"

    echo
    printf 'Queued reboot for the primary server at %s\n' "$S1_DISPLAY"
    printf 'Queued reboot for the secondary server at %s\n' "$S2_DISPLAY"
    echo "Check queued jobs with: atq"
    echo "Cancel queued jobs by rerunning this script and choosing option 2."
}

echo "Select activity:"
echo "  1) Schedule reboot jobs"
echo "  2) Cancel all queued jobs"
read -rp "Enter 1 or 2: " ACTIVITY

case "$ACTIVITY" in
    1) schedule_jobs ;;
    2) cancel_all_jobs ;;
    *)
        echo "Invalid selection: $ACTIVITY"
        exit 1
        ;;
esac
