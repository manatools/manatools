# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::PurposeLabelRole;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::PurposeLabelRole - a PurposeLabelRole Moose Role

=head1 SYNOPSIS
    package Foo;

    with 'ManaTools::Shared::disk_backend::PurposeLabelRole';

    1;

    ...

    my $f = Foo->new();
    $f->prop('dev', 'maj:min');
    $f->sync_majorminor();
    my $major = $f->major();
    my $minor = $f->minor();


=head1 DESCRIPTION

    This Role is an collection of PurposeLabelRole in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this Role with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::PurposeLabelRole


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

use Moose::Role;

#=============================================================

=head2 purpose_label

=head3 DESCRIPTION

    this method finds in descendants the label denoting the purpose

=cut

#=============================================================
sub purpose_label {
    my $self = shift;
    my $partstate = shift;
    # finding a purpose label if one has overridden the purpose_label or has a PurposeLabelRole child
    my @labels = ();
    my @children = $self->children($partstate);
    for my $child (@children) {
        my $label = $child->purpose_label($partstate) if ($child->does('ManaTools::Shared::disk_backend::PurposeLabelRole'));
        push @labels, $label if defined($label);
    }
    return undef if scalar(@labels) == 0;
    @labels = sort @labels;
    return $labels[0];
}

1;
