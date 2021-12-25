#!/bin/bash

echo ". Recent changes:" > changelog.log
git log -5 --pretty=format:"%ct %cI %s" >> changelog.log
echo "" >> changelog.log
git log -1 --pretty=format:"%ct" > latest_version

tar c -C .. --exclude='dist' --exclude='.git' --exclude='*.swp' -zf dist/awesome_devops.tgz awesome_devops/

./ad put latest_version @latest_version@
./ad put install.sh @aadi@
./ad put dist/awesome_devops.tgz @awesome_devops.tgz@
