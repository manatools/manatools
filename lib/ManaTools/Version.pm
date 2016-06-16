# vim: set et ts=4 sw=4:
package ManaTools::Version;
#============================================================= -*-perl-*-

=head1 NAME

    Manatools::Version - Role to manage command line

=head1 SYNOPSIS

    package Foo;

    use Moose;
    with 'Manatools::Version';

    1;

=head1 DESCRIPTION

    Version just define a role in which command line is accessible.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc Manatools::Version

=head1 SEE ALSO

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015-2016, Angelo Naselli.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be
useful, but without any warranty; without even the implied
warranty of merchantability or fitness for a particular purpose

=cut

use Moose::Role;

=head2 attributes

=head3 definitions

    Version: manatools common version override it
             if you want your own versioning

=cut
#=============================================================

=head1 VERSION

    Version 1.1.3
    See Changes for details

=cut

our $VERSION = '1.1.3';

has 'Version' => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    default  => sub {
        return $VERSION;
    }
);


no Moose::Role;

1;
