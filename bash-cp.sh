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
    if rpm -qa | grep "nginx\|php"
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
    	
    	dnf install nginx php-fpm php-common
    fi
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
        INSTALL_LEMP=true
        ;;
        2)
        INSTALL_LEMP=false
        ;;
    esac
fi

if [[ "$INSTALL_LEMP" = true ]]; then
	#statements
	install_lemp
else
	Info "Ok, see next time, bye :)"
	exit 0
fi
