#! /usr/bin/env python3
import subprocess
import os
import sys
import re

print(f"Script {sys.argv[0]} starting ...")
errcnt = 0

bootcmdline = open("/proc/cmdline","r").readline()
bootopts = bootcmdline.split()

for curopt in bootopts:

    # Configure keyboard layout if requested in the boot command line
    match = re.search(r"^setkmap=(\S+)$", curopt)
    if match != None:
        curval = match.group(1)
        print(f"=> Found option '{curopt}' on the boot command line")
        p = subprocess.run(["localectl", "set-keymap", curval], text=True)
        if p.returncode == 0:
            print (f"Have changed the keymap successfully")
        else:
            print (f"Failed to change keymap")
            errcnt+=1

    # Configure root login shell if requested in the boot command line
    match = re.search(r"^rootshell=(\S+)$", curopt)
    if match != None:
        curval = match.group(1)
        print(f"=> Found option '{curopt}' on the boot command line")
        p = subprocess.run(["chsh", "--shell", curval, "root"], text=True)
        if p.returncode == 0:
            print (f"Have changed the root shell successfully")
        else:
            print (f"Failed to change the root shell")
            errcnt+=1

    # Set the system root password from a clear password
    match = re.search(r"^rootpass=(\S+)$", curopt)
    if match != None:
        curval = match.group(1)
        print(f"=> Found option 'rootpass=******' on the boot command line")
        p = subprocess.run(["chpasswd", "--crypt-method", "SHA512"], text=True, input=f"root:{curval}")
        if p.returncode == 0:
            print (f"Have changed the root password successfully")
        else:
            print (f"Failed to change the root password")
            errcnt+=1

    # Set the system root password from an encrypted password
    # A password can be encrypted using a one-line python3 command such as:
    # python3 -c 'import crypt; print(crypt.crypt("MyPassWord123", crypt.mksalt(crypt.METHOD_SHA512)))'
    match = re.search(r"^rootcryptpass=(\S+)$", curopt)
    if match != None:
        curval = match.group(1)
        print(f"=> Found option 'rootcryptpass=******' on the boot command line")
        p = subprocess.run(["chpasswd", "--encrypted"], text=True, input=f"root:{curval}")
        if p.returncode == 0:
            print (f"Have changed the root password successfully")
        else:
            print (f"Failed to change the root password")
            errcnt+=1

    # Disable the firewall
    match = re.search(r"^nofirewall$", curopt)
    if match != None:
        print(f"=> Found option 'nofirewall' on the boot command line")
        # The firewall service(s) must be in the Before-section of sysrescue-initialize.service
        p = subprocess.run(["systemctl", "disable", "--now", "iptables.service", "ip6tables.service"], text=True)
        if p.returncode == 0:
            print (f"Have disabled the firewall successfully")
        else:
            print (f"Failed to disable the firewall")
            errcnt+=1

    # Auto-start the graphical environment (tty1 only), dovnc implies dostartx
    match = re.search(r"^dostartx|dovnc$", curopt)
    if match != None:
        print(f"=> Found option '{match.group(0)}' on the boot command line")
        str = '[[ ! $DISPLAY ]] && [[ ! $SSH_TTY ]] && [[ $XDG_VTNR == 1 ]] && startx'
        if (os.path.exists("/root/.bash_profile") == False) or (open("/root/.bash_profile", 'r').read().find(str) == -1):
            file1 = open("/root/.bash_profile", "a")
            file1.write(f"{str}\n")
            file1.close()
        file2 = open("/root/.zlogin", "w")
        file2.write(f"{str}\n")
        file2.close()

    # Require authenticated console access
    match = re.search(r"^noautologin$", curopt)
    if match != None:
        print(f"=> Found option '{match.group(0)}' on the boot command line")
        p = subprocess.run(["systemctl", "revert", "getty@.service", "serial-getty@.service"], text=True)
        if p.returncode == 0:
            print (f"Have enabled authenticated console access successfully")
        else:
            print (f"Failed to enable authenticated console access")
            errcnt+=1

    # Set the VNC password from a clear password
    match = re.search(r"^vncpass=(\S+)$", curopt)
    if match != None:
        curval = match.group(1)
        print(f"=> Found option 'vncpass=******' on the boot command line")
        os.makedirs("/root/.vnc", exist_ok = True)
        p = subprocess.run(["x11vnc", "-storepasswd", curval, "/root/.vnc/passwd"], text=True)
        if p.returncode == 0:
            print (f"Have changed the vnc password successfully")
        else:
            print (f"Failed to change the vnc password")
            errcnt+=1

    # Auto-start x11vnc with the graphical environment
    match = re.search(r"^dovnc$", curopt)
    if match != None:
        # No need to print "Found option 'dovnc' on the boot command line" a second time
        file = open("/root/.xprofile", "w")
        file.write("""[ -f ~/.vnc/passwd ] && pwopt="-usepw" || pwopt="-nopw"\n""")
        file.write("""x11vnc $pwopt -nevershared -forever -logfile /var/log/x11vnc.log &\n""")
        file.close()

sys.exit(errcnt)
