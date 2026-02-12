#!/bin/bash

set -e

mkdir -p ~/tmp/
curl @GETURL@/@awesome_devopsVERSION_STR.tar@ -o ~/tmp/awesome_devops.tar
if [[ -e ~/.awesome_devops ]]; then
    rm -rf ~/.awesome_devops.bak
    mv ~/.awesome_devops ~/.awesome_devops.bak
fi

cd ~/tmp
tar xf awesome_devops.tar
mv awesome_devops ~/.awesome_devops

if ! readlink -f ~ > /dev/null 2>&1; then
    if ! type brew > /dev/null 2>&1; then
        echo "Unsupported system !"
        exit 1
    else
        # macos需要安装gnu版本工具
        brew install coreutils findutils grep
        source ~/.awesome_devops/ad-completion.bash
    fi
fi

mkdir -p ~/bin
if [[ ! -e ~/.bashrc ]]; then
    printf "\nsource ~/.awesome_devops/ad-completion.bash\n" > ~/.bashrc
else
    grep -q "source ~/.awesome_devops/ad-completion.bash" ~/.bashrc || \
        printf "\nsource ~/.awesome_devops/ad-completion.bash\n" >> ~/.bashrc
fi

rm -f ~/bin/ad
ln -s `readlink -f ~/.awesome_devops/ad` ~/bin/ad

cat ~/.awesome_devops/changelog.log | awk '{$1=""; print $0}'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "${GREEN}Happy Hacking!${NC}\n"
