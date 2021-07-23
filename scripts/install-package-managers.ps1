# Adapted from: https://github.com/ChrisTitusTech/win10script/blob/master/win10debloat.ps1
# Adapted from: https://github.com/W4RH4WK/Debloat-Windows-10/blob/master/utils/install-basic-software.ps1

function Install-PackageManager() {
  [CmdletBinding()]
  param (
    [String]	$PackageManagerFullName,
    [String]  $CheckExistenceBlock,
    [String]  $InstallCommandBlock,
    [String]	$UpdateScriptBlock,
    [Parameter(Mandatory = $false)]
    [String]  $PostInstallBlock
  )
  
  Try {

    $err = $null
    $err = (invoke-expression "$CheckExistenceBlock")
    if (($LASTEXITCODE)) { throw $err } # 0 = False, 1 = True
    Write-Host "[=] $PackageManagerFullName is already installed."

  }
  Catch {

    Write-Host "[?] $PackageManagerFullName was not found."
    Write-Host "[+] Setting up $PackageManagerFullName package manager"

    Invoke-Expression "$InstallCommandBlock"

    If ($PostInstallBlock) {
      Write-Host "[+] Executing post install script: $PostInstallBlock"
      Invoke-Expression "$PostInstallBlock"
    }

  }

  # Adapted from: https://blogs.technet.microsoft.com/heyscriptingguy/2013/11/23/using-scheduled-tasks-and-scheduled-jobs-in-powershell/
  # Find it on "Microsoft\Windows\PowerShell\ScheduledJobs\{PackageManagerFullName} Daily Upgrade"
  Write-Host "[+] Creating a daily task to automatically upgrade $PackageManagerFullName packages"
  $JobName = "$PackageManagerFullName Daily Upgrade"
  $ScheduledJob = @{
    Name               = $JobName
    ScriptBlock        = { $UpdateScriptBlock }
    Trigger            = New-JobTrigger -Daily -At 12:00
    ScheduledJobOption = New-ScheduledJobOption -RunElevated -MultipleInstancePolicy StopExisting -RequireNetwork
  }
  
  # If the Scheduled Job already exists, delete
  If (Get-ScheduledJob -Name $JobName -ErrorAction SilentlyContinue) {
    Write-Host "[+] ScheduledJob: $JobName FOUND! Re-Creating..."
    Unregister-ScheduledJob -Name $JobName
  }
  # Then register it again
  Register-ScheduledJob @ScheduledJob

}

function Main() {
  $ChocolateyParams = @(
    "Chocolatey",
    { choco --version },
    { Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) },
    { choco upgrade all -y },
    { choco install chocolatey-core.extension -y } #--force
  )

  if (!(Test-Path "$PSScriptRoot\..\tmp")) {
    Write-Host "Folder $PSScriptRoot\..\tmp doesn't exist, creating..."
    mkdir "$PSScriptRoot\..\tmp" | Out-Null
  }

  $WingetDownload = "https://github.com/microsoft/winget-cli/releases/download/v1.0.11692/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
  $WingetOutput = "$PSScriptRoot\..\tmp\winget-latest.appxbundle"

  $WingetParams = @(
    "Winget",
    { winget -v },
    { Invoke-WebRequest -Uri $WingetDownload -OutFile $WingetOutput; Write-Host "Installing the package"; Add-AppxPackage -Path $WingetOutput; Remove-Item -Path "$WingetOutput" },
    { winget upgrade --all },
    {}
  )

  # Install Chocolatey on Windows
  Install-PackageManager -PackageManagerFullName $ChocolateyParams[0] -CheckExistenceBlock $ChocolateyParams[1] -InstallCommandBlock $ChocolateyParams[2] -UpdateScriptBlock $ChocolateyParams[3] -PostInstallBlock $ChocolateyParams[4]
  # Install Winget on Windows
  Install-PackageManager -PackageManagerFullName $WingetParams[0] -CheckExistenceBlock $WingetParams[1] -InstallCommandBlock $WingetParams[2] -UpdateScriptBlock $WingetParams[3]
}

Main