These scripts build the compiler in preparation for release, for the
platforms not supported by GitHub Actions.

They use [Linux Containers](https://linuxcontainers.org/) to work in
sandboxes for various Linux distributions.  The scripts have been tested
on Debian 11 (Bullseye).

To build for all the Linux distributions, run `bash 00manyos.sh`.\
Look inside the script to see how to build for a specific
distribution.

To customize the build, copy and edit `hostvariables.sh` and
`guestvariables.sh`:
```
cp hostvariables.sh.sample hostvariables.sh
cp guestvariables.sh.sample guestvariables.sh
```
