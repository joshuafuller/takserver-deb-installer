# takserver-deb-installer
install scripts for .deb package of tak server

** WORKING BUILD **

``` cd /tmp/ && git clone https://github.com/atakhq/takserver-deb-installer.git && cd ./takserver-deb-installer && sudo chmod +x install-deb.sh && ./install-deb.sh```


- creates ubuntu user 'tak' with password 'tak' to install the service under
- installs takserver and enables the service to run at startup on reboots
- disables insecure ports
- Link to admin login with random gen password when script is done
