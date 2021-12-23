#!/bin/bash -e

mkdir -p /tmp/
curl http://10.151.170.16:8890/@awesome_devops.tgz@ -o /tmp/awesome_devops.tgz
if [[ -e ~/.awesome_devops ]]; then
    rm -rf ~/.awesome_devops.bak
    mv ~/.awesome_devops ~/.awesome_devops.bak
fi

cd /tmp
tar xf awesome_devops.tgz
mv awesome_devops ~/.awesome_devops

mkdir -p ~/bin
if [[ ! -e ~/.bashrc ]]; then
    echo "export PATH=~/bin:\$PATH" > ~/.bashrc
fi

grep -q "export PATH=~/bin" ~/.bashrc || echo "export PATH=~/bin:\$PATH" >> ~/.bashrc
rm -f ~/bin/ad
ln -s `readlink -f ~/.awesome_devops/ad` ~/bin/ad

GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "${GREEN}Happy Hacking!${NC}\n"
