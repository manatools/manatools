# vim: set et ts=4 sw=4:
package ManaTools::SettingsReader;
#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::SettingsReader - This module allows to load an XML configuration file

=head1 SYNOPSIS

    use ManaTools::SettingsReader;

    my $settings = new ManaTools::SettingsReader({filNema => $fileName});

=head1 DESCRIPTION

    This module allows to load a configuration file returning a Hash references with its content.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::SettingsReader

=head1 SEE ALSO

    XML::Simple

=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

    Copyright (C) 2012-2015, Angelo Naselli.

   This file is part of ManaTools

   ManaTools is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   ManaTools is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with ManaTools.  If not, see <http://www.gnu.org/licenses/>.

=head1 FUNCTIONS

=cut


use Moose;
use diagnostics;
use XML::Simple;
use Data::Dumper;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        fileName: settings configuration file name

=head3 OUTPUT attributes

    settings: Hash reference containing read settings

=head3 DESCRIPTION

    The constructor just loads the given file and return its representation
    into a hash reference.

=cut

#=============================================================

has 'fileName' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'settings' => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    lazy     => 1,
    builder  => '_settingsInitialize',
);

sub _settingsInitialize {
    my $self = shift;

    my $xml = new XML::Simple (KeyAttr=>[]);
    return $xml->XMLin($self->fileName());
}

no Moose;
1;
