# vim: set et ts=4 sw=4:
package ManaTools::Shared::Logging;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::Logging - Class to manage logging

=head1 SYNOPSIS

use ManaTools::Shared::Logging;

my $obj = ManaTools::Shared::Logging->new(loc => $loc);

$obj->D("debug test string %d", 1) . "\n";
$obj->I("info test string %d", 2) . "\n";
$obj->W("warning test string %d", 3) . "\n";
$obj->E("error test string %d", 4) . "\n";

=head1 DESCRIPTION

This class wraps Sys::Syslog to manage logging


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::Logging

=head1 SEE ALSO

Sys::Syslog

=head1 AUTHOR

Maarten Vanraes <alien@rmail.be>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2015, Maarten Vanraes.

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
use diagnostics;
use utf8;
use Sys::Syslog;
use ManaTools::Shared::Locales;


#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        loc:         optional ManaTools::Shared::Locales to translate before logging

=head3 DESCRIPTION

    new is inherited from Moose, to create a Logging object

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

=head2 new

=head3 INPUT

    hash ref containing
        ident:         optional string used as identifier into syslog

=head3 DESCRIPTION

    new is inherited from Moose, to create a Logging object

=cut

#=============================================================
has 'ident' => (
    is      => 'ro',
    isa     => 'Str',
    default => ''
);

#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    Into this method additional data are initialized.
    This method just calls openlog if "ident" is set.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    Sys::Syslog::openlog($self->ident) if $self->ident;
}

#=============================================================

=head2 DEMOLISH

=head3 INPUT

    $val: boolean value indicating whether or not this method
        was called as part of the global destruction process
        (when the Perl interpreter exits)

=head3 DESCRIPTION

    Moose provides a hook for object destruction with the
    DEMOLISH method as it does for construtor with BUILD

=cut

#=============================================================
sub DEMOLISH {
    my ($self, $val) = @_;

    Sys::Syslog::closelog();
}

#=============================================================

=head2 R

=head3 INPUT

    $self: this object
    $syslog: syslog class and priority
    $s: text

=head3 DESCRIPTION

    outputs a string to syslog with given class and priority

=cut

#=============================================================
sub R {
    my $self = shift;
    my $syslog = shift;
    my $s = shift;

    Sys::Syslog::syslog($syslog, $s);
}

#=============================================================

=head2 P

=head3 INPUT

    $self: this object
    $syslog: syslog class and priority
    $s_singular: msg id singular
    $s_plural: msg id plural
    $nb: value for plural

=head3 DESCRIPTION

    outputs the given string localized (see dngettext) to syslog
    with the given class and priority

=cut

#=============================================================
sub P {
    my ($self, $syslog, $s_singular, $s_plural, $nb, @para) = @_;

    $self->R($syslog, $self->loc->P($s_singular, $s_plural, $nb, @para));
}

#=============================================================

=head2 S

=head3 INPUT

    $self: this object
    $syslog: syslog class and priority
    $s: text

=head3 DESCRIPTION

    outputs a localized string to syslog with given class and priority

=cut

#=============================================================
sub S {
    my ($self, $syslog, $s, @para) = @_;

    $self->R($syslog, $self->loc->N($s, @para));
}

#=============================================================

=head2 I

=head3 INPUT

    $self: this object
    $s: text

=head3 DESCRIPTION

    outputs a localized string to syslog as info|local1

=cut

#=============================================================
sub I {
    my ($self, $s, @para) = @_;

    $self->S('info|local1', $s, @para);
}

#=============================================================

=head2 W

=head3 INPUT

    $self: this object
    $s: text

=head3 DESCRIPTION

    outputs a localized string to syslog as warning

=cut

#=============================================================
sub W {
    my ($self, $s, @para) = @_;

    $self->S('warning', $s, @para);
}

#=============================================================

=head2 E

=head3 INPUT

    $self: this object
    $s: text

=head3 DESCRIPTION

    outputs a localized string to syslog as err

=cut

#=============================================================
sub E {
    my ($self, $s, @para) = @_;

    $self->S('err', $s, @para);
}

#=============================================================

=head2 D

=head3 INPUT

    $self: this object
    $s: text

=head3 DESCRIPTION

    outputs a localized string to syslog as debug

=cut

#=============================================================
sub D {
    my ($self, $s, @para) = @_;

    $self->S('debug', $s, @para);
}

#=============================================================

=head2 setmask

=head3 INPUT

    $self: this object
    $mask: new log mask

=head3 DESCRIPTION

    Sets the log mask for the current process to $mask and returns the old mask.
    See Sys::Syslog::setlogmask for details.

=cut

#=============================================================
sub setmask {
    my ($self, $mask) = @_;

    Sys::Syslog::setlogmask($mask);
}


no Moose;
__PACKAGE__->meta->make_immutable;


1;
