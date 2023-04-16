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


echo "*****************************************"
echo "Import DEB using Google Drive"
echo "*****************************************"
echo ""
echo "WHAT IS YOUR FILE ID ON GOOGLE DRIVE?"
echo "(Right click > Get Link > Allow Sharing to anyone with link > Open share link > 'https://drive.google.com/file/d/<YOUR_FILE_ID_IS_HERE>/view?usp=sharing')"
read FILE_ID

echo "WHAT IS YOUR FILE NAME?"
echo "(ex: takserver_4.8-RELEASE45_all.deb) - Press Enter to use this as default"
read FILE_NAME

if [[ -z $FILE_NAME ]]; then
  FILE_NAME="takserver_4.8-RELEASE45_all.deb"
fi

sudo wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$FILE_ID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p'
sudo wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=t&id=$FILE_ID" -O $FILE_NAME
sudo rm -rf /tmp/cookies.txt


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

clear

#login as tak user and install there
echo "Logging in as tak user to install TakServer..."
su - tak <<EOF
#install the DEB
sudo apt install /tmp/takserver-deb-installer/$FILE_NAME
clear
EOF

#Need to build CoreConfig.xml and put it into /opt/tak/CoreConfig.xml so next script uses it
# Set variables for generating CA and client certs
echo "SSL Configuration: Hit enter (x3) to accept the defaults:"
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

#Setup the DB
sudo /opt/tak/db-utils/takserver-setup-db.sh

sudo systemctl daemon-reload

sudo systemctl start takserver

#wait for 30seconds so takserver can launch
echo "Waiting 30 seconds for Tak Server to Load...."
sleep 30

clear

while :
do
	sleep 10 
	echo  "------------CERTIFICATE GENERATION--------------\n"
	echo " YOU ARE LIKELY GOING TO SEE ERRORS FOR java.lang.reflect..... ignore it and let the script finish it will keep retrying until successful"
	read -p "Press any key to continue..."
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

clear

echo "Setting up Certificate Enrollment so you can assign user/pass for login."
echo "When asked to move files around, reply Yes"
read -p "Press any key to being setup..."

#Make the int cert and edit the tak config to use it
echo "Generating Intermediate Cert"
cd /opt/tak/certs/ && ./makeCert.sh ca intermediate-CA

#Add new conx type
sed -i '3 a\        <input _name="cassl" auth="x509" protocol="tls" port="8089" />' /opt/tak/CoreConfig.xml

#Replace CA Config
# Set the filename
filename="/opt/tak/CoreConfig.xml"

search="<dissemination smartRetry=\"false\"/>"
replace="${search}\n    <certificateSigning CA=\"TAKServer\">\n        <certificateConfig>\n            <nameEntries>\n                <nameEntry name=\"O\" value=\"TAK\"/>\n                <nameEntry name=\"OU\" value=\"TAK\"/>\n            </nameEntries>\n        </certificateConfig>\n        <TAKServerCAConfig keystore=\"JKS\" keystoreFile=\"/opt/tak/certs/files/takserver.jks\" keystorePass=\"atakatak\" validityDays=\"30\" signatureAlg=\"SHA256WithRSA\"/>\n    </certificateSigning>"
sed -i "s@$search@$replace@g" $filename

#Add new TLS Config
search='<tls keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs/files/truststore-root.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"/>'
replace='<tls keystore="JKS" keystoreFile="/opt/tak/certs/files/takserver.jks" keystorePass="atakatak" crlFile="/opt/tak/certs/files/intermediate-CA.crl" truststore="JKS" truststoreFile="/opt/tak/certs/files/truststore-intermediate-CA.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"/>'
sed -i "s|$search|$replace|" $filename

search='<auth>'
replace='<auth x509groups=\"true\" x509addAnonymous=\"false\">'
sed -i "s@$search@$replace@g" $filename
clear

#FQDN Setup
read -p "Do you want to setup a FQDN? y or n " response
if [[ $response =~ ^[Yy]$ ]]; then
#install certbot 
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
echo "What is your domain name? ex: atakhq.com or tak-public.atakhq.com "
read FQDN
DOMAIN=$FQDN
echo ""
echo "What is your hostname? ex: atakhq-com or tak-public-atakhq-com "
echo "** Suggest using same value you entered for domain name but replace . with -"
read HOSTNAME
#request inital cert

