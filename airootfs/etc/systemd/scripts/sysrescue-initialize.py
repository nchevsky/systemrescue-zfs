#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later

import subprocess
import yaml
import glob
import os
import sys
import re

# ==============================================================================
# Initialization
# ==============================================================================
print(f"====> Script {sys.argv[0]} starting ...")
errcnt = 0

# ==============================================================================
# Define the default configuration
# ==============================================================================
config_global = {
    'dostartx': False,
    'dovnc': False,
    'noautologin': False,
    'nofirewall': False,
    'rootshell': None,
    'rootpass': None,
    'rootcryptpass': None,
    'setkmap': None,
    'vncpass': None,
}

# ==============================================================================
# Load configuration from the yaml files
# ==============================================================================
print(f"====> Loading configuration from yaml files located on the boot device ...")
yamlconfdirs = ["/run/archiso/bootmnt/config.d", "/run/archiso/copytoram/config.d"]

def parse_config_file(yamlfile):
    print(f"Parsing yaml file: {yamlfile} ...")
    with open(yamlfile) as myfile:
        try:
            curconfig = yaml.safe_load(myfile)
            if 'global' in curconfig:
                curglobal = curconfig['global']
                for entry in config_global:
                    if entry in curglobal:
                        config_global[entry] = curglobal[entry]
            return True
        except yaml.YAMLError as err:
            print(err)
            errcnt+=1
            return False

for yamlconfdir in yamlconfdirs:
    if os.path.isdir(yamlconfdir):
        conffiles = glob.glob(os.path.join(yamlconfdir, '*.[Yy][Aa][Mm][Ll]'), recursive=True)
        conffiles.sort() # Load yaml files in the alphabetical order
        for curfile in conffiles:
            parse_config_file(curfile)

# ==============================================================================
# Load configuration from the boot command line
# ==============================================================================
print(f"====> Parsing configuration from the boot command line ...")

bootcmdline = open("/proc/cmdline","r").readline()
bootopts = bootcmdline.split()

