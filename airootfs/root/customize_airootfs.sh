#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

cp -aT /etc/skel/ /root/

# Permissions
chmod 750 /root
chmod 755 /etc/systemd/scripts/*

# Configuration
sed -i 's/#\(PermitRootLogin \).\+/\1yes\nAllowUsers root/' /etc/ssh/sshd_config
sed -i 's/#\(PermitEmptyPasswords \).\+/\1no/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf
sed -i 's/#\(Audit=\)yes/\1no/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# PulseAudio takes care of volume restore
ln -sf /dev/null /etc/udev/rules.d/90-alsa-restore.rules

# config symlink
mkdir /etc/sysrescue/
ln -sf /run/archiso/config/sysrescue-effective-config.json /etc/sysrescue/sysrescue-effective-config.json

# Services
systemctl enable NetworkManager.service
systemctl enable iptables.service
systemctl enable ip6tables.service
systemctl enable pacman-init.service
systemctl enable choose-mirror.service
systemctl enable sshd.service
systemctl enable sysrescue-initialize.service
systemctl enable sysrescue-autorun.service
systemctl enable qemu-guest-agent.service
systemctl enable var-lib-pacman\\x2drolling-local.mount
systemctl set-default multi-user.target

# Mask irrelevant timer units (#140)
systemctl mask atop-rotate.timer
systemctl mask shadow.timer
systemctl mask man-db.timer
systemctl mask updatedb.timer

# ldconfig ("Rebuild Dynamic Linker Cache") unnecessarily slows down boot some time after the release
systemctl mask ldconfig.service

# Provide additional commands (using busybox instead of binutils to save space)
ln -sf /usr/bin/busybox /usr/local/bin/ar
ln -sf /usr/bin/busybox /usr/local/bin/strings

# Cleanup
find /usr/lib -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
find /usr/lib -type f,l -name '*.a' -delete
rm -rf /usr/lib/{libgo.*,libgphobos.*,libgfortran.*}
rm -rf /usr/share/gtk-doc /usr/share/doc /usr/share/keepassxc/docs/*.pdf
rm -rf /usr/share/keepassxc/translations
rm -rf /usr/share/help/*/ghex/
rm -rf /usr/share/gir*
rm -rf /usr/include
rm -rf /usr/share/man/man3

# save some more space by removing large & unnecessary files
rm -f /lib/modules/*/vmlinuz
rm -f /usr/share/grub/themes/starfield/starfield.png

# Cleanup XFCE menu
sed -i '2 i NoDisplay=true' /usr/share/applications/{xfce4-mail-reader,xfce4-web-browser}.desktop
sed -i "s/^\(Categories=\).*\$/Categories=Utility;/" /usr/share/applications/{geany,*ristretto*,*GHex*}.desktop

# Remove large/irrelevant firmwares
rm -rf /usr/lib/firmware/{liquidio,netronome,mellanox,mrvl/prestera,qcom}

# Remove extra locales
if [ -x /usr/bin/localepurge ]
then
    echo -e "MANDELETE\nDONTBOTHERNEWLOCALE\nSHOWFREEDSPACE\nen\nen_US\nen_US.UTF-8" > /etc/locale.nopurge
    /usr/bin/localepurge
fi

# Update pacman.conf
sed -i -e '/# ==== BEGIN sysrescuerepo ====/,/# ==== END sysrescuerepo ====/d' /etc/pacman.conf

# Check for issues with binaries
/usr/bin/check-binaries.sh

# Customizations
/usr/bin/updatedb

# Packages
pacman -Q > /root/packages-list.txt
expac -H M -s "%-30n %m" | sort -rhk 2 > /root/packages-size.txt
