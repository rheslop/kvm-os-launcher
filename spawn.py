#!/usr/bin/python

import argparse, os, sys

if not os.geteuid() == 0:
    print ("\nYou must be root to run this script.\n")
    sys.exit(1)

# Options
troll = argparse.ArgumentParser()
troll.add_argument("-c", "--config", help="Instance configuration")
troll.add_argument("-i", "--id", help="Instance ID number, between 10 & 200 inclusive", type=int)
vm = troll.parse_args()

# Variables, dictionaries and functions
CURRENT_DIRECTORY=os.getcwd()
CONF_OPTIONS={}
EXEC = CURRENT_DIRECTORY + "/exec"

# The CONF_OPTION is the name of a configuration file with '.conf' stripped away
# The CONF_OPTION is the key that points to the full path and filename as the value

def ADDCONFFILES(path):
    for i in (os.listdir(path)):
        if i.endswith(".conf"):
            CONF_OPTION=i[:-5]
            if CONF_OPTION in CONF_OPTIONS:
                # Nothing is added to the dictionary if the key already exists
                # so the first paths added take precedence
                pass
            else:
                CONF_OPTIONS[CONF_OPTION] = path + "/" + i

if not os.path.exists(EXEC):
    os.makedir(EXEC)

# /opt/kol/conf takes precedence over ./conf

if os.path.exists("/opt/kol/conf"):
    ADDCONFFILES("/opt/kol/conf")
if os.path.exists(CURRENT_DIRECTORY + "/conf"):
    ADDCONFFILES(CURRENT_DIRECTORY + "/conf")

# Use dictionary `CONF_OPTIONS` to find user's choice for instance configuration
if vm.config is None:
    print("")
    print("Available configurations:")
    print("-------------------------")
    for keys, value in CONF_OPTIONS.items():
        print(keys)
    print("")
    CONFIG = input("Instance configuration: ")
else:
    CONFIG = vm.config

if not CONFIG in CONF_OPTIONS:
    print("\nNo such configuration file: %s" % CONFIG)
    sys.exit(2)

if not os.path.isfile(CONF_OPTIONS.get(CONFIG)):
    print("\nERROR opening configuration file: %s" % CONFIG)
    sys.exit(3)

if vm.id is None:
    VMID = int(input("Instance ID number: "))
else:
    VMID = vm.id

if VMID < 10 or VMID > 200:
    print("\nID out of range.\n")
    sys.exit(1)

# Prefer the installed executable if it is found

if os.path.isfile("/opt/kol/scripts/init-vm.sh"):
    script = "/opt/kol/scripts/init-vm.sh"
else:
    script = (CURRENT_DIRECTORY + "/scripts/init-vm.sh")

createVM = (script + " %s %d") % (CONF_OPTIONS.get(CONFIG), VMID)
os.system(createVM)

customize_disk_and_start = (EXEC + "/" + "%s" + "-customize_disk_and_create.sh") % (VMID)
os.system(customize_disk_and_start)
