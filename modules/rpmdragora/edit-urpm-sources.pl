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

use strict;
use lib qw(/usr/lib/libDrakX);
use AdminPanel::Rpmdragora::init;
use standalone;
use AdminPanel::rpmdragora;
use common;
use AdminPanel::Rpmdragora::edit_urpm_sources;

require_root_capability();

readconf();

run();

myexit 0;
