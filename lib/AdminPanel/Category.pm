# vim: set et ts=4 sw=4:
#    Copyright 2012 Steven Tucker
#
#    This file is part of AdminPanel
#
#    AdminPanel is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    AdminPanel is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.


#Class Category
package AdminPanel::Category;

use strict;
use warnings;
use diagnostics;
use yui;

## Can only add the config file data at constructor
## The Gui elements are added in setupGui inside MainDisplay
#=============================================================

=head2 new

=head3 INPUT

    $newName: new category name
    $newIcon: new category icon

=head3 OUTPUT

    $self: this object

=head3 DESCRIPTION

    Constructor: creates a new category named Name

=cut

#=============================================================

sub new {
    my ($class, $newName, $newIcon) = @_;
    my $self = {
        name    => 0,
        button  => 0,
        icon    => 0,
        modules => [],
    };
    bless $self, 'AdminPanel::Category';

    $self->{name} = $newName;
    $self->{icon} = $newIcon;

    return $self;
}

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
        push ( @{$self->{modules}}, $module );

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

    if (!$module_name || ! $self->{modules}) {
        return $present;
    }

    foreach my $mod (@{$self->{modules}}) { 
        if (exists $params{-CLASS} && ref($mod) eq $params{-CLASS}) {
            $present = 1; 
            last;
        }
        elsif ($mod->{name} eq $module_name) {
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
    $panel:   parent panel layout in which to create buttons
    $factory: yui factory

=head3 DESCRIPTION

    Creates and adds buttons for each module_name
 
=cut

#=============================================================
sub addButtons {
    my($self, $panel, $factory) = @_;
    my $count = 0;
    my $tmpButton;
    my $currLayout = 0;
    $factory->createVSpacing($panel, 2);
    foreach my $mod (@{$self->{modules}}) {
        if(($count % 2) != 1) {
            $currLayout = $factory->createHBox($panel);
            $factory->createHStretch($currLayout);
        }
        $count++;
        $tmpButton = $factory->createPushButton($currLayout,
                                                $mod->name);
        $mod->setButton($tmpButton);
        $tmpButton->setLabel($mod->name);
        $tmpButton->setIcon($mod->icon);
        $factory->createHStretch($currLayout);
        if(($count % 2) != 1) {
            $factory->createVSpacing($panel, 2);     
        }
    }
    $factory->createVStretch($panel);
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

    for(@{$self->{modules}}) {
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

    $self->{button}->setIcon($self->{icon});
}

1;
__END__ 

=pod

=head1 NAME

       Category - add new category to window

=head1 SYNOPSIS
       
       $category = new Category('Category Name');


=head1 USAGE

    This class is used by MainDisplay internally and should not
    be used outside, since MainDisplay::setupGui use it to
    build GUI layout.

=head1 FUNCTIONS

=cut
