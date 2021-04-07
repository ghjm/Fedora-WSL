#Requires -RunAsAdministrator

##########################################################
######### Constants - set these as appropriate ###########
##########################################################

$username = "winuser"       # Linux username
$fedora_filename = "fedora-33.20210401-x86_64.tar.xz"
$fedora_userland_url = "https://github.com/fedora-cloud/docker-brew-fedora/raw/33/x86_64/fedora-33.20210401-x86_64.tar.xz"
$distro_name = "Fedora-33"
$xming_installer = ".\rel_x64_Xming-7-7-0-62-setup.exe"
$xming_fonts_installer = ".\Xming-fonts-7-7-0-10-setup.exe"
$xlunch_source_url = "https://github.com/Tomas-M/xlunch/archive/refs/tags/v4.7.0.tar.gz"

##########################################################

$ErrorActionPreference = "Stop"

# Verify Windows version
if ([Environment]::OSVersion.Version.Build -lt 19042) {
    Write-Host "Windows 10 version must be 20H2 or above"
    exit 1
}

# cd to the script directory
$wsl_dir = Split-Path $MyInvocation.MyCommand.Path -Parent
Set-Location -Path $wsl_dir

# Determine the extracted tar filename
$fedora_tar = $fedora_filename -replace ".xz"

if (-not (Test-Path -Path $fedora_tar -PathType Leaf -ErrorAction SilentlyContinue)) {

    Write-Host "Downloading and installing the Fedora userland tarball..."

    # Download the userland tarball of the Fedora container image
    if (-not (Test-Path -Path $fedora_filename -PathType Leaf -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest -Uri $fedora_userland_url -OutFile "fedora-33.20210401-x86_64.tar.xz"
    }

    # Make sure 7Zip is installed
    if (-not (Get-Command Expand-7Zip -ErrorAction SilentlyContinue)) {
        Install-Package -Scope CurrentUser -Force 7Zip4PowerShell > $null
    }

    # Un-xz the Fedora tarball and move it to the current directory
    Expand-7Zip -ArchiveFileName $fedora_filename -TargetPath extract
    Move-Item -Path ("extract\{0}" -f $fedora_tar) -Destination $fedora_tar
    Remove-Item -Path "extract"

    # Remove the xz file since it is no longer needed
    Remove-Item -Path $fedora_filename

}

# Install WSL
Write-Host "Checking if the WSL Windows featire is installed..."
if (-not ((Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq "Enabled") `
    -or -not ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled")) {

    Write-Host "Installing the WSL Windows feature..."

    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

    Write-Host "Reboot required.  Run this script again after rebooting."
    Restart-Computer -confirm
}

# Update WSL kernel
Write-Host "Installing WSL kernel update..."
if (-not (Test-Path -Path "wsl_update_64.msi" -PathType Leaf -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" `
        -OutFile "wsl_update_64.msi"
}
.\wsl_update_64.msi /passive /promptrestart

# Set default mode to WSL2
wsl --set-default-version 2 > $null

# Import the distro
Write-Host "Importing tarball as WSL distro..."
wsl --import "$distro_name" "$wsl_dir\$distro_name" $fedora_tar

# Set the locale
Write-Host 'Configuring locale.  A "Failed to set locale" error is normal here.'
wsl -u root bash -c 'dnf -y install glibc-langpack-en && echo ''LANG="en_US.UTF-8"'' > /etc/locale.conf'

# Set up the Fedora instance - install packages, etc
Write-Host "Configuring Fedora..."
Set-Content -Path setup.sh -NoNewline -Value (@"
if ! man man >& /dev/null; then
    sed -i '/nodocs/d' /etc/dnf/dnf.conf
    dnf -y reinstall `$(rpm -qa)
fi
dnf -y update
dnf -y install wget curl sudo ncurses dnf-plugins-core dnf-utils passwd findutils \
    bind-utils man man-pages procps-ng psmisc iproute net-tools iputils which telnet nc \
    podman python-devel python3-virtualenv lxterminal firefox python "@Development Tools" \
    liberation-sans-fonts imlib2-devel libX11-devel
if ! id $username >& /dev/null; then
    useradd -G wheel $username
fi
sed -i 's/^%wheel/# %wheel/' /etc/sudoers
sed -i 's/^# \(%wheel.*NOPASSWD\)/\1/' /etc/sudoers
cp /usr/share/containers/containers.conf /etc/containers
sed -i 's/^# cgroup_manager.*$/cgroup_manager = "cgroupfs"/' /etc/containers/containers.conf
sed -i 's/^# events_logger.*$/events_logger = "file"/' /etc/containers/containers.conf
"@).Replace("`r`n","`n")
wsl -u root bash -e setup.sh
Remove-Item -Path setup.sh

# Set uid 1000 as the default user
Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ `
    DistributionName | Where-Object -Property DistributionName -eq Fedora-33  | `
    Set-ItemProperty -Name DefaultUid -Value 1000

# Install Xming
if (-not (Test-Path -Path "C:\Program Files\Xming\Xming.exe" -PathType Leaf -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Xming..."
    Start-Process -Wait "$xming_installer" -ArgumentList "/verysilent", "/norestart"
    Write-Host "Installing Xming Fonts..."
    Start-Process -Wait "$xming_fonts_installer" -ArgumentList "/verysilent", "/norestart"
}

# Set up xlunch
Write-Host "Setting up xlunch..."
Set-Content -Path xlunch.conf -NoNewline -Value (@"
width: 600
height: 400
prompt: Run:
font: /usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf/10
iconpadding: 10
textpadding: 10
borderratio: 50
promptspacing: 48
iconsize: 48
textcolor: ffffffff
promptcolor: ffffffff
backgroundcolor: 2e3440ff
highlightcolor: ffffff32
"@).Replace("`r`n","`n")

Set-Content -Path entries.dsv -NoNewline -Value (@"
terminal;/usr/share/icons/hicolor/128x128/apps/lxterminal.png;lxterminal
firefox;/usr/share/icons/hicolor/48x48/apps/firefox.png;firefox
"@).Replace("`r`n","`n")

Set-Content -Path lxterminal.conf -NoNewline -Value (@"
[general]
fontname=Source Code Pro 12
color_preset=Tango
"@).Replace("`r`n","`n")


Set-Content -Path setup_xlunch.sh -NoNewline -Value (@"
mkdir -p /home/$username/.config/xlunch
for file in xlunch.conf entries.dsv; do
  if [ ! -f "/home/$username/.config/xlunch/`$file" ]; then
    cp `$file /home/$username/.config/xlunch/`$file
  fi
done
mkdir -p /home/$username/.config/lxterminal
if [ ! -f "/home/$username/.config/lxterminal/lxterminal.conf" ]; then
  cp lxterminal.conf /home/$username/.config/lxterminal/lxterminal.conf
fi
if [ ! -f "/home/$username/bin/xlunch" ]; then
  mkdir -p /home/$username/xlunch
  cd /home/$username/xlunch
  wget --quiet https://github.com/Tomas-M/xlunch/archive/refs/tags/v4.7.0.tar.gz
  tar xzf v*.tar.gz
  cd xlunch*
  make xlunch
  mkdir -p /home/$username/bin
  cp xlunch /home/$username/bin
fi
"@).Replace("`r`n","`n")
wsl -u $username bash -e setup_xlunch.sh
Remove-Item -Path setup_xlunch.sh
Remove-Item -Path xlunch.conf
Remove-Item -Path entries.dsv
Remove-Item -Path lxterminal.conf

Write-Host "Creating start menu shortcut..."
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$HOME\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\$distro_name.lnk")
$Shortcut.IconLocation = "%SystemRoot%\System32\SHELL32.dll,48"
$Shortcut.TargetPath = "$wsl_dir\xlunch.vbs"
$Shortcut.Save()

Write-Host "Done!"