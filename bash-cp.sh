#!/bin/bash
# Cretaed by Yevgeniy Gonvharov, https://sys-adm.in
# Simple BASH Conreol Panel for VPS (CentOS / Fedora) LEMP Server

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

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

ME=`basename "$0"`
SITE_AVALIABLE="/etc/nginx/sites-available"

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
	      Info "Success. LEMP Installed and ready"
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

    # Configure
    sed -i 's/^\(user =\).*/\1 nginx/' /etc/php-fpm.d/www.conf
    sed -i 's/^\(group =\).*/\1 nginx/' /etc/php-fpm.d/www.conf
    sed -i 's/^\(listen =\).*/\1 \/run\/php-fpm\/www.sock/' /etc/php-fpm.d/www.conf
    sed -i 's/;listen.owner = .*/listen.owner = nginx/' /etc/php-fpm.d/www.conf
    sed -i 's/;listen.group = .*/listen.group = nginx/' /etc/php-fpm.d/www.conf
    sed -i 's/;listen.mode = .*/listen.mode = 0600/' /etc/php-fpm.d/www.conf
    sed -i '/^    include \/etc\/nginx\/conf.d*/a \    include \/etc\/nginx\/sites-available\/*.conf;' /etc/nginx/nginx.conf

    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload

    # Enabling and start services
    systemctl enable php-fpm.service && systemctl start php-fpm.service
    systemctl enable nginx && systemctl start nginx

    Info "Ok, all software installed... I'm trying self restarting..."

    $SCRIPT_PATH/$(basename $0) && exit

    elif [[ "$DISTR" == "Fedora" ]]; then
    	# Need
    	dnf install nginx php-fpm php-common
    fi
}

function genIndexPage ()
{
      cat > $1/index.php <<_EOF_
<html>
 <head>
    <title>${2}</title>
 </head>
 <body>
    <h1>${2} working!</h1>
 </body>
</html>
_EOF_

}

function setup_nginx_config_site ()
{
  local user=$1
  local site=$2

  cat > /etc/nginx/sites-available/$1-$2.conf <<_EOF_
server {
    listen         80 default_server;
    listen         [::]:80 default_server;

    server_name ${2} www.${2};
    access_log /srv/www/${1}/${2}/logs/access.log;
    error_log /srv/www/${1}/${2}/logs/error.log;
    root /srv/www/${1}/${2}/public_html;
    location / {
        index index.php;
    }
    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass  unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
_EOF_

  cd /etc/nginx/sites-enabled/
  ln -s /etc/nginx/sites-available/$1-$2.conf

}

function setup_new_site ()
{

  read -p "Setup new site name (domain name): " site

  if [[ $site != "" ]] ; then

    if [ -d /srv/www/$1/$site/ ]; then
      Error "Site exist!"
    else

      mkdir -p /srv/www/$1/$site/logs
      mkdir -p /srv/www/$1/$site/public_html
      genIndexPage /srv/www/$1/$site/public_html $site

      chown -Rf $1:nginx /srv/www/$1/$site

      # Setup $1 = username, $2 = domain name
      setup_nginx_config_site $1 $site

      systemctl restart nginx
      Info "Site $site created in the /srv/www/$1/$site"
    fi
  fi
}

function setup_new_user
{
	Info "Setup new site"
	read -p "Setup new user name: " user

	if [[ $user != "" ]] ; then

		if [ $(getent passwd $user) ] ; then
	        Error "User $user exists"
          read -p "Add new site to $user? [y/n] " addsite
          if [[ $addsite = y ]]; then
            setup_new_site $user
          fi
		else
	      Info "User name is $user"
		  	useradd $user -r -s /sbin/nologin
		  	usermod -G nginx $user

        setup_new_site $user

		  Info "Done! User and site created!"
		fi
	fi
}

function view_sites
{
	Info "View installed sites"

	ls /srv/www

}

function delete_user
{
	Info "Delete existing sites"
	read -p "Which user to remove?: " user

	if [[ $user != "" ]] ; then
		if [[ $(getent passwd $user) ]]; then
			Info "Delete user $user"
			read -p "Are you shure? [y/n] " shure
			if [[ $shure = y ]]; then
				userdel -r $user > /dev/null 2>&1
				rm -rf /srv/www/$user
			else
				Info "User does not deleted!"
			fi
		else
			Error "User does not exist!"
		fi
	fi
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


while true
	do
		PS3='Please enter your choice: '
		options=("Setup new site" "View installed sites" "Delete user" "Quit")
		select opt in "${options[@]}"
		do
		 case $opt in
		     "Setup new site")
		         setup_new_user
		         break
		         ;;
		     "View installed sites")
		         view_sites
		         break
		         ;;
		     "Delete user")
		         delete_user
		         break
		         ;;
		     "Quit")
		         Info "Thank You... Bye"
		         exit
		         ;;
		     *) echo invalid option;;
		 esac
	done
 done

fi


