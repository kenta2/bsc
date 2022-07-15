#!/bin/bash
set -x
set -v
set -e
set -o pipefail
set -u


date
echo $PATH
pwd
echo $0
mydirectory=$(dirname $0)
cd $mydirectory

. vars.sh


curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org > ghcupinstall.sh

cat ghcupinstall.sh

BOOTSTRAP_HASKELL_VERBOSE=1 BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 bash ghcupinstall.sh

. ~/.ghcup/env

# these command should be kept in sync with .github/workflows/build.yml

ghcversion=9.0.1

ghcup install ghc $ghcversion
ghcup set ghc $ghcversion

ghcup install cabal
cabal update

if [ -z "${cabalgofast-}" ]
# single-threaded for better logs
then perl -plwi.orig -e 'if(/^\s*jobs:/){$_="jobs: 1"}' ~/.cabal/config
fi

cabal v1-install old-time regex-compat split syb

if [ "$ostarget" = centos7 ]
then gitclonejobs=
     # centos 7 git does not support -j flag
else gitclonejobs="-j 1"
fi
git clone $gitclonejobs --recurse https://github.com/B-Lang-org/bsc

sudo ip link set eth0 down

pushd bsc
if ! [ -z "${gitcommit-}" ]
then git checkout "$gitcommit"
     git submodule update --recursive
fi

git log -1

# also consider building BSC_BUILD=PROF and BSC_BUILD=DEBUG
# BSC_BUILD=DEBUG is known to fail for debian10 and debian11

parallelmake=${parallelmake-1}
# GHCRTSFLAGS might not be necessary
make -j$parallelmake GHCJOBS=$parallelmake GHCRTSFLAGS='+RTS -M5G -A128m -RTS' install-src
tar czf ../inst.tar.gz inst
popd

true $0 all done
