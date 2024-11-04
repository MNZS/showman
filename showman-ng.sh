#!/bin/bash

## user-defined variables #################

base_dir='/opt/showman' ## full path to the mount point for persistent data
tls_url='' ## TLD used by SWAG to create TLS certificate

## global variables #######################

log_path="$base_dir/log"
log_file="$log_path/messages"
tmp_file="$log_path/workfile.tmp"
dc_exec="/usr/bin/docker compose -f $base_dir/compose/showman.yaml"

###########################################

function log_action() {
  local log_date=$(date '+%Y-%m-%d %H:%M')
  echo "$log_date ** executed showman $1" >> "$log_file"
}

function create_systemd_service() {
  local sys_path='/etc/systemd/system'
  local timer='showman-check.timer'
  local service='showman-check.service'

  # Create timer
  {
    echo "[Unit]"
    echo "Description=Daily check for docker image updates (installed by showman)"
    echo "Requires=showman-check.service"
    echo ""
    echo "[Timer]"
    echo "Unit=showman-check.service"
    echo "OnCalendar=*-*-* 4:00:00"
    echo ""
    echo "[Install]"
    echo "WantedBy=timers.target"
  } > "$sys_path/$timer"

  # Create service
  {
    echo "[Unit]"
    echo "Description=Checks for docker image updates (installed by showman)"
    echo "Wants=showman-check.timer"
    echo ""
    echo "[Service]"
    echo "Type=oneshot"
    echo "ExecStart=/bin/bash $base_dir/bin/showman.sh update"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } > "$sys_path/$service"

  systemctl daemon-reload
  systemctl start "$timer"
  systemctl enable "$timer"
}

function schedule_cron_jobs() {
  (crontab -l 2>/dev/null; echo "0 4 * * * /bin/bash $base_dir/bin/showman.sh update >/dev/null 2>&1") | crontab -
  (crontab -l 2>/dev/null; echo "0 0 1 * * /bin/bash $base_dir/bin/showman.sh rotate >/dev/null 2>&1") | crontab -
}

function make_routine() {
  . /etc/os-release
  case "$ID" in
    arch)
      create_systemd_service
      ;;
    debian)
      schedule_cron_jobs
      ;;
  esac
}

function showman_up() {
  $dc_exec up -d
  log_action "up"
}

function showman_down() {
  $dc_exec down
  log_action "down"
}

function showman_destroy() {
  $dc_exec --rmi all down
  log_action "destroy"
}

function showman_start() {
  $dc_exec start
  log_action "start"
}

function showman_stop() {
  $dc_exec stop
  log_action "stop"
}

function get_user_choice() {
  local prompt="$1"
  local default="$2"
  local choice

  printf "$prompt"
  read -r choice
  choice=${choice:-$default}
  echo "${choice,,}" | cut -c1  # Return first character, lowercase
}

function showman_install() {
  ## figure out which base distro we're running
  . /etc/os-release

  if [[ $(get_user_choice "Do you intend to access media from outside of the network where the media server will reside? (y/N)\n" "n") == "y" ]]; then
    printf "\n\tshowman will be installed with options for public access\n\n"
  else
    printf "\n\tshowman will be installed for use on local network only\n\n"
  fi

  printf "\tIf this isn\'t what you wanted, hit ctrl-c now to cancel install\n\n"
  sleep 7

  printf "\n\tStarting Showman install...\n\n"

  ## function variables
  local user='showman'
  local group='showman'
  local all_directories=('bin' 'config' 'downloads' 'incomplete-downloads' 'tv' 'movies' 'compose' 'log')

  mkdir -p "$base_dir" || { echo "Failed to create base directory"; exit 1; }
  cp -a "$(dirname "$0")" "$base_dir/bin/"
  chmod 700 "$base_dir/bin/showman.sh"

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
    mkdir -p "$base_dir/$directory" && chown -R "$user:$group" "$base_dir/$directory"
  done

  cp ./showman.yaml "$base_dir/compose/showman.yaml"

  local user_id=$(id -u "$user")
  local group_id=$(id -g "$user")

  sed -i -e "s/SHOWMAN_USER/$user_id/g" \
         -e "s/SHOWMAN_GROUP/$group_id/g" \
         -e "s/SHOWMAN_URL/$tls_url/g" \
         "$base_dir/compose/showman.yaml"

  if [[ $(get_user_choice "Do you prefer to use Jellyfin(j) or Emby(e) for watching content?\n" "j") == "j" ]]; then
    sed -i -e "s/JF//g" -e "s/MB/##/g" "$base_dir/compose/showman.yaml"
  else
    sed -i -e "s/JF/##/g" -e "s/MB//g" "$base_dir/compose/showman.yaml"
  fi

  make_routine
  log_action "install"
  showman_up
}

function compose_pull() {
  $dc_exec pull
}

function compose_up() {
  $dc_exec up -d
}

function log_rotate() {
  for ((i=6; i>0; i--)); do
    [[ -f $log_path/messages.$i ]] && mv "$log_path/messages.$i" "$log_path/messages.$((i+1))"
  done
  [[ -f $log_path/messages ]] && mv "$log_path/messages" "$log_path/messages.1"
  log_action "rotate"
  echo "$(date '+%Y-%m-%d %H:%M') ~~~~ rotated showman log files" >> "$log_file"
}

function update_log() {
  if grep -qi 'recreat' "$tmp_file"; then
    /usr/bin/docker image prune -f -a
    log_action "update"
    echo "$(date '+%Y-%m-%d %H:%M') ++ update has been found" >> "$log_file"

    while read -r service; do
      echo "$(date '+%Y-%m-%d %H:%M') ++++ $service container updated" >> "$log_file"
    done < <(grep -i 'recreat' "$tmp_file" | cut -d' ' -f3 | sort -u)
  else
    echo "$(date '+%Y-%m-%d %H:%M') ---- no updates found" >> "$log_file"
  fi

  rm -f "$tmp_file"
}

function showman_update() {
  if [[ -f /tmp/stopfile ]]; then
    log_action "skip"
    exit 1
  fi
  compose_pull 
  compose_up > "$tmp_file" 2>&1
  update_log
}

case "$1" in
  install)
    printf "\n\e[32mStarting Showman install...\e[0m\n\n"
    showman_install
    ;;
  up)
    printf "\n\e[92mBringing up Showman containers...\e[0m\n\n"
    showman_up
    ;;
  update)
    printf "\n\e[92mStarting update of Showman containers...\e[0m\n\n"
    showman_update
    ;;
  down)
    printf "\n\e[91mShutting down Showman containers...\e[0m\n\n"
    showman_down
    ;;
  stop)
    printf "\n\e[91mStopping Showman containers...\e[0m\n\n"
    showman_stop
    ;;
  start)
    printf "\n\e[92mStarting Showman containers...\e[0m\n\n"
    showman_start
    ;;
  destroy)
    printf "\n\e[92mClearing Showman containers...\e[0m\n\n"
    showman_destroy
    ;;
  rotate)
    printf "\n\e[92mRotating log files...\e[0m\n\n"
    log_rotate
    ;;
  *)
    printf "\n\e[34mUsage: showman.sh (install|update|stop|start)\e[0m\n\n"
    exit 1
    ;;
esac

exit 0

