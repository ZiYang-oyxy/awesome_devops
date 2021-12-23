#!/bin/bash

cd ../
tar c --exclude='.git' --exclude='*.swp' -zf awesome_devops.tgz awesome_devops/
ad put awesome_devops.tgz @awesome_devops.tgz@
ad put awesome_devops/install.sh @aadi@
cd -
