#!/bin/bash

set -e

AD_RELEASE_ROOT="@AD_RELEASE_ROOT@"
AD_RELEASE_VERSION="@AD_RELEASE_VERSION@"
AD_DEFAULT_NAMESPACE="@PH_FTS_NAMESPACE@"

if ! type ph-fts >/dev/null 2>&1; then
    echo "ph-fts command not found. Please install ph-fts first."
    exit 1
fi

PH_FTS_NAMESPACE="${PH_FTS_NAMESPACE:-${AD_DEFAULT_NAMESPACE:-}}"
PH_FTS_TOKEN="${PH_FTS_TOKEN:-}"
PH_FTS_PROFILE="${PH_FTS_PROFILE:-}"
PH_FTS_ENV="${PH_FTS_ENV:-prod}"

PH_FTS_ARGS=()
[[ -n "$PH_FTS_ENV" ]] && PH_FTS_ARGS+=(-e "$PH_FTS_ENV")
[[ -n "$PH_FTS_PROFILE" ]] && PH_FTS_ARGS+=(--profile "$PH_FTS_PROFILE")
[[ -n "$PH_FTS_NAMESPACE" ]] && PH_FTS_ARGS+=(-n "$PH_FTS_NAMESPACE")
[[ -n "$PH_FTS_TOKEN" ]] && PH_FTS_ARGS+=(-t "$PH_FTS_TOKEN")

mkdir -p ~/tmp/
REMOTE_TAR="${AD_RELEASE_ROOT}/${AD_RELEASE_VERSION}/awesome_devops.tar"
ph-fts download "${PH_FTS_ARGS[@]}" -L ~/tmp/awesome_devops.tar -R "$REMOTE_TAR"
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
ln -sf `readlink -f ~/.awesome_devops/ad` ~/bin/ad

cat ~/.awesome_devops/changelog.log | awk '{$1=""; print $0}'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "${GREEN}Happy Hacking!${NC}\n"
