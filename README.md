# SystemRescueCd

## Project website
Homepage: http://www.system-rescue-cd.org/

## Project sources
This git repository contains SystemRescueCd sources files. This is based on
https://git.archlinux.org/archiso.git

## Building SystemRescueCd
SystemRescueCd can be built for x86_64 or i686 architectures. It must be built
on archlinux (or archlinux32). The following packages must be installed on the
build system: archiso, grub, mtools. The archiso package must be modified to add
support for an option which allows to optimize the squashfs compression. The
patch can be found in the "patches" folder in this git repository.

The package list contains packages which are not part of the official binary
package repositories. These packages need to be built from sources from the AUR
website. These sources are made of at least a PKGBUILD file and quite often
other related files, such as patches. These can be built using the makepkg
command which generates binary packages. These binary packages must be copied to
a custom package repository which can be hosted locally using httpd or nginx.
The repo-add command must be used to generate the repository package index.
The pacman.conf file must be updated with the address of this repository so
custom packages can be accessed.

By default the target architecture will be x86_64. The following must be changed
in order to build a 32bit version instead:
* Update the ARCHITECTURE file (replace "x86_64" with "i686")
* Update Architecture in pacman.conf (replace "auto" with "i686")
* Replace archlinux repositories with archlinux32 repositories in pacman.conf

The build process can be started by running the build.sh script. It will create
a large "work" sub-directory and the ISO file will be written in the "out"
sub-directory.
