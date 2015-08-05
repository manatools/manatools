# vim: set et ts=4 sw=4:
package ManaTools::Shared::JournalCtl;

#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::JournalCtl - journalctl perl wrapper

=head1 SYNOPSIS

    my $log = ManaTools::Shared::JournalCtl->new();
    my @log_content = $log->getLog();

=head1 DESCRIPTION

This module wraps journalctl allowing some running options and provides the
output log content.

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::JournalCtl


=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2015, Angelo Naselli.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 METHODS

=cut

use Moose;

use diagnostics;


has 'this_boot' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has 'since' => (
    is => 'rw',
    isa => 'Str',
    default => "",
);

has 'until' => (
    is => 'rw',
    isa => 'Str',
    default => "",
);

has 'priority' => (
    is => 'rw',
    isa => 'Str',
    default => "",
);

has 'unit' => (
    is => 'rw',
    isa => 'Str',
    default => "",
);

has 'identifier' => (
    is => 'rw',
    isa => 'Str',
    default => "",
);

#=============================================================

=head2 getLog

=head3 INPUT

Input_Parameter: in_par_description

=head3 OUTPUT

\@content: ARRAYREF containing the log content.

=head3 DESCRIPTION

This methods gets the log using the provided options

=cut

#=============================================================

sub getLog {
    my $self = shift;

    my $params = "--no-pager -q";
    if ($self->this_boot == 1) {
        $params .= " -b";
    }
    if ($self->since ne "") {
        $params .= " --since=" . '"' . $self->since . '"';
    }
    if ($self->until ne "") {
        $params .= " --until=" . '"' . $self->until .'"';
    }
    if ($self->unit ne "") {
        $params .= " --unit=" . $self->unit;
    }
    if ($self->priority ne "") {
        $params .= " --priority=" . $self->priority;
    }
    if ($self->identifier ne "") {
        $params .= " --identifier=" . $self->identifier;
    }

    $ENV{'PATH'} = '/usr/sbin:/usr/bin';
    my $jctl = "/usr/bin/journalctl " . $params;

    # TODO remove or add to log
    print " Running  " . $jctl . "\n";
    my @content = `$jctl`;

    return \@content;
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;
