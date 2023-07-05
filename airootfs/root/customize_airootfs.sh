#!/bin/bash

set -e -u

echo "customize_airootfs.sh started..."

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
mkdir -p /etc/sysrescue/
ln -sf /run/archiso/config/sysrescue-effective-config.json /etc/sysrescue/sysrescue-effective-config.json

# Services
systemctl enable NetworkManager.service
systemctl enable iptables.service
systemctl enable ip6tables.service
systemctl enable choose-mirror.service
systemctl enable sshd.service
systemctl enable sysrescue-initialize-prenet.service
systemctl enable sysrescue-initialize-whilenet.service
systemctl enable sysrescue-autorun.service
systemctl enable qemu-guest-agent.service
systemctl enable var-lib-pacman\\x2drolling-local.mount
systemctl set-default multi-user.target

# Mask irrelevant timer units (#140)
systemctl mask atop-rotate.timer
systemctl mask shadow.timer
systemctl mask man-db.timer
systemctl mask updatedb.timer
systemctl mask archlinux-keyring-wkd-sync.timer

# ldconfig ("Rebuild Dynamic Linker Cache") unnecessarily slows down boot some time after the release
systemctl mask ldconfig.service

# systemd-gpt-auto-generator could automatically mount filesystems given the right config. Prevent that.
mkdir -p /etc/systemd/system-generators/
ln -sf /dev/null /etc/systemd/system-generators/systemd-gpt-auto-generator

# setup pacman signing key storage
/usr/bin/pacman-key --init
/usr/bin/pacman-key --populate
rm -f /etc/pacman.d/gnupg/*~

echo "" >>/etc/pacman.d/gnupg/gpg.conf
echo "# disable caching & trustdb regeneration to be able to use pacman with faketime in the pacman-faketime wrapper" >>/etc/pacman.d/gnupg/gpg.conf
echo "no-sig-cache" >>/etc/pacman.d/gnupg/gpg.conf
echo "no-auto-check-trustdb" >>/etc/pacman.d/gnupg/gpg.conf

# get a list of all packages from sysrescuerepo to exclude them from reinstall by yay-prepare
mkdir -p /usr/share/sysrescue/lib/
pacman -Sl sysrescuerepo | sed -e "s/^sysrescuerepo //" \
   | sed -e "s/\[installed.*\]//" >/usr/share/sysrescue/lib/yay-prepare-exclude

# Cleanup
# ATTENTION: adapt airootfs/usr/share/sysrescue/bin/yay-prepare when deleting anything that
# could be required for building packages
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
rm -f /usr/share/keepassxc/docs/*
rm -f /usr/share/qt6/translations/*
rm -f /usr/share/qt/translations/*

# Cleanup XFCE menu
sed -i '2 i NoDisplay=true' /usr/share/applications/{xfce4-mail-reader,xfce4-web-browser}.desktop
sed -i "s/^\(Categories=\).*\$/Categories=Utility;/" /usr/share/applications/{geany,*ristretto*,*GHex*}.desktop

# nm-applet with application indicator enabled gives better integration with xfce4-panel's systray
mkdir -p /root/.config/autostart/ /usr/local/share/applications/
sed 's/^Exec=nm-applet$/& --indicator/' /etc/xdg/autostart/nm-applet.desktop > /root/.config/autostart/nm-applet.desktop
sed 's/^Exec=nm-applet$/& --indicator/' /usr/share/applications/nm-applet.desktop > /usr/local/share/applications/nm-applet.desktop

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

# Trust archzfs key
pacman-key --init
pacman-key -r DDF7DB817396A49B2A2723F7403BD972F75D9D76
pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76

# Packages
pacman -Q > /root/packages-list.txt
expac -H M -s "%-30n %m" | sort -rhk 2 > /root/packages-size.txt
