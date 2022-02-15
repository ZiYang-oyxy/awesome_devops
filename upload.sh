#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"
source $_curdir/lib/common.sh

cd $_curdir
bash <(curl -s $GETURL/@aadi@) && source ~/.bashrc

echo ". Recent changes:" > changelog.log
git log -5 --pretty=format:"%ct %cI %s" >> changelog.log
echo "" >> changelog.log
git log -1 --pretty=format:"%ct" > latest_version

tar c -C .. --exclude='dist' --exclude='.git' --exclude='*.swp' -f dist/awesome_devops.tar awesome_devops/

./ad put latest_version @latest_version@
./ad put install.sh @aadi@
./ad put dist/awesome_devops.tar @awesome_devops.tar@

cecho y "bash <(curl -s $GETURL/@aadi@) && source ~/.bashrc"

cd -
