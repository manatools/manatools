#!/usr/bin/perl

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


#Class Module
package Module;

use strict;
use warnings;
use diagnostics;
use yui;

sub new {
    my ($class, $newName, $newIcon, $newLaunch) = @_;
    my $self = {
	my $name = 0,
	my $icon = 0,
	my $launch = 0,
	my $button = 0
    };
    bless $self, 'Module';
    
    $self->{name} = $newName;
    $self->{icon} = $newIcon;
    $self->{launch} = $newLaunch;

    return $self;
}

sub setButton {
    my ($self, $button) = @_;
    $self->{button} = $button;
}

sub removeButton {
    my($self) = @_;

    undef($self->{button});
}

1;
