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

pushd .
cd ..
cp extras/org.mageia.policykit.pkexec.adminpanel.policy /usr/share/polkit-1/actions/
ln -s $PWD/AdminPanel `rpm --eval %perl_privlib`
popd

