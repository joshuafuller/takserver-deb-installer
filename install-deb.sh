#!/bin/bash
echo "Run this script to begin the install process for TAK Server using the .deb installer, it will take a while so please be patient."
echo ""
echo " *** WARNING - THIS SCRIPT IS FOR UBUNTU 20.04 *** "
echo ""
read -p "Press any key to begin ..."

sudo apt-get update -y

#Install Deps
sudo apt-get install unzip zip wget git nano openssl net-tools dirmngr ca-certificates software-properties-common gnupg gnupg2 apt-transport-https curl openjdk-11-jdk -y

#import postgres repo
curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

#import stable build
echo deb [arch=amd64,arm64,ppc64el signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main | sudo tee -a /etc/apt/sources.list.d/postgresql.list

#install postgresql
sudo apt-get update
sudo apt install postgresql-client-15 postgresql-15 postgresql-15-postgis-3 -y

echo "*****************************************"
echo "Import DEB Installed using Google Drive"
echo "*****************************************"
echo ""
echo "WHAT IS YOUR FILE ID ON GOOGLE DRIVE?"
echo "(Right click > Get Link > Allow Sharing to anyone with link > Open share link > 'https://drive.google.com/file/d/<YOUR_FILE_ID_IS_HERE>/view?usp=sharing')"
read FILE_ID

echo "WHAT IS YOUR FILE NAME?"
echo "(ex: takserver_4.8-RELEASE45_all.deb)"
read FILE_NAME

cd /tmp
sudo wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$FILE_ID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p'
sudo wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=t&id=$FILE_ID" -O $FILE_NAME
sudo rm -rf /tmp/cookies.txt

#install the DEB
sudo apt install ./$FILE_NAME

#Setup the DB
#sudo /opt/tak/db-utils/takserver-setup-db.sh

sudo systemctl daemon-reload


#Create login credentials for local adminstrative access to the configuration interface:
#sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p AtakAtak54321! admin

#After creating certificates, restart TAK Server so that the newly created certificates can be loaded.
#sudo systemctl restart takserver


#start the service
sudo systemctl start takserver

echo "=================================================================="
echo "=================================================================="
echo "=================================================================="
echo "******************************************************************"
echo "                                                                   "
echo " DONE HOPEFULLY IT WORKED... MORE TO DO NEXT                       "
echo "                                                                   "
echo "******************************************************************"
echo "=================================================================="
echo "=================================================================="
