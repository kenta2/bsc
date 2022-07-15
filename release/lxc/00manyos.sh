#!/bin/bash
set -x
set -e

# this has to go outside the loop because the loop overrides ostarget
if [ -e hostvariables.sh ]
then . hostvariables.sh
fi

for ostarget in debian10 debian11 centos7 centos8 ubuntu2204 debian12 ubuntu1804 ubuntu2004
do time ostarget=$ostarget destroyoldcontainer=1 bash 10host.sh
done
