# SystemRescueCd+ZFS

**SystemRescueCd+ZFS** is a fork of the [SystemRescueCd](http://www.system-rescue-cd.org/) Linux distribution by [Francois Dupoux](https://gitlab.com/fdupoux) (based on [Arch Linux](https://www.archlinux.org) as of version 6.0) with improvements such as:

* [ZFS](https://github.com/archzfs/archzfs/) 0.8+ built-in
* [Serial console](#serial-console) enabled out of the box*
* Build improvements
* Extra polish

## Serial Console

Serial I/O is enabled by default on `COM1`/`ttyS0` at 115,200 baud. If your serial console is on another port or requires a different speed, make adjustments in the following places and [rebuild](#build) the image.

1. [GRUB](https://www.gnu.org/software/grub/manual/grub/grub.html) (**UEFI boot**): `serial --speed=115200 efi0` in `./efiboot/grub/grubsrcd.cfg`
2. [SYSLINUX](https://wiki.syslinux.org/wiki/index.php?title=SYSLINUX) (**BIOS boot**): `SERIAL 0 115200` in `./syslinux/sysresccd_head.cfg`
3. [Kernel](https://www.kernel.org/doc/html/latest/admin-guide/serial-console.html) (**post-boot**): `console=ttyS0,115200` in `./build.sh`

## Building

`./build.sh -v`

### Dependencies

[Arch Linux](https://www.archlinux.org) installation with the following packages:

* `arch-install-scripts`
* `archiso`
* `base-devel`
* `grub`
* `mtools`

### Rebuilds

The state of successfully completed [build steps](#steps) is persisted in `./work/build.make_*` files. If such a file is present for a given build step, `./build.sh` will skip that step indefinitely going forward. Before a rebuild, you must remove these state files to ensure that the appropriate build steps are re-executed and any customizations actually take effect.

* **Full rebuild (recommended):** `# rm ./work/build.make_*`
* **Partial rebuild:** Delete the state file for the **earliest** affected step and **all steps that come after it**. For example, if you have customized the GRUB (UEFI boot) configuration, you must remove `build.make_efi` and its successors `build.make_efiboot`, `build.make_prepare` and `build.make_iso`.

### Steps

1. `make_pacman_conf`
2. `make_basefs`
3. `make_packages`
4. `make_setup_mkinitcpio`
5. `make_customize_airootfs`
6. `make_boot`
7. `make_boot_extra`
8. `make_syslinux`
9. `make_isolinux`
10. `make_efi`
11. `make_efiboot`
12. `make_prepare`
13. `make_iso`
