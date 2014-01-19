#!/usr/bin/perl

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


#Class Module
package Module;

use Moose;

=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.0.0';

use strict;
use warnings;
use diagnostics;
use yui;

=head1 SUBROUTINES/METHODS

=head2 create - returns a Module object such as a module
                launcher (this object) or an extension of
                this class

=cut

sub create {
    my $class = shift;
    $class = ref $class || $class;
    my (%params) = @_;

    my $obj;
    if ( exists $params{-CLASS} ) {
        my $driver = $params{-CLASS};
        
        eval {
            my $pkg = $driver;
            $pkg =~ s/::/\//g;
            $pkg .= '.pm';
            require $pkg;
            $obj=$driver->new();
        };
        if ( $@ ) {
            die "Error getting obj for driver $params{-CLASS}: $@";
            return undef;
        }
    }
    else {
        $obj = new Module(@_);
    }
    return $obj;
}

has 'icon' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'name' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'launch' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'button' => (
    is      => 'rw',
   init_arg => undef,
);


sub setButton {
    my ($self, $button) = @_;
    $self->{button} = $button;
}

sub removeButton {
    my($self) = @_;

    undef($self->{button});
}

# base class launcher
sub start {
    my $self = shift;

    if ($self->{launch}) {
        my $err = yui::YUI::app()->runInTerminal( $self->{launch} . " --ncurses");
        if ($err == -1) {
            system($self->{launch});
        }   
    }
}


no Moose;
1;
