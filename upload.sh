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

# 打包一些外部工具
if [[ -d $_curdir/../ad_external ]]; then
    rm -rf dist/awesome_devops
    tar x -C dist -f dist/awesome_devops.tar
    rsync --filter=":- .gitignore" -avzP $_curdir/../ad_external/ dist/awesome_devops
    tar c -C dist --exclude='dist' --exclude='.git' --exclude='*.swp' -f dist/awesome_devops.tar awesome_devops/
fi

./ad put latest_version @latest_version@
./ad put install.sh @aadi@
./ad put dist/awesome_devops.tar @awesome_devops.tar@

cecho y "bash <(curl -s $GETURL/@aadi@) && source ~/.bashrc"

cd -
