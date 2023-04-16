# takserver-deb-installer

## Notes:

If you encounter this error: 

```Waiting for cache lock: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process XXXXXX (unattended-upgr) ```

Open a new SSH terminal, and fire this command to remove the apt upgrade lock - REPLACE XXXXXX with the process ID shown in the error

```sudo kill -9 XXXXXX```


## First:
- Download the .deb installer from tak.gov
- Upload to Google Drive
- Share the file, set share permissions to "anyone with the link"
- Get the sharing link, you will need the file id during the script install

```https://drive.google.com/file/d/<FILE ID STRING HERE>/view?usp=sharing```

## Second:
Run install script for .deb package of tak server

``` cd /tmp/ && git clone https://github.com/atakhq/takserver-deb-installer.git && cd ./takserver-deb-installer && sudo chmod +x install-deb.sh && ./install-deb.sh```

## What the script does:

- creates ubuntu user 'tak' with random 15char password to install the service under
- installs takserver and enables the service to run at startup on reboots
- disables insecure ports in CoreConfig.xml
- configures certificate enrollment
- Optional: Configure FQDN for seamless cert enrollment and no SSL warnings in browser
- Link to admin login with random gen password when script is done

