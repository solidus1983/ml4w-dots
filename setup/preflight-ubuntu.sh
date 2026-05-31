#!/usr/bin/env bash

# --------------------------------------------------------------
# Repositories
# --------------------------------------------------------------

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe
sudo add-apt-repository -y restricted

# --------------------------------------------------------------
# Hyprland PPA
# --------------------------------------------------------------

if ! grep -R "^deb .*cppiber.*hyprland" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | grep -q .; then
    echo ":: Adding PPA: ppa:cppiber/hyprland"
    sudo add-apt-repository -y ppa:cppiber/hyprland
else
    echo ":: Hyprland PPA already present"
fi

sudo apt-get update

# --------------------------------------------------------------
# Uninstall swww if exists. To be replaced with awww in the next steps
# --------------------------------------------------------------

if dpkg -l 2>/dev/null | grep -q "^ii  swww "; then
    sudo apt-get remove -y swww
fi
