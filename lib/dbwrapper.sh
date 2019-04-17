#!/bin/bash

# Envs
# ---------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# dir=${PWD%/*}
baseDir=$(cd -P . && pwd -P)
config="$baseDir/config/conf-rmt.json"
users="$baseDir/config/users.json"
source "$baseDir/lib/lib.sh"

function addDBUser() {
  jq '.users.$1 += {"$2": "enable"}' users.json | sponge users.json
}
