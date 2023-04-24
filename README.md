# takserver-deb-installer

## First:
- Download the .deb installer from tak.gov
- Upload to Google Drive
- Share the file, set share permissions to "anyone with the link"
- Get the sharing link, you will need the file id during the script install

```https://drive.google.com/file/d/<FILE ID STRING HERE>/view?usp=sharing```

*** If you are setting up a FQDN for SSL, make sure you already have your DNS entry (A Record) setup to point your server IP to the domain name you want the server hosted at. ***

## Second:

- Login as root user to your install target machine
- Download and Run the install script with the command below

```cd /tmp/ && git clone https://github.com/atakhq/takserver-deb-installer.git && cd ./takserver-deb-installer && sudo chmod +x install-deb.sh && ./install-deb.sh```


## What the script does:

- creates ubuntu user 'tak' with random 15char password to install the service under
- installs takserver and enables the service to run at startup on reboots
- disables insecure ports in CoreConfig.xml
- configures certificate enrollment
- Optional: 
    - Configure FQDN for seamless cert enrollment and no SSL warnings in browser
    - Setup simple-rtsp-server for video streaming
    - Additional user connection datapackage creation

- Instruction at the end with link to admin login with random gen password

![Example Install Complete image](https://raw.githubusercontent.com/atakhq/takserver-deb-installer/master/deb-installer-done.png)


## Notes:

If you encounter this error: 

```Waiting for cache lock: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process XXXXXX (unattended-upgr) ```

Open a new SSH terminal, and fire this command to remove the apt upgrade lock - REPLACE XXXXXX with the process ID shown in the error

```sudo kill -9 XXXXXX```

- 4/23/2023
  - Added support for TAK Server 4.9 (some minor changes)
  - Added prompt for additional user cert creation

- 4/22/2023
  - Added ITAK Server Auto-Setup QR Code to end of script, and png saved to /opt/tak/certs/files
  - Error trapping for dependency installs, tak server isntall, and user execution permission of the scripts
  - General improvements to speed up the install

- 4/19/2023
  - FQDN SSL issue was fixed
  - rtsp-simple-server installer prompt added

## To Do:
- UFW