# Check for existing certificates
EXISTING_CERTS=$(sudo certbot certificates)
if [[ $EXISTING_CERTS =~ "Certificate Name: $DOMAIN" ]]; then
  echo "Certificate found for $DOMAIN"
  CERT_NAME=$(echo "$EXISTING_CERTS" | grep -oP "(?<=Certificate Name: ).*" | head -1)
  echo "Using existing certificate: $CERT_NAME"
else
  echo "No existing certificates found for $DOMAIN"
  echo "Requesting a new certificate..."
  # Request a new certificate
  echo "What is your email?"
  read EMAIL

  if certbot certonly --standalone -d $DOMAIN -m $EMAIL --agree-tos --non-interactive ; then
    echo "Certificate obtained successfully!"
    CERT_NAME=$(sudo certbot certificates | grep -oP "(?<=Certificate Name: ).*")
  else
    echo "Error obtaining certificate: $(sudo certbot certificates)"
    exit 1
  fi
fi


echo ""
read -p "When prompted for password, use 'atakatak' Press any key to resume setup..."
echo ""
sudo openssl pkcs12 -export -in /etc/letsencrypt/live/$FQDN/fullchain.pem -inkey /etc/letsencrypt/live/$FQDN/privkey.pem -name $HOSTNAME -out ~/$HOSTNAME.p12
sudo apt install openjdk-16-jre-headless -y
echo ""
read -p "If asked to save file becuase an existing copy exists, reply Y. Press any key to resume setup..."
echo ""
sudo keytool -importkeystore -deststorepass atakatak -destkeystore ~/$HOSTNAME.jks -srckeystore ~/$HOSTNAME.p12 -srcstoretype PKCS12
sudo keytool -import -alias bundle -trustcacerts -file /etc/letsencrypt/live/$FQDN/fullchain.pem -keystore ~/$HOSTNAME.jks
#copy files to common folder
sudo mkdir /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.jks /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.p12 /opt/tak/certs/letsencrypt
sudo chown tak:tak -R /opt/tak/certs/letsencrypt
############################################# MAKE THIS A SEARCH AND REPLACE

#Add new Config line
search='<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\"/>'
replace='<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\" truststorePass=\"atakatak\" truststoreFile=\"certs/files/truststore-intermediate-CA.jks\" truststore=\"JKS\" keystorePass=\"atakatak\" keystoreFile=\"certs/letsencrypt/$HOSTNAME.jks\" keystore=\"JKS\"/>'
sed -i "s@$search@$replace@g" $filename





else
  echo "skipping FQDN setup..."
fi

echo "Making sure correct java version is set"
sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java

echo "******** RESTARTING TAKSERVER FOR CHANGES TO APPLY ***************"
#After creating certificates, restart TAK Server so that the newly created certificates can be loaded.
sudo systemctl restart takserver
#start the service at boot
sudo systemctl enable takserver
if [[ $response =~ ^[Yy]$ ]]; then
echo "=================================================================="
echo "=================== RESTARTING TAK SERVICE ======================="
echo "============== GIVE A MIN BEFORE ACCESSING URL ==================="
echo "=================================================================="
echo "******************************************************************"
echo " Login at https://$IP:8446 with your admin account                "
echo " Web portal user: admin                                           "
echo " Web portal password: $adminpass                                  "
echo ""
echo "You should now be able to authenticate ITAK and ATAK clients using only user/password and server URL."
echo ""
echo "Server Address: $FQDN:8089 SSL"
echo "Create new users here: https://$FQDN:8446/user-management/index.html#!/"
echo "                                                                  "
echo "******************************************************************"
echo "=================================================================="
echo "=================================================================="
else
echo "=================================================================="
echo "=================== RESTARTING TAK SERVICE ======================="
echo "============== GIVE A MIN BEFORE ACCESSING URL ==================="
echo "=================================================================="
echo "******************************************************************"
echo " Login at https://$IP:8446 with your admin account                "
echo " Web portal user: admin                                           "
echo " Web portal password: $adminpass                                  "
echo ""
echo "******************************************************************"
echo "=================================================================="
echo "=================================================================="
echo "***************************************************"
echo "Run the following command on your LOCAL machine to download the common cert"
echo ""
echo "ATAK - You will need this file for user/pass auth if you do not have a FQDN with SSL setup"
echo "ITAK - Requires FQDN SSL and has QR code auth"
echo ""
echo "replace 111.222.333.444 with your server IP"
echo ""
echo "scp tak@111.222.333.444:/opt/tak/certs/files/truststore-intermediate-CA.p12 ~/Downloads"
echo ""
echo "***************************************************"
fi

