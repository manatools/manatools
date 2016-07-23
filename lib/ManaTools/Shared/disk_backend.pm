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
    my @parts = $db_man->findpart($type);
    ...
    $db_man->save();
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

use ManaTools::Shared::Locales;
use ManaTools::Shared::Logging;

#=============================================================

=head2 loc

    loc attribute defines localization object that uses "manatools"
    domain as default. (see ManaTools::Shared::Locales for details).
    To use your own Module domain, override this attribute by using
        has '+loc' => (
            ...
        )
    or assign it again to your ManaTools::Shared::Locales object into
    the extension module implementation.

=cut

#=============================================================
has 'loc' => (
    is => 'rw',
    isa => 'ManaTools::Shared::Locales',
    lazy => 1,
    default => sub {
        return ManaTools::Shared::Locales->new();
    }
);


#=============================================================

=head2 logger

    logger attribute defines logging object that uses the loc attribute
    and goes to Syslog. (see ManaTools::Shared::Logging for details).
    You can use this attribute to log various messages:

        $log->D("debugstuff: %s", $somestring);
        $log->I("infostuff: %s", $somestring);
        $log->W("warnstuff: %s", $somestring);
        $log->E("errorstuff: %s", $somestring);

    if you wish to trace (goes to STDERR):

        $log->trace(1);

=cut

#=============================================================
has 'logger' => (
    is => 'rw',
    isa => 'ManaTools::Shared::Logging',
    lazy => 1,
    init_arg => undef,
    required => 0,
    default => sub {
        my $self = shift;
        # make sure to trigger loc & name first
        return ManaTools::Shared::Logging->new(loc => $self->loc(), ident => 'disk_backend');
    },
    handles => ['D','I','W','E'],
);

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
    push @{$self->parts()}, $part;
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

=head2 changedpart

=head3 INPUT

    $part: ManaTools::Shared::disk_backend::Part
    $state: PartState (L, P, S)

=head3 DESCRIPTION

    this method will call changedpart for all plugins, should only be called when a module is done with the changed part

=cut

#=============================================================
sub changedpart {
    my $self = shift;
    my $part = shift;
    my $state = shift;

    for my $plugin (@{$self->plugins}) {
        $plugin->changedpart($part, $state);
    }
}

#=============================================================

=head2 diff

=head3 INPUT

    $from: PartState (L, P, S)
    $to: PartState (L, P, S)

=head3 OUTPUT

    list of translated strings explaining the differences

=head3 DESCRIPTION

    this method will call diff on all Parts with $from state on their $to counterpart.

=cut

#=============================================================
sub diff {
    my $self = shift;
    my $from = shift;
    my $to = shift;

    my @res = ();
    for my $part (grep {$_->is_state($from)} @{$self->parts}) {
        for my $str ($part->diff($to)) {
            push @res, $str;
        }
    }
    return @res;
}

#=============================================================

=head2 findpart

=head3 INPUT

    $type: Str
    @tags: Str

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that match on a type and have all the tags

=cut

#=============================================================
sub findpart {
    my $self = shift;
    my $type = shift;
    my @tags = @_;

    return grep {(!defined $type || $_->type() eq $type) && $_->has_link(undef, @tags)} @{$self->parts};
}

#=============================================================

=head2 findnopart

=head3 INPUT

    $type: Str
    @tags: Str

=head3 OUTPUT

    array of Part

=head3 DESCRIPTION

    this method will return all Part that match on a type and do not have any of the tags

=cut

#=============================================================
sub findnopart {
    my $self = shift;
    my $type = shift;
    my @tags = @_;

    return grep {(!defined $type || $_->type() eq $type) && !$_->has_link(undef, @tags)} @{$self->parts};
}

#=============================================================

=head2 trypart

=head3 INPUT

    $partstate: PartState
    $identify: CodeRef
    $parttype: Str
    $parameters: HashRef

=head3 OUTPUT

    ManaTools::Shared::disk_backend::Part

=head3 DESCRIPTION

    this method will return the first matching Part or create a Part if not found

=cut

#=============================================================
sub trypart {
    my $self = shift;
    my $partstate = shift;
    my $identify = shift;
    my $parttype = shift;
    my $parameters = shift;

    # walk all parts and try to identify
    my $part = $self->walkparts($parttype, sub {
        my $part = shift;
        my $partstate = shift;
        my $identify = shift;
        my $parameters = shift;

        # use the identification function
        if (!defined $identify || $identify->($part, $parameters)) {

            # if it's the state we're looking for, just return it
            return 1 if ($part->is_state($partstate));

            # assign a link to the others, in case we'll need to create it
            # this way, it'll be already linked to the others
            $parameters->{loaded} = $part if ($part->is_loaded());
            $parameters->{probed} = $part if ($part->is_probed());
            $parameters->{saved} = $part if ($part->is_saved());
        }
    }, $partstate, $identify, $parameters);

    # create the part if it doesn't exist yet
    $part = $self->mkpart($parttype, $parameters) if (!defined $part);
    return $part;
}

#=============================================================

=head2 walkparts

=head3 INPUT

    $parttype: Str
    $code: CodeRef
    ...

=head3 OUTPUT

    a Plugin or undef

=head3 DESCRIPTION

    this method will return the first matching Plugin

=cut

#=============================================================
sub walkparts {
    my $self = shift;
    my $parttype = shift;
    my $code = shift;
    my @parameters = @_;
    for my $part (@{$self->parts()}) {
        if (!defined $parttype || $part->type() eq $parttype) {
            return $part if (!defined $code || $code->($part, @parameters));
        }
    }
    return undef;
}

#=============================================================

=head2 walkplugins

=head3 INPUT

    $code: CodeRef
    ...

=head3 OUTPUT

    a return value of the code or undef

=head3 DESCRIPTION

    this method will return the first non-zero return value from
    a code with each Plugin

=cut

#=============================================================
sub walkplugins {
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

    return grep {(( !defined($type) || $type eq $_->type() ) && $_->has_prop($prop) && ($_->prop($prop) eq $value))} @{$self->parts()};
}

1;
