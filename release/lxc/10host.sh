#!/bin/bash

set -x
set -v
set -e
set -o pipefail
set -u
component=bsc

# running jobs in parallel could have collisions at the 1 second
# level, so include nanoseconds.
datestring=$(date '+on-%Y%m-%dd%Hh%Mm%S.%N%z')

if [ -z "$component" ]
then true ERROR: NEED component
    exit 1
fi

logdir=${logdir-output}
if ! [ -e "$logdir" ]
then mkdir "$logdir"
     hadtocreatelogdir=1
else hadtocreatelogdir=
fi

#save stdout
exec 6>&1

#save stderr
exec 7>&2

logfilename=${logfilename-$component-$datestring.log}
logfile=$logdir/$logfilename
# ts is in moreutils
exec >& >(ts '%.s: ' > "$logfile")
# this is "process substitution"

date

# set the "container" environment variable to override the container name
container=${container-bscbuild}

if [ -z "${ostarget-}" ]
then set +x
     echo "ERROR: need to set ostarget variable to a distribution name, e  choose among subdirectories of lxcdistros/ ."
     exit 1
fi

. lxcdistros/$ostarget/lxcvars.sh

versionsuffix=${versionsuffix:-alpha}
versionprefix=${versionprefix-$(date '+%Y.%m%d')}
version=${version-$versionprefix${versionsuffix}}

hostname
pwd

# we will need this at the end; test that it exists
zip -h

zipdir=${zipdir-output}
mkdir -p "$zipdir"

git log -1
git status
git diff
git submodule status --recursive

inner=builduser

# print important stuff to tty
exec 1>&6
exec 2>&7
set +x
set +v

if [ "$hadtocreatelogdir" ]
then echo "WARNING: had to create log dir at $logdir"
fi

cat <<EOF
container=$container
destroyoldcontainer=${destroyoldcontainer-}
ostarget=$ostarget
version=$version
gitcommit=${gitcommit-}
$logfilename
EOF
set -x
#pause before potentially drastic action
sleep 15
set -v
exec >& >(ts '%.s: ' >> "$logfile")

# need to check --running before lxc-stop or else an undeletable file gets created in ~/.local/ which interferes with lxc-create

if lxc-ls -1 | grep "^${container}\$"
then if [ "${destroyoldcontainer-}" = "1" ]
     then lxc-ls -1 --running | grep "^${container}\$" && lxc-stop -n $container || true
          lxc-destroy -n $container || true
     else echo "ERROR: LXC container '$container' exists.  Refusing to destroy it.  Set variable destroy=1 to destroy running container."
          exit 1
     fi
fi

# It looks like the "download" template can handle all kinds of new releases, e.g., s/trusty/bionic .
# See http://us.images.linuxcontainers.org/

# DOWNLOAD_KEYSERVER for /usr/share/lxc/templates/lxc-download
# but hkp://pool.sks-keyservers.net has gone down, as of approximately 2021-06

DOWNLOAD_KEYSERVER=hkp://keyserver.ubuntu.com lxc-create -n $container -o $logdir/lxc-create-$component-$datestring.log -t download ${lxccreateflags-} -- -d $lxcdistribution -r $lxcrelease -a amd64 ${lxctemplateflags-}
#lxccreateflags="-B btrfs"
#lxctemplateflags=--no-validate
#lxctemplateflags=--flush-cache
lxc-unpriv-start -n $container -o $logdir/lxc-start-$component-$datestring.log || \
lxc-start -n $container -o $logdir/lxc-start-$component-$datestring.log

function incontainer () {
    lxc-unpriv-attach -n $container -- env -i PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@" || \
    lxc-attach -n $container -- env -i PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"
}

function inlocal () {
    incontainer sudo -u $inner "$@"
}

function packages_install () {
    case $ostarget in
        centos8)
            incontainer dnf install -y $@
            ;;
        centos7)
            incontainer yum install -y $@
            ;;
        debian* | ubuntu* )
            # jackd2 pops up a dialog, which (silently) hangs unless we specify FRONTEND
            incontainer env DEBIAN_FRONTEND=noninteractive apt-get install -q --no-install-recommends -y -V $@
            ;;
        * )
            false "unknown ostarget"
            ;;
        esac
}


# debian11 bullseye comes up with /etc/resolv.conf pointing to a file in a non-existent directory /run/systemd/resolve/stub-resolv.conf .  after a few seconds, the directory comes to exist, but we do not want to use stub-resolv.conf because it cannot resolv local DNS aliases (local package mirror), so we change the symlink to systemd's resolv.conf file .

etcresolvconffile=/etc/resolv.conf
systemdresolvconfdir=/run/systemd/resolve
if incontainer [ -L "$etcresolvconffile" ]
then if [ $(incontainer readlink "$etcresolvconffile") = "$systemdresolvconfdir"/stub-resolv.conf ]
     then incontainer rm "$etcresolvconffile"
          incontainer ln -s "$systemdresolvconfdir"/resolv.conf "$etcresolvconffile"
          incontainer ls -l "$etcresolvconffile"
     fi
