#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"

VERSION_STR=${VERSION_STR:-}

source $_curdir/config
cd $_curdir

if [[ $1 = "fast" ]]; then
    FAST_EXCLUDE_STR="--exclude=not_in_ad_tar"
fi

curl --connect-timeout 1 -f http://Awesome:Devops@$SERVEFILE_PUT_ADDR/@latest_version@ > /dev/null || {
    ad cecho -R "Unable to connect to ad server"
    exit 1
}

echo ". Recent changes:" > changelog.log
git log -5 --pretty=format:"%ct %cI %s" >> changelog.log
echo "" >> changelog.log
git log -1 --pretty=format:"%ct" > latest_version

rm -rf dist
mkdir -p dist
tar c -C .. --exclude='awesome_devops/vim' --exclude='awesome_devops/not_in_ad_tar/' --exclude='awesome_devops/docs' --exclude='awesome_devops/dist' --exclude='.git' --exclude='*.swp' -f dist/awesome_devops.tar awesome_devops/

# 打包一些外部工具
if [[ -d $_curdir/../ad_external ]]; then
    rm -rf dist/awesome_devops
    tar x -C dist -f dist/awesome_devops.tar
    rsync --filter=":- .gitignore" -avzP $FAST_EXCLUDE_STR $_curdir/../ad_external/awesome_devops/ dist/awesome_devops

    # 让本地也能用
    rsync --filter=":- .gitignore" -avzP $FAST_EXCLUDE_STR $_curdir/../ad_external/awesome_devops/ $_curdir
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
$SED -i 's/VERSION_STR/'$VERSION_STR'/g' dist/awesome_devops/install.sh

# 临时替换common.sh，否则./ad无法执行
cp -f $_curdir/lib/common.sh .common.sh
cp -f dist/awesome_devops/lib/common.sh $_curdir/lib/common.sh
source $_curdir/lib/common.sh

# 打包上传，不用tar z，因为有些环境tar不支持
tar c -C dist --exclude='dist' --exclude='not_in_ad_tar' --exclude='.git' --exclude='*.swp' -f dist/awesome_devops.tar awesome_devops/
./ad put dist/awesome_devops.tar @awesome_devops"$VERSION_STR".tar@
./ad put dist/awesome_devops/install.sh @aadi"$VERSION_STR"@
./ad put latest_version @latest_version"$VERSION_STR"@

# 上传一些没有发布到ad tar中的文件
tar cz --exclude='vim/undodir/%*' --exclude='vim/cache' --exclude='.git' --exclude='*.swp' -f dist/vim.tgz vim
./ad put dist/vim.tgz @vim_bundle.tgz@

if [[ $1 = "fast" ]]; then
    ad cecho -C "skip not_in_ad_tar routine"
else
    cd not_in_ad_tar
    for folder in */
    do
        tgz_file=@${folder%/}.tgz@
        tar -czvf "$tgz_file" "$folder"
        ../ad put $tgz_file
        rm $tgz_file
    done
    cd -
fi

cat changelog.log

echo
echo "Install link:"
ad cecho -Y "bash <(curl -s $GETURL/@aadi"$VERSION_STR"@) && source ~/.bashrc"

cp -f .common.sh $_curdir/lib/common.sh
rm -f .common.sh

cd - > /dev/null
