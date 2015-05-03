# vim: set et ts=4 sw=4:
#
#    Copyright 2013-2015 Angelo Naselli
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

use ManaTools::Shared;
use Moose;

=head1 VERSION

Version 1.0.1

=cut

our $VERSION = '1.0.1';

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
);

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
);

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

    loc attribute defines localization object taht use "manatools"
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
        init_arg => undef,
        builder => '_localeInitialize'
);

sub _localeInitialize {
    my $self = shift;

    my $cmdline    = new yui::YCommandLine;
    my $locale_dir = ManaTools::Shared::custom_locale_dir();
    $self->loc(
        ManaTools::Shared::Locales->new(
            domain_name => 'manatools',
            dir_name    => $locale_dir,
        )
    );
}

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
