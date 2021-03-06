<h2>Dockerized Media Server (Showman)</h2>

<h3>Jellyfin, Sabnzbd, Organizr, Sonarr, Radarr, Swag, and Ombi</h3>

Showman acts as an abstraction layer for installation and maintenance of docker, 
docker-compose, and several containers (from LinuxServer.io). Combined they perform as a Media Server
that will allow for download and viewing of TV shows and Movies on an 
individual's home network as well as remotely (if network configuration allows).

<h3>INSTALLATION:</h3>

Showman is written in bash and configured to run on a Linux distribution based on Debian. 
Currently tested on Debian and Ubuntu. 

It is recommended, but not required, that the default installation path directory (/opt/showman) 
is mounted to an external drive and separate from the disk where the OS is installed.

Two global variables may be edited prior to the first run of the script. These variables
are used to identify the installation path (default is /opt/showman) and the domain
name that may be used for instances where the media server will be made available
to remote networks using the SWAG reverse proxy. (If you will not be using the reverse
proxy, this variable may remain empty)

As root or with root privileges, run 

     /bin/bash showman.sh install
     
Upon executing the script, you will be given an option to choose between a local 
network configuration or to allow your media server to be available to remote networks. 
See post-installation documentation for next steps in completing setup for the individual
services and understanding how the containers work together.

<h3>MAINTENANCE & LOGGING:</h3>

During installation, Showman will install a crontab entry to monitor for updated docker containers once per
day. Updates will be downloaded and installed in place transparently to the user.
All activity performed by Showman will be logged to /opt/showman/log/messages.

<h3>USAGE:</h3>

showman (install | up | down | start | stop | update | destroy)

install - running this option will install docker, docker-compose, and containers from LinuxServer.io for:<br>
      * Organizr<br>
      * Sonarr<br>
      * Radarr<br>
      * SABNZBd<br>
      * Jellyfin<br>
      * Swag (optional)<br>
      * Ombi (optional)<p>

update - running this option will update the containers for in place services running

up - running this option will bring up containers 

down - running this option will shutdown containers

start - running this option will start all compose services 

stop - running this option will stop all compose services

destroy - running this option will shutdown services as well as remove containers and images
