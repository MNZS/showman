<h2>Dockerized Media Server (Showman)</h2>

<h3>Prowlarr, Sabnzbd, Organizr, Sonarr, Radarr, Swag, and Ombi</h3>
<h3>with option for either Jellyfin or Emby as media viewer</h3><p>

Showman acts as an abstraction layer for installation and maintenance several docker containers (from LinuxServer.io) running as a group of "microservices". Combined they perform as a Media Server that will allow for download and viewing of TV shows and Movies on an individual's home network as well as remotely (if network configuration allows).

<h3>INSTALLATION:</h3>

Showman is written in bash and configured to run on either Debian or Arch Linux. 

It is recommended, but not required, that the default installation path directory (/opt/showman) is mounted to an external drive and separate from the disk where the OS is installed.

Two global variables may be edited prior to the first run of the script. These variables are used to identify the installation path (default is /opt/showman) and the domain name that may be used for instances where the media server will be made available to remote networks using the SWAG reverse proxy. (If you will not be using the reverse proxy, this variable may remain empty)


As root or with root privileges, run 

     /bin/bash showman.sh install
     
Upon executing the script, you will be given an option to choose between a local network configuration or to allow your media server to be available to remote networks. See post-installation documentation for next steps in completing setup for the individual services and understanding how the containers work together.

<h3>MAINTENANCE & LOGGING:</h3>

During installation, Showman will install a crontab (debian) or systemd.timers (arch) entry to monitor for updated docker containers once per day. Updates will be downloaded and installed in place transparently to the user. All activity performed by Showman will be logged to /opt/showman/log/messages.

<h3>USAGE:</h3>

showman (install | update | start | stop )

install - running this option will install docker and containers from LinuxServer.io for:<br>
      * Organizr<br>
      * Prowlarr<br>
      * Sonarr<br>
      * Radarr<br>
      * SABNZBd<br>
      * Emby -or- Jellyfin<br>
      * Swag (optional)<br>
      * Ombi (optional)<p>

update - running this option will update all containers to the latest stable release available and relaunch containers

start - running this option will start all containers

stop - running this option will stop all containers
