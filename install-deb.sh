#!/bin/bash
echo "Run this script to begin the install process for TAK Server using the .deb installer, it will take a while so please be patient."
echo ""
echo " *** WARNING - THIS SCRIPT IS FOR UBUNTU 20.04 *** "
echo ""
read -p "Press any key to begin ..."

# Get important vals
NIC=$(route | grep default | awk '{print $8}')
IP=$(ip addr show $NIC | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f1)


#create tak user to run the service under
adduser tak
usermod -aG sudo tak

sudo apt-get update -y

#Install Deps
sudo apt-get install unzip zip wget git nano openssl net-tools dirmngr ca-certificates software-properties-common gnupg gnupg2 apt-transport-https curl openjdk-11-jdk -y

#import postgres repo
curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

#import stable build
#20.04
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

sudo wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$FILE_ID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p'
sudo wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=t&id=$FILE_ID" -O $FILE_NAME
sudo rm -rf /tmp/cookies.txt

#login as tak user and install there
su - tak <<EOF

#install the DEB
sudo apt install /tmp/takserver-deb-installer/$FILE_NAME

EOF


#Need to build CoreConfig.xml and put it into /opt/tak/CoreConfig.xml so next script uses it


## Set variables for generating CA and client certs
echo "SSL setup. Hit enter (x3) to accept the defaults:\n"
read -p "State (for cert generation). Default [state] :" state
read -p "City (for cert generation). Default [city]:" city
read -p "Organizational Unit (for cert generation). Default [org]:" orgunit

if [ -z "$state" ];
then
	state="state"
fi

if [ -z "$city" ];
then
	city="city"
fi

if [ -z "$orgunit" ];
then
	orgunit="org"
fi

# Update local env - makes these available when the next scripts run?
export STATE=$state
export CITY=$city
export ORGANIZATIONAL_UNIT=$orgunit

# Define the characters to include in the random string
chars='!@#%^*()_+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

# Get the length of the string to generate 
length=15

# Generate a random pw for admin account
adminpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")

# Check if the random string contains a special character
while true; do
    adminpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    if [[ $adminpass =~ ^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{15,}$ ]]; then
        break
    fi
done

# Generate a random pw for postgresql DB
dbpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")

# Check if the random string contains a special character
while true; do
    dbpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    if [[ $dbpass =~ ^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9]).{15,}$ ]]; then
        break
    fi
done

#set the db password in CoreConfig
sed -i "s/password=\".*\"/password=\"${dbpass}\"/" /opt/tak/CoreConfig.xml

# Replaces HOSTIP for rate limiter and Fed server. Database URL is a docker alias of tak-database
#sed -i "s/HOSTIP/$IP/g" /opt/tak/CoreConfig.xml


#Setup the DB
sudo /opt/tak/db-utils/takserver-setup-db.sh

sudo systemctl daemon-reload

sudo systemctl start takserver

#wait for 30seconds so takserver can launch
echo "Waiting 30 seconds for Tak Server to Load...."
sleep 30


#Create CA
cd /opt/tak/certs && ./makeRootCa.sh --ca-name CRFtakserver

#Create Server Cert
cd /opt/tak/certs && ./makeCert.sh server takserver

#Create Client Cert for Admin
cd /opt/tak/certs && ./makeCert.sh client admin

#Create login credentials for local adminstrative access to the configuration interface:
sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p $adminpass admin

sudo java -jar /opt/tak/utils/UserManager.jar certmod -A certs/files/admin.pem

#After creating certificates, restart TAK Server so that the newly created certificates can be loaded.
sudo systemctl restart takserver


#start the service at boot
sudo systemctl enable takserver

echo "=================================================================="
echo "=================================================================="
echo "=================================================================="
echo "******************************************************************"
echo " Login at https://$IP:8443 with your admin account                "
echo " Web portal user: admin                                           "
echo " Web portal password: $adminpass                                  "
echo " Postgresql DB password: $dbpass                                  "
echo "                                                                  "
echo "******************************************************************"
echo "=================================================================="
echo "=================================================================="

