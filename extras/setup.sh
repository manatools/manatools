#!/bin/bash
# vim: set et ts=4 sw=4:

apanel=`rpm --eval %perl_privlib`/ManaTools

function check_root_permissions
{
	if [[ $EUID -ne 0 ]]; then
           echo "You must be root to run this script" 1>&2
	   exit 1
	fi
}

function uninstall
{
   echo "== Uninstalling ManaTools..."
   if [ -L $apanel ]
   then
      unlink $apanel
   fi

   if [ -f /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.manatools.policy ]
   then
      rm /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.manatools.policy
   fi

   if [ -f /usr/bin/apanel.pl ]
   then
      unlink /usr/bin/apanel.pl
   fi
   echo "== Removed"
}

# setup xhost to make apanel able to gain the required privileges using sudo
function setup_xhost_conf {
    echo "== Setup xhost settings"
    xhost +local:root
    echo "== Done"
}

function uninstall_xhost_conf {
    echo "== xhost settings restored"
    xhost -
    echo "== Done"
}

function setup {
   echo "== Installing ManaTools..."
   pushd .
      cd ..
      cp extras/org.mageia.policykit.pkexec.manatools.policy /usr/share/polkit-1/actions/
      ln -s $PWD/ManaTools `rpm --eval %perl_privlib`
      ln -s $PWD/apanel.pl /usr/bin
   popd
   echo "== Done"
}

function usage {
	echo "Usage:"
	echo "--remove      uninstall ManaTools references"
	echo "--install     install ManaTools references"
    echo "--privilege   define the authentication method to gain privileges (NOT IMPLEMENTED YET)"
}

check_root_permissions

while getopts "hrip:" OPTIONS
do
	case $OPTIONS in
		r  ) uninstall && uninstall_xhost_conf ;;
		i  ) setup && setup_xhost_conf ;;
		h  ) usage ;;
		* ) usage ;;
	esac
done

