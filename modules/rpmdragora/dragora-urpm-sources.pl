#!/usr/bin/perl
#*****************************************************************************
# 
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2002-2007 Mandriva Linux
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
#
# $Id: edit-urpm-sources.pl 244763 2008-09-04 16:12:52Z tv $


use AdminPanel::Rpmdragora::init;
use AdminPanel::rpmdragora;
use AdminPanel::Rpmdragora::edit_urpm_sources;
use AdminPanel::Privileges;
use AdminPanel::Shared::Locales;

my $loc = AdminPanel::Shared::Locales->new(domain_name => 'rpmdrake');

if (AdminPanel::Privileges::is_root_capability_required()) {
    require AdminPanel::Shared::GUI;
    my $sh_gui = AdminPanel::Shared::GUI->new();
    $sh_gui->warningMsgBox({
        title => $loc->N("Configure media"),
        text  => $loc->N("root privileges required"),
    });
    exit (-1);
}

AdminPanel::rpmdragora::readconf();

AdminPanel::Rpmdragora::edit_urpm_sources::run();

AdminPanel::rpmdragora::myexit 0;
