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

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# PulseAudio takes care of volume restore
ln -sf /dev/null /etc/udev/rules.d/90-alsa-restore.rules

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
systemctl set-default multi-user.target

# Mask irrelevant timer units (#140)
systemctl mask atop-rotate.timer
systemctl mask shadow.timer
systemctl mask man-db.timer
systemctl mask updatedb.timer

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

# Cleanup XFCE menu
sed -i '2 i NoDisplay=true' /usr/share/applications/{exo-mail-reader,exo-web-browser,jmacs,jpico,jstar}.desktop
sed -i "s/^\(Categories=\).*\$/Categories=Utility;/" /usr/share/applications/{geany,joe,jmacs,jpico,jstar,ristretto,*GHex*}.desktop

# Remove large/irrelevant firmwares
rm -rf /usr/lib/firmware/{liquidio,netronome,mellanox,mrvl/prestera}

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

# Trust archzfs key
pacman-key --init
pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76

# Packages
pacman -Q > /root/packages-list.txt
expac -H M -s "%-30n %m" | sort -rhk 2 > /root/packages-size.txt

# Generate HTML version of the manual
markdown -o usr/share/sysrescue/index.html usr/share/sysrescue/index.md
