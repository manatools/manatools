# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend::Part;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend::Part - Part class

=head1 SYNOPSIS
    package ManaTools::Shared::disk_backend::Part::MBR;

    extends 'ManaTools::Shared::disk_backend::Part';

    use MooseX::ClassAttribute;

    class_has '+type' => (
        default => 'MBR',
    );
    class_has '+restrictions' => (
        default => sub {
            return {
                sibling => sub {
                    my $self = shift;
                    my $part = shift;
                    return 0;
                },
                parent => sub {
                    my $self = shift;
                    my $part = shift;
                    return $part->does('ManaTools::Shared::disk_backend::BlockDevice');
                },
            }
        }
    );

    override('label', sub {
        my $self = shift;
        my $label = super;
        my @children = $self->children();
        if (scalar(@children) < 1) {
            return $label;
        }
        $label .= "(". $child[0]->label() .")";
        return $label;
    });

    1;

    ...

    my $mbr = ManaTools::Shared::disk_backend::Part::MBR->new();
    $mbr->label();  // MBR(/dev/sda)
    my $size = $mbr->prop('size');
    $mbr->prop('size', '20G');
    $mbr->action('format');


=head1 DESCRIPTION

    This is an abstract class for Part in the backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend::Part


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

with 'ManaTools::Shared::ActionsRole', 'ManaTools::Shared::PropertiesRole';

use MooseX::ClassAttribute;
use Moose::Util::TypeConstraints qw/subtype as where/;

## Class DATA

subtype 'PartState'
    => as Int
    => where {($_ > 0 && $_<=3)};

class_has 'LoadedState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'CurrentState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 2;},
);

class_has 'FutureState' => (
    is => 'ro',
    isa => 'PartState',
    init_arg => undef,
    default => sub {return 3;},
);

class_has 'type' => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    default => 'Part'
);

class_has 'order' => (
    is => 'ro',
    init_arg => undef,
    isa => 'Maybe[CodeRef]',
    default => undef,
);

## Object Variables
has 'loaded' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'probed' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'saved' => (
    is => 'rw',
    init_arg => undef,
    lazy => 1,
    isa => 'Maybe[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        my $self = shift;
        return $self;
    }
);

has 'db' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend',
    init_arg => undef,
    lazy => 1,
    default => undef,
);

has 'plugin' => (
    is => 'rw',
    isa => 'ManaTools::Shared::disk_backend::Plugin',
    required => 1,
    handles => ['tool', 'tool_exec', 'tool_lines', 'tool_fields'],
);

has 'links' => (
    is => 'ro',
    isa => 'ArrayRef[ManaTools::Shared::disk_backend::PartLink]',
    required => 0,
    init_arg => undef,
    default => sub {return []}
);

class_has 'restrictions' => (
    is => 'ro',
    isa => 'HashRef[CodeRef]',
    traits => ['Hash'],
    default => sub {return {}},
    init_arg => undef,
    required => 0,
    handles => {
        restriction => 'get',
    }
);

sub allow_tag {
    my $self = shift;
    my $tag = shift;
    my $part = shift;
    my $restriction = $self->restriction($tag);
    return 1 if (!defined $restriction);
    return $restriction->($self, $part);
}

sub _reverse_tag {
    my $tag = shift;
    return 'child' if ($tag eq 'parent');
    return 'parent' if ($tag eq 'child');
    return 'previous' if ($tag eq 'next');
    return 'next' if ($tag eq 'previous');
    return undef if ($tag eq 'first');
    return undef if ($tag eq 'last');
    return $tag;
}

sub _add_partlink {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my $partlink = ManaTools::Shared::disk_backend::PartLink->new(parent => $self, part => $part);
    my $count = $partlink->add_tags(@tags);
    return 0 if ($count == 0);
    return $partlink;
}

sub add_link {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my @rtags = grep { defined $_ } map { _reverse_tag($_) } @tags;
    my $partlink1 = $self->_add_partlink($part, @tags);
    my $partlink2 = $part->_add_partlink($self, @rtags);
    return ($partlink1, $partlink2);
}

