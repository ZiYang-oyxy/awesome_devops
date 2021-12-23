#!/bin/bash -e

mkdir -p /tmp/
curl http://10.151.170.16:8890/@another_airdrop.tgz@ -o /tmp/another_airdrop.tgz
if [[ -e ~/.another_airdrop ]]; then
    rm -rf ~/.another_airdrop.bak
    mv ~/.another_airdrop ~/.another_airdrop.bak
fi

cd /tmp
tar xf another_airdrop.tgz
mv another_airdrop ~/.another_airdrop

mkdir -p ~/bin
if [[ ! -e ~/.bashrc ]]; then
    echo "export PATH=~/bin:\$PATH" > ~/.bashrc
fi

grep -q "export PATH=~/bin" ~/.bashrc || echo "export PATH=~/bin:\$PATH" >> ~/.bashrc
rm -f ~/bin/ad
ln -s `readlink -f ~/.another_airdrop/ad` ~/bin/ad

GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "${GREEN}Happy Hacking!${NC}\n"
