# /sbin is not used on ArchLinux but it is often required in chroot
# also support chrooting on older systems without usrmerge (/usr/sbin and /bin)
export PATH=${PATH}:/sbin:/usr/sbin:/bin:/usr/share/sysrescue/bin/