sub add_taglink {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my @rtags = grep { defined $_ } map { _reverse_tag($_) } @tags;

    # partlink1
    my $partlink1 = $self->find_link($part);
    if (defined $partlink1) {
        $partlink1->add_tags(@tags);
    }
    else {
        $partlink1 = $self->_add_partlink($part, @tags);
    }

    # partlink2
    my $partlink2 = $part->find_link($self);
    if (defined $partlink2) {
        $partlink2->add_tags(@rtags);
    }
    else {
        $partlink2 = $part->_add_partlink($self, @rtags);
    }
    return ($partlink1, $partlink2);
}

sub has_link {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my $links = $self->links();
    for my $link (@{$links}) {
        return 1 if ($link->check($self, $part, @tags));
    }
    return 0;
}

sub find_link {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my $links = $self->links();
    for my $link (@{$links}) {
        return $link if ($link->check($self, $part, @tags));
    }
    return undef;
}

sub find_links {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my $links = $self->links();
    my @res = ();
    for my $link (@{$links}) {
        push @res, $self if ($link->check($self, $part, @tags));
    }
    return @res;
}

sub _remove_partlink {
    my $self = shift;
    my $partlink = shift;
    my $links = $self->links();
    my $i = scalar(@{$links});
    while ($i > 0) {
        $i = $i - 1;
        splice @{$links}, $i, 1 if ($links->[$i] == $partlink);
    }
}

sub remove_links {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my $links = $self->links();
    for my $link (@{$links}) {
        $self->_remove_partlink($link) if ($link->check($self, $part, @tags));
    }
}

sub remove_taglinks {
    my $self = shift;
    my $part = shift;
    my @tags = @_;
    my @rtags = grep { defined $_ } map { _reverse_tag($_) } @tags;

    # partlink1
    my $partlink1 = $self->find_link($part);
    if (defined $partlink1) {
        $partlink1->remove_tags(@tags);
        $self->_remove_partlink($partlink1) if ($partlink1->tagcount() == 0);
    }

    # partlink2
    my $partlink2 = $part->find_link($self);
    if (defined $partlink2) {
        $partlink2->remove_tags(@rtags);
        $part->_remove_partlink($partlink2) if ($partlink2->tagcount() == 0);
    }
    return ($partlink1, $partlink2);
}

sub find_parts {
    my $self = shift;
    my $parttype = shift;
    my @tags = @_;
    my $links = $self->links();
    my @res = ();
    for my $link (@{$links}) {
        push @res, $link->part() if ($link->check($self, $parttype, @tags));
    }
    return @res;
}

sub find_closest {
    my $self = shift;
    my $partstate = shift;
    my $identify = shift;
    my $parttype = shift;
    my $parameters = shift;
    my @tags = @_;
    my @res = ($self);
    while (scalar(@res) > 0) {
        my @next = ();
        for my $p (@res) {
            my $links = $p->links();
            for my $link (@{$links}) {
                if ($link->check($p, $parttype, @tags)) {
                    if (!defined $identify || $identify->($link->part(), $parameters)) {
                        # if it's the state we're looking for, just return it
                        return $link->part() if ($link->part()->is_state($partstate));
                    }

                    # add it to the next list to be checked
                    push @next, $link->part();
                }
            }
        }
        @res = @next;
    }
    return undef;
}

sub find_part {
    my $self = shift;
    my $parttype = shift;
    my @tags = @_;
    my $links = $self->links();
    my @res = ();
    for my $link (@{$links}) {
        return $link->part() if ($link->check($self, $parttype, @tags));
    }
    return undef;
}

sub children {
    my $self = shift;
    my @children = $self->find_parts(undef, 'child');
    return @children if (scalar(@children) == 0 || !defined $children[0]->order());
    my $child = $self->find_part(undef, 'first');
    return @children if (!defined $child);
    @children = ($child);
    while ($child = $child->find_part(undef, 'next')) {
        push @children, $child;
    }
    return @children;
}

sub find_recursive_parts {
    my $self = shift;
    my $parttype = shift;
    my @tags = @_;
    my $links = $self->links();
    my @res = ();
    for my $link (@{$links}) {
        if ($link->check($self, $parttype, @tags)) {
            my $part = $link->part();
            push @res, $part;
            for my $p ($part->find_recursive_parts($part, $parttype, @tags)) {
                push @res, $p;
            }
        }
    }
    return @res;
}

sub mkpart {
    my $self = shift;
    my $parttype = shift;
    my $parameters = shift;
    my @tags = @_;
    my $db = $self->db();
    my $part = $db->mkpart($parttype, $parameters);
    $self->add_taglink($part, @tags);
    return $part;
}

