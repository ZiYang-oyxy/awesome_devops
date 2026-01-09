#!/bin/bash

set -e

ensure_local_domain() {
    local domain="ad-local-domain.com"
    local ipv4="10.131.251.191"
    local ipv6="fdbd:dc03:4:ffff:11:131:251:191"
    local hosts_file="/etc/hosts"
    local tmp

    tmp=$(mktemp)

    if sudo sh -c "cat '$hosts_file' >/dev/null" 2>/dev/null; then
        # backup once to ease rollback if needed
        sudo cp "$hosts_file" "${hosts_file}.bak.$(date +%Y%m%d%H%M%S)" >/dev/null 2>&1 || true
        sudo grep -v -E "(^|[[:space:]])${domain}([[:space:]]|$)" "$hosts_file" > "$tmp"
        printf "%s\t%s\n" "$ipv4" "$domain" >> "$tmp"
        printf "%s\t%s\n" "$ipv6" "$domain" >> "$tmp"
        sudo cp "$tmp" "$hosts_file"
        sudo chmod 644 "$hosts_file" >/dev/null 2>&1 || true
        rm -f "$tmp"
        echo "Configured $domain in /etc/hosts"
    else
        rm -f "$tmp"
        echo "Warning: unable to update /etc/hosts automatically. Add manually:"
        echo "  $ipv4    $domain"
        echo "  $ipv6    $domain"
    fi
}

ensure_local_domain

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
