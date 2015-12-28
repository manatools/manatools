# vim: set et ts=4 sw=4:
package ManaTools::LoggingRole;
#============================================================= -*-perl-*-

=head1 NAME

    Manatools::LoggingRole - Role to manage configuration directory

=head1 SYNOPSIS

    package Foo;

    use Moose;
    with 'Manatools::LoggingRole';

    sub identifier {
        return "logger_identifier";
    }

    ...
    $self->logger->I("info message");
    ...

    1;

=head1 DESCRIPTION

    LoggingRole just define a role in which a ManaTools::Shared::Logging object can be used to log.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc Manatools::LoggingRole

=head1 SEE ALSO

    ManaTools::Shared::Logging

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
use ManaTools::Shared::Logging;

=head2 requires

=head3 definitions

        identifier: a string that is used as logging identifier

=cut
#=============================================================

requires 'identifier';

#=============================================================

=head2 logger

    logger attribute defines the Logging object
    see ManaTools::Shared::Logging for details and usage.

=cut

#=============================================================
has 'logger' => (
    is => 'ro',
    isa => 'ManaTools::Shared::Logging',
    init_arg => undef,
    lazy => 1,
    builder => '_loggerInitialize',
);

sub _loggerInitialize{
    my $self = shift;

    return ManaTools::Shared::Logging->new(ident => $self->identifier());
}


no Moose::Role;

1;