sub mkchild {
    my $self = shift;
    my $parttype = shift;
    my $parameters = shift;
    my @tags = @_;
    my $db = $self->db();
    # make the part
    my $part = $db->mkpart($parttype, $parameters);

    # add a sibling tag to all other children
    my @children = $self->children();
    for my $child (@children) {
        $part->add_taglink($child, 'sibling');
    }

    # if child has order, insert the child in 'previous' and 'next' tags, and re-mark 'first' and 'last' if applicable
    my $order = $part->order();
    if (defined $order) {
        for (my $i = 0; $i <= scalar(@children); $i = $i + 1) {
            if ($i < scalar(@children)) {
                if ($order->($part, $children[$i]) < 0) {
                    # insert
                    if ($i == 0) {
                        # remove first tag from first
                        $self->remove_taglinks($children[$i], 'first');

                        # tag it first
                        push @tags, 'first';
                    }
                    else {
                        # decouple prev and next
                        $children[$i - 1]->remove_taglinks($children[$i], 'next');
                        $children[$i]->remove_taglinks($children[$i - 1], 'previous');

                        # tag to the previous one
                        $part->add_taglink($children[$i - 1], 'previous');
                    }
                    # tag to the next one
                    $part->add_taglink($children[$i], 'next');

                    # make sure it doesn't go through this again
                    last;
                }
            }
            else {
                # append it instead
                if ($i > 0) {
                    # remove last tag from previous one, and tag it previous
                    $self->remove_taglinks($children[$i - 1], 'last');
                    $part->add_taglink($children[$i - 1], 'previous');
                }
                else {
                    # tag it first as well (because, there are no other children!)
                    push @tags, 'first';
                }
                # tag it last
                push @tags, 'last';
            }
        }
    }

    # tag the new part
    unshift @tags, 'child';
    $self->add_taglink($part, @tags);
    return $part;
}

sub trychild {
    my $self = shift;
    my $partstate = shift;
    my $identify = shift;
    my $parttype = shift;
    my $parameters = shift;
    my @tags = @_;
    my %params = ();

    # try to look for the child if it exists already
    for my $child ($self->children()) {

        # use the identification function
        if (!defined $identify || $identify->($child, $parameters)) {

            # if it's the state we're looking for, just return it
            return $child if ($child->is_state($partstate));

            # assign a link to the others, in case we'll need to create it
            # this way, it'll be already linked to the others
            $parameters->{loaded} = $child if ($child->is_loaded());
            $parameters->{probed} = $child if ($child->is_probed());
            $parameters->{saved} = $child if ($child->is_saved());
        }
    }

    # make a new child
    return $self->mkchild($parttype, $parameters, @tags);
}

sub changedpart {
    my $self = shift;
    my $partstate = shift;
    my $db = $self->db();
    return $db->changedpart($self, $partstate);
}

sub _save {
    return 1;
}

sub save {
    my $self = shift;
    return $self->_save();
}

sub _diff {
    return ();
}

sub diff {
    my $self = shift;
    my $partstate = shift;
    # get the other part
    my $part = $self->part_state($partstate);
    return () if (!defined $part);

    return $self->_diff($part, $partstate);
}

#=============================================================

=head2 label

=head3 OUTPUT

    label of the Part

=head3 DESCRIPTION

    this method returns the label for this Part

=cut

#=============================================================
sub label {
    my $self = shift;

    return $self->type;
}

#=============================================================

=head2 is_state

=head3 INPUT

    $state: PartState

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part is in this particular state

=cut

#=============================================================
sub is_state {
    my $self = shift;
    my $state = shift;
    return $self->is_loaded() if ($state == ManaTools::Shared::disk_backend::Part->LoadedState);
    return $self->is_current() if ($state == ManaTools::Shared::disk_backend::Part->CurrentState);
    return $self->to_be_saved() if ($state == ManaTools::Shared::disk_backend::Part->FutureState);
    return undef;
}

#=============================================================

=head2 part_state

=head3 INPUT

    $state: PartState

=head3 OUTPUT

    ManaTools::Shared::disk_backend::Part|undef

=head3 DESCRIPTION

    this method returns to requested state of this part

=cut