for curopt in bootopts:

    # Configure keyboard layout
    match = re.search(r"^setkmap=(\S+)$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['setkmap'] = match.group(1)

    # Configure root login shell
    match = re.search(r"^rootshell=(\S+)$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['rootshell'] = match.group(1)

    # Set the system root password from a clear password
    match = re.search(r"^rootpass=(\S+)$", curopt)
    if match != None:
        print(f"Found option 'rootpass=******' on the boot command line")
        config_global['rootpass'] = match.group(1)

    # Set the system root password from an encrypted password
    match = re.search(r"^rootcryptpass=(\S+)$", curopt)
    if match != None:
        print(f"Found option 'rootcryptpass=******' on the boot command line")
        config_global['rootcryptpass'] = match.group(1)

    # Disable the firewall
    match = re.search(r"^nofirewall$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['nofirewall'] = True

    # Auto-start the graphical environment (tty1 only), dovnc implies dostartx
    match = re.search(r"^dostartx$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['dostartx'] = True

    # Require authenticated console access
    match = re.search(r"^noautologin$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['noautologin'] = True

    # Set the VNC password from a clear password
    match = re.search(r"^vncpass=(\S+)$", curopt)
    if match != None:
        print(f"Found option 'vncpass=******' on the boot command line")
        config_global['vncpass'] = match.group(1)

    # Auto-start x11vnc with the graphical environment, "dovnc" implies "dostartx"
    match = re.search(r"^dovnc$", curopt)
    if match != None:
        print(f"Found option '{curopt}' on the boot command line")
        config_global['dovnc'] = True
        config_global['dostartx'] = True

# ==============================================================================
# Show the effective configuration
# ==============================================================================
print(f"====> Showing the effective global configuration (except clear passwords) ...")
print(f"config['setkmap']={config_global['setkmap']}")
print(f"config['rootshell']={config_global['rootshell']}")
print(f"config['rootcryptpass']={config_global['rootcryptpass']}")
print(f"config['nofirewall']={config_global['nofirewall']}")
print(f"config['dostartx']={config_global['dostartx']}")
print(f"config['noautologin']={config_global['noautologin']}")
print(f"config['dovnc']={config_global['dovnc']}")

# ==============================================================================
# Apply the effective configuration
# ==============================================================================
print(f"====> Applying configuration ...")

# Configure keyboard layout if requested in the configuration
if config_global['setkmap'] != None:
    p = subprocess.run(["localectl", "set-keymap", config_global['setkmap']], text=True)
    if p.returncode == 0:
        print (f"Have changed the keymap successfully")
    else:
        print (f"Failed to change keymap")
        errcnt+=1

# Configure root login shell if requested in the configuration
if config_global['rootshell'] != None:
    p = subprocess.run(["chsh", "--shell", config_global['rootshell'], "root"], text=True)
    if p.returncode == 0:
        print (f"Have changed the root shell successfully")
    else:
        print (f"Failed to change the root shell")
        errcnt+=1

# Set the system root password from a clear password
if config_global['rootpass'] != None:
    p = subprocess.run(["chpasswd", "--crypt-method", "SHA512"], text=True, input=f"root:{config_global['rootpass']}")
    if p.returncode == 0:
        print (f"Have changed the root password successfully")
    else:
        print (f"Failed to change the root password")
        errcnt+=1

# Set the system root password from an encrypted password
# A password can be encrypted using a one-line python3 command such as:
# python3 -c 'import crypt; print(crypt.crypt("MyPassWord123", crypt.mksalt(crypt.METHOD_SHA512)))'
if config_global['rootcryptpass'] != None:
    p = subprocess.run(["chpasswd", "--encrypted"], text=True, input=f"root:{config_global['rootcryptpass']}")
    if p.returncode == 0:
        print (f"Have changed the root password successfully")
    else:
        print (f"Failed to change the root password")
        errcnt+=1

# Disable the firewall
if config_global['nofirewall'] == True:
    # The firewall service(s) must be in the Before-section of sysrescue-initialize.service
    p = subprocess.run(["systemctl", "disable", "--now", "iptables.service", "ip6tables.service"], text=True)
    if p.returncode == 0:
        print (f"Have disabled the firewall successfully")
    else:
        print (f"Failed to disable the firewall")
        errcnt+=1

# Auto-start the graphical environment (tty1 only)
if config_global['dostartx'] == True:
    str = '[[ ! $DISPLAY ]] && [[ ! $SSH_TTY ]] && [[ $XDG_VTNR == 1 ]] && startx'
    if (os.path.exists("/root/.bash_profile") == False) or (open("/root/.bash_profile", 'r').read().find(str) == -1):
        file1 = open("/root/.bash_profile", "a")
        file1.write(f"{str}\n")
        file1.close()
    file2 = open("/root/.zlogin", "w")
    file2.write(f"{str}\n")
    file2.close()

# Require authenticated console access
if config_global['noautologin'] == True:
    p = subprocess.run(["systemctl", "revert", "getty@.service", "serial-getty@.service"], text=True)
    if p.returncode == 0:
        print (f"Have enabled authenticated console access successfully")
    else:
        print (f"Failed to enable authenticated console access")
        errcnt+=1

# Set the VNC password from a clear password
if config_global['vncpass'] != None:
    os.makedirs("/root/.vnc", exist_ok = True)
    p = subprocess.run(["x11vnc", "-storepasswd", config_global['vncpass'], "/root/.vnc/passwd"], text=True)
    if p.returncode == 0:
        print (f"Have changed the vnc password successfully")
    else:
        print (f"Failed to change the vnc password")
        errcnt+=1

# Auto-start x11vnc with the graphical environment
if config_global['dovnc'] == True:
    print (f"Enabling VNC Server in /root/.xprofile ...")
    file = open("/root/.xprofile", "w")
    file.write("""[ -f ~/.vnc/passwd ] && pwopt="-usepw" || pwopt="-nopw"\n""")
    file.write("""x11vnc $pwopt -nevershared -forever -logfile /var/log/x11vnc.log &\n""")
    file.close()

# ==============================================================================
# End of the script
# ==============================================================================
print(f"====> Script {sys.argv[0]} completed with {errcnt} errors ...")
sys.exit(errcnt)
