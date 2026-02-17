#!/bin/bash

set -euo pipefail

echo "==========SCRIPT STARTED=========="

# IMMORTALDIR and IMMORTALCTL
# Install dependencies
sudo apt update
sudo apt install -y git build-essential
sudo apt install -y golang
# single command for both:
# sudo apt install golang-go git build-essential -y

# Download and build immortal
cd /opt
sudo git clone https://github.com/immortal/immortal.git
cd immortal
sudo make

# Install binaries
sudo cp -r immortal immortaldir /usr/local/bin/ /usr/bin/ # this prevents it from going to /usr/local/bin/immortal* in ubuntu 22.04 # added destination /usr/bin to copy from /usr/local/bin
sudo cp -r immortal immortalctl /usr/local/bin/ /usr/bin/ # this prevents it from going to /usr/local/bin/immortal* in ubuntu 22.04 # added destination /usr/bin to copy from /usr/local/bin
sudo chmod +x /usr/bin/immortal /usr/bin/immortaldir
sudo chmod +x /usr/bin/immortal /usr/bin/immortalctl

# Verify
ls -l /usr/bin/immortaldir
ls -l /usr/bin/immortalctl

# Start Jobs
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart immortaldir.service
sudo systemctl status immortaldir.service

# IMMORTALCTL
#sudo apt update

# Download latest release
#cd /tmp
#git clone https://github.com/immortal/immortal.git
#cd immortal
#sudo make
#sudo cp immortal immortalctl /usr/local/bin/
#sudo chmod +x /usr/local/bin/immortal*
#sudo mv /usr/local/bin/immortal /usr/local/immortal

echo "==========SCRIPT ENDED=========="
