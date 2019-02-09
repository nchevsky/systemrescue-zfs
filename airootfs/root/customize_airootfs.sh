#!/bin/bash

set -e -u

sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

cp -aT /etc/skel/ /root/

# Permissions
chmod 700 /root
chown root:root /root -R
chmod 755 /etc/systemd/scripts/sysresccd-*
chown root:root /etc/systemd/scripts/sysresccd-*

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
systemctl enable pacman-init.service
systemctl enable choose-mirror.service
systemctl enable sshd.service
systemctl enable sysresccd-initialize.service
systemctl enable sysresccd-autorun.service
systemctl set-default multi-user.target

# Cleanup
find /usr/lib -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete

# Fix desktop
sed -i -e 's!Exec=notepadqq!Exec=notepadqq --allow-root!g' /usr/share/applications/notepadqq.desktop

# Customizations
/usr/bin/updatedb

# Packages
pacman -Qe > /root/packages-list.txt
pacman -Qi | egrep '^(Name|Installed)' | cut -f2 -d':' | paste - - | column -t | sort -nrk 2 | grep MiB > /root/packages-size.txt
