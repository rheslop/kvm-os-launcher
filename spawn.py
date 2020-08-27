#!/usr/bin/python

import argparse, os, sys

if not os.geteuid() == 0:
    print ("\nYou must be root to run this script.\n")
    sys.exit(1)

troll = argparse.ArgumentParser()
troll.add_argument("-c", "--config", help="Instance configuration")
troll.add_argument("-i", "--id", help="Instance ID number, between 10 & 200 inclusive", type=int)
vm = troll.parse_args()

if vm.config is None:
    print("")
    print("Available configurations:")
    print("-------------------------")
    for i in (os.listdir("conf")):
        if i.endswith('.conf'):
            print(i[:-5])
    print("")
    CONFIG = input("Instance configuration: ")
else:
    CONFIG = vm.config

if not os.path.isfile("conf/%s.conf" % CONFIG):
    print("\nNo such configuration file: %s." % CONFIG)
    sys.exit(2)

if vm.id is None:
    VMID = int(input("Instance ID number: "))
else:
    VMID = vm.id

if VMID < 10 or VMID > 200:
    print("\nID out of range.\n")
    sys.exit(1)

createVM = ("scripts/init-vm.sh %s.conf %d") % (CONFIG, VMID)
os.system(createVM)

