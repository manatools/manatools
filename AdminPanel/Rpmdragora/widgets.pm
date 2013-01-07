package Gtk2::Mdv::TextView;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
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
# $Id: widgets.pm 233986 2008-02-06 14:14:06Z tv $

use strict;
use MDK::Common::Func 'any';
use lib qw(/usr/lib/libDrakX);

use Time::HiRes;
use feature 'state';


sub new {
    my ($_class) = @_;
    my $w = gtknew('TextView', editable => 0);
    state $time;
    $w->signal_connect(size_allocate => sub {
        my ($w, $requisition) = @_;
        return if !ref($w->{anchors});
        return if Time::HiRes::clock_gettime() - $time < 0.200;
        $time = Time::HiRes::clock_gettime();
        foreach my $anchor (@{$w->{anchors}}) {
            $_->set_size_request($requisition->width-30, -1) foreach $anchor->get_widgets;
        }
        1;
    });
    $w;
}

1;
