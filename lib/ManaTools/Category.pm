# vim: set et ts=4 sw=4:
package ManaTools::Category;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Category - add new category to window

=head1 SYNOPSIS

    my $category = new ManaTools::Category({name => 'Category Name'});

=head1 DESCRIPTION

    This class is used by MainDisplay internally and should not
    be used outside, since MainDisplay::setupGui use it to
    build GUI layout.

=head1 EXPORT

exported

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Category

=head1 SEE ALSO

    ManaTools::MainDisplay

=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

    Copyright 2013-2017, Angelo Naselli.
    Copyright 2012, Steven Tucker.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA

=head1 METHODS

=cut

use Moose;
use diagnostics;
use yui;

has 'name' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'icon' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'button' => (
    is       => 'rw',
    isa      => 'Maybe[yui::YPushButton]',
    init_arg => undef,
);

has 'modules' => (
    is      => 'rw',
    isa     => 'ArrayRef[ManaTools::Module]',
    init_arg => undef,
    default => sub {[];},
);


## Can only add the config file data at constructor
## The Gui elements are added in setupGui inside MainDisplay
#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        name: new category name
        icon: new category icon


=head3 DESCRIPTION

    Constructor: creates a new category named Name

=cut

#=============================================================



## Add a new module to the list
#=============================================================

=head2 loadModule

=head3 INPUT

    $self:   this object
    $module: module to add

=head3 OUTPUT

    1: if the module has been added
    0: otherwise

=head3 DESCRIPTION

    This method adds a module to the loaded
    modules if it is not already in.

=cut

#=============================================================
sub loadModule {
    my ($self, $module) = @_;

    if (!$self->moduleLoaded($module->{name})) {
        push ( @{$self->modules()}, $module );

        return 1;
    }
    return 0;
}

#=============================================================

=head2 moduleLoaded

=head3 INPUT

    $self:        this object
    $module_name or -CLASS => name : module/CLASS name to look for

=head3 OUTPUT

    $present: module present or not

=head3 DESCRIPTION

    This method looks for the given module and if already in
    returns true.
=cut

#=============================================================
sub moduleLoaded {
    my $self = shift;
    my ($module_name) = @_;
    my %params = ();
    if ($module_name eq '-CLASS') {
        (%params) = @_;
    }

    my $present = 0;

    if (!$module_name || (scalar @{$self->modules()} == 0) ) {
        return $present;
    }

    foreach my $mod (@{$self->modules()}) {
        if (exists $params{-CLASS} && ref($mod) eq $params{-CLASS}) {
            $present = 1;
            last;
        }
        elsif ($mod->name() eq $module_name) {
            $present = 1;
            last;
        }
    }

    return $present;
}

#=============================================================

=head2 addButtons

=head3 INPUT

    $self:    this object
    $mainDisplay:  main dialog

=head3 DESCRIPTION

    Creates and adds buttons for each module_name

=cut

#=============================================================
sub addButtons {
    my($self, $mainDisplay) = @_;
    my $tmpButton;
    my $currLayout = 0;
    my %weights = ();
    my $curr;
    my $count = 0;
    my $factory = $mainDisplay->factory();

    foreach my $mod (@{$self->modules()}) {
        if(($count % 2) != 1) {
            $factory->createVSpacing($mainDisplay->rightPane(), 0.5);
            $currLayout = $factory->createHBox($mainDisplay->rightPane());
            $factory->createHSpacing($currLayout, 1);
            $currLayout->setWeight($yui::YD_VERT, 10);
        }

        $tmpButton = $factory->createPushButton(
            $currLayout,
            $mod->name
        );
        $count++;
        if (($count < scalar @{$self->modules()}) || (($count >= scalar @{$self->modules()}) && ($count % 2) == 0)) {
            $tmpButton->setWeight($yui::YD_HORIZ, 20);
        }
        $factory->createHSpacing($currLayout, 1);
        $mod->setButton($tmpButton);
        $tmpButton->setLabel($mod->name);
        $tmpButton->setIcon($mod->icon);
        $mainDisplay->mainWin()->addWidget(
            $mod->name(),
            $tmpButton,  sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $self = $event->parentDialog()->module(); #this object
                my $mod = $self->_moduleSelected($event->widget());
                if ($mod) {
                    $self->selectedModule($mod);
                    return 0;
                }
                return 1;
            }
        );

    }
}

#=============================================================

=head2 removeButtons

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    Delete the module buttons

=cut

#=============================================================
sub removeButtons {
    my($self) = @_;

    for(@{$self->modules()}) {
        $_->removeButton();
    }
}

#=============================================================

=head2 setIcon

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    set the button icon

=cut

#=============================================================
sub setIcon {
    my($self) = @_;

    $self->button()->setIcon($self->icon());
}

no Moose;

1;

