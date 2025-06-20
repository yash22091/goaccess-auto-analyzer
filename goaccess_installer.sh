#!/bin/bash
# Author: Yash Patel
# GoAccess Prerequisite Checker, Installer & Runner (supports live and historical logs)

set -e

LOGFILE="/var/log/goaccess_installer.log"
mkdir -p "$(dirname "$LOGFILE")"
: > "$LOGFILE"
chmod 600 "$LOGFILE"

print_help() {
  cat <<EOF
Usage: $0 [mode] [options]

Modes:
  install             Check for Nginx/Apache and install GoAccess if present
  run [options]       Generate report (static or real-time) on live or rotated logs
  daily-report        Generate yesterday's report from rotated logs to /tmp
  realtime-dashboard  Start real-time HTML dashboard on localhost:7890
  help                Show this help message

Install is non-interactive; logs saved to $LOGFILE

Run options (for 'run' mode):
  --logfile <path>    Path to access log (can specify access.log, access.log.1, etc.)
  --output <file>     Output HTML file (required in static mode)
  --format <fmt>      Log format: COMBINED or COMMON (default COMBINED)
  --real-time         Enable real-time dashboard mode
  --ws-url <url>      WebSocket URL (default ws://127.0.0.1:7890)
  --since <YYYY-MM-DD> Include only entries from this date onward
  --until <YYYY-MM-DD> Include only entries up to this date

Examples:
  $0 install
  $0 run --logfile /var/log/nginx/access.log --output /tmp/report.html
  $0 run --logfile /var/log/nginx/access.log.1 --since 2025-06-01 --until 2025-06-05 --output old.html
  $0 run --real-time --ws-url ws://0.0.0.0:7890
  $0 daily-report
  $0 realtime-dashboard
EOF
}

install_goaccess() {
  echo "[*] Checking for web server..." | tee -a "$LOGFILE"
  if command -v nginx &>/dev/null; then
    WEBSRV=nginx
    ACCESS_LOG="$(grep -m1 'access_log' /etc/nginx/nginx.conf | awk '{print $2}' | tr -d ';')"
  elif command -v httpd &>/dev/null || command -v apache2 &>/dev/null; then
    WEBSRV=apache
    ACCESS_LOG=$([[ -f /etc/apache2/apache2.conf ]] && echo /var/log/apache2/access.log || echo /var/log/httpd/access_log)
  else
    echo "[!] No Nginx or Apache detected; skipping installation." | tee -a "$LOGFILE"
    return
  fi
  echo "[*] Detected $WEBSRV; log: $ACCESS_LOG" | tee -a "$LOGFILE"

  . /etc/os-release || { echo "[!] OS detection failed." | tee -a "$LOGFILE"; exit 1; }
  echo "[*] Installing GoAccess..." | tee -a "$LOGFILE"
  case $ID in
    ubuntu|debian)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq >>"$LOGFILE" 2>&1
      apt-get install -qq -y goaccess >>"$LOGFILE" 2>&1
      unset DEBIAN_FRONTEND
      ;;
    rhel|centos|fedora|rocky|almalinux|amzn)
      yum install -y -q goaccess >>"$LOGFILE" 2>&1 || dnf install -y -q goaccess >>"$LOGFILE" 2>&1
      ;;
    suse|opensuse*)
      zypper --non-interactive install goaccess >>"$LOGFILE" 2>&1
      ;;
    alpine)
      apk add --no-cache goaccess >>"$LOGFILE" 2>&1
      ;;
    *) echo "[!] Unsupported OS: $ID" | tee -a "$LOGFILE"; exit 1;;
  esac
  echo "[✓] Installed GoAccess." | tee -a "$LOGFILE"
}

