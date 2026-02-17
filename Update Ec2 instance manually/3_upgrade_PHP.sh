#!/bin/bash
# Created by: Tarj Mehta
# Creation Date: 29-12-2025
# Last edit: 15-01-2026


set -euo pipefail # stop execution if error is encountered

echo "==========SCRIPT STARTED=========="

# PHP settings - adding the repo
sudo apt update
sudo apt install -y software-properties-common # dependency
sudo add-apt-repository -y ppa:ondrej/php # adding repository
sudo apt update
sleep 5 # pause for 5 seconds

# Confirm the addition of PHP repo
ls /etc/apt/sources.list.d/ | grep ondrej
sleep 5 # pause for 5 seconds

# Adjust as per the available latest PHP
sudo apt install php8.5 php8.5-cli php8.5-fpm php8.5-common -y

#------------------------------------------------
# 1. Get the list of all installed PHP versions from update-alternatives
#    We grep for 'php' to ensure we match valid binary paths.
AVAILABLE_PHPS=$(update-alternatives --list php)

if [ -z "$AVAILABLE_PHPS" ]; then
    echo "No PHP alternatives found."
    exit 1
fi

# 2. Sort the versions to find the latest one.
#    'sort -V' sorts by version number (natural sort). 
#    'tail -n 1' grabs the last line (the highest version).
LATEST_PHP=$(echo "$AVAILABLE_PHPS" | sort -V | tail -n 1)

echo "Found latest PHP version: $LATEST_PHP"

apt install libapache2-mod-php8.5

# 3. Set the detected latest version as the default
sudo update-alternatives --set php "$LATEST_PHP"

# 4. Confirm the change
echo "------------------------------------------------"
echo "Active PHP CLI version updated to:"
php -v | head -n 1
echo "------------------------------------------------"

#-------------------------------------------------------------------------------------

sleep 5 # pause for 5 seconds

#Checking PHP verison
php -v
sleep 5 # pause for 5 seconds

sudo apt update
sudo apt install -y php8.5-bcmath php8.5-curl php8.5-xml php8.5-mbstring php8.5-gd php8.5-mysql php8.5-zip php8.5-xsl
sleep 5 # pause for 5 seconds

#Checking AWS Linux version
dpkg -l | grep linux-image-aws
sleep 5 # pause for 5 seconds

#checking apache2 syntax checking
sudo apache2ctl configtest
sleep 5 # pause for 5 seconds

# Restart apache2 for changes to take place
sudo systemctl restart apache2
sleep 5 # sleep for 5 seconds

# Printing the status of apache2 for confirmation
sudo systemctl status apache2
sleep 5 # pause for 5 seconds

sleep 5 # sleep for 5 seconds

# Printing Ubuntu version
lsb_release -a
sleep 5 # sleep for 5 seconds

sudo a2dismod php8.4 #check php version from instance
sudo systemctl restart apache2
sudo systemctl status apache2
# apt install libapache2-mod-php8.5 #moved to line 42
sudo a2enmod php8.5 #check latest php version


echo "==========SCRIPT ENDED=========="