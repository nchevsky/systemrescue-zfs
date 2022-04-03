#!/usr/bin/env python3

# SPDX-License-Identifier: GPL-3.0-or-later

import subprocess
import json
import glob
import os
import sys
import re
import tempfile

# pythons os.symlink bails when a file already exists, this function also handles overwrites
def symlink_overwrite(target, link_file):
    link_dir = os.path.dirname(link_file)
    
    while True:
        # get a tmp filename in the same dir as link_file
        tmp = tempfile.NamedTemporaryFile(delete=True, dir=link_dir)
        tmp.close()
        # tmp is now deleted
        
        # os.symlink aborts when a file with the same name already exists
        # someone could have created a new file with the tmp name right in this moment
        # so we need to loop and try again in this case
        try:
            os.symlink(target,tmp.name)
            break
        except FileExistsError:
            pass
    
    os.replace(tmp.name, link_file)


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
# autoterminal: programs that take over a virtual terminal for user interaction
# ==============================================================================

# expect a dict with terminal-name: command, like config['autoterminal']['tty2'] = "/usr/bin/setkmap"
if ('autoterminal' in config) and (config['autoterminal'] is not None) and \
   (config['autoterminal'] is not False) and isinstance(config['autoterminal'], dict):
    print("====> Configuring autoterminal ...")
    with open('/usr/share/sysrescue/template/autoterminal.service', 'r') as template_file:
        conf_template = template_file.read()
    start_services = []
    for terminal, command in sorted(config['autoterminal'].items()):
        if not re.match(r"^[a-zA-Z0-9_-]+$", terminal):
            print (f"Ignoring invalid terminal name '{terminal}'")
            errcnt+=1
            continue
        # do not check if terminal or command exists: an autorun could create them later on
        print (f"setting terminal '{terminal}' to '{command}'")
        with open(f"/etc/systemd/system/autoterminal-{terminal}.service", "w") as terminal_conf:
            # write service config, based on the template config we loaded above
            # don't use getty@{terminal}.service name to not use autovt@{terminal}.service on-demand logic
            conf_data=conf_template.replace("%TTY%",terminal)
            conf_data=conf_data.replace("%EXEC%",command)
            terminal_conf.write(conf_data)
        # enable service: always start it, do not wait for the user to switch to the terminal
        # means other programs (like X.org) can't allocate it away, also allows for longer running init sequences
        symlink_overwrite(f"/etc/systemd/system/autoterminal-{terminal}.service",
                        f"/etc/systemd/system/getty.target.wants/autoterminal-{terminal}.service")
        # mask the regular getty for this terminal
        symlink_overwrite("/dev/null",f"/etc/systemd/system/getty@{terminal}.service")
        symlink_overwrite("/dev/null",f"/etc/systemd/system/autovt@{terminal}.service")
        start_services.append(f"autoterminal-{terminal}.service")
    # reload systemd to allow the new config to take effect
    subprocess.run(["/usr/bin/systemctl", "daemon-reload"])
    # explicitly start new services (after daemon-reload): systemd can't update dependencies while starting
    for s in start_services:
        subprocess.run(["/usr/bin/systemctl", "--no-block", "start", s])

# ==============================================================================
# End of the script
# ==============================================================================
print(f"====> Script {sys.argv[0]} completed with {errcnt} errors ...")
sys.exit(errcnt)
