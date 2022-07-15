#  Please ensure the following distro packages are installed before continuing (you can exit ghcup and return at any time):

# I cannot figure out how or where ghcup calculates what packages are necessary.  https://gitlab.haskell.org/haskell/ghcup-hs/-/blob/master/lib/GHCup/Requirements.hs

# BOOTSTRAP_HASKELL_VERBOSE=1 bash ~/ghcup/install.sh
# [ Debug ] Identified Platform as: Linux Debian, 10
# [ Info  ] downloading: https://raw.githubusercontent.com/haskell/ghcup-metadata/master/ghcup-0.0.7.yaml as file /home/iuser/.ghcup/cache/ghcup-0.0.7.yaml
# see the variable ghcupURL in https://gitlab.haskell.org/haskell/ghcup-hs/-/blob/master/lib/GHCup/Version.hs
# https://github.com/haskell/ghcup-metadata

# packages with the same name of Debian, Ubuntu, and Centos
packages_install $(awk '/^#/{next}{print$1}' <<EOF
git - because we git clone inside
gperf - yices
autoconf - yices
flex - stp
bison - stp
EOF
    )

case $ostarget in
    debian* | ubuntu* )
packages_install $(awk '/^#/{next}{print$1}' <<EOF
build-essential - needed by ghcup according to documentation
curl - needed by ghcup according to documentation
libffi-dev - needed by ghcup according to documentation
#libffi6 - needed by ghcup according to documentation (but seems not because preinstalled in lxc image, and is a dependency)
libgmp-dev - needed by ghcup according to documentation
#libgmp10 - needed by ghcup according to documentation (but seems not because preinstalled in lxc image)
libncurses-dev - needed by ghcup according to documentation
#libncurses5 - needed by ghcup according to documentation, might actually be needed because libncurses6 installed by default
libtinfo5 - needed by ghcup according to documentation
ca-certificates - needed for curl to work
tcl-dev - bluetcl, presumably
EOF
)
;;
    centos*)
packages_install $(awk '/^#/{next}{print$1}' <<EOF
gcc - needed by ghcup according to documentation
# also consider devtoolset-11 for a newer gcc
gmp-devel - needed by ghcup according to documentation
make - needed by ghcup according to documentation
ncurses - needed by ghcup according to documentation
xz - needed by ghcup according to documentation
perl - needed by ghcup according to documentation
gcc-c++ - presumably for yices or stp
tcl-devel - bluetcl-presumably
EOF
)
;;
esac

case $ostarget in
    centos7)
packages_install $(awk '/^#/{next}{print$1}' <<EOF
ncurses - needed by ghcup according to documentation
zlib-devel - stp (centos8 installs this automatically as a dependency)
which - htcl
EOF
    )
;;

centos8)
packages_install $(awk '/^#/{next}{print$1}' <<EOF
ncurses-compat-libs - needed by ghcup according to documentation
EOF
    )
;;
esac
