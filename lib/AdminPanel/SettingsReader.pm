# vim: set et ts=4 sw=4:
package AdminPanel::SettingsReader;
#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::SettingsReader - This module allows to load an XML configuration file

=head1 SYNOPSIS

    use AdminPanel::SettingsReader;

    my $settings = new AdminPanel::SettingsReader($fileName);

=head1 DESCRIPTION

    This module allows to load a configuration file returning a Hash references with its content.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::SettingsReader

=head1 SEE ALSO

    XML::Simple

=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

    Copyright (C) 2012-2014, Angelo Naselli.

   This file is part of AdminPanel

   AdminPanel is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   AdminPanel is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.

=head1 FUNCTIONS

=cut


use strict;
use warnings;
use diagnostics;
use XML::Simple;
use Data::Dumper;

#=============================================================

=head2 new

=head3 INPUT

    $fileName: File to be loaded

=head3 OUTPUT

    $settings: Hash reference containing read settings

=head3 DESCRIPTION

    The constructor just loads the given files and return its representation 
    into a hash reference.

=cut

#=============================================================

sub new {
    my ($class, $fileName) = @_;

    my $self = {
        settings => 0,
    };
    bless $self, 'AdminPanel::SettingsReader';

    die "File " . $fileName . " not found" if (! -e $fileName);

    my $xml = new XML::Simple (KeyAttr=>[]);
    $self->{settings} = $xml->XMLin($fileName);

    return $self->{settings};
}


1;
