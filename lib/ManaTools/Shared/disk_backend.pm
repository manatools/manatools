# vim: set et ts=4 sw=4:
package ManaTools::Shared::disk_backend;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::disk_backend - disks backend class

=head1 SYNOPSIS

    use ManaTools::Shared::disk_backend;

    my $db_man = ManaTools::Shared::disk_backend->new();
    $db_man->load();
    $db_man->probe();
    $db_man->findin($io);
    $db_man->findout($io);
    $db_man->findnoin();
    $db_man->findnoout();
    my @parts = $db_man->findpart($type);
    my @ios = $db_man->findioprop($prop, $value);
    ...
    $db_man->save();
    $db_man->mkio('Foo', {id => 'foo-id', other => 'value'});
    $db_man->mkpart('Foo', {other => 'value'});


=head1 DESCRIPTION

    This plugin is a backend to manadisk

=head1 SUPPORT

    You can find documentation for this plugin with the perldoc command:

    perldoc ManaTools::Shared::disk_backend


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

use File::Basename;
use Module::Path qw(module_path);


has 'plugins' => (
    is => 'ro',
    isa => 'ArrayRef[ManaTools::Shared::disk_backend::Plugin]',
    default => sub {
        my $self = shift;
        my $plugins = [];
        my @more = ();
        for my $pluginfile (glob((module_path($self->blessed()) =~ s/\.pm$//r ) ."/Plugin/*.pm")) {
            my $pluginclass = "ManaTools::Shared::disk_backend::Plugin::". basename($pluginfile, '.pm');
            require $pluginfile;
            my $plugin = $pluginclass->new(parent => $self);
            if ($self->_check_dependencies($plugins, @{$plugin->dependencies()})) {
                push @{$plugins}, $plugin;
            }
            else {
                push @more, $plugin;
            }
        }
        # reorder the other plugins correctly according to dependencies
        my $progress = 1;
        while ($progress && scalar(@more) > 0) {
            $progress = 0;
            my $i = 0;
            while ($i < scalar(@more)) {
                if ($self->_check_dependencies($plugins, @{$more[$i]->dependencies()})) {
                    # move plugin from @more to $plugins
                    push @{$plugins}, $more[$i];
                    $progress = 1;
                    splice @more, $i, 1;
                }
                else {
                    $i = $i + 1;
                }
            }
        }
        return $plugins;
    }
);

has 'ios' => (
    is => 'rw',
    isa =>'HashRef[ManaTools::Shared::disk_backend::IO]',
    default => sub {
        return {};
    }
);

has 'parts' => (
    is => 'rw',
    isa =>'ArrayRef[ManaTools::Shared::disk_backend::Part]',
    default => sub {
        return [];
    }
);


#=============================================================

=head2 _check_dependencies

=head3 OUTPUT

    1 if true, 0 otherwise

=head3 DESCRIPTION

    this method checks to see if plugins are already loaded

=cut

#=============================================================
sub _check_dependencies {
    my $self = shift;
    my $plugins = shift;
    while (my $plugin = shift) {
        if (! grep { blessed($_) eq 'ManaTools::Shared::disk_backend::Plugin::'. $plugin } @{$plugins}) {
            return 0;
        }
    }
    return 1;
}

#=============================================================

=head2 mkio

=head3 OUTPUT

    ManaTools::Shared::disk_backend::IO subclass

=head3 DESCRIPTION

    this method creates an IO and adds it to the list if it does not already exists, and returns the IO

=cut

#=============================================================
sub mkio {
    my $self = shift;
    my $class = 'ManaTools::Shared::disk_backend::IO::'. shift;
    my $parameters = shift;
    defined($parameters->{'id'}) or die('id is a required parameter when creating IO');
    my $id = $parameters->{'id'};
    if (!defined($self->ios->{$id})) {
        $self->ios->{$id} = $class->new(%$parameters);
        $self->ios->{$id}->db($self);
        $self->probeio($self->ios->{$id});
    }
    return $self->ios->{$id};
}

#=============================================================

=head2 rmio

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO subclass

=head3 DESCRIPTION

    this method removes a IO and returns the IO

=cut

#=============================================================
sub rmio {
    my $self = shift;
    my $io = shift;
    my $parts = $self->parts();
    my $ios = $self->ios();
    delete $ios->{$io->id()};
    # walk parts and remove io from ins or outs
    for my $part (@{$parts}) {
        $part->rmio($io);
    }
    return $io;
}

#=============================================================

=head2 mkpart

=head3 OUTPUT

    ManaTools::Shared::disk_backend::Part subclass

=head3 DESCRIPTION

    this method creates a Part and returns the Part

=cut

#=============================================================
sub mkpart {
    my $self = shift;
    my $class = 'ManaTools::Shared::disk_backend::Part::'. shift;
    my $parameters = shift;
    my $part = $class->new(%$parameters);
    $part->db($self);
    push @{$self->parts}, $part;
    return $part;
}

#=============================================================

=head2 rmpart

=head3 INPUT

    $part: ManaTools::Shared::disk_backend::Part subclass

=head3 DESCRIPTION

    this method removes a Part and returns the Part

=cut

#=============================================================
sub rmpart {
    my $self = shift;
    my $part = shift;
    my $parts = $self->parts();
    my $i = scalar(@{$parts});
    while ($i >= 0) {
        $i = $i - 1;
        if ($parts->[$i] eq $part) {
            splice @{$parts}, $i;
            return $part;
        }
    }
    return $part;
}

#=============================================================

=head2 load

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method loads the config files for all plugins

=cut

#=============================================================
sub load {
    my $self = shift;

    for my $plugin (@{$self->plugins}) {
        $plugin->load();
    }
    1;
}

#=============================================================

=head2 save

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method saves the config files for all plugins

=cut

#=============================================================
sub save {
    my $self = shift;

    for my $plugin (@{$self->plugins}) {
        $plugin->save();
    }
    1;
}

#=============================================================

=head2 probe

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will call probe for all plugins and merge results of the probe

=cut

#=============================================================
sub probe {
    my $self = shift;

    for my $plugin (@{$self->plugins}) {
        $plugin->probe();
    }
    1;
}

#=============================================================

=head2 probeio

=head3 OUTPUT

    0 if failed, 1 if success

=head3 DESCRIPTION

    this method will call probeio for all plugins and merge results of the probe

=cut

#=============================================================
sub probeio {
    my $self = shift;
    my $io = shift;

    for my $plugin (@{$self->plugins}) {
        $plugin->probeio($io);
    }
    1;
}

#=============================================================

=head2 findin

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO
    $state: ManaTools::Shared::disk_backend::Part::PartState|undef

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that match on an in IO

=cut

#=============================================================
sub findin {
    my $self = shift;
    my $io = shift;
    my $state = shift;

    return grep {scalar(grep {$io eq $_} $_->get_ins()) > 0 && (!defined $state || $_->is_state($state))} @{$self->parts};
}

#=============================================================

=head2 findout

=head3 INPUT

    $io: ManaTools::Shared::disk_backend::IO
    $state: ManaTools::Shared::disk_backend::Part::PartState|undef

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that match on an out IO

=cut

#=============================================================
sub findout {
    my $self = shift;
    my $io = shift;
    my $state = shift;

    return grep {scalar(grep {$io eq $_} $_->get_outs()) > 0 && (!defined $state || $_->is_state($state))} @{$self->parts};
}

#=============================================================

=head2 findnoin

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that have no ins

=cut

#=============================================================
sub findnoin {
    my $self = shift;
    my $io = shift;

    return grep {$_->in_length() == 0} @{$self->parts};
}

#=============================================================

=head2 findoutnoin

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that have outs, but no ins

=cut

#=============================================================
sub findoutnoin {
    my $self = shift;
    my $io = shift;

    return grep {$_->in_length() == 0 && $_->out_length() > 0} @{$self->parts};
}

#=============================================================

=head2 findnoout

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that have no outs

=cut

#=============================================================
sub findnoout {
    my $self = shift;
    my $io = shift;

    return grep {$_->out_length() == 0} @{$self->parts};
}

#=============================================================

=head2 findinnoout

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that have ins, but no outs

=cut

#=============================================================
sub findinnoout {
    my $self = shift;
    my $io = shift;

    return grep {$_->out_length() == 0 && $_->in_length() > 0} @{$self->parts};
}

#=============================================================

=head2 findpart

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that match on a type

=cut

#=============================================================
sub findpart {
    my $self = shift;
    my $type = shift;

    return grep {$_->type() eq $type} @{$self->parts};
}

#=============================================================

=head2 walkplugins

=head3 INPUT

    $code: CodeRef
    ...

=head3 OUTPUT

    a Plugin or undef

=head3 DESCRIPTION

    this method will return the first matching Plugin

=cut

#=============================================================
sub walkplugin {
    my $self = shift;
    my $code = shift;
    my @parameters = @_;
    my $plugins = $self->plugins;
    for my $plugin (@{$plugins}) {
        my $res = $code->($plugin, @parameters);
        return $res if ($res);
    }
    return undef;
}

#=============================================================

=head2 findioprop

=head3 OUTPUT

    array of IO

=head3 DESCRIPTION

    this method will return all IO that matches on a prop value

=cut

#=============================================================
sub findioprop {
    my $self = shift;
    my $prop = shift;
    my $value = shift;

    return grep {$_->has_prop($prop) && $_->prop($prop) eq $value} values %{$self->ios};
}

#=============================================================

=head2 findpartprop

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that matches on a prop value and optionally a type

=cut

#=============================================================
sub findpartprop {
    my $self = shift;
    my $type = shift;
    my $prop = shift;
    my $value = shift;

    return grep {( !defined($type) || $type eq $_->type() ) && $_->has_prop($prop) && $_->prop($prop) eq $value} @{$self->parts};
}

1;
