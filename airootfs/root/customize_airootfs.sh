#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

cp -aT /etc/skel/ /root/

rm -f /usr/lib/modules-load.d/pkcs8.conf

# Permissions
chmod 700 /root
chown root:root /root -R
chmod 755 /etc/systemd/scripts/*
chown root:root /etc/systemd -R
chown root:root /etc/modprobe.d -R
chown root:root /etc/{fstab,hostname}

# Configuration
sed -i 's/#\(PermitRootLogin \).\+/\1yes\nAllowUsers root/' /etc/ssh/sshd_config
sed -i 's/#\(PermitEmptyPasswords \).\+/\1no/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

# Services
systemctl enable NetworkManager
systemctl enable iptables.service
systemctl enable ip6tables.service
systemctl enable pacman-init.service
systemctl enable choose-mirror.service
systemctl enable sshd.service
systemctl enable sysresccd-initialize.service
systemctl enable sysresccd-autorun.service
systemctl set-default multi-user.target

# Provide additional commands (using busybox instead of binutils to save space)
ln -f -s /usr/bin/busybox /usr/bin/ar
ln -f -s /usr/bin/busybox /usr/bin/strings

# Cleanup
find /usr/lib -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
find /usr/lib -type f,l -name '*.a' -delete
rm -rf /usr/share/gtk-doc /usr/share/doc /usr/share/keepassxc/docs/*.pdf
rm -rf /usr/share/gir*
rm -rf /usr/include

# Remove large/irrelevant firmwares
rm -rf /usr/lib/firmware/{liquidio,netronome}

# Remove extra locales
if [ -x /usr/bin/localepurge ]
then
    echo -e "MANDELETE\nDONTBOTHERNEWLOCALE\nSHOWFREEDSPACE\nen\nen_US\nen_US.UTF-8" > /etc/locale.nopurge
    /usr/bin/localepurge
fi

# Update pacman.conf
sed -i -e '/# ==== BEGIN customrepos ====/,/# ==== END customrepos ====/d' /etc/pacman.conf

# Customizations
/usr/bin/updatedb

# Packages
pacman -Q > /root/packages-list.txt
pacman -Qi | egrep '^(Name|Installed)' | cut -f2 -d':' | paste - - | column -t | sort -nrk 2 | grep MiB > /root/packages-size.txt
