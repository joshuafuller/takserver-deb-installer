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

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  echo "curl is not installed, installing now..."
  sudo apt-get install curl -y
else
  echo ""
fi

#import postgres repo
curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

#import stable build
#20.04
echo deb [arch=amd64,arm64,ppc64el signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ focal-pgdg main | sudo tee -a /etc/apt/sources.list.d/postgresql.list

sudo apt-get update -y

#Install Deps
sudo apt-get install postgresql-client-15 postgresql-15 postgresql-15-postgis-3 unzip zip wget git nano qrencode openssl net-tools dirmngr ca-certificates software-properties-common gnupg gnupg2 apt-transport-https curl openjdk-11-jdk -y

if [ $? -ne 0 ]; then
	echo "Error installing dependencies...."
	read -n 1 -s -r -p "Press any key to exit...."
	exit 1
fi

clear
echo ""
echo "++++ DONE INSTALLING DEPENDENCIES ++++"
echo ""
echo "*****************************************"
echo "Import TAK Server DEB using Google Drive"
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

SUCCESS=false
while [[ $SUCCESS == false ]]; do
  sudo wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$FILE_ID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p'
  sudo wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=t&id=$FILE_ID" -O $FILE_NAME
  sudo rm -rf /tmp/cookies.txt

  if [[ -f $FILE_NAME && -s $FILE_NAME ]]; then
    echo "DEB File found!"
    SUCCESS=true
  else
    echo "Download failed. Would you like to retry? (y/n)"
    read RETRY

    if [[ $RETRY == "n" ]]; then
      echo "Quitting Install Script..."
      sleep 2
      exit
    else
      echo "Please enter the FILE_ID again:"
      echo "(Right click > Get Link > Allow Sharing to anyone with link > Open share link > 'https://drive.google.com/file/d/<YOUR_FILE_ID_IS_HERE>/view?usp=sharing')"
      echo ""
      read FILE_ID
    fi
  fi
done



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
echo "Generated admin web-portal password: $adminpass"



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



clear

#FQDN Setup
read -p "Do you want to install and configure simple-rtsp-server? y or n " response
if [[ $response =~ ^[Yy]$ ]]; then

echo "Installing simple-rtsp-server - for use with TAK Server"
echo " "

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



#Install the DEB
RETRY_LIMIT=5

for ((i=1;i<=RETRY_LIMIT;i++)); do
    sudo apt install /tmp/takserver-deb-installer/$FILE_NAME -y && break
    echo "Retry $i: Failed to install the package. Retrying in 5 seconds..."
    sleep 5
done

sudo chown -R tak:tak /opt/tak

clear


if [[ $FILE_NAME == *"4.8"* ]]; then

#Setup the DB -this is now automated in 4.8 during the deb install
sudo /opt/tak/db-utils/takserver-setup-db.sh
clear

fi
echo "************* Done installing Takserver **************"
echo ""


sudo systemctl daemon-reload

sudo systemctl start takserver

clear

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

sudo openssl pkcs12 -export -in /etc/letsencrypt/live/$FQDN/fullchain.pem -inkey /etc/letsencrypt/live/$FQDN/privkey.pem -name $HOSTNAME -out ~/$HOSTNAME.p12 -passout pass:atakatak
sudo apt install openjdk-16-jre-headless -y
echo ""
read -p "If asked to save file becuase an existing copy exists, reply Y. Press any key to resume setup..."
echo ""
#read -p "If prompted for password, use 'atakatak' Press any key to resume setup..."
#echo ""
sudo keytool -importkeystore -deststorepass atakatak -srcstorepass atakatak -destkeystore ~/$HOSTNAME.jks -srckeystore ~/$HOSTNAME.p12 -srcstoretype PKCS12
sudo keytool -import -alias bundle -trustcacerts -deststorepass atakatak -srcstorepass atakatak -file /etc/letsencrypt/live/$FQDN/fullchain.pem -keystore ~/$HOSTNAME.jks
#copy files to common folder
sudo mkdir /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.jks /opt/tak/certs/letsencrypt
sudo cp ~/$HOSTNAME.p12 /opt/tak/certs/letsencrypt
sudo chown tak:tak -R /opt/tak/certs/letsencrypt



#echo "Making sure correct java version is set, since we had to install 16 to run this"
sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java
HAS_FQDNSSL=1
else
  HAS_FQDNSSL=0
  echo "skipping FQDN setup..."
fi

clear

#Need to build CoreConfig.xml and put it into /opt/tak/CoreConfig.xml so next script uses it to make certs
echo "SSL Configuration: Hit enter (x3) to accept the defaults:"
