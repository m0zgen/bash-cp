#!/bin/bash

function test
{

	cat > /etc/yum.repos.d/nginx.repo <<_EOF_
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=0
enabled=1
_EOF_

}

test
