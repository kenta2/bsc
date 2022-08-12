Instructions
============

These scripts assemble the various built `inst.tar.gz` into release
tarballs.

Copy the zip files created by LXC, and artifacts produced by Github CI
to a directory, for example `/tmp/source`.

(Note: Github CI artifacts are visible in the Actions tab of the
repository.  You need to be logged in and have sufficient credentials
to see the artifacts.)

Then, run `10go.sh` with the release version number:
```
bash 10go.sh 2022.07 /tmp/source /tmp/outputdir
```

`/tmp/outputdir` must *not* already exist.
