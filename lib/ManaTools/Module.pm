# vim: set et ts=4 sw=4:
#
#    Copyright 2013-2017 Angelo Naselli
#    Copyright 2012 Steven Tucker
#
#    This file is part of ManaTools
#
#    ManaTools is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    ManaTools is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with ManaTools.  If not, see <http://www.gnu.org/licenses/>.


#Class Module
package ManaTools::Module;

use Moose;
with 'ManaTools::Version';

use ManaTools::Shared;
use ManaTools::Shared::Locales;
use ManaTools::Shared::Logging;
use ManaTools::Shared::GUI::CommandLine;

use yui;

#=============================================================

=head1 Attributes - Optional constructor parameters

=head2 icon

    icon attribute defines the Module icon, override this
    attribute by using
        has '+icon' => (
            ...
        )
    into your module implementation.

=cut

#=============================================================
has 'icon' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_iconInitializer',
);

sub _iconInitializer {
    my $self = shift;

    return File::ShareDir::dist_file(ManaTools::Shared::distName(), sprintf('images/%s.png', $self->name())),
}

#=============================================================

=head2 name

    name attribute defines the Module name, override this
    attribute by using
        has '+name' => (
            ...
        )
    into your module implementation.

=cut

#=============================================================
has 'name' => (
    is      => 'rw',
    isa     => 'Str',
    required => 1,
);

#=============================================================

=head2 title

    title attribute defines the Module title, override this
    attribute by using
        has '+title' => (
            ...
        )
    into your module implementation.

=cut

#=============================================================
has 'title' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_titleInitializer',
);

sub _titleInitializer {
    my $self = shift;

    return ($self->loc->N("%s - Management Tool", $self->name()));
}

#=============================================================

=head2 launch

    launch attribute defines the Module as external command
    to be run, pass this attribute to the "create" to set it.

=cut

#=============================================================

has 'launch' => (
    is      => 'rw',
    isa     => 'Str',
);

has 'button' => (
    is      => 'rw',
    init_arg => undef,
);

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
        return ManaTools::Shared::Logging->new(loc => $self->loc(), ident => $self->name());
    },
    handles => ['D','I','W','E'],
);


#=============================================================

=head2 commandline

    commandline attribute defines the given command line, if
    --help is passed help message is shown and the module is not
    loaded.
    See ManaTools::Shared::GUI::CommandLine for details and usage.

=cut

#=============================================================
has 'commandline' => (
    is => 'ro',
    isa => 'ManaTools::Shared::GUI::CommandLine',
    init_arg => undef,
    default => sub {
        return ManaTools::Shared::GUI::CommandLine->new_with_options();
    }
);



#=============================================================

=head1 SUBROUTINES/METHODS

=head2 create

=head3 INPUT

    %params:    moudule extension construtcor parameters
                --CLASS <name> name of the Class module extension name
                in the case of acting as a launcher mandatory parameters
                are name, icon and launch (see Attributes section of
                this manual)

=head3 DESCRIPTION

    returns a Module instance, such as a module launcher
    (this object) or an extension of this class

=cut

#=============================================================
sub create {
    my $class = shift;
    $class = ref $class || $class;
    my (%params) = @_;

    my $obj;
    if ( exists $params{-CLASS} ) {
        my $driver = $params{-CLASS};

        eval {
            my $pkg = $driver;
            $pkg =~ s/::/\//g;
            $pkg .= '.pm';
            require $pkg;
            $obj=$driver->new();
        };
        if ( $@ ) {
            die "Error getting obj for driver $params{-CLASS}: $@";
            return undef;
        }
    }
    else {
        $obj = new ManaTools::Module(@_);
    }
    return $obj;
}

#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    base Module class sets title and icon

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    ## set title
    yui::YUI::app()->setApplicationTitle($self->title) if $self->title;
    ## set icon
    yui::YUI::app()->setApplicationIcon($self->icon) if $self->icon;
}

#=============================================================

=head2 setButton

=head3 INPUT

    $self:   this object
    $button: yui push button to be assigned to this module

=head3 DESCRIPTION

    This method assignes a button to this module

=cut

#=============================================================
sub setButton {
    my ($self, $button) = @_;
    $self->{button} = $button;
}

#=============================================================

=head2 removeButton

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method remove the assigned button from this module

=cut

#=============================================================
sub removeButton {
    my($self) = @_;

    undef($self->{button});
}

# base class launcher
#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method is the base class launcher that runs an external
    module, defined in launch attribute.

=cut

#=============================================================
sub start {
    my $self = shift;

    if ($self->{launch}) {
        my $err = yui::YUI::app()->runInTerminal( $self->{launch} . " --ncurses");
        if ($err == -1) {
            system($self->{launch});
        }
    }
}


no Moose;
1;
