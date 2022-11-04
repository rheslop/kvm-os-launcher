#!/bin/bash

if [[ $UID -ne 0 ]]; then
        echo "This script must be run as root."
        exit
fi


INSTALL_DIR=/opt/kol

if [ "$1" == "" ]; then
    mkdir -p $INSTALL_DIR
    cp ./spawn.py    $INSTALL_DIR && chmod 755 $INSTALL_DIR/spawn.py
    cp ./README.adoc $INSTALL_DIR
    cp -R ./ansible  $INSTALL_DIR
    cp -R ./scripts  $INSTALL_DIR
    if [ -d $INSTALL_DIR/conf ]; then
        for i in $(ls ./conf); do
            if [ -f $INSTALL_DIR/conf/$i ]; then
                read -p "Do you wish to overwrite $INSTALL_DIR/conf/$i [y/n]?" CONFIRM
                if [ "$CONFIRM" == "y" ]; then
                    cp conf/$i $INSTALL_DIR/conf/$i
                fi
            fi
        done
    else
        cp -R ./conf $INSTALL_DIR
    fi
    ln -sf $INSTALL_DIR/spawn.py /usr/bin/kol

else

    if [ $1 == uninstall ]; then
        rm -rf /usr/bin/kol
        rm -rf $INSTALL_DIR/spawn.py
        rm -rf $INSTALL_DIR/README.adoc
        rm -rf $INSTALL_DIR/ansible
        rm -rf $INSTALL_DIR/scripts
        echo -e "\E[0;31mThis script does not remove templates from $INSTALL_DIR/conf.\E[0m"
    else
        echo "$1 is not a recognized option."

    fi
fi

