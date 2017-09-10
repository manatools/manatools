# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2015-2017 Angelo Naselli <anaselli@linux.it>
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


# icon will be by default the name + .png ; if not, override _iconInitializer

has '+name' => (
    default => 'manatemplate',
    required => 0,
    init_arg => undef,
);

sub _titleInitializer {
    my $self = shift;

    return ($self->loc->N("%s - Module template tools", $self->name()));
}


=head1 VERSION

    Module implements Version Role so if you want to have your own versioning
    override Version attributes e.g. using
    has '+Version' => (
        default => "X.Y.Z"
    );

=cut

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

    # if you want to use your module into mpan you should consider to
    # use either Shared::Module::GUI::Dialog to implement your layout
    # and manage your events or use yui::YUI::app()->setApplicationTitle
    # and yui::YUI::app()->setApplicationIcon to here

    $self->sh_gui->msgBox({
        text => $self->loc->N("Hello world, I am the beautiful module template")
    });

};


1;
