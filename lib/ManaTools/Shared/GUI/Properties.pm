# vim: set et ts=4 sw=4:
package ManaTools::Shared::GUI::Properties;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::GUI::Properties - Class to manage a yui YProperties properly

=head1 SYNOPSIS

package FooProps;

with 'ManaTools::Shared::PropertiesRole';

...


use ManaTools::Shared::GUI::Properties;

my $hbox = ...
my $foo = FooProps->new();
my $properties = ManaTools::Shared::GUI::Properties->new(parentWidget => $hbox, properties => $foo);
$foo->prop('bar', 'baz');
$properties->refresh();
...

=head1 DESCRIPTION

This class wraps YProperties and it's child widgets to handle


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::GUI::Properties

=head1 SEE ALSO

yui::YProperties

=head1 AUTHOR

Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015-2016, Maarten Vanraes.

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

use ManaTools::Shared::GUI::ReplacePoint;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        parentWidget: the parent widget
        properties: the properties object

=head3 DESCRIPTION

    new is inherited from Moose, to create a Properties object

=cut

#=============================================================

has 'parentDialog' => (
    is => 'ro',
    isa => 'ManaTools::Shared::GUI::Dialog',
    required => 1,
);

has 'parentWidget' => (
    is => 'ro',
    isa => 'yui::YWidget',
    required => 1,
);

has 'properties' => (
    is => 'rw',
    does => 'Maybe[ManaTools::Shared::PropertiesRole]',
    trigger => \&refresh,
    default => undef,
);

has 'replacepoint' => (
    is => 'ro',
    isa => 'ManaTools::Shared::GUI::ReplacePoint',
    init_arg => undef,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $rpl = ManaTools::Shared::GUI::ReplacePoint->new(eventHandler => $self->parentDialog(), parentWidget => $self->parentWidget());
        $rpl->finished();
        return $rpl;
    },
);

#=============================================================

=head2 refresh

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    rebuilds the properties

=cut

#=============================================================
sub refresh {
    my $self = shift;
    my $dialog = $self->parentDialog();
    my $factory = $dialog->factory();
    my $parentWidget = $self->parentWidget();
    my $replacepoint = $self->replacepoint();
    my $properties = $self->properties();

    # clear and start new changes on replacepoint
    $replacepoint->clear();
    if (defined $properties) {
        my $vbox = $factory->createVBox($replacepoint->container());
        # rebuild for all properties a hbox with label and outfield
        for my $key (sort $properties->properties()) {
            # $properties->prop($key)
            my $hbox = $factory->createHBox($vbox);
            $factory->createLabel($hbox, $key .': ');
            my $val = $properties->prop($key);
            $val = '' if (!defined($val));
            $val = '' if (ref($val) != '');
            $val = ''. $val;
            $factory->createOutputField($hbox, $val);
            $factory->createHStretch($hbox);
        }
    }
    # finished
    $replacepoint->finished();
}

#=============================================================

no Moose;
__PACKAGE__->meta->make_immutable;


1;
