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
Write-Host "log_mon skriptet startat" -ForegroundColor Yellow


# Säkerhetskontroller och åtgärder

# Funktion som kontrollerar ifall brandvägg är aktiv för alla profiler
function Enable-Firewall {
    Write-Log "Kontrollerar Windows Brandvägg-status..."
    Write-Host "Kontrollerar Windows Brandvägg-status..." -ForegroundColor Yellow
    Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled True
    Write-Log "Windows Firewall är -AKTIVERAD- för alla profiler."
    Write-Host "Windows Firewall är -AKTIVERAD- för alla profiler." -ForegroundColor Green
}

# Verifierar och kollar ifall Windows defender är aktivt och uppdaterat
function Update-Defender {
    Write-Log "Verifierar Windows Defender..."
    Write-Host "Verifierar Windows Defender..." -ForegroundColor Yellow

    $defender = Get-MpComputerStatus

    if ($defender.AntivirusEnabled -eq $true) {
        Write-Log "Windows Defender är -AKTIVT-."
        Write-Host "Windows Defender är -AKTIVT-." -ForegroundColor Green
    } else {
        Write-Log "Windows Defender är -INTE AKTIVT-."
        Write-Host "Windows Defender är -INTE AKTIVT-." -ForegroundColor Red
    }

    
    Write-Log "Söker efter uppdateringar..."
    Write-Host "Söker efter uppdateringar..." -ForegroundColor Yellow

    if  ($defender.AntivirusSignatureUpToDate -eq $true) {
        Write-Log "Windows Defender är -UPPDATERAD-."
        Write-Host "Windows Defender är -UPPDATERAD-." -ForegroundColor Green
    } else {
        Write-Log "Windows Defender är -INTE UPPDATERAD-"
        Write-Host "Windows Defender är -INTE UPPDATERAD-" -ForegroundColor Red
    }
}

function Update-Admins {
    # Hämtar godkända användare från fil
    $approvedUsers = Get-Content "C:\Path\To\approved_users.txt"

    # Hämtar alla användare i Administrators-gruppen
    $admins = Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.ObjectClass -eq 'User' }

    foreach ($admin in $admins) {
        $username = $admin.Name

        if ($approvedUsers -notcontains $username) {
            Write-Log "Otillåten användare hittad: $username - tas bort från Administrators-gruppen"
            Write-Host "Otillåten användare hittad: $username - tas bort från Administrators-gruppen" -ForegroundColor Green
            Remove-LocalGroupMember -Group "Administrators" -Member $username

            # Kontrollera senaste inloggning
            $lastLogon = (Get-LocalUser -Name $username).LastLogon
            if ($lastLogon -lt (Get-Date).AddDays(-90)) {
                Disable-LocalUser -Name $username
                Write-Log "Användare $username har inte loggat in på 90 dagar och har -INAKTIVERATS-" 
                Write-Host "Användare $username har inte loggat in på 90 dagar och har -INAKTIVERATS-" -ForegroundColor Red
            }
        }
    }
}

function Disable-SMBv1 {
    # Inaktiverar SMBv1 
    Write-Log "Inaktiverar SMBv1 via registerändringar"
    Write-Host "Inaktiverar SMBv1 via registerändringar" -ForegroundColor Yellow
    
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
                     -Name SMB1 -Value 0 -PropertyType DWORD -Force | Out-Null
                     
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force | Out-Null

    Write-Log "SMBv1 -INAKTIVERAD-"
    Write-Host "SMBv1 -INAKTIVERAD-" -ForegroundColor Green
}

function Disable-Onödiga_tjänster {
    $servicesToDisable = @("Telnet", "ftpsvc")

    foreach ($serviceName in $servicesToDisable) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force
                Write-Log "Tjänsten $serviceName stoppades"
            }
            Set-Service -Name $serviceName -StartupType Disabled
            Write-Log "Tjänsten $serviceName inaktiverades"
        } else {
            Write-Log "Tjänsten $serviceName hittades inte"
        }
    }
}

