#!/bin/bash

apanel=`rpm --eval %perl_privlib`/AdminPanel

function check_root_permissions
{
	if [[ $EUID -ne 0 ]]; then
           echo "You must be root to run this script" 1>&2
	   exit 1
	fi
}

function uninstall
{
   echo "== Uninstalling AdminPanel..."
   if [ -L $apanel ]
   then
      unlink $apanel
   fi
   
   if [ -f /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.adminpanel.policy ]
   then
      rm /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.adminpanel.policy
   fi
   
   if [ -f /usr/bin/apanel.pl ]
   then
      unlink /usr/bin/apanel.pl
   fi
   echo "== Removed"
}

function setup {
   echo "== Installing AdminPanel..."
   pushd .
      cd ..
      cp extras/org.mageia.policykit.pkexec.adminpanel.policy /usr/share/polkit-1/actions/
      ln -s $PWD/AdminPanel `rpm --eval %perl_privlib`
      ln -s $PWD/apanel.pl /usr/bin
   popd
   echo "== Done"
}

function usage {
	echo "Usage:"
	echo "--remove   uninstall AdminPanel references"
	echo "--install  install AdminPanel references"
}

check_root_permissions

while getopts "hri" OPTIONS
do
	case $OPTIONS in
		r  ) uninstall ;;
		i  ) uninstall && setup ;;
		h  ) usage ;;
		\? ) usage ;;
	esac
done

