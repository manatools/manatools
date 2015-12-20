# vim: set et ts=4 sw=4:
package ManaTools::Shared::CommandLine;
#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::CommandLine - A common command line management

=head1 SYNOPSIS

    use ManaTools::Shared::CommandLine;

    my $cl = ManaTools::Shared::CommandLine->new();
    $cl->new_with_options();

=head1 DESCRIPTION

    This class extends MooseX::Getopt adding the option --locales-dir and its
    documentation. This option is usually caught by modules to look for translation
    files into the given directory instead of the default one, and it is useful for
    translators and translation testers.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:
    perldoc ManaTools::Shared::CommandLine

=head1 SEE ALSO

    MooseX::Getopt

=head1 AUTHOR

    Angelo Naselli <angelo.naselli@softeco.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015, Angelo Naselli.

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

=head1 SUBROUTINES/METHODS

=cut
use Moose;
with qw/MooseX::Getopt/;
use Getopt::Long qw(:config pass_through no_auto_version no_auto_help);

use diagnostics;
use utf8;

use ManaTools::Shared::Locales;


my $loc = ManaTools::Shared::Locales->new();

has 'locales_dir' => (
    traits    => [ 'Getopt' ],
    isa => 'Str',
    is => 'ro',
    cmd_flag  => 'locales-dir',
    documentation => $loc->N('<dir> optional directory containing localization strings (developer only)',)
);

# Overriding help_flag from MooseX::Getopt::GLD so we can translate the usage string message
# captures the options: --help --usage --? -? -h
has help_flag => (
    is => 'ro', isa => 'Bool',
    traits => ['Getopt'],
    cmd_flag => 'help',
    cmd_aliases => [ qw(usage ? h) ],
    documentation => $loc->N("Prints this usage information."),
);


no Moose;
__PACKAGE__->meta->make_immutable;

1;

