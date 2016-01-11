# vim: set et ts=4 sw=4:
package  ManaTools::Shared::GUI::CommandLine;
#============================================================= -*-perl-*-

=head1 NAME

    Manatools::Shared::GUI::CommandLine - Shared CommandLine extension with some yui parameters explanation

=head1 SYNOPSIS

    use ManaTools::Shared::GUI::CommandLine;

    my $cl = ManaTools::Shared::GUI::CommandLine->new_with_options();
    $cl->usage();

    # to extend it
    use Moose;
    extends 'ManaTools::Shared::GUI::CommandLine';
    use ManaTools::Shared::Locales;

    my $loc = ManaTools::Shared::Locales->new();

    has 'new_option' => (
        traits    => [ 'Getopt' ],
        is => 'ro',
        documentation => $loc->N('we have a new option to manage here')
    );

    ...

    # check if new option is set
    if ($cl->new_option) {
        ...
    }

=head1 DESCRIPTION

    This class extends ManaTools::Shared::CommandLine adding the documentation for option such as
    --qt, --gtk and --ncurses, options that are common to every Manatools::Module module, since they
    use yui module.


=head1 SUPPORT

    You can find documentation for this module with the perldoc command:
    perldoc Manatools::Shared::GUI::CommandLine

=head1 SEE ALSO

    Manatools::Shared::CommandLine, MooseX::GetOpt

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

    Copyright (C) 2015-2016, Angelo Naselli.

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

=head1 FUNCTIONS

=cut

use Moose;
extends 'ManaTools::Shared::CommandLine';

use ManaTools::Shared::Locales;

my $loc = ManaTools::Shared::Locales->new();

has 'gtk' => (
    traits    => [ 'Getopt' ],
    is => 'ro',
    documentation => $loc->N('start using yui gtk plugin implementation')
);

has 'ncurses' => (
    traits    => [ 'Getopt' ],
    is => 'ro',
    documentation => $loc->N('start using yui ncurses plugin implementation')
);

has 'qt' => (
    traits    => [ 'Getopt' ],
    is => 'ro',
    documentation => $loc->N('start using yui qt plugin implementation')
);

has 'fullscreen' => (
    traits    => [ 'Getopt' ],
    is => 'ro',
    documentation => $loc->N('use full screen for dialogs')
);

has 'noborder' => (
    traits    => [ 'Getopt' ],
    is => 'ro',
    documentation => $loc->N('no window manager border for dialogs')
);

has 'conf_dir' => (
    traits    => [ 'Getopt' ],
    isa => 'Str',
    is => 'ro',
    cmd_flag  => 'conf-dir',
    documentation => $loc->N('<dir> optional directory containing configuration files for each module (e.g. modulename/config_files)',)
);



no Moose;
__PACKAGE__->meta->make_immutable;

1;

