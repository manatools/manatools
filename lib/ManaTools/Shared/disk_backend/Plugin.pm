# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Plugin;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Plugin - disks object

=head1 SYNOPSIS

    package ManaTools::Shared::disk_backend::Plugin::Foo;
    use Moose;

    extend 'ManaTools::Shared::disk_backend::Plugin';

    override('load', sub {
        ...
    });

    override('save', sub {
        ...
    });

    override('probe', sub {
        ...
    });

    override('probeio', sub {
        ...
    });

    1;

    package ManaTools::Shared::disk_backend::IO::Bar;
    use Moose;

    extend 'ManaTools::Shared::disk_backend::IO';

    has '+type', default => 'bar';

    ...

    1;

    package ManaTools::Shared::disk_backend::Part::Baz;
    use Moose;

    extend 'ManaTools::Shared::disk_backend::Part';

    has '+type', default => 'baz';
    has '+in_restriction', default => sub { ... };
    has '+out_restriction', default => sub { ... };

    ...

    1;

=head1 DESCRIPTION

    This plugin is a abstract plugin for the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Plugin


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

## class DATA
has 'dependencies' => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub {
        return [];
    }
);

has 'parent' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend',
    required => 1
);

#=============================================================

=head2 load

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for loading Part's, the idea is to override it if needed

=cut

#=============================================================
sub load {
    my $self = shift;

    1;
}

#=============================================================

=head2 save

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for saving Part's, the idea is to override it if needed

=cut

#=============================================================
sub save {
    my $self = shift;

    1;
}

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for probing IO's and/or Part's, the idea is to override it if needed

=cut

#=============================================================
sub probe {
    my $self = shift;

    1;
}

#=============================================================

=head2 loadio

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for loading a Part from a specific IO, the idea is to override it if needed

=cut

#=============================================================
sub loadio {
    my $self = shift;
    my $io = shift;

    1;
}

#=============================================================

=head2 savepart

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for saving a specific Part, the idea is to override it if needed

=cut

#=============================================================
sub savepart {
    my $self = shift;
    my $part = shift;

    1;
}

#=============================================================

=head2 probeio

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this is a default method for probing specific a specific IO, the idea is to override it if needed

=cut

#=============================================================
sub probeio {
    my $self = shift;
    my $io = shift;

    1;
}

1;