run_goaccess() {
  # defaults
  LOGFILES=()
  OUTPUT=""
  FORMAT="COMBINED"
  REALTIME=false
  WS_URL="ws://127.0.0.1:7890"
  SINCE=""
  UNTIL=""

  # parse
  while [[ $# -gt 0 ]]; do
    case $1 in
      --logfile) LOGFILES=("$2"); shift 2;;
      --output) OUTPUT="$2"; shift 2;;
      --format) FORMAT="$2"; shift 2;;
      --real-time) REALTIME=true; shift;;
      --ws-url) WS_URL="$2"; shift 2;;
      --since) SINCE="$2"; shift 2;;
      --until) UNTIL="$2"; shift 2;;
      *) echo "Unknown option: $1"; exit 1;;
    esac
  done

  # autodetect if needed
  if [[ ${#LOGFILES[@]} -eq 0 ]]; then
    install_goaccess >/dev/null 2>&1
    if [[ $WEBSRV == nginx ]]; then
      LOGFILES=("$(grep -m1 'access_log' /etc/nginx/nginx.conf | awk '{print $2}' | tr -d ';')"*)
    else
      LOGFILES=(/var/log/httpd/access_log*)
    fi
  fi

  # prepare files list
  FILE_LIST="${LOGFILES[@]}"

  if $REALTIME; then
    echo "[*] Starting GoAccess real-time dashboard..."
    cat $FILE_LIST | goaccess --log-format=$FORMAT --real-time-html --ws-url=$WS_URL --stdin
  else
    if [[ -z $OUTPUT ]]; then
      echo "[!] --output is required for static mode"; exit 1
    fi
    mkdir -p "$(dirname "$OUTPUT")"
    echo "[*] Generating GoAccess report..."
    # apply filters if any
    if [[ -n $SINCE || -n $UNTIL ]]; then
      PATTERN=""
      [[ -n $SINCE ]] && PATTERN+="^$SINCE"
      [[ -n $UNTIL ]] && PATTERN+="|^$UNTIL"
      cat $FILE_LIST | grep -E "$PATTERN" | goaccess --log-format=$FORMAT -o "$OUTPUT" --stdin
    else
      cat $FILE_LIST | goaccess --log-format=$FORMAT -o "$OUTPUT" --stdin
    fi
    echo "[✓] Report saved to $OUTPUT"
  fi
}

daily_report() {
  install_goaccess >/dev/null 2>&1
  # Determine rolled log based on web server
  if [[ $WEBSRV == nginx ]]; then
    ROLLED_LOG="/var/log/nginx/access.log.1"
  else
    # apache
    if [[ -f /var/log/apache2/access.log.1 ]]; then
      ROLLED_LOG="/var/log/apache2/access.log.1"
    else
      ROLLED_LOG="/var/log/httpd/access_log.1"
    fi
  fi
  FILE="/tmp/goaccess_$(date -d 'yesterday' +%F).html"
  echo "[*] Daily report (rolled log: $ROLLED_LOG) → $FILE"
  cat "$ROLLED_LOG" | goaccess --log-format=COMBINED -o "$FILE"
  echo "[✓] Done"
}

realtime_dashboard() {
  install_goaccess >/dev/null 2>&1
  # Determine live log based on web server
  if [[ $WEBSRV == nginx ]]; then
    LIVE_LOG="/var/log/nginx/access.log"
  else
    # apache
    if [[ -f /var/log/apache2/access.log ]]; then
      LIVE_LOG="/var/log/apache2/access.log"
    else
      LIVE_LOG="/var/log/httpd/access_log"
    fi
  fi
  echo "[*] Starting real-time dashboard on :7890 (log: $LIVE_LOG)"
  cat "$LIVE_LOG" | goaccess --log-format=COMBINED --real-time-html --ws-url=ws://0.0.0.0:7890 --stdin
}

# main
[[ $# -lt 1 ]] && { print_help; exit; }
case $1 in
  install) install_goaccess ;;  
  run) shift; run_goaccess "$@" ;;  
  daily-report) daily_report ;;  
  realtime-dashboard) realtime_dashboard ;;  
  help) print_help ;;  
  *) print_help; exit 1;;
esac
