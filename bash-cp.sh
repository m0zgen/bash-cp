#!/bin/bash
# Cretaed by Yevgeniy Gonvharov, https://sys-adm.in
# Simple BASH Conreol Panel for VPS (CentOS / Fedora) LEMP Server


# Additions
# ---------------------------------------------------\
Info() {
  printf "\033[1;32m$@\033[0m\n"
}

Error()
{
  printf "\033[1;31m$@\033[0m\n"
}

Warn() {
        printf "\033[1;35m$@\033[0m\n"
}

# Checking admin permissions and current distro
# ---------------------------------------------------\
# Checking root permission for current user
if [[ "$EUID" -ne 0 ]]; then
    echo "Sorry, you need to run this as root"
    exit 1
fi

# Checking distro
if [ -e /etc/centos-release ]; then
    DISTR="CentOS"
elif [ -e /etc/fedora-release ]; then
    DISTR="Fedora"
    Error "At this time scipt workink on CentOS only"
    exit 0
else
    echo "Your distribution is not supported (yet)"
    exit 1
fi

# Checking folders
# ---------------------------------------------------\
if [[ ! -d /srv/www ]]; then
  mkdir -p /srv/www
fi

if [[ ! -d /etc/nginx/sites-available ]]; then
  mkdir -p /etc/nginx/sites-available
fi

if [[ ! -d /etc/nginx/sites-enabled ]]; then
  mkdir -p /etc/nginx/sites-enabled
fi

# Functions
# ---------------------------------------------------\
function is_lemp_installed
{
    if rpm -qa | grep "nginx\|php" > /dev/null 2>&1
	then
	      Info "Success. LEMP Installed"
	      _IS_LEMP_INSTALLED=1
	else
	      Error "Nginx or PHP-FPM not installed"
	fi
    # _IS_LEMP_INSTALLED=0
    
}

function install_lemp
{
    Info "Install LEMP procedure..."

    if [[ "$DISTR" == "CentOS" ]]; then
    	Info "CentOS detected... Install necessary software.."
		cat > /etc/yum.repos.d/nginx.repo <<_EOF_
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
_EOF_

		yum install yum-utils epel-release -y
		yum install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm -y
		yum-config-manager --enable remi-php72
		yum install nginx php-fpm php-common -y

    elif [[ "$DISTR" == "Fedora" ]]; then
    	# Need 
    	dnf install nginx php-fpm php-common
    fi
}

function setup_new_site
{
	Info "Setup new site"
}

function view_sites
{
	Info "View installed sites"	
}

function delete_sites
{
	Info "Delete existing sites"
}

function close_me
{
	Info "Ok, bye!"
	exit 0
}


# Checking is LEMP installed
is_lemp_installed

if [ "$_IS_LEMP_INSTALLED" == "" ]; then
    Info "Install NGINX and PHP-FPM?"
    echo "   1) Yes"
    echo "   2) No"
    read -p "Install [1-2]: " -e -i 1 INSTALL_CHOICE

    case $INSTALL_CHOICE in
        1)
        INSTALL_LEMP=1
        ;;
        2)
        INSTALL_LEMP=0
        ;;
    esac

    if [[ "$INSTALL_LEMP" = 1 ]]; then
		#statements
		install_lemp
	else
		Info "Ok, see next time, bye :)"
		exit 0
	fi
else

	Info "Whant do you want?"
    echo "   1) Setup new site"
    echo "   2) View installed sites"
    echo "   3) Delete site"
    echo "   4) Exit"
    read -p "Install [1-3]: " -e -i 1 ACTION

    case $ACTION in
        1)
        SITE_ACTION=1
        ;;
        2)
        SITE_ACTION=2
        ;;
        3)
        SITE_ACTION=3
        ;;
        4)
        SITE_ACTION=4
        ;;
    esac

    if [[ "$SITE_ACTION" = 1 ]]; then
		#statements
		setup_new_site
	elif [[ "$SITE_ACTION" = 2 ]]; then
		view_sites
	elif [[ "$SITE_ACTION" = 3 ]]; then
		delete_sites
	else
		Info "Ok, see next time, bye :)"
		exit 0
	fi

fi


