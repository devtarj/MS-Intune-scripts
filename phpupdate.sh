#!/bin/bash#!/bin/bash
# Created by: Tarj Mehta
# First created on: 17-December-2025
# Last update on: 22-December-2025

#---------- UPDATE PHP ----------

# Ubuntu version check
echo "Checking Ubuntu version"
lsb_release -a
sleep 5 # pause 5 seconds

# PHP version check
echo "Checking PHP version"
php -v
sleep 5 # pause 5 seconds

# update and upgrade remaining packages
echo "Checking package updates"
sudo apt update && sudo apt upgrade -y
sleep 5 # pause 5 seconds

# check apache2 status
echo "Checking Apache status"
systemctl status apache2
sleep 5 # pause 5 seconds

# adding package and the PHP repository
echo "Adding PHP repo"
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sleep 5 # pause 5 seconds

# Attempting to install PHP 8.5 and required extensions
echo "Installing PHP 8.5"
sudo apt install -y php8.5 libapache2-mod-php8.5

sudo apt install -y php8.5-{bcmath,calendar,Core,ctype,curl,date,dom,exif,FFI,fileinfo,filter,ftp,gd,gettext,hash,iconv,json,libxml,mbstring,mysqli,mysqlnd,openssl,pcntl,pcre,PDO,pdo_mysql,Phar,posix,random,readline,Reflection,session,shmop,SimpleXML,sockets,sodium,SPL,standard,sysvmsg,sysvsem,sysvshm,tokenizer,xml,xmlreader,xmlwriter,xsl,Zend OPcache,zip,zlib}
sleep 5 # pause 5 seconds

echo "Disabling previously installed PHP version"
udo a2dismod php7.4
sleep 5 # pause 5 seconds

echo "Enabling newly installed PHP"
sudo a2enmod php8.5
sleep 5 # pause 5 seconds

#checking apache2 syntax checking
echo "Syntax check for apache2"
sudo apache2ctl configtest
# if condition to check whether configtest passes or not, script will stop if it fails
if [ $? ne 0 ]; then
echo "Syntax check failed, Syntax NOT OK"
exit 1
fi
sleep 5 # pause 5 seconds

echo "Restarting apache2"
sudo systemctl restart apache2
# if condition to catch the error and exit the script if apache2 restart fails
if [ $? -ne 0 ]; then
echo "Apache faced an error in restart."
exit 1
fi

echo "Apache2 started successfully after restart"
sleep 5 # pause 5 seconds

# Printing the status of apache2 for confirmation
sudo systemctl status apache2

sudo a2dismod phpx.x
sudo a2enmod phpx.x

sleep 5 # 5 seconds pause

# Suggested to restart the instance/server after update
# sudo reboot

echo "End of Script"

#---------- END OF SCRIPT ----------
