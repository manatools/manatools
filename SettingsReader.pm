# vim: set et ts=4 sw=4:
#    Copyright 2012 Angelo Naselli
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


#Class SettingsReader
package SettingsReader;

use strict;
use warnings;
use diagnostics;
use XML::Simple;
use Data::Dumper;

sub new {
    my ($class, $fileName) = @_;
    
    my $self = {
        my $settings = 0,
        my $justToGetRidOfERROR = 0
    };
    bless $self, 'SettingsReader';
    
    my $xml = new XML::Simple (KeyAttr=>[]);
    $self->{settings} = $xml->XMLin($fileName);

    return $self->{settings};
}


1;
