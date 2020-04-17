# SystemRescueCd offline manual

This page tells you more about the important programs which comes with this
system rescue distribution, and which tools can be used for common tasks. Please
use the **man** command in a termainal to get more details about these programs.

## Packages
As SystemRescueCd is based on ArchLinux you can use the **pacman** command to
install additional packages. The most common command is **pacman -Sy package**
if you want to install new packages.

## Storage and disk partitioning

* You can run **lsblk** and **blkid** in the terminal to identify block devices
* **GParted** is a graphical partition editor which displays, checks, resizes,
copies, moves, creates, formats, deletes, and modifies disk partitions.
* **GNU Parted** can also be used to manipulate partitions and it can be run
from the **parted** command in the terminal.
* **fsarchiver** and **partclone** allows you to save and restore the contents
of file systems to/from a compressed archive file. It needs to be run using the
command line from the terminal.
* You can use **fdisk** and **gdisk** to edit MBR and GPT partition tables from
the terminal
* **sfdisk** is a tool to save and restore partition tables to/from a file.
* You can use **growpart** in order to grow a partition so it uses all the space
available on the block storage. You normally need this command after you have
extended the disk of a virtual machine and need to make the additional space
usable.
* The **lvm** package provide all tools required to access linux logical volumes

## Network tools

* You can configure the network (ethernet or wifi) very easily using the
**Network-Manager** icon located next to the clock at the bottom of the screen.
* You can also configure the network using traditional Linux commands from a
terminal. The following commands are available: **nmcli**, **ifconfig**, **ip**,
**route**, **dhclient**.
* You can use **tcpdump** if you need to see network packets being transmitted.
* Both **netcat** and **udpcast** allow to transfer data via network connections.
* You can connect to VPNs using **OpenVPN**, **WireGuard**, and **openconnect**

## File system tools

* Tools for the most common linux file systems are included and allow you to
create new file systems, or administrate these (check consistency, repair,
reisize, ...). You can use **e2fsprogs**, **xfsprogs**, **btrfs-progs**, ...
* You can use **ntfs-3g** if you need to access NTFS file systems and
**dosfstools** if you need to work with FAT file systems.

## Web Browsers and Internet

* **Firefox** is available via an icon in the taskbar if you need to search for
additional information from internet while you are using SystemRescueCd.
* You can also use **elinks** from a terminal if you prefer a text mode browser
* Both **curl** and **wget** allow you to download files from the command line
* The **lftp** program can be run from a terminal if you need an FTP client

## Remote control

* You can run an **OpenSSH client** by using the **ssh** or **sftp** commands
from a terminal
* You can also connect from another machine to the **OpenSSH server** running
on SystemRescueCd via the **sshd** service. You will need to set a root password
and update firewall rules to be able to connect.
* You can run **Remmina** from the menu if you need to connect to another
machine via VNC or NX, and you can run **rdekstop** from a terminal in order to
connect to remote Windows machines over RDP.

## Security

* **GnuPG** is the most common command to perform encryption and decryption of
files. It can be executed via the **gpg** command from a terminal.
* **KeepassXC** is a very good tool for securely storing your passwords in a
file which is encrypted using a master password.
* The **cryptsetup** command is available if you need to access Linux encrypted
disks.

## Recovery tools

* **testdisk** is a popular disk recovery software. It recovers lost partitions
and repairs unbootable systems by repairing boot sectors. It can also be used to
recover deleted files from FAT, NTFS and ext4 filesystems.
* **photorec** is a data recovery software focused on lost files including
video, photos, documents and archives.
* **whdd** is another diagnostic and recovery tool for block devices

## Secure deletion

Both **wipe** and **nwipe** are available if you need to make sure data are
securelty deleted from a disk. Be careful as these tools are destructive.

## File managers

* **Midnight Commander** is a text based file manager that you can run from the
terminal using the **mc** command. It is very convenient to manipulate files
and folders.
* **Thunar** is a graphical file manager provided as part of the XFCE environment.

## Hardware information

* The **lspci** and **lsusb** commands are useful to list PCI and USB devices
connected your your system, and they can display the exact hardware IDs of these
devices that are used to find the right drivers.
* The **hwinfo** command can be run from the terminal and will display a detail
report about the hardware.

## Hardware testing

* You can run **memtest86** from the boot menu if you are booting in BIOS/Legacy
mode. This is not available if you are booting in UEFI mode.
* You can run the **memtester** command in a terminal if you want to test your
system memory. This command runs from the Linux system and hence is available if
you run in UEFI mode. Make sure you run the 64bit version if your computer has
more than 4GB of RAM so it can address all your memory.
* The **stress** commmand can be used from a terminal in order to stress tests
your system (CPU, memory, I/O, disks)

## Boot loader and UEFI

* The **Grub** bootloader programs can be used if you need to repair the boot
loader of your Linux distribution.
* You will need **efibootmgr** if you want to change the definitions or the
order of the UEFI boot entries on your computer.

## Text editors

* You can use graphical text editors such as **featherpad** and **geany**
* You can use text editors such as **vim**, **nano** and **joe** from the
terminal

## Archival and file transfer

* The **tar** command is often used to create and extract unix file archives
from the command line.
* The system comes with all the common compression programs such as **gzip**,
**xz**, **zstd**, **lz4**, **bzip2**
* You can also use the **zip** and **unzip** commands for manipulate ZIP archives
* Also **p7zip** is available using the **7z** command in the terminal if you
need to work with 7zip files.
* The **rsync** utility is very powerful for copying files either locally or
remotely over an SSH connection. You can also use **grsync** if you prefer a
graphical interface.

## CD/DVD utilities

* You can use CD/DVD command line utilities such as **growisofs**, **cdrecord**
and **mkisofs** if you need to work with ISO images and need to burn CD/DVD
medias from the system. Also **udftools** are available to manipulate UDF
filesystems.

## Scripting languages

* You can use **bash** for running scripts as well as **Perl**, **Python** and
**Ruby** dynamic languages which are all available.

## Miscellanous

* **flashrom** is an utility for reading, writing, erasing and verifying flash ROM chips
* **nvme** is a tool for manipulating NVM-Express disks.
