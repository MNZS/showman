#!/bin/bash

## user-defined variables #################

base_dir='/opt/showman' ## full path to the mount point for persistent data

## global variables #######################

dc_exec="/usr/bin/docker compose -f $base_dir/compose/showman.yaml"

###########################################

function showman_install() {
  ## figure out which base distro we're running
  . /etc/os-release

  ## function variables
  local user='showman'
  local group='showman'
  local all_directories=('bin' 'config' 'compose' 'content' 'factory' )

  mkdir -p "$base_dir" || { echo "Failed to create base directory"; exit 1; }

  ## Install Docker based on the OS
  case "$ID" in
    debian)
      apt-get update
      apt-get install -y ca-certificates curl
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    arch)
      pacman -Sy --noconfirm docker docker-compose which
      systemctl enable --now docker.service
      ;;
  esac

  ## create user
  local NOLOGIN=$(which nologin)
  useradd -s "$NOLOGIN" -d /dev/null -M -c 'Showman Role Account' "$user" || { echo "Failed to create user"; exit 1; }

  # Create necessary directories
  for directory in "${all_directories[@]}"; do
    mkdir -p "$base_dir/$directory" 
  done

  cp ./showman-ng.yaml "$base_dir/compose/showman.yaml"

  local user_id=$(id -u "$user")
  local group_id=$(id -g "$user")

  . ./showman_vars

  sed -i -e "s/SHOWMAN_USER/$user_id/g" \
         -e "s/SHOWMAN_GROUP/$group_id/g" \
         -e "s/SHOWMAN_URL/$SWAG_URL/g" \
         -e "s/SHOWMAN_IP/$SHOWMAN_IP/g" \
         -e "s/DISCORD_ID/$DISCORD_ID/g" \
         -e "s/DISCORD_TOKEN/$DISCORD_TOKEN/g" \
         "$base_dir/compose/showman.yaml"
  
  chown -R $user_id:$group_id $base_dir

  $dc_exec up -d
}

case "$1" in
  install)
    printf "\n\e[32mStarting Showman install...\e[0m\n\n"
    showman_install
    ;;
  *)
    printf "\n\e[34mUsage: showman.sh (install|update|stop|start)\e[0m\n\n"
    exit 1
    ;;
esac

exit 0