function Disable-Onödiga_tjänster {
    # Inaktiverar onödiga tjänster som telnet och ftpsvc
    $servicesToDisable = @("Telnet", "ftpsvc")
    Write-Log "Letar efter aktiva tjänster"
    Write-Host "Letar efter aktiva tjänster" -ForegroundColor Yellow

    foreach ($serviceName in $servicesToDisable) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force
                Write-Log "Tjänsten $serviceName -STOPPAD-"
                Write-Host "Tjänsten $serviceName -STOPPAD-" -ForegroundColor Green
            }
            Set-Service -Name $serviceName -StartupType Disabled
            Write-Log "Tjänsten $serviceName -INAKTIVERAD-"
            Write-Host "Tjänsten $serviceName -INAKTIVERAD-" -ForegroundColor Green
        } else {
            Write-Log "Tjänsten $serviceName hittades inte"
            Write-Host "Tjänsten $serviceName hittades inte" -ForegroundColor Red
        }
    }
}


function Update-Diskutrymme_arkiverar {
    # Funktionen kontrollerar diskutrymme och flyttar sedan temporära filer ifall diskutrymme är under 15 procent
    Write-Log "Kontrollerar diskutrymme C"
    Write-Host "Kontrollerar diskutrymme C" -ForegroundColor Yellow
    $drive = Get-PSDrive -Name C
    $freePercent = ($drive.Free / $drive.Used + $drive.Free) * 100
    # Kontrollerar diskutrymmet
    if ($freePercent -lt 15) {
        $archivePath = "C:\Archive_TempFiles"
        if (-not (Test-Path $archivePath)) {
            New-Item -Path $archivePath -ItemType Directory | Out-Null
        }

        $tempPath = "$env:TEMP\*"
        Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Move-Item $_.FullName -Destination $archivePath -Force
                Write-Log "Flyttade temporär fil: $($_.FullName) till $archivePath"
                Write-Host "Flyttade temporär fil: $($_.FullName) till $archivePath" -ForegroundColor Green
            } catch {
                Write-Log "Kunde inte flytta fil: $($_.FullName) - $_"
                Write-Host "Kunde inte flytta fil: $($_.FullName) - $_" -ForegroundColor Red
            }
        }
        Write-Log "Temporära filer arkiverade på grund av låg diskutrymme"
        Write-Host "Temporära filer arkiverade på grund av låg diskutrymme" -ForegroundColor Green
    } else {
        Write-Log "Diskutrymme är tillräckligt: $([math]::Round($freePercent, 2))%"
        Write-Host "Diskutrymme är tillräckligt: $([math]::Round($freePercent, 2))%" -ForegroundColor Green
    }
}

function Enable-Bitlocker {
    Write-Log "Aktiverar Bitlocker om möjligt"
    Write-Host "Aktiverar Bitlocker om möjligt"
    # Funktionen aktiverar bitlocker
    $bitLockerStatus = Get-BitLockerVolume -MountPoint "C:"
    if ($bitLockerStatus.ProtectionStatus -eq 'Off') {
        Write-Log "BitLocker är inte aktiverat - försöker aktivera" 
        Write-Host "BitLocker är inte aktiverat - försöker aktivera"  -ForegroundColor Red

        $recoveryKeyPath = "C:\BitLocker_Recovery"
        if (-not (Test-Path $recoveryKeyPath)) {
            New-Item -Path $recoveryKeyPath -ItemType Directory | Out-Null
        }

        Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -TpmProtector -RecoveryKeyPath $recoveryKeyPath -UsedSpaceOnly -Confirm:$false
        Write-Log "BitLocker aktiverat med TPM och återställningsnyckel sparad i $recoveryKeyPath"
        Write-Host "BitLocker aktiverat med TPM och återställningsnyckel sparad i $recoveryKeyPath" -ForegroundColor Green
    } else {
        Write-Log "BitLocker är redan aktiverat på systemdisken"
        Write-Host "BitLocker är redan aktiverat på systemdisken" -ForegroundColor Green
    }
}


Write-Host "Skripet avslutat och alla händelser sparat i loggfil"


# Kör funktionen kontrollera brandvägg
Enable-Firewall

# Kör funktionen kontrollera windows defender
Update-Defender

# Kör funktionen lista admin
Update-Admins

# Kör funktionen och inaktiverar SMBv1
Disable-SMBv1

# Kör funktionen inaktiverar onödiga tjänster
Disable-Onödiga_tjänster

# Kör funktionen kontrollerar diskutrymme och arkiverar ifall under 15%
Update-Diskutrymme_arkiverar

# Kör funktionen aktiverar bitlocker om möjligt
Enable-BitLocker