# vim: set et ts=4 sw=4:
package ManaTools::ConfigDirRole;
#============================================================= -*-perl-*-

=head1 NAME

    Manatools::ConfigDirRole - Role to manage configuration directory

=head1 SYNOPSIS

    package Foo;

    use Moose;

    has 'configDir' => (
        ...
    );

    has 'configName' => (
        ...
    );
    with 'Manatools::ConfigDirRole';

    1;

=head1 DESCRIPTION

    ConfigDirRole just define a role in which the config dir is defined in a single point
    for all the module that uses it.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc Manatools::ConfigDirRole

=head1 SEE ALSO

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015, Angelo Naselli.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be
useful, but without any warranty; without even the implied
warranty of merchantability or fitness for a particular purpose

=cut

use Moose::Role;

=head2 requires

=head3 definitions

        configDir:          a root directory for configuration, e.g. a path
        configName:         a name under configDir in which to find configuration file

=cut
#=============================================================

requires 'configDir';
requires 'configName';

has 'defaultConfigDir' => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    default => '/etc/manatools',
);

#=============================================================

=head2 configPathName

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    return the path name, e.g. configDir/configName

=cut

#=============================================================
sub configPathName {
    my $self = shift;

    my $dir = $self->configDir() || $self->defaultConfigDir();
    chop $dir if substr($dir, -1) eq '/';

    return $dir . "/" . $self->configName();
}

1;