#=============================================================
sub part_state {
    my $self = shift;
    my $state = shift;
    return $self->loaded() if ($state == ManaTools::Shared::disk_backend::Part->LoadedState);
    return $self->probed() if ($state == ManaTools::Shared::disk_backend::Part->CurrentState);
    return $self->saved() if ($state == ManaTools::Shared::disk_backend::Part->FutureState);
    return undef;
}

#=============================================================

=head2 is_loaded

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part has been loaded like this (past state)

=cut

#=============================================================
sub is_loaded {
    my $self = shift;
    return ($self->loaded == $self);
}

#=============================================================

=head2 is_current

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part is how it actually currently is (current state)

=cut

#=============================================================
sub is_current {
    my $self = shift;
    return ($self->probed == $self);
}

#=============================================================

=head2 to_be_saved

=head3 OUTPUT

    bool

=head3 DESCRIPTION

    this method returns true if this part has changed and is awaiting saving (future state)

=cut

#=============================================================
sub to_be_saved {
    my $self = shift;
    return ($self->saved == $self);
}

#=============================================================

=head2 check_merge

=head3 DESCRIPTION

    this method checks if the other Part States are actually equal and merge back

=cut

#=============================================================
sub check_merge {
    my $self = shift;
    my $db = $self->db();

    $db->rmpart($self->loaded()) && $self->loaded($self) if !$self->is_loaded() && $self->equal($self->loaded());
    $db->rmpart($self->probed()) && $self->probed($self) if !$self->is_current() && $self->equal($self->probed());
    $db->rmpart($self->saved()) && $self->saved($self) if !$self->to_be_saved() && $self->equal($self->saved());
}

#=============================================================

=head2 unhook

=head3 DESCRIPTION

    this method returns removes the Part from the parent

=cut

#=============================================================
sub unhook {
    my $self = shift;
    $self->db->rmpart($self);
}


package ManaTools::Shared::disk_backend::PartLink;

use Moose;

has 'parent' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend::Part',
    required => 1,
    handles => {
        parenttype => 'type',
    },
    trigger => sub {
        my $self = shift;
        my $parent = $self->parent();
        my $links = $parent->links();
        push @{$links}, $self;
    }
);

has 'part' => (
    is => 'ro',
    isa => 'ManaTools::Shared::disk_backend::Part',
    required => 1,
    handles => {
        parttype => 'type',
    }
);

has 'tags' => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub {return []},
    handles => {
        tagcount => 'count',
    }
);

sub has_tag {
    my $self = shift;
    my $tag = shift;
    my $tags = $self->tags();
    for my $t (@{$tags}) {
        return 1 if $t eq $tag;
    }
    return 0;
}

sub is_tagged {
    my $self = shift;
    my @tags = @_;
    for my $tag (@tags) {
        return 0 if (defined $tag && !$self->has_tag($tag));
    }
    return 1;
}

sub check_parent {
    my $self = shift;
    my $parent = shift;
    return 1 if (!defined $parent);
    if (!ref($parent)) {
        return ($self->parenttype() == $parent);
    }
    return ($self->parent() == $parent);
}

sub check_part {
    my $self = shift;
    my $part = shift;
    return 1 if (!defined $part);
    if (!ref($part)) {
        return ($self->parttype() eq $part);
    }
    return ($self->part() == $part);
}

sub check {
    my $self = shift;
    my $parent = shift;
    my $part = shift;
    my @tags = @_;
    return ($self->check_parent($parent) && $self->check_part($part) && $self->is_tagged(@tags));
}

sub add_tag {
    my $self = shift;
    my $tag = shift;
    my $parent = $self->parent();
    return 1 if (!defined $tag || $self->has_tag($tag));
    return 0 if (!$parent->allow_tag($tag, $self->part()));
    my $tags = $self->tags();
    push @{$tags}, $tag;
    return 1;
}

sub add_tags {
    my $self = shift;
    my @tags = @_;
    my $count = 0;
    for my $tag (@tags) {
        $count = $count + $self->add_tag($tag);
    }
    return $count;
}

sub remove_tag {
    my $self = shift;
    my $tag = shift;
    my $tags = $self->tags();
    my $i = scalar(@{$tags});
    while ($i > 0) {
        $i = $i - 1;
        splice @{$tags}, $i, 1 if ($tags->[$i] eq $tag);
    }
}

sub remove_tags {
    my $self = shift;
    my @tags = @_;
    for my $tag (@tags) {
        $self->remove_tag($tag);
    }
}

1;