fi

# if networking does not come up we let the next failure abort the process
case $ostarget in
    debian* | ubuntu* )
        # use "approx" to set up a local debian package mirror
        if [ "${localsources-}" ]
        then incontainer cat /etc/apt/sources.list
             tar cf - -C "$localsources"/$ostarget -h sources.list | incontainer tar xf - -C /etc/apt
             incontainer cat /etc/apt/sources.list
        fi
        # weirdly still need this.  ping (in an older version of this script) succeeds but apt update fails.
        tempfile=$(mktemp)
        for i in $(seq 0 999)
        do incontainer apt-get update -q | tee $tempfile
           if ! grep '^Err' $tempfile
           then rm $tempfile
                # because output of apt-get update is echoed to logs, no need to keep this file
                break
           fi
           sleep 2
        done

        # apt-get (and apt) update returns success even if network failure
        ;;
esac

#setting UIDs to match the host does not work
incontainer useradd -m $inner

if [ -z "${noadditionalpackages-}" ]
then case $ostarget in
         debian* | ubuntu* )
             # avoid message "delaying package configuration, since apt-utils is not installed"
             packages_install apt-utils
             ;;
         centos7 )
             # keep trying because of occasional network unreliability
             for i in $(seq 0 999)
             do if packages_install epel-release
                then break
                fi
                incontainer ifup eth0  # might only be needed if host is bullseye
                sleep 2
             done
             ;;
         centos8)
             # use this loop for to wait for networking to come up
             for i in $(seq 0 999)
             do if packages_install dnf-plugins-core
                then break
                fi
                sleep 2
             done
             #dnf-plugins-core needed for "config-manager" command
             incontainer dnf config-manager --set-enabled powertools
             packages_install epel-release
             incontainer dnf repolist
             packages_install tar
             ;;
         *)
             ;;
     esac

     if [ "${containeronly-}" ]
     then true "exiting because containeronly"
          exit
     fi

     packages_install sudo

     # make it easier to extract the finished tarball, needed for Centos 7
     inlocal chmod a+rx /home/$inner
     inlocal env

     case $ostarget in
         debian* | ubuntu* )
             inlocal dpkg -l
             # how out of date is the downloaded lxc binary image?
             inlocal apt-get dist-upgrade -sV
             ;;
         centos*)
             inlocal rpm -qa
             ;;
     esac

     udir=/home/$inner/build
     inlocal mkdir -p $udir
     tar cf - -h guest.sh | inlocal tar xf - -C $udir

     cat <<EOF | inlocal tee -a $udir/vars.sh
ostarget=$ostarget
gitcommit=${gitcommit-}
EOF

     guestvariablesfile=guestvariables.sh
     if [ -e $guestvariablesfile ]
     then cat "$guestvariablesfile" | inlocal tee -a $udir/vars.sh
     fi

     inlocal env

     case $ostarget in
         debian* | ubuntu* )
             cat <<EOF | incontainer tee /etc/sudoers.d/iuser-internet
$inner ALL = NOPASSWD: /sbin/ip link set eth0 down, /sbin/ip link set eth0 up, /bin/systemctl restart networking
EOF
             ;;
         centos8)
             cat <<EOF | incontainer tee /etc/sudoers.d/iuser-internet
$inner ALL = NOPASSWD: /usr/sbin/ip link set eth0 down, /usr/sbin/ip link set eth0 up, /usr/bin/systemctl restart network
EOF
             ;;
         centos7)
             cat <<EOF | incontainer tee /etc/sudoers.d/iuser-internet
$inner ALL = NOPASSWD: /usr/sbin/ip link set eth0 down, /usr/sbin/ip link set eth0 up, /usr/sbin/ifup eth0 down, /usr/sbin/ifdown eth0
EOF
             ;;
esac
fi
incontainer chmod 0440 /etc/sudoers.d/iuser-internet
# packages are done in their own file because they get called again in part2
. packages.sh

# internet needed for ghcup
#incontainer ip link set eth0 down

case $ostarget in
    debian* | ubuntu* )
        inlocal dpkg -l
        ;;
    *)
        inlocal rpm -qa
        ;;
esac

## end of setup

if [ "${setuponly-}" ]
then true "exiting because setuponly"
     exit
fi

# assume communication is done with vars.sh
inlocal nice bash $udir/guest.sh

# make a zip file of the inst.tar.gz to match what Github actions do

tmpdir=$(mktemp -d)

insttargz=inst.tar.gz

inlocal tar cf - -C $udir "$insttargz" | tar xf - -C "$tmpdir"

# need to provide .zip extension because periods in $version cause .zip not to be automatically added.
zipname=$component-$version-$ostarget-$datestring.zip
pushd "$tmpdir"
zip "$zipname" "$insttargz"
popd

cp "$tmpdir"/"$zipname" "$zipdir"
rm -fr "$tmpdir"

date

true $0 all done $component-$datestring
