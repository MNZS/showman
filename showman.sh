#!/bin/bash

## user-defined variables #################

base_dir='/opt/showman' ## full path to the mount point for persistent data
tls_url='' ## tld used by swag to create tls certificate

## global variables #######################

log_path="$base_dir/log"
log_file="$log_path/messages"
tmp_file="$log_path/workfile.tmp"
log_date=$(date '+%Y-%m-%d %H:%M')
## dc_exec="/usr/local/bin/docker-compose -f $base_dir/compose/showman.yaml"
dc_exec="/usr/bin/docker compose -f $base_dir/compose/showman.yaml"

###########################################

function log_action () {
	echo "$log_date ** executed showman $1" >> $log_file
}

function make_cron () {
	cp "$1" $base_dir/bin/showman.sh
	chmod 700 $base_dir/bin/showman.sh
	(crontab -l 2>/dev/null; echo "0 4 * * * /bin/bash $base_dir/bin/showman.sh update >/dev/null 2>&1") | crontab -
	(crontab -l 2>/dev/null; echo "0 0 1 * * /bin/bash $base_dir/bin/showman.sh rotate >/dev/null 2>&1") | crontab -
}

function showman_up () {
        $dc_exec up -d
        log_action "up"
}

function showman_down () {
        $dc_exec down
        log_action "down"
}

function showman_destroy () {
        $dc_exec down --rmi all
        log_action "destroy"
}

function showman_start () {
        $dc_exec start
        log_action "start"
}

function showman_stop () {
        $dc_exec stop
        log_action "stop"
}

function showman_install () {

        printf "\n\tDo you intend to access media from outside of the\n"
        printf "\tnetwork where the media server will reside? (y/N)\n\n"

        read user_choice

        user_choice=${user_choice::1}
        user_choice=`echo $user_choice | tr '[:upper:]' '[:lower:]'`

	if [ $user_choice = 'y' ]; then
		printf "\n\tshowman will be installed with options for public access\n\n"
	elif [ $user_choice = 'n' ]; then
		printf "\n\tshowman will be installed for use on local network only\n\n"
	else
		printf "\n\tAnswer must be Y or N\n"	
		printf "\n\tPlease re-run script and try again\n\n"
		exit 1
	fi

	printf "\tIf this isn't what you wanted, hit ctrl-c now to cancel install\n\n"
	sleep 7

	printf "\n\tStarting Showman install...\n\n"

	## function variables
	user='showman'
	group='showman'

	all_directories=('bin' 'config' 'downloads' 'incomplete-downloads' 'tv' 'movies' 'compose' 'log')

	mkdir $base_dir

	## figure out which .deb based distro we're running
	. /etc/os-release

	apt-get update

	apt-get -y upgrade

	apt-get -y install \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg \
		lsb-release	

	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg

	echo \
	  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
	  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
	  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	apt-get update

	apt-get -y install docker-ce docker-ce-cli containerd.io

	### Install docker-compose
	### curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	### chmod +x /usr/local/bin/docker-compose

	### Install user
	useradd \
       		-c 'Showman Role Account' \
	        $user

	for directory in "${all_directories[@]}"; do
		if [ ! -d "$base_dir/$directory" ]; then
			mkdir "$base_dir/$directory"
			chown -R $user:$group "$base_dir/$directory"
		fi	
	done

	user_id=$(id -u $user)
	group_id=$(id -g $user)

	sed -i "s/SHOWMAN_USER/$user_id/g" ./showman.yaml
	sed -i "s/SHOWMAN_GROUP/$group_id/g" ./showman.yaml
	sed -i "s/SHOWMAN_URL/$tls_url/g" ./showman.yaml

	if [ $user_choice = 'y' ]; then
		sed -i "s/##//g" ./showman.yaml
		sed -i "s/ORG_PORT/8010/" ./showman.yaml
	else 
		sed -i "s/ORG_PORT/80/" ./showman.yaml
	fi

	cp ./showman.yaml $base_dir/compose/

	make_cron "$0"

	log_action "install"	
	showman_up

}

function compose_pull () {
	$dc_exec -f /opt/showman/compose/showman.yaml \
		pull
}

function compose_up () {
	$dc_exec up -d --no-deps
}

function log_rotate () {
	i='6'
	[[ -f $log_path/messages.$i ]] \
		&& rm -f $log_path/messages.$i
	while [ $i -gt '0' ]; do
		[[ -f $log_path/messages.$i ]] \
			&& mv $log_path/messages.$i $log_path/messages.$(($i+1))
		i=$(($i-1))
	done
	mv $log_path/messages $log_path/messages.1
	log_action "rotate"
	echo "$log_date ~~~~ rotated showman log files" >> $log_file
	 
}

function update_log () {
	if grep -i 'recreating' $tmp_file; then
		/usr/bin/docker image prune -f -a
		
		echo "$log_date ++++ update has been found" \
			>> $log_file

		for service in $(grep -i 'recreating' $tmp_file | \
			cut -d' ' -f2 | \
			sort -u); do 

			echo "$log_date ++++ $service container updated" \
				>> $log_file
		done
		
	else
		echo "$log_date ---- no updates found" \
			>> $log_file
	fi

	rm -f $tmp_file
}

function showman_update () {
	compose_pull
	compose_up > $tmp_file 2>&1
	log_action "update"
	update_log
}

if [ "$1" = 'install' ]; then
	printf "\n\e[32mStarting Showman install...\e[0m\n\n"
	showman_install

elif [ "$1" = 'up' ]; then
	printf "\n\e[92mBringing up Showman containers...\e[0m\n\n"
	showman_up

elif [ "$1" = 'update' ]; then
	printf "\n\e[92mStarting update of Showman containers...\e[0m\n\n"
	showman_update

elif [ "$1" = 'down' ]; then
	printf "\n\e[91mShutting down Showman containers...\e[0m\n\n"
	showman_down

elif [ "$1" = 'stop' ]; then
	printf "\n\e[91mStopping Showman containers...\e[0m\n\n"
	showman_stop

elif [ "$1" = 'start' ]; then
	printf "\n\e[92mStarting Showman containers...\e[0m\n\n"
	showman_start

elif [ "$1" = 'destroy' ]; then
	printf "\n\e[92mClearing Showman containers...\e[0m\n\n"
	showman_destroy

elif [ "$1" = 'rotate' ]; then
	printf "\n\e[92mRotating log files...\e[0m\n\n"
	log_rotate

else
	printf "\n\e[34mUsage: showman.sh (install|update|down|stop|start)\e[0m\n\n"
	exit 1
fi

exit 0
