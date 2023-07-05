# Overview

**SystemRescue+ZFS** is a fork of the [SystemRescue](http://www.system-rescue.org/) distribution (based on [Arch Linux](https://www.archlinux.org)) with the following improvements:

- [ZFS](https://github.com/archzfs/archzfs/) supported out of the box
- [Serial console](#serial-console) enabled for all boot options, including [Memtest86+](https://www.memtest.org/)
- EFI boot progress indicators for the kernel/initramfs/system stages
- Headers and done vs. skipped indicators for each build step
- Extra polish

# Serial console

A serial terminal is enabled out of the box on `ttyS0`/`COM1` at 115,200 baud. If these settings are unsuitable, adjust the configuration of the appropriate bootloader and the [kernel](https://www.kernel.org/doc/html/latest/admin-guide/serial-console.html), then [build](#building) a new image.

## Bootloader

| [GRUB](https://www.gnu.org/software/grub/manual/grub/grub.html) (EFI boot) | [SYSLINUX](https://wiki.syslinux.org/wiki/index.php?title=SYSLINUX) (legacy boot) |
| --- | --- |
| 📍 [`efiboot/grub/grubsrcd.cfg`](efiboot/grub/grubsrcd.cfg)<br/>`serial --unit=0 --speed=115200 …` | 📍 [`syslinux/sysresccd_head.cfg`](syslinux/sysresccd_head.cfg)<br/>`SERIAL 0 115200` |

## Kernel

📍 [`build.sh`](build.sh)<br/>`consoles='console=ttyS0,115200 …'`

# Building

```sh
$ sudo ./build.sh [-d] [-v]
```

- `-d`: Turn off compression, significantly speeding up development builds.
- `-v`: Print more information while building (strongly recommended).

## Dependencies

[Arch Linux](https://www.archlinux.org) with the following packages installed:
- `arch-install-scripts`
- `archiso` from the custom [SystemRescue repository](https://sysrescuerepo.system-rescue.org/) ⚠️
- `base-devel`
- `edk2-shell`
- `grub`
- `hugo`
- `isomd5sum`
- `mtools`

## Rebuilds

The state of successful [build steps](#steps) is persisted in `work/build.make_*` files. If such a file exists for a given build step, `build.sh` skips that step indefinitely. State files must be manually deleted for any steps that one wants reexecuted.

### Full rebuild

```sh
$ sudo rm work/build.make_*
```

### Partial rebuild

Delete the state file for the desired step **and any downstream steps**. For example, if you have customized the GRUB configuration, you must remove `build.make_efi` and its successors `build.make_efiboot` and `build.make_iso`.

## Steps

1. `make_pacman_conf`
2. `make_basefs`
3. `make_documentation`
4. `make_packages`
5. `make_customize_airootfs`
6. `make_setup_mkinitcpio`
7. `make_boot`
8. `make_boot_extra`
9. `make_syslinux`
10. `make_isolinux`
11. `make_efi`
12. `make_efiboot`
13. `make_prepare`
14. `make_imageinfo`
15. `make_iso`
