#!/bin/bash

set -e -u

script_path=$(readlink -f ${0%/*})
version_file="${script_path}/VERSION"

iso_name=systemrescue
iso_version="$(<${version_file})"
iso_mainver="${iso_version%-*}"
iso_label="RESCUE${iso_mainver//.}"
iso_publisher="SystemRescue <http://www.system-rescue.org>"
iso_application="SystemRescue"
install_dir=sysresccd
image_info_file="${install_dir}/.imageinfo"
work_dir=work
out_dir=out
gpg_key=
arch="$(uname -m)"
sfs_comp="xz"
sfs_opts="-Xbcj x86 -b 512k -Xdict-size 512k"
sfs_comp_devel="zstd"
sfs_opts_devel="-Xcompression-level 5"
devel_build=
snapshot_date=""
default_kernel_param="iomem=relaxed"
documentation_dir="/usr/share/sysrescue/html"
mkinitcpio_comp_algo="xz"
mkinitcpio_comp_opts="--threads=0 --verbose"
mkinitcpio_comp_algo_devel="zstd"
mkinitcpio_comp_opts_devel="--threads=0 --fast --verbose"

verbose=""

umask 0022

case ${arch} in
    x86_64)
        efiarch="x86_64-efi"
        efiboot="bootx64.efi"
        edk2arch="x64"
        mirrorlist_url='https://archlinux.org/mirrorlist/?country=all&protocol=http&use_mirror_status=on'
        archive_prefix='https://archive.archlinux.org/repos/'
        archive_mirrorlist_file='mirrorlist-snapshot-x86_64'
        mkinitcpio_comp_opts="--threads=0 --lzma2=preset=9e,dict=128MiB --verbose"
        ;;
    i686)
        efiarch="i386-efi"
        efiboot="bootia32.efi"
        edk2arch="ia32"
        mirrorlist_url='https://archlinux32.org/mirrorlist/?country=all&protocol=http&use_mirror_status=on'
        archive_prefix='https://archive.archlinux32.org/repos/'
        archive_mirrorlist_file='mirrorlist-snapshot-i686'
        mkinitcpio_comp_opts="--threads=0 --verbose"
        ;;
    *)
        echo "ERROR: Unsupported architecture: '${arch}'"
        exit 1
        ;;
esac

_usage ()
{
    echo "usage ${0} [options]"
    echo
    echo " General options:"
    echo "    -N <iso_name>      Set an iso filename (prefix)"
    echo "                        Default: ${iso_name}"
    echo "    -V <iso_version>   Set an iso version (in filename)"
    echo "                        Default: ${iso_version}"
    echo "    -L <iso_label>     Set an iso label (disk label)"
    echo "                        Default: ${iso_label}"
    echo "    -P <publisher>     Set a publisher for the disk"
    echo "                        Default: '${iso_publisher}'"
    echo "    -A <application>   Set an application name for the disk"
    echo "                        Default: '${iso_application}'"
    echo "    -D <install_dir>   Set an install_dir (directory inside iso)"
    echo "                        Default: ${install_dir}"
    echo "    -w <work_dir>      Set the working directory"
    echo "                        Default: ${work_dir}"
    echo "    -o <out_dir>       Set the output directory"
    echo "                        Default: ${out_dir}"
    echo "    -s <YYYY/MM/DD>    Set the snapshot date to use the repository from"
    echo "    -d                 Devel build: faster build time with low compression"
    echo "    -v                 Enable verbose output"
    echo "    -h                 This help message"
    exit ${1}
}

# Determine the latest repository snapshot available at the Arch Linux Archive
determine_snapshot_date() {
    # store the snapshot date in build.snapshot_date and read it out on later runs
    # so don't run this function with run_once
    if [[ -e ${work_dir}/build.snapshot_date ]]; then
        snapshot_date=`cat ${work_dir}/build.snapshot_date`
        return
    fi

    if [[ -z "$snapshot_date" ]]; then
        # while archive.archlinux.org offers lastsync files we could read out, archive.archlinux32.org doesn't
        # so use the current date (UTC), check if it's dir exists on the mirror, use the day before if not
        local now=`date +%s`
        local yesterday=$[$[now]-86400]
        local today_ymd=`date --utc "+%Y/%m/%d" --date="@${now}"`
        local yesterday_ymd=`date --utc "+%Y/%m/%d" --date="@${yesterday}"`

        if curl --silent --show-error --fail --max-time 15 -o /dev/null "${archive_prefix}${today_ymd}/"; then
            snapshot_date="${today_ymd}"
        else
            if curl --silent --show-error --fail --max-time 15 -o /dev/null "${archive_prefix}${yesterday_ymd}/"; then
                snapshot_date="${yesterday_ymd}"
            else
                echo "can't determine latest snapshot date available at the archive, specify one with -s"
                exit 1
            fi
        fi
    else
        # -s commandline option given
        if [[ ! "$snapshot_date" =~ ^[0-9]{4}/(0[1-9]|1[0-2])/(0[1-9]|[1-2][0-9]|3[0-1])$ ]]; then
            echo "illegal snapshot date, format must be YYYY/MM/DD"
            exit 1
        fi
        # we got a snapshot date that looks valid, use it without further network tests
    fi

    echo "$snapshot_date" >${work_dir}/build.snapshot_date
}


# Helper function to run make_*() only one time per architecture.
run_once() {
    if [[ ! -e ${work_dir}/build.${1} ]]; then
        $1
        touch ${work_dir}/build.${1}
    fi
}

# Setup custom pacman.conf with current cache directories, insert the snapshot date into the URLs
make_pacman_conf() {
    local _cache_dirs
    _cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g;
            s|^Architecture\s*=.*$|Architecture = ${arch}|;
            s|^Include =.*$|Include = ${work_dir}/mirrorlist|g" \
            ${script_path}/pacman.conf > ${work_dir}/pacman.conf

    sed "s|%SNAPSHOT_DATE%|${snapshot_date}|g;" \
        ${script_path}/${archive_mirrorlist_file} > ${work_dir}/mirrorlist
}

# Base installation: base metapackage + syslinux (airootfs)
make_basefs() {
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" init
}

# offline documentation
make_documentation() {
    if ! [ -f "website/config-offline.toml" ]; then
        echo "ERROR: website content missing. Did you forget to check out with git submodules?"
        exit 1
    fi

    # is the documentation up to date? ignore for beta and test versions
    if ! echo "${iso_version}" | grep -i -q "beta\|test" && \
       ! grep -q "${iso_version}" website/content/Changes-x86/_index.md; then
        echo "ERROR: current version not in changelog. Did you update the website submodule?"
        exit 1
    fi

    mkdir -p "${work_dir}/${arch}/airootfs/${documentation_dir}"

    # Delete the download page from the offline version as it makes no sense to keep it
    rm -rf website/content/Download

    # parameters are all relative to --source dir
    /usr/bin/hugo --source "website/" --config "config-offline.toml" --gc --verbose \
        --destination "../${work_dir}/${arch}/airootfs/${documentation_dir}"
    RET=$?

    if ! [ "$RET" -eq 0 ]; then
        echo "error generating offline documentation (returned $RET), aborting"
        exit 1
    fi

    # post-process hugo output and add index.hmtl to all directory links
    # required until https://github.com/gohugoio/hugo/issues/4428 is implemented
    find "${work_dir}/${arch}/airootfs/${documentation_dir}" -name "*.html" \
        -exec sed -i -e 's#<a href="\.\(.*\)/"#<a href=".\1/index.html"#g' \{} \;
}

# Additional packages (airootfs)
make_packages() {
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v '^#' ${script_path}/packages)" install
}

# Customize installation (airootfs)
make_customize_airootfs() {
    cp -af --no-preserve=ownership ${script_path}/airootfs ${work_dir}/${arch}

    cp ${script_path}/pacman.conf ${work_dir}/${arch}/airootfs/etc

    cp ${version_file} ${work_dir}/${arch}/airootfs/root/version

    sed "s|%ARCHISO_LABEL%|${iso_label}|g;
         s|%ISO_VERSION%|${iso_version}|g;
         s|%ISO_ARCH%|${arch}|g;
         s|%INSTALL_DIR%|${install_dir}|g" \
         ${script_path}/airootfs/etc/issue > ${work_dir}/${arch}/airootfs/etc/issue

    # delete the target file first because it is a symlink
    rm -f ${work_dir}/${arch}/airootfs/etc/os-release
    sed "s|%ARCHISO_LABEL%|${iso_label}|g;
         s|%ISO_VERSION%|${iso_version}|g;
         s|%ISO_ARCH%|${arch}|g;
         s|%INSTALL_DIR%|${install_dir}|g;
         s|%SNAPSHOT_DATE%|${snapshot_date//\//-}|g;" \
         ${script_path}/airootfs/etc/os-release > ${work_dir}/${arch}/airootfs/etc/os-release
    cp -f ${work_dir}/${arch}/airootfs/etc/os-release ${work_dir}/${arch}/airootfs/usr/lib/os-release

    curl -o ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist "$mirrorlist_url"

    sed "s|%SNAPSHOT_DATE%|${snapshot_date}|g;" \
        ${script_path}/${archive_mirrorlist_file} > ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist-snapshot

    mkdir -p ${work_dir}/${arch}/airootfs/var/lib/pacman-rolling/local

    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r '/root/customize_airootfs.sh' run

    if findmnt --mountpoint "${work_dir}/${arch}/airootfs/dev" >/dev/null 2>&1 ; then
        # unmount chroot /dev again, it was busy before due to gpg-agent
        umount "${work_dir}/${arch}/airootfs/dev"
    fi

    rm -f ${work_dir}/${arch}/airootfs/root/customize_airootfs.sh

    # change pacman config in airootfs to use snapshot repo by default
    # we can just do this after the mkarchiso run, it would flatten the symlink otherwise
    rm -f ${work_dir}/${arch}/airootfs/etc/pacman.conf
    ln -s pacman-snapshot.conf ${work_dir}/${arch}/airootfs/etc/pacman.conf

    # strip large binaries
    find ${work_dir}/${arch}/airootfs/usr/lib -type f -name "lib*.so.*" -exec strip --strip-all {} \;

    # recompress kernel modules to save space (#247)
    echo "Uncompressing kernel modules ..."
    kernelver=$(basename ${work_dir}/${arch}/airootfs/usr/lib/modules/*)
    find ${work_dir}/${arch}/airootfs/usr/lib/modules/${kernelver} -type f -name "*.ko.zst" -exec zstd -q -d --rm {} \;
    depmod --all --basedir=${work_dir}/${arch}/airootfs/usr ${kernelver}
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/install
    for _hook in archiso archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/install
    done
    cp /usr/lib/initcpio/install/archiso_kms ${work_dir}/${arch}/airootfs/etc/initcpio/install

    # when the "devel build" option is enabled, apply low but fast compression to reduce build time
    if [ -n "$devel_build" ]; then
        mkinitcpio_comp_algo="${mkinitcpio_comp_algo_devel}"
        mkinitcpio_comp_opts="${mkinitcpio_comp_opts_devel}"
    fi
    # configure the compression algorithm and options to use for the initramfs
    sed "s|^COMPRESSION=.*|COMPRESSION=\"${mkinitcpio_comp_algo}\"|g;
         s|^COMPRESSION_OPTIONS=.*|COMPRESSION_OPTIONS=\"${mkinitcpio_comp_opts}\"|g;" \
            ${script_path}/mkinitcpio.conf > ${work_dir}/${arch}/airootfs/etc/mkinitcpio-archiso.conf

    gnupg_fd=
    if [[ ${gpg_key} ]]; then
      gpg --export ${gpg_key} >${work_dir}/gpgkey
      exec 17<>${work_dir}/gpgkey
    fi

    ARCHISO_GNUPG_FD=${gpg_key:+17} setarch ${arch} mkarchiso ${verbose} -w "${work_dir}/${arch}" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux-lts -g /boot/sysresccd.img' run
    if [[ ${gpg_key} ]]; then
      exec 17<&-
    fi
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
    mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
    cp ${work_dir}/${arch}/airootfs/boot/sysresccd.img ${work_dir}/iso/${install_dir}/boot/${arch}/sysresccd.img
    chmod 644 ${work_dir}/iso/${install_dir}/boot/${arch}/sysresccd.img
    cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux-lts ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz
}

# Add other aditional/extra files to ${install_dir}/boot/
make_boot_extra() {
    cp ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.bin ${work_dir}/iso/${install_dir}/boot/memtest
    cp ${work_dir}/${arch}/airootfs/usr/share/licenses/common/GPL2/license.txt ${work_dir}/iso/${install_dir}/boot/memtest.COPYING
    cp ${work_dir}/${arch}/airootfs/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
    cp ${work_dir}/${arch}/airootfs/usr/share/licenses/intel-ucode/LICENSE ${work_dir}/iso/${install_dir}/boot/intel_ucode.LICENSE
    cp ${work_dir}/${arch}/airootfs/boot/amd-ucode.img ${work_dir}/iso/${install_dir}/boot/amd_ucode.img
    cp ${work_dir}/${arch}/airootfs/usr/share/licenses/amd-ucode/LICENSE* ${work_dir}/iso/${install_dir}/boot/amd_ucode.LICENSE
}

# Prepare /${install_dir}/boot/syslinux
make_syslinux() {
    _uname_r=$(file -b ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux-lts| awk 'f{print;f=0} /version/{f=1}' RS=' ')
    mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux
    for _cfg in ${script_path}/syslinux/*.cfg; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%ISO_VERSION%|${iso_version}|g;
             s|%ISO_ARCH%|${arch}|g;
             s|%DEFAULT_KERNEL_PARAM%|${default_kernel_param}|g;
             s|%INSTALL_DIR%|${install_dir}|g" ${_cfg} > ${work_dir}/iso/${install_dir}/boot/syslinux/${_cfg##*/}
    done
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/*.c32 ${work_dir}/iso/${install_dir}/boot/syslinux
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/lpxelinux.0 ${work_dir}/iso/${install_dir}/boot/syslinux
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/memdisk ${work_dir}/iso/${install_dir}/boot/syslinux
    mkdir -p ${work_dir}/iso/${install_dir}/boot/syslinux/hdt
    gzip -c -9 ${work_dir}/${arch}/airootfs/usr/share/hwdata/pci.ids > ${work_dir}/iso/${install_dir}/boot/syslinux/hdt/pciids.gz
    gzip -c -9 ${work_dir}/${arch}/airootfs/usr/lib/modules/${_uname_r}/modules.alias > ${work_dir}/iso/${install_dir}/boot/syslinux/hdt/modalias.gz
}

# Prepare /isolinux
make_isolinux() {
    mkdir -p ${work_dir}/iso/isolinux
    sed "s|%INSTALL_DIR%|${install_dir}|g" ${script_path}/isolinux/isolinux.cfg > ${work_dir}/iso/isolinux/isolinux.cfg
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isolinux.bin ${work_dir}/iso/isolinux/
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/isohdpfx.bin ${work_dir}/iso/isolinux/
    cp ${work_dir}/${arch}/airootfs/usr/lib/syslinux/bios/ldlinux.c32 ${work_dir}/iso/isolinux/
}

# Prepare /EFI
make_efi() {
    rm -rf ${work_dir}/iso/EFI
    rm -rf ${work_dir}/iso/boot
    mkdir -p ${work_dir}/iso/EFI/boot
    mkdir -p ${work_dir}/iso/boot/grub
    cp -a /usr/lib/grub/${efiarch} ${work_dir}/iso/boot/grub/
    cp ${script_path}/efiboot/grub/font.pf2 ${work_dir}/iso/boot/grub/
    sed "s|%ARCHISO_LABEL%|${iso_label}|g;
         s|%ISO_VERSION%|${iso_version}|g;
         s|%ISO_ARCH%|${arch}|g;
         s|%DEFAULT_KERNEL_PARAM%|${default_kernel_param}|g;
         s|%INSTALL_DIR%|${install_dir}|g" \
         ${script_path}/efiboot/grub/grubsrcd.cfg > ${work_dir}/iso/boot/grub/grubsrcd.cfg
    cp ${script_path}/efiboot/grub/loopback.cfg ${work_dir}/iso/boot/grub/
    cp ${script_path}/efiboot/grub/custom.cfg ${work_dir}/iso/boot/grub/
    cp -a /usr/share/edk2-shell/${edk2arch}/Shell_Full.efi ${work_dir}/iso/EFI/shell.efi
    cp ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.efi ${work_dir}/iso/EFI/memtest.efi
}

# Prepare efiboot.img::/EFI for "El Torito" EFI boot mode
make_efiboot() {

    rm -rf ${work_dir}/memdisk
    mkdir -p "${work_dir}/memdisk"
    mkdir -p "${work_dir}/memdisk/boot/grub"
    cp -a ${script_path}/efiboot/grub/grubinit.cfg "${work_dir}/memdisk/boot/grub/grub.cfg"
    tar -c -C "${work_dir}/memdisk" -f ${work_dir}/memdisk.img boot

    rm -rf ${work_dir}/efitemp
    mkdir -p ${work_dir}/efitemp/efi/boot

    grub-mkimage -m "${work_dir}/memdisk.img" -o "${work_dir}/iso/EFI/boot/${efiboot}" \
    	--prefix='(memdisk)/boot/grub' -d /usr/lib/grub/${efiarch} -C xz -O ${efiarch} \
    	search iso9660 configfile normal memdisk tar boot linux part_msdos part_gpt \
    	part_apple configfile help loadenv ls reboot chain search_fs_uuid multiboot \
    	fat iso9660 udf ext2 btrfs ntfs reiserfs xfs lvm ata

    cp -a "${work_dir}/iso/EFI/boot/${efiboot}" "${work_dir}/efitemp/efi/boot/${efiboot}"

    mkdir -p ${work_dir}/iso/EFI/archiso
    rm -f "${work_dir}/iso/EFI/archiso/efiboot.img"
    mkfs.fat -C "${work_dir}/iso/EFI/archiso/efiboot.img" 1440
    mcopy -s -i "${work_dir}/iso/EFI/archiso/efiboot.img" "${work_dir}/efitemp/efi" ::/
}

# Build airootfs filesystem image
make_prepare() {

    if [ -n "$devel_build" ]; then
        # devel build, low compression but fast build time
        sfs_comp="$sfs_comp_devel"
        sfs_opts="$sfs_opts_devel"
    fi

    cp -a -l -f ${work_dir}/${arch}/airootfs ${work_dir}
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" pkglist
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" ${gpg_key:+-g ${gpg_key}} -c ${sfs_comp} -t "${sfs_opts}" prepare
    rm -rf ${work_dir}/airootfs
    # rm -rf ${work_dir}/${arch}/airootfs (if low space, this helps)
}

# Create the .imageinfo file, used by systemrescue-usbwriter to check compatibility
make_imageinfo() {
    local syslinux_ver=$(grep -E "^syslinux " "${work_dir}/${arch}/airootfs/root/packages-list.txt" | sed -e "s#syslinux \(.*\)#\1#")

    echo "# SystemRescue imageinfo - used by systemrescue-usbwriter to check compatibility" >"${work_dir}/iso/${image_info_file}"
    echo "NAME=SystemRescue" >>"${work_dir}/iso/${image_info_file}"
    echo "VERSION=${iso_version}" >>"${work_dir}/iso/${image_info_file}"
    echo "ARCH=${arch}" >>"${work_dir}/iso/${image_info_file}"
    echo "SYSLINUX_VERSION=${syslinux_ver}" >>"${work_dir}/iso/${image_info_file}"
    echo "" >>"${work_dir}/iso/${image_info_file}"
    echo "# FORMAT_EPOCH can be used to explicitly declare incompatibility" >>"${work_dir}/iso/${image_info_file}"
    echo "FORMAT_EPOCH=1" >>"${work_dir}/iso/${image_info_file}"
}

# Build ISO
make_iso() {
    # Copy version file
    cp ${version_file} ${work_dir}/iso/${install_dir}/
    # Copy autorun folder
    test -d autorun && cp -r autorun ${work_dir}/iso/
    # Copy configuration files
    cp -r sysrescue.d/ ${work_dir}/iso/
    # Copy SRM modules
    (
        shopt -s nullglob
        rm -vf ${work_dir}/iso/${install_dir}/*.srm
        for srm in srm/*.srm; do
            cp -vf "$srm" ${work_dir}/iso/${install_dir}/
        done
    )
    # Create the ISO image
    setarch ${arch} mkarchiso ${verbose} -w "${work_dir}" -D "${install_dir}" -L "${iso_label}" -P "${iso_publisher}" -A "${iso_application}" -o "${out_dir}" iso "${iso_name}-${iso_version}-${arch/x86_64/amd64}.iso"

    # embed checksum
    implantisomd5 "${out_dir}/${iso_name}-${iso_version}-${arch/x86_64/amd64}.iso"
}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    _usage 1
fi

while getopts 'N:V:L:P:A:D:w:o:g:s:vdh' arg; do
    case "${arg}" in
        N) iso_name="${OPTARG}" ;;
        V) iso_version="${OPTARG}" ;;
        L) iso_label="${OPTARG}" ;;
        P) iso_publisher="${OPTARG}" ;;
        A) iso_application="${OPTARG}" ;;
        D) install_dir="${OPTARG}" ;;
        w) work_dir="${OPTARG}" ;;
        o) out_dir="${OPTARG}" ;;
        g) gpg_key="${OPTARG}" ;;
        s) snapshot_date="${OPTARG}" ;;
        v) verbose="-v" ;;
        d) devel_build="-d" ;;
        h) _usage 0 ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

mkdir -p ${work_dir}

determine_snapshot_date
run_once make_pacman_conf
run_once make_basefs
run_once make_documentation
run_once make_packages
run_once make_customize_airootfs
run_once make_setup_mkinitcpio
run_once make_boot
run_once make_boot_extra
run_once make_syslinux
run_once make_isolinux
run_once make_efi
run_once make_efiboot
run_once make_prepare
run_once make_imageinfo
run_once make_iso
