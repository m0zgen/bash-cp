#!/bin/bash
# Cretaed by Yevgeniy Gonvharov, https://sys-adm.in
# Simple BASH Conreol Panel for VPS (CentOS / Fedora) LEMP Server

# Libs / Configs
# ---------------------------------------------------\
source "$(pwd)/lib/lib.sh"
source "$(pwd)/lib/dbwrapper.sh"
config="$(pwd)/config/conf-cp.json"

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Checking admin permissions and current distro
# ---------------------------------------------------\
# Checking root permission for current user
isRoot

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
SERVER_IP=$(hostname -I | cut -d' ' -f1)
SITE_AVALIABLE="/etc/nginx/sites-available"

#
if [[ ! -f $SCRIPT_PATH/config/users.json ]]; then
	  touch $SCRIPT_PATH/config/users.json
    echo -e "{\n}" > $SCRIPT_PATH/config/users.json
fi

function setConfigVars
{
  # DB server settings
  typeset -l DB_NAME
  DB_NAME="$(getConfig "dbname")$(getRandom)"
  typeset -l DB_USER
  DB_USER="$(getConfig "dbuser")$(getRandom)"
  DB_PASS=$(getRandom)
}

# Checking /srv/www folders
# ---------------------------------------------------\
checkAndCreateFolder "/srv/www"
checkAndCreateFolder "/etc/nginx/sites-available"
checkAndCreateFolder "/etc/nginx/sites-enabled"

# Functions
# ---------------------------------------------------\
# Restart LEMP stack
function restartLEMP
{
  systemctl restart php-fpm && systemctl restart nginx
}

# Setup SELinux (testing)
function setupSELinux {
  Info "Checking SELinux..."
  isSELinux

  ##
  cd $SCRIPT_PATH/se/
  checkmodule -M -m -o nginx.mod nginx.te
  semodule_package  -m nginx.mod -o nginx.pp
  semodule -i nginx.pp
  semanage fcontext -a -t httpd_sys_rw_content_t "/home/$OS_USER/user/roject(/.*)?"
  semanage fcontext -a -t httpd_sys_rw_content_t "/home/$OS_USER/web-files(/.*)?"
  restorecon -RF /home/$OS_USER/RMT/rtproject
  restorecon -RF /home/$OS_USER/web-files

  restartLEMP
}

function setupMariaDB
{
  DB_ROOT_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

  # Enable and start MariaDB
  systemctl enable mariadb && systemctl start mariadb

  # mysql_secure_installation analog
  mysql --user=root <<_EOF_
  UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASS}') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_

}

