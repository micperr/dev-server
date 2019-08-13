#!/usr/bin/env bash

bold=`tput bold` underline=`tput smul` reset=`tput sgr0` red=`tput setaf 1` green=`tput setaf 34` yellow=`tput setaf 3`
function success() { echo ${green} $1 >&2; exit 0; }
function error() { echo "${red}ERROR:" $1 >&2; exit 1; }

while true; do
    case "$1" in
        -h|--help)
            help=true
            shift
        ;;
        -d|--docker)
            docker=true
            shift
        ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done


############
# SHOW HELP
if [[ -n ${help} ]]; then
echo "
${bold}DESCRIPTION${reset}
    Add NFS entry to /etc/exports for Vagrant (default) and Docker
${bold}SYNOPSIS${reset}
    $(basename "$0") ${green}PATH HOST [HOST...]${reset}

    ${green}PATH${reset} - path to a directory destined to be under NFS
    ${green}HOST${reset} - list of NFS destination IPs (${yellow}localhost${reset} is valid value also)
${bold}OPTIONS${reset}
    -h, --help         show help
    -d, --docker         Stop and restart docker containers
"; exit 0
fi

function is_valid_ip()
{
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    return $stat
}

OS=`uname -s`

if [ $OS != "Darwin" ]; then
  error "This script is OSX-only. Please do not run it on any other Unix."
fi

if [[ $EUID -eq 0 ]]; then
  error "This script must NOT be run with sudo/root. Please re-run without sudo." 1>&2
fi

if [[ ! $1 ]]; then
    error "\"path\" argument is required. See $(basename "$0") --help"
fi

if [[ ! $2 ]]; then
    error "\"host\" argument is required. See $(basename "$0") --help"
fi

path=$1
hosts=${@:2}

if [ ! -d $path ]; then
  error "Path \"${path}\" does not exist."
fi

IFS=' ' read -ra hostsArr <<< "${hosts}"
for h in "${hostsArr[@]}"; do
  if [[ $h != 'localhost' ]]; then
    if ! is_valid_ip $h; then
        error "Invalid host IP \"${h}\""
    fi
  fi
done

#
# DOCKER
#
if [[ -n ${docker} ]]; then
  echo ""
  echo " +-----------------------------+"
  echo " | Setup native NFS for Docker/Vagrant |"
  echo " +-----------------------------+"
  echo ""


  echo "WARNING: This script will shut down running containers."
  echo ""
  echo -n "Do you wish to proceed? [y]: "
  read decision

  if [ "$decision" != "y" ]; then
    echo "Exiting. No changes made."
    exit 1
  fi

  echo ""

  if ! docker ps > /dev/null 2>&1 ; then
    echo "== Waiting for docker to start..."
  fi

  open -a Docker

  while ! docker ps > /dev/null 2>&1 ; do sleep 2; done

  echo "== Stopping running docker containers..."
  docker-compose down > /dev/null 2>&1
  docker volume prune -f > /dev/null

  osascript -e 'quit app "Docker"'
fi
################


echo "== Resetting folder permissions..."
U=`id -u`
G=`id -g`
sudo chown -R "$U":"$G" .

echo "== Setting up nfs..."
LINE="${path} -alldirs -mapall=$U:$G ${hosts}"
FILE=/etc/exports
# sudo cp /dev/null $FILE
grep -qF -- "$LINE" "$FILE" || sudo echo "$LINE" | sudo tee -a $FILE > /dev/null

LINE="nfs.server.mount.require_resv_port = 0"
FILE=/etc/nfs.conf
grep -qF -- "$LINE" "$FILE" || sudo echo "$LINE" | sudo tee -a $FILE > /dev/null

echo "== Restarting nfsd..."
sudo nfsd restart

#
# DOCKER
#
if [[ -n ${docker} ]]; then
  echo "== Restarting docker..."
  open -a Docker

  while ! docker ps > /dev/null 2>&1 ; do sleep 2; done
fi
################

echo ""
echo "SUCCESS! 🎉🎉🎉"
