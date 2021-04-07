Graham's Fedora WSL Setup
=========================

This repo sets up Fedora under WSL2 the way I happen to like.  It creates
and configures a Fedora WSL distro, and includes a script to easily launch
X11 apps from Windows.

To use this:

* Clone, or download and extract a zip file of, this repo, into the directory where you want your WSL distro stored in (for example, C:\Fedora).
* Download Xming and Xming-fonts and place them into the repo folder, or have them already installed.
* Edit Setup-Fedora-WSL.ps1 and set the variables at the top, particularly the username.
* Run Setup-Fedora-WSL.ps1 (as administrator).
* If prompted to reboot, do so and then run the script again.

