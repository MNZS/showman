<h2>Dockerized Media Server (Showman)</h2>

<h3>Watchtower, Prowlarr, Organizr, Radarr, Sonarr, NZBGet, Jellyfin, Jellyseerr, and  Swag</h3>

Showman acts as an abstraction layer for installation and maintenance several docker containers (from LinuxServer.io) running as a group of "microservices". Combined they perform as a Media Server that will allow for download and viewing of TV shows and Movies on an individual's home network as well as remotely (if network configuration allows).

<h3>INSTALLATION:</h3>

Showman is written in bash and configured to run on either Debian or Arch Linux. 

It is recommended, but not required, that the default installation path directory (/opt/showman) is mounted to an external drive and separate from the disk where the OS is installed.

<<< Placeholder for showman_vars file >>>

As root or with root privileges, run 

     /bin/bash showman.sh install
     
