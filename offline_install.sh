#!/bin/bash

_curdir="`dirname $(readlink -f $0)`"
source $_curdir/lib/common.sh

if [[ -e ~/.awesome_devops ]]; then
    rm -rf ~/.awesome_devops.bak
    mv ~/.awesome_devops ~/.awesome_devops.bak
fi
_ln $_curdir/../awesome_devops ~/.awesome_devops

mkdir -p ~/bin
if [[ ! -e ~/.bashrc ]]; then
    printf "\nsource ~/.awesome_devops/ad-completion.bash\n" > ~/.bashrc
else
    grep -q "source ~/.awesome_devops/ad-completion.bash" ~/.bashrc || \
        printf "\nsource ~/.awesome_devops/ad-completion.bash\n" >> ~/.bashrc
fi
ln -s `readlink -f ~/.awesome_devops/ad` ~/bin/ad

