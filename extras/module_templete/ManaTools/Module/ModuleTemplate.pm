# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2015 Angelo Naselli <anaselli@linux.it>
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

package ManaTools::Module::ModuleTemplate;

use Moose;

use yui;
use File::ShareDir ':ALL';

use ManaTools::Shared;
use ManaTools::Shared::Locales;
use ManaTools::Shared::GUI;

extends qw( ManaTools::Module );


#uncomment this and set the right icon
#has '+icon' => (
#    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/ModuleTemplate.png'),
#);

has '+name' => (
    lazy     => 1,
    builder => '_nameInitializer',
);

sub _nameInitializer {
    my $self = shift;

    return ($self->loc->N("Module template tools"));
}


=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

# sh_gui to use Shared/GUI object
has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start  host manager

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->sh_gui->msgBox({
        text => $self->loc->N("Hello world, I am the beautiful module template")
    });
    
};


1;
