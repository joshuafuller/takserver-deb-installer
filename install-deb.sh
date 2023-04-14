#!/bin/bash
echo ""
echo ""
echo "This script will install the necessary dependancies for TAK Server and complete the install using the .deb package"
echo "!!!!!!!!!! This will take ~5min so please be patient !!!!!!!!!! "
echo ""
echo ""
read -p "Press any key to begin ..."

# Get the Ubuntu version number
version=$(lsb_release -rs)

# Check if the version is 20.04
if [ "$version" != "20.04" ]; then
  echo "Error: This script requires Ubuntu 20.04"
  exit 1
fi

# Get important vals
NIC=$(route | grep default | awk '{print $8}')
IP=$(ip addr show $NIC | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f1)


#create tak user to run the service under
takuser="tak"

# Set variables for the new user
password="tak"
fullname="Tak User"

# Create the new user
sudo useradd -m -s /bin/bash -c "$fullname" "$takuser"

# Set the password for the new user
echo "$takuser:$password" | chpasswd

#adduser $takuser
usermod -aG sudo $takuser


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


# Set variables for generating CA and client certs
echo "SSL Configuration: Hit enter (x3) to accept the defaults:\n"
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

# Update local env - makes these available when the next scripts run
export STATE=$state
export CITY=$city
export ORGANIZATIONAL_UNIT=$orgunit

# Define the characters to include in the random string
chars='!@#%^*()_+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

# Get the length of the string to generate 
length=15

# Generate a random pw for admin account
has_upper=false
has_lower=false
has_digit=false
has_special=false

while [[ "$has_upper" != true || "$has_lower" != true || "$has_digit" != true || "$has_special" != true ]]; do
    adminpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    for (( i=0; i<${#adminpass}; i++ )); do
        char="${adminpass:i:1}"
        if [[ "$char" =~ [A-Z] ]]; then
            has_upper=true
        elif [[ "$char" =~ [a-z] ]]; then
            has_lower=true
        elif [[ "$char" =~ [0-9] ]]; then
            has_digit=true
        elif [[ "$char" =~ [!@#%^*()_+] ]]; then
            has_special=true
        fi
    done
done

# Output the generated password
echo "Generated admin password: $adminpass"

# Generate a random pw for postgresql DB
has_upper=false
has_lower=false
has_digit=false
has_special=false

while [[ "$has_upper" != true || "$has_lower" != true || "$has_digit" != true || "$has_special" != true ]]; do
    dbpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    for (( i=0; i<${#dbpass}; i++ )); do
        char="${dbpass:i:1}"
        if [[ "$char" =~ [A-Z] ]]; then
            has_upper=true
        elif [[ "$char" =~ [a-z] ]]; then
            has_lower=true
        elif [[ "$char" =~ [0-9] ]]; then
            has_digit=true
        elif [[ "$char" =~ [!@#%^*()_+] ]]; then
            has_special=true
        fi
    done
done

# Output the generated password
#echo "Generated database password: $dbpass"

#set the db password in CoreConfig
#sudo sed -i "s/password=\".*\"/password=\"${dbpass}\"/" /opt/tak/CoreConfig.xml
#echo "update db password in CoreConfig.xml"

# Replaces HOSTIP for rate limiter and Fed server. Database URL is a docker alias of tak-database
#sudo sed -i "s/HOSTIP/$IP/g" /opt/tak/CoreConfig.xml


#Setup the DB
sudo /opt/tak/db-utils/takserver-setup-db.sh

sudo systemctl daemon-reload

sudo systemctl start takserver

#wait for 30seconds so takserver can launch
echo "Waiting 30 seconds for Tak Server to Load...."
sleep 30



while :
do
	sleep 10 
	echo  "------------CERTIFICATE GENERATION--------------\n"
	cd /opt/tak/certs && ./makeRootCa.sh --ca-name takserver
	if [ $? -eq 0 ];
	then
		cd /opt/tak/certs && ./makeCert.sh server takserver
		if [ $? -eq 0 ];
		then
			cd /opt/tak/certs && ./makeCert.sh client admin	
			if [ $? -eq 0 ];
			then
				# Set permissions so user can write to certs/files
				sudo chown -R $USER:$USER /opt/tak/certs/
				break
			else 
				sleep 5
			fi
		else
			sleep 5
		fi
	fi
done

#Create login credentials for local adminstrative access to the configuration interface:
while :
do
	sleep 10
	sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p $adminpass admin
	if [ $? -eq 0 ];
	then
		sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/admin.pem
		if [ $? -eq 0 ]; 
		then
			break
		else
			sleep 10
		fi
	fi
done

# Remove unsecure ports in core config
coreconfig_path="/opt/tak/CoreConfig.xml"

# define the lines to remove
lines_to_remove=(
    '<input auth="anonymous" _name="stdtcp" protocol="tcp" port="8087"/>'
    '<input auth="anonymous" _name="stdudp" protocol="udp" port="8087"/>'
    '<input auth="anonymous" _name="streamtcp" protocol="stcp" port="8088"/>'
    '<connector port="8080" tls="false" _name="http_plaintext"/>'
)

# loop through the lines and remove them from the file
for line in "${lines_to_remove[@]}"
do
   sudo sed -i "\~$line~d" "$coreconfig_path"
done



#After creating certificates, restart TAK Server so that the newly created certificates can be loaded.
sudo systemctl restart takserver


#start the service at boot
sudo systemctl enable takserver

echo "=================================================================="
echo "=================== RESTARTING TAK SERVICE ======================="
echo "============== GIVE A MIN BEFORE ACCESSING URL ==================="
echo "=================================================================="
echo "******************************************************************"
echo " Login at http://$IP:8446 with your admin account                "
echo " Web portal user: admin                                           "
echo " Web portal password: $adminpass                                  "
#echo " Postgresql DB password: $dbpass                                  "
echo "                                                                  "
echo "******************************************************************"
echo "=================================================================="
echo "=================================================================="

