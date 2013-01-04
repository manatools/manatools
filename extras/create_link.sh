#!/bin/bash

apanel=`rpm --eval %perl_privlib`/AdminPanel

if [ -L $apanel ]
then
   rm $apanel
fi

if [ -f /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.adminpanel.policy ]
then
   rm /usr/share/polkit-1/actions/org.mageia.policykit.pkexec.adminpanel.policy
fi

if [ -f /usr/bin/apanel.pl ]
then
   rm usr/bin/apanel.pl
fi

pushd .
cd ..
cp extras/org.mageia.policykit.pkexec.adminpanel.policy /usr/share/polkit-1/actions/
ln -s $PWD/AdminPanel `rpm --eval %perl_privlib`
ln -s $PWD/apanel.pl /usr/bin
popd

