# ids_mon.py = Ett python skript för att skapa en ids som övervakar,blockerar och rapporterar
# Skriptet är skapat av = Christian Dumitraskovic, Maj 2025

# Syfte
# Läsa en loggfil
# Analysera traffken
# Skicka epost varningar
# Generera en cvs rapport
# Blockera via ufw

# Modulering 
import time
import subprocess
import smtplib
from email.message import EmailMessage
import os
import logging

# --- Konfiguration ---
TRAFFIC_LOG = os.path.expanduser("~/network_traffic.log")
EMAIL_FROM = "dumitraskovichchristian@gmail.com"
EMAIL_TO = "dumitraskovichchristian@gmail.com"
EMAIL_PASSWORD = "gdxg jfvv fzvwotav"
PORT_BLACKLIST = {"21", "23", "666", "8080", "3389", "9999"}  # misstänkta portar

# Loggning
LOG_FILE = os.path.expanduser("~/monitor.log")
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

def log_message(level, message):
    if level == "INFO":
        logging.info(message)
    elif level == "WARNING":
        logging.warning(message)
    elif level == "ERROR":
        logging.error(message)
    print(f"{level}: {message}")

def send_email(subject, body):
    try:
        msg = EmailMessage()
        msg["From"] = EMAIL_FROM
        msg["To"] = EMAIL_TO
        msg["Subject"] = subject
        msg.set_content(body)

        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            server.login(EMAIL_FROM, EMAIL_PASSWORD)
            server.send_message(msg)

        log_message("INFO", "E-postvarning skickad.")
    except Exception as e:
        log_message("ERROR", f"Kunde inte skicka e-post: {e}")

def block_ip(ip):
    try:
        subprocess.run(["sudo", "ufw", "deny", "from", ip], check=True)
        log_message("INFO", f"Blockerade IP med UFW: {ip}")
    except Exception as e:
        log_message("ERROR", f"Kunde inte blockera IP {ip}: {e}")

# === Huvudkontroll ===
try:
    count = 3
    while count > 0:
        connections = {}

        with open(TRAFFIC_LOG, "r") as file:
            for line in file:
                parts = line.strip().split(",")
                if len(parts) < 5:
                    continue

                timestamp, source_ip, dest_ip, port, protocol = [p.strip() for p in parts]

                # Kolla efter svartlistade portar
                if port in PORT_BLACKLIST:
                    message = f"Hittat misstänkt port {port} från IP {source_ip}"
                    log_message("WARNING", message)
                    send_email("Nätverksvarning", message)
                    block_ip(source_ip)

                # Räkna anslutningar per IP
                connections[source_ip] = connections.get(source_ip, 0) + 1

        # Rapportera och blockera IPs med för många anslutningar
        with open("Rapport.csv", "w") as report:
            report.write("IP,Antal anslutningar\n")
            for ip, conn_count in connections.items():
                report.write(f"{ip},{conn_count}\n")
                if conn_count > 5:
                    msg = f"IP {ip} har {conn_count} anslutningar - blockeras."
                    log_message("WARNING", msg)
                    send_email("Anslutningsvarning", msg)
                    block_ip(ip)

        log_message("INFO", "Klar med en kontrollomgång.")
        time.sleep(10)
        count -= 1

    log_message("INFO", "Loggen kontrollerad tre gånger.")

except Exception as e:
    log_message("ERROR", f"Något gick fel: {e}")
