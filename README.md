# takserver-deb-installer
install scripts for .deb package of tak server

** WORKING BUILD **

``` cd /tmp/ && git clone https://github.com/atakhq/takserver-deb-installer.git && cd ./takserver-deb-installer && sudo chmod +x install-deb.sh && ./install-deb.sh```


** WORK IN PROGRESS BUILD **
- adds cert enrollment, FQDN setup

``` cd /tmp/ && git clone https://github.com/atakhq/takserver-deb-installer.git && cd ./takserver-deb-installer && sudo chmod +x install-deb-wip.sh && ./install-deb-wip.sh```

## First:
- Download the .deb installer from tak.gov
- Upload to Google Drive
- Share the file, set share permissions to "anyone with the link"
- Get the sharing link, you will need the file id during the script install

```https://drive.google.com/file/d/<FILE ID STRING HERE>/view?usp=sharing```

## What the script does:

- creates ubuntu user 'tak' with password 'tak' to install the service under
- installs takserver and enables the service to run at startup on reboots
- disables insecure ports
- Link to admin login with random gen password when script is done
