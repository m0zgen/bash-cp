#!/bin/bash

function checkFolder ()
{
  read -p "Setup new site name (domain name): " site
  echo $site
  checkSite="/srv/www/$1/$site"
  echo $checkSite

  if [ -d $checkSite ]; then
    echo "Folder exist"
  else
    mkdir -p $checkSite
    echo "Folder for $site created"
  fi

}

checkFolder testuser
