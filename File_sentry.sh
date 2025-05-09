#!/bin/bash
# file_sentry.sh - Övervakar en katalog för misstänkta filer
# Skapat av: Christian, April 2025

readonly LOG_FILE="$HOME/file_sentry.log" #Loggfil i hemmappen
readonly TEMP_FILE="/tmp/file_sentry_$$.tmp" #Temporär fil med unikt namn
readonly SIZE_THRESHOLD=1048576 # 1 MB i bytes
readonly TARGET_DIR="$1" # Första argumentet är katalogen

set -e # Avsluta vid fel
set -u # Fel om odefinierade variabler används
trap 'echo "Skript avbrutet!"; rm -f "$TEMP_FILE"; exit 1' INT TERM EXIT

log_message(){
    local level="$1" #INFO,WARNING,ERROR
    local message="$2"
    printf "%s [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" >> "$LOG_FILE"
    }
    
 if [[ -z "$TARGET_DIR" ]]; then
    log_message "ERROR" "Ingen katalog angiven. Använd: ./file_sentry.sh <katalog>"
    echo "Fel: Ange en katalog!" >&2
    exit 1
 fi 

if [[ ! -d "$TARGET_DIR" ]]; then
   log_message "ERROR" "$TARGET_DIR är inte en katalog."
   echo "Fel: $TARGET_DIR finns inte eller är ingen katalog!" >&2
   exit 1 
fi

log_message "INFO" "Skannar $TARGET_DIR för misstänkta filer.."

# Hitta filer och spara storlek och rättigheter till temprär fil
find "$TARGET_DIR" -type f -exec stat -c "%s %A %n" {} \; > "$TEMP_FILE"

# Analysera varje fil
while read -r size perms name; do
  # Kontrollera storlek
  if (( size > SIZE_THRESHOLD )); then
     log_message "WARNING" "Stor fil: $name ($size bytes)"
  fi

  # Kontrollera körbara rättigheter
  if [[ "$perms" =~ x ]]; then
      log_message "WARNING" "Körbar fil: $name ($perms)"
      echo "Varning: $name är körbar!" >&2
  fi
done < "$TEMP_FILE"

 log_message "INFO" "Skanning klar"
rm -f "$TEMP_FILE"

