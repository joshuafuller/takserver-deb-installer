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
    takpass=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    for (( i=0; i<${#takpass}; i++ )); do
        char="${takpass:i:1}"
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
echo "Generated tak password: $takpass"

#create tak user to run the service under
takuser="tak"

# Set variables for the new user
password=$takpass
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

#FQDN Setup
read -p "Do you want to install and configure simple-rtsp-server? y or n " response
if [[ $response =~ ^[Yy]$ ]]; then

echo "Installing simple-rtsp-server - for use with TAK Server"
echo " "

sudo apt-get install wget -y

wget https://github.com/aler9/rtsp-simple-server/releases/download/v0.17.13/rtsp-simple-server_v0.17.13_linux_amd64.tar.gz

tar -zxvf rtsp-simple-server_v0.17.13_linux_amd64.tar.gz
sudo cp rtsp-simple-server /usr/local/bin/rtsp-simple-server

#Create config
sudo tee /usr/local/etc/rtsp-simple-server.yml >/dev/null << EOF
###############################################
# General parameters
# sets the verbosity of the program; available values are "error", "warn", "info", "debug".
logLevel: info
# destinations of log messages; available values are "stdout", "file" and "syslog".
logDestinations: [stdout]
# if "file" is in logDestinations, this is the file which will receive the logs.
logFile: /tmp/rtsp-simple-server.log
# timeout of read operations.
readTimeout: 10s
# timeout of write operations.
writeTimeout: 10s
# number of read buffers.
# a higher number allows a higher throughput,
# a lower number allows to save RAM.
readBufferCount: 512
# enable the HTTP API.
api: yes
# address of the API listener.
apiAddress: 0.0.0.0:9997
# enable Prometheus-compatible metrics.
metrics: no
# address of the metrics listener.
metricsAddress: 127.0.0.1:9998
# enable pprof-compatible endpoint to monitor performances.
pprof: no
# address of the pprof listener.
pprofAddress: 127.0.0.1:9999
# command to run when a client connects to the server.
# this is terminated with SIGINT when a client disconnects from the server.
# the server port is available in the RTSP_PORT variable.
runOnConnect:
# the restart parameter allows to restart the command if it exits suddenly.
runOnConnectRestart: no
###############################################
# RTSP parameters
# disable support for the RTSP protocol.
rtspDisable: no
# supported RTSP transport protocols.
# UDP is the most performant, but doesn't work when there's a NAT/firewall between
# server and clients, and doesn't support encryption.
# UDP-multicast allows to save bandwidth when clients are all in the same LAN.
# TCP is the most versatile, and does support encryption.
# The handshake is always performed with TCP.
protocols: [tcp, udp]
# encrypt handshake and TCP streams with TLS (RTSPS).
# available values are "no", "strict", "optional".
encryption: "no"
# address of the TCP/RTSP listener. This is needed only when encryption is "no" or "optional".
rtspAddress: :554
# address of the TCP/TLS/RTSPS listener. This is needed only when encryption is "strict" or "optional".
rtspsAddress: :8555
# address of the UDP/RTP listener. This is needed only when "udp" is in protocols.
rtpAddress: :8000
# address of the UDP/RTCP listener. This is needed only when "udp" is in protocols.
rtcpAddress: :8001
# IP range of all UDP-multicast listeners. This is needed only when "multicast" is in protocols.
multicastIPRange: 224.1.0.0/16
# port of all UDP-multicast/RTP listeners. This is needed only when "multicast" is in protocols.
multicastRTPPort: 8002
# port of all UDP-multicast/RTCP listeners. This is needed only when "multicast" is in protocols.
multicastRTCPPort: 8003
# path to the server key. This is needed only when encryption is "strict" or "optional".
# this can be generated with:
# openssl genrsa -out server.key 2048
# openssl req -new -x509 -sha256 -key server.key -out server.crt -days 3650
serverKey: server.key
# path to the server certificate. This is needed only when encryption is "strict" or "optional".
serverCert: server.crt
# authentication methods.
authMethods: [basic, digest]
# read buffer size.
# this doesn't influence throughput and shouldn't be touched unless the server
# reports errors about the buffer size.
readBufferSize: 2048
###############################################
# RTMP parameters
# disable support for the RTMP protocol.
rtmpDisable: no
# address of the RTMP listener.
rtmpAddress: :1935
###############################################
# HLS parameters
# disable support for the HLS protocol.
hlsDisable: no
# address of the HLS listener.
hlsAddress: :8888
# by default, HLS is generated only when requested by a user;
# this option allows to generate it always, avoiding an initial delay.
hlsAlwaysRemux: no
# number of HLS segments to generate.
# increasing segments allows more buffering,
# decreasing segments decreases latency.
hlsSegmentCount: 3
# minimum duration of each segment.
# the final segment duration is also influenced by the interval between IDR frames,
# since the server changes the segment duration to include at least a IDR frame in each one.
hlsSegmentDuration: 1s
# value of the Access-Control-Allow-Origin header provided in every HTTP response.
# This allows to play the HLS stream from an external website.
hlsAllowOrigin: '*'
###############################################
# Path parameters
# these settings are path-dependent.
# it's possible to use regular expressions by using a tilde as prefix.
# for example, "~^(test1|test2)$" will match both "test1" and "test2".
# for example, "~^prefix" will match all paths that start with "prefix".
# the settings under the path "all" are applied to all paths that do not match
# another entry.
paths:
  all:
    # source of the stream - this can be:
    # * publisher -> the stream is published by a RTSP or RTMP client
    # * rtsp://existing-url -> the stream is pulled from another RTSP server
    # * rtsps://existing-url -> the stream is pulled from another RTSP server with RTSPS
    # * rtmp://existing-url -> the stream is pulled from another RTMP server
    # * http://existing-url/stream.m3u8 -> the stream is pulled from another HLS server
    # * https://existing-url/stream.m3u8 -> the stream is pulled from another HLS server with HTTPS
    # * redirect -> the stream is provided by another path or server
    source: publisher
    # if the source is an RTSP or RTSPS URL, this is the protocol that will be used to
    # pull the stream. available values are "automatic", "udp", "multicast", "tcp".
    # the TCP protocol can help to overcome the error "no UDP packets received recently".
    sourceProtocol: automatic
    # if the source is an RTSP or RTSPS URL, this allows to support sources that
    # don't provide server ports or use random server ports. This is a security issue
    # and must be used only when interacting with sources that require it.
    sourceAnyPortEnable: no
    # if the source is a RTSPS or HTTPS URL, and the source certificate is self-signed
    # or invalid, you can provide the fingerprint of the certificate in order to
    # validate it anyway.
    # the fingerprint can be obtained by running:
    # openssl s_client -connect source_ip:source_port </dev/null 2>/dev/null | sed -n '/BEGIN/,/END/p' > server.crt
    # openssl x509 -in server.crt -noout -fingerprint -sha256 | cut -d "=" -f2 | tr -d ':'
    sourceFingerprint:
    # if the source is an RTSP or RTMP URL, it will be pulled only when at least
    # one reader is connected, saving bandwidth.
    sourceOnDemand: no
    # if sourceOnDemand is "yes", readers will be put on hold until the source is
    # ready or until this amount of time has passed.
    sourceOnDemandStartTimeout: 10s
    # if sourceOnDemand is "yes", the source will be closed when there are no
    # readers connected and this amount of time has passed.
    sourceOnDemandCloseAfter: 10s
    # if the source is "redirect", this is the RTSP URL which clients will be
    # redirected to.
    sourceRedirect:
    # if the source is "publisher" and a client is publishing, do not allow another
    # client to disconnect the former and publish in its place.
    disablePublisherOverride: no
    # if the source is "publisher" and no one is publishing, redirect readers to this
    # path. It can be can be a relative path  (i.e. /otherstream) or an absolute RTSP URL.
    fallback:
    # username required to publish.
    # sha256-hashed values can be inserted with the "sha256:" prefix.
    publishUser:
    # password required to publish.
    # sha256-hashed values can be inserted with the "sha256:" prefix.
    publishPass:
    # ips or networks (x.x.x.x/24) allowed to publish.
    publishIPs: []
    # username required to read.
    # sha256-hashed values can be inserted with the "sha256:" prefix.
    readUser:
    # password required to read.
    # sha256-hashed values can be inserted with the "sha256:" prefix.
    readPass:
    # ips or networks (x.x.x.x/24) allowed to read.
    readIPs: []
    # command to run when this path is initialized.
    # this can be used to publish a stream and keep it always opened.
    # this is terminated with SIGINT when the program closes.
    # the path name is available in the RTSP_PATH variable.
    # the server port is available in the RTSP_PORT variable.
    runOnInit:
    # the restart parameter allows to restart the command if it exits suddenly.
    runOnInitRestart: no
    # command to run when this path is requested.
    # this can be used to publish a stream on demand.
    # this is terminated with SIGINT when the path is not requested anymore.
    # the path name is available in the RTSP_PATH variable.
    # the server port is available in the RTSP_PORT variable.
    runOnDemand:
    # the restart parameter allows to restart the command if it exits suddenly.
    runOnDemandRestart: no
    # readers will be put on hold until the runOnDemand command starts publishing
    # or until this amount of time has passed.
    runOnDemandStartTimeout: 10s
    # the runOnDemand command will be closed when there are no
    # readers connected and this amount of time has passed.
    runOnDemandCloseAfter: 10s
    # command to run when a client starts publishing.
    # this is terminated with SIGINT when a client stops publishing.
    # the path name is available in the RTSP_PATH variable.
    # the server port is available in the RTSP_PORT variable.
    runOnPublish:
    # the restart parameter allows to restart the command if it exits suddenly.
    runOnPublishRestart: no
    # command to run when a clients starts reading.
    # this is terminated with SIGINT when a client stops reading.
    # the path name is available in the RTSP_PATH variable.
    # the server port is available in the RTSP_PORT variable.
    runOnRead:
    # the restart parameter allows to restart the command if it exits suddenly.
    runOnReadRestart: no
EOF

#Create server file
sudo tee /etc/systemd/system/rtsp-simple-server.service >/dev/null << EOF
[Unit]
After=network.target
[Service]
ExecStart=/usr/local/bin/rtsp-simple-server /usr/local/etc/rtsp-simple-server.yml
[Install]
WantedBy=multi-user.target
EOF


#Open RTSP/RTMP Ports in firewall
#sudo ufw allow 554/tcp
#sudo ufw allow 554/udp
#sudo ufw allow 1935/tcp
#sudo ufw allow 1935/udp
#sudo ufw reload 

# Enable the service on server boot
sudo systemctl enable rtsp-simple-server
sudo systemctl start rtsp-simple-server


#Show conx info at end
DEVICE_NAME=$(ip -o -4 route show to default | awk '{print $5}')
PUB_SERVER_IP=$(ip addr show $DEVICE_NAME | awk 'NR==3{print substr($2,1,(length($2)-3))}')

HAS_SIMPLERTSP=1

clear

else
  echo "skipping simple-rtsp-server setup..."
fi





#login as tak user and install there
echo "Logging in as tak user to install TakServer..."
echo "Password is $takpass"
su - tak <<EOF
#install the DEB
sudo apt install /tmp/takserver-deb-installer/$FILE_NAME -y
clear
EOF

echo "Done installing Takserver, setting cert-metadata values..."

#Need to build CoreConfig.xml and put it into /opt/tak/CoreConfig.xml so next script uses it

echo "SSL Configuration: Hit enter (x3) to accept the defaults:"

read -p "State (for cert generation). Default [state] :" state
read -p "City (for cert generation). Default [city]:" city
read -p "Organizational Unit (for cert generation). Default [org_unit]:" orgunit

# define the input file path
CERTMETAPATH="/opt/tak/certs/cert-metadata.sh"

if [ -z "$state" ];
then
	# Default state to "STATE"
	sed -i 's/\${STATE}/\${STATE:-STATE}/g' "$CERTMETAPATH"
else
	# Set new defualt from user entry
	sed -i 's/\${STATE}/\${STATE:-$state}/g' "$CERTMETAPATH"
fi

if [ -z "$city" ];
then
	# Default city to "CITY"
	sed -i 's/\${CITY}/\${CITY:-CITY}/g' "$CERTMETAPATH"
else
	# Set new defualt from user entry
	sed -i 's/\${CITY}/\${CITY:-$city}/g' "$CERTMETAPATH"
fi

if [ -z "$orgunit" ];
then
	# Default org unit to "ORG_UNIT"
	sed -i 's/\${ORGANIZATIONAL_UNIT}/\${ORGANIZATIONAL_UNIT:-ORG_UNIT}/g' "$CERTMETAPATH"
else
	# Default org unit to "ORG_UNIT"
	sed -i 's/\${ORGANIZATIONAL_UNIT}/\${ORGANIZATIONAL_UNIT:-$orgunit}/g' "$CERTMETAPATH"
fi


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

#FQDN Setup
read -p "Do you want to setup a FQDN? y or n \n" response
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
  echo "What is your email? - Needed for Letsencrypt Alerts"
  read EMAIL

  if certbot certonly --standalone -d $DOMAIN -m $EMAIL --agree-tos --non-interactive; then
    echo "Certificate obtained successfully!"
    CERT_NAME=$(sudo certbot certificates | grep -oP "(?<=Certificate Name: ).*")
  else
    echo "Error obtaining certificate: $(sudo certbot certificates)"
    exit 1
  fi
fi



sudo openssl pkcs12 -export -in /etc/letsencrypt/live/$FQDN/fullchain.pem -inkey /etc/letsencrypt/live/$FQDN/privkey.pem -name $HOSTNAME -out ~/$HOSTNAME.p12 -passout pass:atakatak
sudo apt install openjdk-16-jre-headless -y
echo ""
read -p "If asked to save file becuase an existing copy exists, reply Y. Press any key to resume setup..."
echo ""
read -p "If prompted for password, use 'atakatak' Press any key to resume setup..."
echo ""
sudo keytool -importkeystore -deststorepass atakatak -srcstorepass atakatak -destkeystore ~/$HOSTNAME.jks -srckeystore ~/$HOSTNAME.p12 -srcstoretype PKCS12
sudo keytool -import -alias bundle -trustcacerts -srcstorepass atakatak -file /etc/letsencrypt/live/$FQDN/fullchain.pem -keystore ~/$HOSTNAME.jks
#copy files to common folder
sudo mkdir /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.jks /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.p12 /opt/tak/certs/letsencrypt
sudo chown tak:tak -R /opt/tak/certs/letsencrypt

#Add new Config line

max_retries=5
retry_interval=10 # seconds
retry_count=0

while [[ $retry_count -lt $max_retries ]]
do
	# Set the filename
	filename="/opt/tak/CoreConfig.xml"
	search='<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\"/>'
	replace='<connector port=\"8446\" clientAuth=\"false\" _name=\"cert_https\" truststorePass=\"atakatak\" truststoreFile=\"certs/files/truststore-intermediate-CA.jks\" truststore=\"JKS\" keystorePass=\"atakatak\" keystoreFile=\"certs/letsencrypt/'"$HOSTNAME"'.jks\" keystore=\"JKS\"/>'
	sed -i "s@$search@$replace@g" $filename
  
  if [[ $? -eq 0 ]]; then
    # Success
    break
  else
    # Retry after interval
    sleep $retry_interval
    retry_count=$((retry_count+1))
  fi
done

if [[ $retry_count -eq $max_retries ]]; then
  echo "Failed to update CoreConfig.xml after $retry_count retries"
  exit 1
fi


echo "Making sure correct java version is set, since we had to install 16 to run this"
sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java
HAS_FQDNSSL=1
else
  HAS_FQDNSSL=0
  echo "skipping FQDN setup..."
fi



while :
do
	sleep 10 
	echo  "------------CERTIFICATE GENERATION--------------"
	echo " YOU ARE LIKELY GOING TO SEE ERRORS FOR java.lang.reflect..... ignore it and let the script finish it will keep retrying until successful"
	read -p "Press any key to continue..."
	cd /opt/tak/certs && ./makeRootCa.sh --ca-name takserver-CA
	if [ $? -eq 0 ];
	then
	
		echo "Setting up Certificate Enrollment so you can assign user/pass for login."
		echo "When asked to move files around, reply Yes"
		read -p "Press any key to being setup..."

		#Make the int cert and edit the tak config to use it
		echo "Generating Intermediate Cert"
		while :
		do
			cd /opt/tak/certs/ && ./makeCert.sh ca intermediate-CA
			if [ $? -eq 0 ];
			then
				break
			else 
				echo "Retry in 10 sec..."
				sleep 10
			fi
		done

	
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



max_retries=5
retry_interval=10 # seconds
retry_count=0

while [[ $retry_count -lt $max_retries ]]
do

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


	#Add new conx type
	sed -i '3 a\        <input _name="cassl" auth="x509" protocol="tls" port="8089" />' /opt/tak/CoreConfig.xml

	#Replace CA Config
	# Set the filename
	filename="/opt/tak/CoreConfig.xml"

	search="<dissemination smartRetry=\"false\"/>"
	replace="${search}\n    <certificateSigning CA=\"TAKServer\">\n        <certificateConfig>\n            <nameEntries>\n                <nameEntry name=\"O\" value=\"TAK\"/>\n                <nameEntry name=\"OU\" value=\"TAK\"/>\n            </nameEntries>\n        </certificateConfig>\n        <TAKServerCAConfig keystore=\"JKS\" keystoreFile=\"/opt/tak/certs/files/intermediate-CA-signing.jks\" keystorePass=\"atakatak\" validityDays=\"30\" signatureAlg=\"SHA256WithRSA\"/>\n    </certificateSigning>"
	sed -i "s@$search@$replace@g" $filename

	#Add new TLS Config
	search='<tls keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs/files/truststore-root.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"/>'
	replace='<tls keystore="JKS" keystoreFile="certs/files/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs/files/truststore-intermediate-CA.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"/>\n      <crl _name="TAKServer CA" crlFile="certs/files/intermediate-CA.crl"/>'
	sed -i "s|$search|$replace|" $filename

	search='<auth>'
	replace='<auth x509groups=\"true\" x509addAnonymous=\"false\" x509useGroupCache=\"true\" x509checkRevocation=\"true\">'
	
	sed -i "s@$search@$replace@g" $filename

  if [[ $? -eq 0 ]]; then
    # Success
    break
  else
    # Retry after interval
    sleep $retry_interval
    retry_count=$((retry_count+1))
  fi
done

if [[ $retry_count -eq $max_retries ]]; then
  echo "Failed to update CoreConfig.xml after $retry_count retries"
  exit 1
fi




echo "******** RESTARTING TAKSERVER FOR CHANGES TO APPLY ***************"
#After creating certificates, restart TAK Server so that the newly created certificates can be loaded.
sudo systemctl restart takserver
#start the service at boot
sudo systemctl enable takserver

echo " "
echo "********************************************************************"
if [ "$HAS_FQDNSSL" = "1" ]; then
	echo " Login at https://$IP:8446 with your admin account                "
	echo " Web portal user: admin                                           "
	echo " Web portal password: $adminpass                                  "
	echo " System User tak password: $takpass                               "
	echo "You should now be able to authenticate ITAK and ATAK clients using only user/password and server URL."
	echo ""
	echo "Server Address: $FQDN:8089 SSL"
	echo "Create new users here: https://$FQDN:8446/user-management/index.html#!/"
	echo "                                                                  "
	echo "******************************************************************"
	echo "=================================================================="
	echo "=================================================================="
else
	echo " Login at https://$IP:8446 with your admin account                "
	echo " Web portal user: admin                                           "
	echo " Web portal password: $adminpass                                  "
	echo " System User tak password: $takpass                               "
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
fi

if [ "$HAS_SIMPLERTSP" = "1" ] && [ "$HAS_FQDNSSL" = "1" ]; then
echo " "
echo "********************************************************************"
echo "Simple RTSP Server should now be running"
echo "********************************************************************"
echo "Verfiy by running the following command:"
echo "sudo systemctl status rtsp-simple-server"
echo "********************************************************************"
echo "You are ready to start streaming video, be sure to unblock the following ports in your firewall config. (TCP & UDP)"
echo "RTSP ADDRESS: $PUB_SERVER_IP:554"
echo "RTMP ADDRESS: $PUB_SERVER_IP:1935"
echo "RTSP ADDRESS: $$FQDN:554"
echo "RTMP ADDRESS: $$FQDN:1935"
echo "********************************************************************"
echo " "
fi
if [ "$HAS_SIMPLERTSP" = "1" ] && [ "$HAS_FQDNSSL" = "0" ]; then
echo " "
echo "********************************************************************"
echo "Simple RTSP Server should now be running"
echo "********************************************************************"
echo "Verfiy by running the following command:"
echo "sudo systemctl status rtsp-simple-server"
echo "********************************************************************"
echo "You are ready to start streaming video, be sure to unblock the following ports in your firewall config. (TCP & UDP)"
echo "RTSP ADDRESS: $PUB_SERVER_IP:554"
echo "RTMP ADDRESS: $PUB_SERVER_IP:1935"
echo "********************************************************************"
echo " "
fi
