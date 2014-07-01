#!/usr/bin/perl
# vim: set et ts=4 sw=4:
#    Copyright 2012-2013 Angelo Naselli <anaselli@linux.it>
#    Copyright 2013-2014 Matteo Pasotti <matteo.pasotti@gmail.com>
#
#    This file is part of AdminPanel
#
#    AdminPanel is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    AdminPanel is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.

package AdminPanel::Shared;

=head1 NAME

AdminPanel::Shared - AdminPanel::Shared contains all the shared routines 
                     needed by AdminPanel and modules

=head1 SYNOPSIS

    

=head1 DESCRIPTION

This module collects all the routines shared between AdminPanel and its modules.

=head1 EXPORT

    trim 
    member
    md5sum
    pathList2hash

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc AdminPanel::Shared

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2013, Angelo Naselli.
Copyright (C) 2014, Matteo Pasotti.

This file is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This file is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this file.  If not, see <http://www.gnu.org/licenses/>.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use diagnostics;

use Digest::MD5;

use yui;
use base qw(Exporter);

# TODO move GUI dialogs to Shared::GUI
our @EXPORT = qw(
                trim 
                member
                md5sum
                pathList2hash
);


=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';



#=============================================================

=head2 trim

=head3 INPUT

    $st: String to be trimmed

=head3 OUTPUT

    $st: trimmed string

=head3 DESCRIPTION

This function trim the given string.

=cut

#=============================================================

sub trim {
    my ($st) = shift;
    $st =~s /^\s+//g;
    $st =~s /\s+$//g;
    return $st;
}

#=============================================================

=head2 member

=head3 INPUT

    $e: Array element to be found into array
    @_: any array

=head3 OUTPUT

    1 or 0: if $e is a member of the given array

=head3 DESCRIPTION

This function look for an element into an array

=cut

#=============================================================
sub member { 
    my $e = shift; 
    foreach (@_) { 
        $e eq $_ and return 1;
    } 
    0; 
}

#=============================================================

=head2 md5sum

=head3 INPUT

$filename: file for md5 calculation

=head3 OUTPUT

md5 sum

=head3 DESCRIPTION

 compute MD5 for the given file

=cut

#=============================================================

sub md5sum {
    my @files = @_;

    my @md5 = map {
        my $sum;
        if (open(my $FILE, $_)) {
            binmode($FILE);
            $sum = Digest::MD5->new->addfile($FILE)->hexdigest;
            close($FILE);
        }
        $sum;
    } @files;
    return wantarray() ? @md5 : $md5[0];
}

#=============================================================

=head2 pathList2hash

=head3 INPUT

$param : HASH ref containing
        paths     =>  ARRAY of string containing path like strings
        separator => item separator inside a single path
                     (default separator is /)

=head3 OUTPUT

\%tree: HASH reference containing the same structur passed as ARRAY
        in a tree view form, leaves are undef.

=head3 DESCRIPTION

This function return a tree representation of the given array.

=cut

#=============================================================

sub pathList2hash {
    my ($param) = @_;

    die "array of path is missing" if ! exists $param->{paths};
    my $separator = '/';
    $separator = $param->{separator} if $param->{separator};
    if ($separator eq "/" || $separator eq "|") {
        $separator = '\\' . $separator;
    }

    my %tree;
    for (@{$param->{paths}})
    {
        my $last = \\%tree;
        $last = \$$last->{$_} for split /$separator/;
    }

    return \%tree;
}

#=============================================================

=head2 disable_x_screensaver

=head3 DESCRIPTION

if exists /usr/bin/xset disable screensaver

=cut

#=============================================================
sub disable_x_screensaver() {
    if (-e '/usr/bin/xset') {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        system ("/usr/bin/xset s off");
        system ("/usr/bin/xset -dpms");
    }
}

#=============================================================

=head2 enable_x_screensaver

=head3 DESCRIPTION

if exists /usr/bin/xset enables screensaver

=cut

#=============================================================
sub enable_x_screensaver() {
    if (-e '/usr/bin/xset') {
        $ENV{PATH} = "/usr/bin:/usr/sbin";
        system ("/usr/bin/xset +dpms");
        system ("/usr/bin/xset s on");
        system ("/usr/bin/xset s reset");
    }
}

1; # End of AdminPanel::Shared