# Install LEMP stack
function install_lemp
{
    Info "Install LEMP procedure..."

    if [[ "$DISTR" == "CentOS" ]]; then
    	Info "CentOS detected... Install necessary software.."

      # Installs
      # ---------------------------------------------------\
      # Install updates && repos
      spin 'Erase packages...' 'yum erase iwl* -y'
      spin 'Update system...' 'yum update -y'
      # NGINX, REMI
      spin 'Install repos...' 'installRepos'
      # Install PSQL, Redis, Python 3.6 and etc...
      spin 'Install general software...' 'installSoftware'

      sleep 5

      # Configure NGINX, PHP-FPM
      sed -i 's/^\(user =\).*/\1 nginx/' /etc/php-fpm.d/www.conf
      sed -i 's/^\(group =\).*/\1 nginx/' /etc/php-fpm.d/www.conf
      sed -i 's/^\(listen =\).*/\1 \/run\/php-fpm\/www.sock/' /etc/php-fpm.d/www.conf
      sed -i 's/;listen.owner = .*/listen.owner = nginx/' /etc/php-fpm.d/www.conf
      sed -i 's/;listen.group = .*/listen.group = nginx/' /etc/php-fpm.d/www.conf
      sed -i 's/;listen.mode = .*/listen.mode = 0600/' /etc/php-fpm.d/www.conf
      sed -i '/^    include \/etc\/nginx\/conf.d*/a \    include \/etc\/nginx\/sites-available\/*.conf;' /etc/nginx/nginx.conf

      sed -i 's/^\(disable_functions =\).*/\1 dl,exec,passthru,pcntl_exec,pfsockopen,popen,posix_kill,posix_mkfifo,posix_setuid,proc_close,proc_open,proc_terminate,shell_exec,system,leak,posix_setpgid,posix_setsid,proc_get_status,proc_nice,show_source,escapeshellcmd/' /etc/php.ini

      # Setup MariaDB
      setupMariaDB

      # Add cert
      installSelfSignedNginxSSL

      # Firewalld
      allowFirewalldService "http" "public"
      allowFirewalldService "https" "public"
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

# Generate index.php page on the user > site > public_html folder
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

# Setup PHP-FPM pool for new site / user
function setup_php_fpm_pool () {

  cat > /etc/php-fpm.d/$1-$2.conf <<_EOF_
[${1}]
user = ${1}
group = ${1}
listen = /run/php-fpm/${1}.sock;
listen.owner = nginx
listen.group = nginx
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
php_admin_flag[allow_url_fopen] = off
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.status_path = /status
chdir = /
_EOF_
}

# Setup NGINX server config for new site / user
function setup_nginx_config_site ()
{
  local user=$1
  local site=$2

  cat > /etc/nginx/sites-available/$1-$2.conf <<_EOF_
server {
    listen         80;
    listen         [::]:80;

    server_name ${2} www.${2};
    access_log /srv/www/${1}/${2}/logs/access.log;
    error_log /srv/www/${1}/${2}/logs/error.log;
    root /srv/www/${1}/${2}/public_html;
    location / {
        index index.php;
    }
    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass  unix:/run/php-fpm/${1}.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}
server {
    listen 443 ssl;
    server_name ${2} www.${2};

    location = /favicon.ico { access_log off; log_not_found off; }
    access_log /srv/www/${1}/${2}/logs/access.log;
    error_log /srv/www/${1}/${2}/logs/error.log;
    root /srv/www/${1}/${2}/public_html;
    location / {
        index index.php;
    }
    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass  unix:/run/php-fpm/${1}.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
ssl on;
ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

ssl_ciphers EECDH:+AES256:-3DES:RSA+AES:RSA+3DES:!NULL:!RC4:!RSA+3DES;
ssl_prefer_server_ciphers on;

ssl_protocols  TLSv1.1 TLSv1.2;
add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload";
add_header X-XSS-Protection "1; mode=block";
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options nosniff;
}
_EOF_

  cd /etc/nginx/sites-enabled/
  ln -s /etc/nginx/sites-available/$1-$2.conf

  addDBUser $user $site
}

# Setup new site
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
      setup_php_fpm_pool $1 $site

      restartLEMP
      Info "Site $site created in the /srv/www/$1/$site"
    fi
  fi
}

# Setup new user & new site from user menu choice
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

# View users
function view_sites
{
  space
	Info "View installed sites:"

  colUsers=$(ls /srv/www | wc -l)
  if [[ "$colUsers" = "" ]]; then
    Warn "Created users - 0"
  else
    Info "Created users - $colUsers"
    ls /srv/www
  fi
  space
}

# Full deletion procedure (delete user, user site folders, configs)
function delete_user
{
	Info "Delete existing sites"
	read -p "Which user to remove?: " user

	if [[ $user != "" ]] ; then
		if [[ $(getent passwd $user) ]]; then
			Info "Delete user $user"
			read -p "Are you shure? [y/n] " shure
			if [[ $shure = y ]]; then

        rm -f $(ls /etc/php-fpm.d/$user-*) > /dev/null 2>&1
        rm -f $(ls /etc/nginx/sites-enabled/$user-*) > /dev/null 2>&1
        rm -f $(ls /etc/nginx/sites-available/$user-*) > /dev/null 2>&1

        restartLEMP

        rm -rf /srv/www/$user > /dev/null 2>&1
        userdel -r $user > /dev/null 2>&1

			else
				Info "User does not deleted!"
			fi
		else
			Error "User does not exist!"
		fi
	fi
}

# Exit from script
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
		install_lemp
	else
		Info "Ok, see next time, bye :)"
		exit 0
	fi
else

  # Bindings local variables from config/config-cp.json
  setConfigVars

  # User menu rotator
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
