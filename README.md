# SystemRescue

## Project website
Homepage: https://www.system-rescue.org/

## Project sources
This git repository contains SystemRescue sources files. This is based on
https://gitlab.archlinux.org/archlinux/archiso/

## Building SystemRescue
SystemRescue can be built for x86_64 or i686 architectures. It must be built
on archlinux if you want to build a 64bit edition, or archlinux32 if you want
to create a 32bit edition. The following packages must be installed on the
build system: archiso, grub, isomd5sum, mtools, edk2-shell, hugo. 

You need to use a modified version of archiso for the build to work. This 
version is provided in the custom `sysrescuerepo` repository. See the 
`pacman.conf` file in the source. Either copy the `sysrescuerepo` section 
into your `/etc/pacman.conf` or replace the whole `/etc/pacman.conf` file with 
the one from the source. Install archiso afterwards.

The package list contains packages which are not part of the official binary
package repositories from Arch Linux. These packages are also provided in the
`sysrescuerepo` repository. If you want to rebuild them, see 
[systemrescue-custompkg](https://gitlab.com/systemrescue/systemrescue-custompkg).
Create a local repository out of them with `repo-add`, host it on a webserver
and then adapt pacman.conf.

The build process requires the systemrescue-website repository which is included
as git submodule. So when checking out this repository, make sure to check out
the submodule too. This can be done for example with
`git clone --recurse-submodules https://gitlab.com/systemrescue/systemrescue-sources.git`

The build process can be started by running the build.sh script. It will create
a large "work" sub-directory and the ISO file will be written in the "out"
sub-directory.

## Building SystemRescue with docker
If you are not running archlinux, you can run the build process in docker
containers. You need to have a Linux system running with docker installed
and configured. You can use the scripts provided in the `docker` folder of
this repository.

You must export the environment variable named `sysrescuearch` before you
run the two helper scripts. It should be set as either `x86_64` or `i686`
depending on the target architecture for which you want to build the ISO image.

After this, you need to run the script which builds a new docker image, and
then the script which uses this docker image to builds the ISO image. The second
script will pass the arguments it receives to the main `build.sh` script.

For example you can build a 64bit version of SystemRescue in docker using these commands:
```
export sysrescuearch="x86_64"
./docker/build-docker-image.sh
./docker/build-iso-image.sh -v
```

## Including your SystemRescueModules
If you want to include your own [SystemRescueModules][srm], place their srm files
in the [srm](./srm) directory of the repository before running the build script.

[srm]: https://www.system-rescue.org/Modules/
