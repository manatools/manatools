# vim: set et ts=4 sw=4:
package ManaTools::Shared::Visualization;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::Visualization - an Visualization helper class

=head1 SYNOPSIS

    use ManaTools::Shared::Visualization;

    has 'visualization' => (
        isa => 'VisualizationType',
        default => ManaTools::Shared::Visualization->treeVisualization,
    );


=head1 DESCRIPTION

    This helper class is used to abstract the Visualization

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::Visualization


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

use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

subtype 'VisualizationType'
    => as Int
    => where {($_ >= 0 && $_ <= 4)};

class_has 'noVisualization' => (
    is => 'ro',
    isa => 'VisualizationType',
    init_arg => undef,
    default => sub {return 0;},
);

class_has 'listVisualization' => (
    is => 'ro',
    isa => 'VisualizationType',
    init_arg => undef,
    default => sub {return 1;},
);

class_has 'treeVisualization' => (
    is => 'ro',
    isa => 'VisualizationType',
    init_arg => undef,
    default => sub {return 2;},
);

class_has 'tabVisualization' => (
    is => 'ro',
    isa => 'VisualizationType',
    init_arg => undef,
    default => sub {return 3;},
);

class_has 'buttonboxVisualization' => (
    is => 'ro',
    isa => 'VisualizationType',
    init_arg => undef,
    default => sub {return 4;},
);

1;

