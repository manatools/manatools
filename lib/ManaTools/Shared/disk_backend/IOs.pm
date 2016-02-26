# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::IOs;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::IOs - list of IOs

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend::IOs;

    my $db_man = ManaTools::Shared::disk_backend::IOs->new(parent => $self, restriction => $restriction);
    $db_man->append($io);
    $db_man->remove($io);
    $db_man->list();
    $db_man->length();


=head1 DESCRIPTION

    This plugin is an collection of IOs in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::IOs


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

has 'parent' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend::Part',
    required => 1
);
has 'restriction' => (
    traits => ['Code'],
    is => 'ro',
    isa => 'CodeRef',
    required => 1,
    handles => {
        check => 'execute'
    }
);
has 'ios' => (
    is => 'ro',
    isa => 'HashRef[ManaTools::Shared::disk_backend::IO]',
    default => sub {return {};}
);

#=============================================================

=head2 length

=head3 OUTPUT

    Int

=head3 DESCRIPTION

    this method returns the number of IOs

=cut

#=============================================================
sub length {
    my $self = shift;

    return scalar(keys %{$self->ios});
}

#=============================================================

=head2 list

=head3 OUTPUT

    array of the IOs

=head3 DESCRIPTION

    this method returns a list of IOs

=cut

#=============================================================
sub list {
    my $self = shift;

    return values %{$self->ios};
}

#=============================================================

=head2 is_equal

=head3 INPUT

    $ios: ManaTools::Shared::disk_backend::IOs

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true of $self is equal to $ios

=cut

#=============================================================
sub is_equal {
    my $self = shift;
    my $ios = shift;

    return 0 if $self->length() != $ios->length();
    for my $key (keys %{$self->ios()}) {
        return 0 if $ios->ios()->{$key} != $self->ios()->{$key};
    }
    return 1;
}

#=============================================================

=head2 append

=head3 INPUT

    $io: IO to add

=head3 OUTPUT

    1 if success, 0 otherwise

=head3 DESCRIPTION

    this method appends an IO

=cut

#=============================================================
sub append {
    my $self = shift;
    my $io = shift;

    # check IO with restriction
    if (defined $self->restriction) {
        if (!$self->check($self->parent(), $io)) {
            return 0;
        }
    }

    $self->ios->{$io->id} = $io;
}

#=============================================================

=head2 remove

=head3 INPUT

    $io: IO to remove

=head3 OUTPUT

    1 if success, 0 otherwise

=head3 DESCRIPTION

    this method removes an IO

=cut

#=============================================================
sub remove {
    my $self = shift;
    my $io = shift;

    # check IO with restriction
    if (defined $self->restriction) {
        if (!$self->check($self->parent(), $io, 1)) {
            return 0;
        }
    }

    # remove the io
    delete $self->ios->{$io->id};
}

1;

