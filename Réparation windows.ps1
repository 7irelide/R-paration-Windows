# Configuration initiale des couleurs et nettoyage
$host.UI.RawUI.BackgroundColor = "DarkBlue" 
$host.UI.RawUI.ForegroundColor = "Gray"
Clear-Host

# Vérification des privilèges administrateurs
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script nécessite des privilèges administrateur. Veuillez relancer PowerShell en tant qu'administrateur." -ForegroundColor Red
    pause
    exit
}

# Initialisation d'un tableau pour suivre les actions effectuées
$actionsDone = @($false, $false, $false, $false, $false, $false, $false, $false, $false)

# Fonction pour écrire dans le fichier LOG.TXT
function WriteToLog {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $username = [Environment]::UserName
    Add-Content -Path "LOG.TXT" -Value "[$timestamp] [$username] $message"
}

# Fonction pour exécuter une commande système avec gestion d'erreurs
function Invoke-SystemCommand {
    param (
        [string]$Command,
        [string]$Description,
        [int]$ActionIndex
    )
    Write-Host "`n$Description" -ForegroundColor Yellow
    Write-Host "----------------------------"
    Write-Host "Veuillez patienter...`n"
    try {
        $result = Invoke-Expression $Command
        Write-Host $result
        WriteToLog "Executed: $Command"
        $actionsDone[$ActionIndex] = $true
        Write-Host "`nOpération terminée avec succès." -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de l'exécution de $Description : $_" -ForegroundColor Red
        WriteToLog "Error: $Command failed - $_"
    }
    pause
}

# Fonction pour planifier une vérification de disque
function ScheduleChkdsk {
    param ([string]$drive)
    Write-Host "`nPlanification de la vérification du lecteur $drive" -ForegroundColor Yellow
    try {
        $taskName = "ChkDsk_$($drive.Replace(':', ''))"
        $action = New-ScheduledTaskAction -Execute 'chkdsk.exe' -Argument "$drive /f /r"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden

        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }

        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Vérification du disque $drive" -Principal $principal -Settings $settings

        Write-Host "La vérification du disque $drive a été planifiée pour le prochain redémarrage." -ForegroundColor Green
        WriteToLog "Scheduled: chkdsk $drive /f /r at next startup"
    } catch {
        Write-Host "Erreur lors de la planification de la vérification du lecteur $drive : $_" -ForegroundColor Red
        WriteToLog "Error: Failed to schedule chkdsk on $drive - $_"
    }
    pause
}

# Fonction pour exécuter chkdsk avec choix de lecteur
function ExecuteChkDsk {
    Clear-Host
    Write-Host "Vérification du disque dur" -ForegroundColor Yellow
    Write-Host "----------------------------"
    Write-Host "Cette action vérifie l'intégrité d'un disque dur choisi et tente de récupérer les informations dans les secteurs défectueux.`n"

    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object { $_.DeviceID }
    $index = 1
    Write-Host "Lecteurs disponibles:" -ForegroundColor Cyan
    foreach ($drive in $drives) {
        Write-Host "$index. $drive"
        $index++
    }
    Write-Host "$index. Tous les lecteurs"
    Write-Host "$($index+1). Rescaner les lecteurs disponibles"
    
    $choice = Read-Host "Veuillez choisir un lecteur (par numéro)"
    
    if ($choice -eq $index) {
        foreach ($drive in $drives) {
            ScheduleChkdsk $drive
        }
    } elseif ($choice -eq ($index+1)) {
        ExecuteChkDsk
    } elseif ([int]$choice -ge 1 -and [int]$choice -lt $index) {
        $selectedDrive = $drives[[int]$choice-1]
        ScheduleChkdsk $selectedDrive
    } else {
        Write-Host "Choix invalide." -ForegroundColor Red
    }
    
    $actionsDone[4] = $true
}

# Boucle principale pour l'exécution du menu
do {
    Clear-Host
    Write-Host "                                   Menu Principal" -ForegroundColor Cyan
    Write-Host "                                 ------------------`n"

    $options = @(
        "Vérification du système Windows",
        "Scan approfondi du système",
        "Réparation automatique",
        "Vérification des fichiers système",
        "Vérification du disque dur",
        "Rafraîchissement des adresses web",
        "Rapport d'énergie",
        "Rapport de batterie",
        "Redémarrage avancé"
    )

    $descriptions = @(
        "Vérifie si des problèmes sont présents dans votre système Windows.",
        "Exécute un scan plus approfondi de l'image du système pour rechercher des corruptions.",
        "Tente de réparer automatiquement toutes les corruptions détectées dans l'image du système.",
        "Exécute l'outil System File Checker pour rechercher et réparer les fichiers système manquants ou corrompus.",
        "Vérifie l'intégrité d'un disque dur choisi et tente de récupérer les informations dans les secteurs défectueux.",
        "Rafraîchit les adresses de sites web pour une navigation plus fluide.",
        "Génère un rapport sur les problèmes d'énergie qui peuvent affecter les performances de la batterie.",
        "Crée un rapport détaillé sur la santé et les performances de la batterie de votre ordinateur.",
        "Redémarre l'ordinateur et ouvre le menu des options de démarrage avancées."
    )

    for ($i = 0; $i -lt $options.Length; $i++) {
        $indicator = if ($actionsDone[$i]) { "[X]" } else { "[ ]" }
        Write-Host ("$indicator $($i + 1) " + $options[$i]) -ForegroundColor Yellow
        Write-Host "   $($descriptions[$i])`n"
    }

    Write-Host "[ ] 10) Quitter" -ForegroundColor Red

    $choice = Read-Host "`nChoisissez une option"

    switch ($choice) {
        "1" { Invoke-SystemCommand "DISM /Online /Cleanup-image /CheckHealth" "Vérification du système Windows" 0 }
        "2" { Invoke-SystemCommand "DISM /Online /Cleanup-image /ScanHealth" "Scan approfondi du système" 1 }
        "3" { Invoke-SystemCommand "DISM /Online /Cleanup-image /RestoreHealth" "Réparation automatique" 2 }
        "4" { Invoke-SystemCommand "sfc /scannow" "Vérification des fichiers système" 3 }
        "5" { ExecuteChkDsk }
        "6" { Invoke-SystemCommand "ipconfig /flushdns" "Rafraîchissement des adresses web" 5 }
        "7" { Invoke-SystemCommand "powercfg /energy" "Rapport d'énergie" 6 }
        "8" {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $reportPath = "$env:USERPROFILE\battery-report_$timestamp.html"
            Invoke-SystemCommand "powercfg /batteryreport /output `"$reportPath`"" "Rapport de batterie" 7
        }
        "9" {
            if ((Read-Host "Êtes-vous sûr de vouloir redémarrer l'ordinateur? (O/N)").ToUpper() -eq 'O') {
                Invoke-SystemCommand "shutdown /r /fw /f /t 0" "Redémarrage avancé" 8
            }
        }
        "10" {
            WriteToLog "User exited the script."
            Write-Host "Au revoir!" -ForegroundColor Green
            exit
        }
        default {
            Write-Host "Option invalide. Veuillez réessayer." -ForegroundColor Red
            pause
        }
    }

    if ($choice -ne "10") {
        Write-Host "`nAppuyez sur Entrée pour revenir au menu principal"
        Read-Host
    }
} while ($true)