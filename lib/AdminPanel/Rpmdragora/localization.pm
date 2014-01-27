#!/usr/bin/perl
# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::localization;
#*****************************************************************************
#
#  Copyright (c) 2013 Matteo Pasotti <matteo.pasotti@gmail.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License version 2, as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#*****************************************************************************
use strict;
use warnings;
use diagnostics;
use lib qw(/usr/lib/libDrakX);
use common;

Locale::gettext::bind_textdomain_codeset($_, 'UTF8') foreach 'libDrakX', if_(!$::isInstall, 'libDrakX-standalone'),
	if_($::isRestore, 'draksnapshot'), if_($::isInstall, 'urpmi'),
	'drakx-net', 'drakx-kbd-mouse-x11', # shared translation
	@::textdomains;

#========= UGLY WORKAROUND ============
push @::textdomains, 'rpmdrake';
#========= UGLY WORKAROUND ============
