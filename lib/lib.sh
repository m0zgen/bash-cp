#!/bin/bash

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# dir=${PWD%/*}
baseDir=$(cd -P . && pwd -P)
config="$baseDir/config/conf-rmt.json"
soft="$baseDir/lib/os-packages.txt"

# Notify in colors
# ---------------------------------------------------\
Info() {
	printf "\033[1;32m$@\033[0m\n"
}

Error() {
	printf "\033[1;31m$@\033[0m\n"
}

space() {
	echo -e "\n"
}

# Functions
# ---------------------------------------------------\
isRoot() {
	if [ $(id -u) -ne 0 ]; then
		Error "You must be root user to continue"
		exit 1
	fi
	RID=$(id -u root 2>/dev/null)
	if [ $? -ne 0 ]; then
		Error "User root no found. You should create it to continue"
		exit 1
	fi
	if [ $RID -ne 0 ]; then
		Error "User root UID not equals 0. User root must have UID 0"
		exit 1
	fi
}

isSELinux() {
	selinuxenabled
	if [ $? -ne 0 ]
	then
	    Error "SELinux - DISABLED"
	else
	    Info "SELinux - ENABLED"
	fi
}

installRepos() {
	# Install epel
	yum install yum-utils epel-release -y

	# Remi
	yum install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm -y
	yum-config-manager --enable remi-php72

# NGINX repo
# http://nginx.org/en/linux_packages.html
cat >> /etc/yum.repos.d/nginx.repo <<_EOF_
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
_EOF_
}

function installSoftware() {
	echo $soft > ~/log.txt
	echo "yum install $(cat $soft) -y" >> ~/log.txt
	yum install $(cat $soft) -y
}

function installSelfSignedNginxSSL() {
	# Self-signed cert data
	country=KZ
	state=Almaty
	locality=Almaty
	organization=raimbek.com
	organizationalunit=IT
	email=support@raimbek.com

	# Generate SSL and config
	mkdir -p /etc/nginx/ssl

	openssl req -x509 -nodes -days 999 -newkey rsa:4096 \
	-keyout /etc/nginx/ssl/nginx-selfsigned.key -out /etc/nginx/ssl/nginx-selfsigned.crt \
	-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$SERVER_NAME/emailAddress=$email"
}

function checkAndCreateFolder() {
	if [[ ! -d $1 ]]; then
	  mkdir -p $1
	fi
}

function is_lemp_installed
{
    if rpm -qa | grep "nginx\|php" > /dev/null 2>&1
	then
	      Info "Success. LEMP Installed and ready"
	      _IS_LEMP_INSTALLED=1
	else
	      Error "Nginx or PHP-FPM not installed"
	fi
    # _IS_LEMP_INSTALLED=0

}

function allowFirewalldService() {
	#statements
	firewall-cmd --permanent --zone=public --add-service=$1
}

# get Actual date
getDate() {
	date '+%d-%m-%Y_%H-%M-%S'
}

# GenPassword
getRandom() {
  local l=$1
  [ "$l" == "" ] && l=8
  tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

getRandomComplex() {
  local l=$1
  [ "$l" == "" ] && l=8
  tr -dc 'A-Za-z0-9!?#$%^&()=+-' < /dev/urandom | head -c ${l} | xargs
}

getConfig() {
	local l=$1
	# echo $l $config
	jq -r '.'${l} "$config"

}

# Spinner
# ---------------------------------------------------\
function _spinner() {
    # $1 start/stop
    #
    # on start: $2 display message
    # on stop : $2 process exit status
    #           $3 spinner function pid (supplied from stop_spinner)

    local on_success="DONE"
    local on_fail="FAIL"
    local white="\e[1;37m"
    local green="\e[1;32m"
    local red="\e[1;31m"
    local nc="\e[0m"

    case $1 in
        start)
            # calculate the column where spinner and status msg will be displayed
            let column=$(tput cols)-${#2}-8
            # display message and position the cursor in $column column
            echo -ne ${2}
            printf "%${column}s"

            # start spinner
            i=1
            sp='\|/-'
            delay=${SPINNER_DELAY:-0.15}

            while :
            do
                printf "\b${sp:i++%${#sp}:1}"
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1

            # inform the user uppon success or failure
            echo -en "\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

function start_spinner {
    # $1 : msg to display
    _spinner "start" "${1}" &
    # set global spinner pid
    _sp_pid=$!
    disown
}

function stop_spinner {
    # $1 : command exit status
    _spinner "stop" $1 $_sp_pid
    unset _sp_pid
}
# /Spin

# Spinner wrapper, initializator
function spin {
	echo $1
	start_spinner '...processing'
	  $2 > /dev/null 2>&1
	  stop_spinner $?
}
