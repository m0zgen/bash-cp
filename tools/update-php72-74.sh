#!/bin/bash

rpm -e $(rpm -qa | grep php)
yum module reset php
yum -y module install php:remi-7.4
yum -y install php-json php-xml php-pdo php-pear php-xmlrpc php-gd php-cli php-fpm php-pspell php-pecl-memcache php-snmp php-process php-mysqlnd php php74-php-xml php-pecl-apcu php-pecl-redis

systemctl start php-fpm && systemctl enable php-fpm
