#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later

import subprocess
import json
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
# Read the effective configuration file
# ==============================================================================
print(f"====> Read the effective configuration file ...")
effectivecfg = "/run/archiso/config/sysrescue-effective-config.json"
if os.path.exists(effectivecfg) == False:
    print (f"Failed to find effective configuration file in {effectivecfg}")
    sys.exit(1)

with open(effectivecfg) as file:
    config = json.load(file)

# ==============================================================================
# Sanitize config, initialize variables
# Make sysrescue-initialize work safely without them being defined
# Also show the effective configuration
# ==============================================================================
print(f"====> Showing the effective global configuration (except clear passwords) ...")

def read_cfg_value(scope, name, printval):
    if not scope in config:
        val = None
    elif name in config[scope]:
        val = config[scope][name]
    else:
        val = None

    if printval:
        print(f"config['{scope}']['{name}']={val}")
    
    return val

setkmap = read_cfg_value('global','setkmap', True)
rootshell = read_cfg_value('global','rootshell', True)
rootpass = read_cfg_value('global','rootpass', False)
rootcryptpass = read_cfg_value('global','rootcryptpass', False)
nofirewall = read_cfg_value('global','nofirewall', True)
noautologin = read_cfg_value('global','noautologin', True)
dostartx = read_cfg_value('global','dostartx', True)
dovnc = read_cfg_value('global','dovnc', True)
vncpass = read_cfg_value('global','vncpass', False)
late_load_srm = read_cfg_value('global','late_load_srm', True)

# ==============================================================================
# Apply the effective configuration
# ==============================================================================
print(f"====> Applying configuration ...")

# Configure keyboard layout if requested in the configuration
if (setkmap != None) and (setkmap != ""):
    p = subprocess.run(["localectl", "set-keymap", setkmap], text=True)
    if p.returncode == 0:
        print (f"Have changed the keymap successfully")
    else:
        print (f"Failed to change keymap")
        errcnt+=1

# Configure root login shell if requested in the configuration
if (rootshell != None) and (rootshell != ""):
    p = subprocess.run(["chsh", "--shell", rootshell, "root"], text=True)
    if p.returncode == 0:
        print (f"Have changed the root shell successfully")
    else:
        print (f"Failed to change the root shell")
        errcnt+=1

# Set the system root password from a clear password
if (rootpass != None) and (rootpass != ""):
    p = subprocess.run(["chpasswd", "--crypt-method", "SHA512"], text=True, input=f"root:{rootpass}")
    if p.returncode == 0:
        print (f"Have changed the root password successfully")
    else:
        print (f"Failed to change the root password")
        errcnt+=1

# Set the system root password from an encrypted password
# A password can be encrypted using a one-line python3 command such as:
# python3 -c 'import crypt; print(crypt.crypt("MyPassWord123", crypt.mksalt(crypt.METHOD_SHA512)))'
if (rootcryptpass != None) and (rootcryptpass != ""):
    p = subprocess.run(["chpasswd", "--encrypted"], text=True, input=f"root:{rootcryptpass}")
    if p.returncode == 0:
        print (f"Have changed the root password successfully")
    else:
        print (f"Failed to change the root password")
        errcnt+=1

# Disable the firewall
if nofirewall == True:
    # The firewall service(s) must be in the Before-section of sysrescue-initialize.service
    p = subprocess.run(["systemctl", "disable", "--now", "iptables.service", "ip6tables.service"], text=True)
    if p.returncode == 0:
        print (f"Have disabled the firewall successfully")
    else:
        print (f"Failed to disable the firewall")
        errcnt+=1

# Auto-start the graphical environment (tty1 only)
if dostartx == True:
    str = '[[ ! $DISPLAY ]] && [[ ! $SSH_TTY ]] && [[ $XDG_VTNR == 1 ]] && startx'
    if (os.path.exists("/root/.bash_profile") == False) or (open("/root/.bash_profile", 'r').read().find(str) == -1):
        file1 = open("/root/.bash_profile", "a")
        file1.write(f"{str}\n")
        file1.close()
    file2 = open("/root/.zlogin", "w")
    file2.write(f"{str}\n")
    file2.close()

# Require authenticated console access
if noautologin == True:
    p = subprocess.run(["systemctl", "revert", "getty@.service", "serial-getty@.service"], text=True)
    if p.returncode == 0:
        print (f"Have enabled authenticated console access successfully")
    else:
        print (f"Failed to enable authenticated console access")
        errcnt+=1

# Set the VNC password from a clear password
if (vncpass != None) and (vncpass != ""):
    os.makedirs("/root/.vnc", exist_ok = True)
    p = subprocess.run(["x11vnc", "-storepasswd", vncpass, "/root/.vnc/passwd"], text=True)
    if p.returncode == 0:
        print (f"Have changed the vnc password successfully")
    else:
        print (f"Failed to change the vnc password")
        errcnt+=1

# Auto-start x11vnc with the graphical environment
if dovnc == True:
    print (f"Enabling VNC Server in /root/.xprofile ...")
    file = open("/root/.xprofile", "w")
    file.write("""[ -f ~/.vnc/passwd ] && pwopt="-usepw" || pwopt="-nopw"\n""")
    file.write("""x11vnc $pwopt -nevershared -forever -logfile /var/log/x11vnc.log &\n""")
    file.close()

# ==============================================================================
# Configure custom CA certificates
# ==============================================================================
ca_anchor_path = "/etc/ca-certificates/trust-source/anchors/"

if 'sysconfig' in config and 'ca-trust' in config['sysconfig'] and config['sysconfig']['ca-trust']:
    print(f"====> Adding trusted CA certificates ...")

    for name, cert in sorted(config['sysconfig']['ca-trust'].items()):
        print (f"Adding certificate '{name}' ...")
        with open(os.path.join(ca_anchor_path, name + ".pem"), "w") as certfile:
            certfile.write(cert)

    print(f"Updating CA trust configuration ...")
    p = subprocess.run(["update-ca-trust"], text=True)

# ==============================================================================
# late-load a SystemRescueModule (SRM)
# ==============================================================================

if (late_load_srm != None) and (late_load_srm != ""):
    print(f"====> Late-loading SystemRescueModule (SRM) ...")
    p = subprocess.run(["/usr/share/sysrescue/bin/load-srm", late_load_srm], text=True)
    # the SRM could contain changes to systemd units -> let them take effect
    p = subprocess.run(["/usr/bin/systemctl", "daemon-reload"], text=True)

# ==============================================================================
# End of the script
# ==============================================================================
print(f"====> Script {sys.argv[0]} completed with {errcnt} errors ...")
sys.exit(errcnt)
