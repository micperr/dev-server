#!/bin/bash

#################################################################################################################################
#                                                         CONFIG                                                                #
#################################################################################################################################
function success() { echo ${green} $1 >&2; exit 0; }
function error() { echo "${red}ERROR:" $1 >&2; exit 1; }
bold=`tput bold` italic=`tput sitm` underline=`tput smul` reset=`tput sgr0` red=`tput setaf 1` green=`tput setaf 34` yellow=`tput setaf 3`

options=$(getopt --options=hbvc:r:w: --longoptions=help,build,containers:,rootdir:,workdir:,volumes --quiet --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then error "Failed parsing options. Unsupported input has been provided."; fi
# eval set -- "$options"

default_rootdir="${HOME}/Workspace"
default_workdir="/var/www"
rootdir=${default_rootdir}
workdir=${default_workdir}

while true; do
    case "$1" in
        -h|--help)
            help=true
            shift
        ;;
        -b|--build)
            build=true
            shift
        ;;
        -v|--volumes)
            volumes=true
            shift
        ;;
        -c|--containers)
            containers=$2
            shift 2
        ;;
        -r|--rootdir)
            rootdir=$2
            shift 2
        ;;
        -w|--workdir)
            workdir=$2
            shift 2
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
    Local docker server service management

${bold}USAGE${reset}
    ${bold}$(basename "$0")${reset} up|stop|down|restart|build|configure

${bold}OPTIONS${reset}
    ${bold}${green}-h, --help         ${reset}show help
    ${bold}${green}-b, --build        ${reset}build or rebuild images
    ${bold}${green}-c, --containers   ${reset}build or rebuild only selected containers separated by comma (container1,container2,...)
    ${bold}${green}-v, --volumes      ${reset}remove volumes on server down
    ${bold}${green}-r, --rootdir      ${reset}source workspace directory. Default to ${bold}"${default_rootdir}"
    ${bold}${green}-w, --workdir      ${reset}docker container work directory path Default: ${bold}"${default_workdir}"
"; exit 0
fi

################################
# DETERMINE DIRS DEPENDING ON OS

uname="$(uname -s)"
if [[ ${uname} == 'Linux' ]]; then
    SERVER_ROOT_DIR="$(dirname "$(readlink -f "$0")")"
elif [[ ${uname} == 'Darwin' ]]; then
    SERVER_ROOT_DIR="$(dirname "$(greadlink -f "$0")")"
else
    error 'Unsupported OS.'
fi
#################################################################################################################################
#                                                         ENDCONFIG                                                             #
#################################################################################################################################

contains () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 1; done
  return 0
}
actions=("up" "stop" "down" "restart" "build" "configure")
contains $1 "${actions[@]}"
if [[ $? == 0 ]]; then
    error "Invalid action parameter. See $(basename "$0") --help"
fi

# exit 0

function run() {

    cd ${SERVER_ROOT_DIR}
    source .venv/bin/activate
    #cd ${SERVER_ROOT_DIR}/inc # required to allow python script `sites_configure.py` read relative filepaths from within the origin folder

    if [[ -z ${containers} ]]; then
        configure_sites.py ${rootdir} ${workdir}
    else
        configure_sites.py --containers ${containers} ${rootdir} ${workdir}
    fi

    configure_result=$?

    # Set ENVs
    # echo -e "USER_ID=`id -u`\nGROUP_ID=`id -g`\nROOT_DIR=$rootdir\nWORK_DIR=$workdir" > .env

    if [[ ${configure_result} -ne 0 ]]; then # sites_configure failed
        error "Sites configuring has failed."
        exit 1
    fi

    if [[ $1 == 'configure' ]]; then
        success "Sites have been configured."
        exit 0
    fi

     COMPOSE="docker-compose -f docker-compose.yml"
    # COMPOSE="docker-compose --project-name ${PROJECT_NAME} -f docker-compose.yml"

    if [[ $1 == 'stop' || $1 == 'restart' ]]; then
        ${COMPOSE} stop
    fi

    if [[ $1 == 'up' || $1 == 'restart' ]]; then

        if [[ -z ${build} ]]; then
            ${COMPOSE} up -d
        else
            ${COMPOSE} up -d --build
        fi
    fi

    if [[ $1 == 'down' ]]; then

        if [[ -z ${volumes} ]]; then
            ${COMPOSE} down --remove-orphans
        else
            read -p "${yellow}All volumes are going to be removed. Are you sure?${reset}" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${COMPOSE} down --volumes --remove-orphans
            fi
        fi
    fi

    if [[ $1 == 'build' ]]; then
        ${COMPOSE} build
    fi

    # rm 'docker-compose.yml'
    deactivate
}

run $1
