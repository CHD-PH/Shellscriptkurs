# log_mon = Ett script som kommer att härda och logga samt senare presentera allt i konsolen
# Skriptet är skapat av : Christian Dumitraskovic , April 2025

# Detta är vår loggfil
$LogFile = "C:\Users\dumit\logs\Security_Hardening_$(Get-Date -Format 'yyyyMMdd').log"

# Loggfilen skapas
"Loggfil skapad: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogFile -Encoding UTF8


#--------Funktioner--------
# Vår funktion för att kunna skriva ut en logg
function Write-Log {
    param (
        [string]$message
     )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp : $message"
}

# Loggar att skriptet har startat
Write-Log "log_mon skriptet startat"


# Säkerhetskontroller och åtgärder

# Funktion som kontrollerar ifall brandvägg är aktiv för alla profiler
function Enable-Firewall {
    Write-Log "Kontrollerar Windows Brandvägg-status..."
    Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled True
    Write-Log "Windows Firewall är aktiverad för alla profiler."
}

# Verifierar och kollar ifall Windows defender är aktivt och uppdaterat
function Update-Defender {
    Write-Log "Verifierar Windows Defender..."

    $defender = Get-MpComputerStatus

    if ($defender.AntivirusEnabled -eq $true) {
        Write-Log "Windows Defender är aktivt."
    } else {
        Write-Log "Windows Defender är INTE aktivt."
    }
    
    Write-Log "Söker efter uppdateringar..."

    if  ($defender.AntivirusSignatureUpToDate -eq $true) {
        Write-Log "Windows Defender är uppdaterad."
    } else {
        Write-Log "Windows Defender är INTE uppdaterad"
    }
}

# Kör funktionen kontrollera brandvägg
Enable-Firewall

# Kör funktionen kontrollera windows defender
Update-Defender

