# AdminPanel #

AdminPanel is a generic launcher application that can run 
internal or external modules, such as system configuration tools.

AdminPanel is also a collection of configuration tools that allows
users to configure most of their system components in a very simple, 
intuitive and attractive interface. It consists of some modules 
that can be also run as autonomous applications.

AdminPanel started as a porting of MCC (Mageia/Mandriva Control Center)
to libYui (Suse widget abstraction library), but its aim is to give 
an easy and common interface to developer to add new modules based
on libYui. Every modules as well as AdminPanel itself can be run
using QT, Gtk or ncurses interface.

# REQUIREMENTS #
* SUSE libyui *
    * https://github.com/libyui/libyui
    * Consider to check some not yet approved changes here https://github.com/anaselli/libyui

* libyui-mga - our widget extension *
    * https://github.com/xquiet/libyui-mga

* SUSE libyui-bindings - anaselli fork *
    * https://github.com/anaselli/libyui-bindings/tree/mageia
      This fork is necessary to include also libyui-mga extension.
    * For references, master is https://github.com/libyui/libyui-bindings

* at least one of the SUSE libyui plugins *
    * libyui-gtk     - https://github.com/libyui/libyui-gtk
    * libyui-ncurses - https://github.com/libyui/libyui-ncurses
    * libyui-qt      - https://github.com/libyui/libyui-qt
    * Consider here also to check some not yet approved changes at
      https://github.com/anaselli/libyui-XXX forks (where XXX is
      gtk, qt or ncurses)

* at least one of the MGA libyui widget extension plugins (according to the one above)*
    * libyui-mga-gtk     - https://github.com/xquiet/libyui-mga-gtk
    * libyui-mga-ncurses - https://github.com/xquiet/libyui-mga-ncurses
    * libyui-mga-qt      - https://github.com/xquiet/libyui-mga-qt

Note that libyui-mga and libyui-mga plugins are mainly developed
on https://bitbucket.org/_pmat_/libyui-YYY (where YYY is mga,
mga-gtk, mga-ncurses, mga-qt) and then synchronized on github.

# INSTALLATION #

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make install

To install this module with local::lib (see perldoc local::lib for 
details)
	# add also -MCPAN if you want to install from cpan locally	
	alias perl='perl -Mlocal::lib'
	perl Makefile.PL
	make
	make test
	make install

Since admin panel works with root privilege you can do the above
or just install it locally and run as root but using user environment
variable to know which ones run perl -Mlocal::lib as user and
execute the output as root.


# SUPPORT AND DOCUMENTATION #

After installing, you can find documentation for this module with the
perldoc command.

    perldoc AdminPanel


# LICENSE AND COPYRIGHT #

Copyright (C) 2012-2014 Angelo Naselli, Matteo Pasotti, Steven Tucker

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

NOTE: some icons are under the license:
Creative Commons Attribution-No Derivative Works 3.0 Unported 
http://creativecommons.org/licenses/by-nd/3.0/