# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::IO;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::IO - IO class

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::IO;

    my $db_man = ManaTools::Shared::disk_backend::IO->new($id);
    $db_man->label();
    $db_man->id();


=head1 DESCRIPTION

    This is an abstract class for IO in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this class with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::IO


=head1 AUTHOR

    Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015 Maarten Vanraes <alien@rmail.be>

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

with 'ManaTools::Shared::PropertiesRole';

## Class data
has 'type' => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    default => 'IO'
);

## Object vars
has 'db' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend',
    init_arg => undef,
    lazy => 1,
    default => undef,
);

has 'id' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

#=============================================================

=head2 label

=head3 OUTPUT

    label of the IO

=head3 DESCRIPTION

    this method returns the label for this IO

=cut

#=============================================================
sub label {
    my $self = shift;

    return $self->type .' '. $self->id;
}

#=============================================================

=head2 unhook

=head3 DESCRIPTION

    this method returns removes the IO from the parent and Parts

=cut

#=============================================================
sub unhook {
    my $self = shift;
    $self->db->rmio($self);
}

1;
