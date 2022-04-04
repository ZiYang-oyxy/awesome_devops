#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"

source $_curdir/config
cd $_curdir

echo ". Recent changes:" > changelog.log
git log -5 --pretty=format:"%ct %cI %s" >> changelog.log
echo "" >> changelog.log
git log -1 --pretty=format:"%ct" > latest_version

rm -rf dist
mkdir -p dist
rsync -azP $_curdir/ dist/awesome_devops

# 打包一些外部工具
if [[ -d $_curdir/../ad_external ]]; then
    rsync --filter=":- .gitignore" -avzP $_curdir/../ad_external/awesome_devops/ dist/awesome_devops
fi

if [[ $OSTYPE == 'darwin'* ]]; then
    SED=gsed
else
    SED=sed
fi

# 替换访问地址
$SED -i 's/SERVEFILE_PUT_ADDR=.*/SERVEFILE_PUT_ADDR='$SERVEFILE_PUT_ADDR'/g' dist/awesome_devops/lib/common.sh
$SED -i 's/SERVEFILE_GET_ADDR=.*/SERVEFILE_GET_ADDR='$SERVEFILE_GET_ADDR'/g' dist/awesome_devops/lib/common.sh
$SED -i 's/SERVEFILE_GET_ADDR/'$SERVEFILE_GET_ADDR'/g' dist/awesome_devops/install.sh

# 临时替换common.sh，否则./ad无法执行
cp -f $_curdir/lib/common.sh dist/common.sh
cp -f dist/awesome_devops/lib/common.sh $_curdir/lib/common.sh
source $_curdir/lib/common.sh

# 打包上传
tar c -C dist --exclude='dist' --exclude='.git' --exclude='*.swp' -f dist/awesome_devops.tar awesome_devops/
./ad put dist/awesome_devops.tar @awesome_devops.tar@
./ad put dist/awesome_devops/install.sh @aadi@
./ad put latest_version @latest_version@

cat changelog.log

echo
echo "install link:"
cecho y "bash <(curl -s $GETURL/@aadi@) && source ~/.bashrc"

cp -f dist/common.sh $_curdir/lib/common.sh

cd - > /dev/null
