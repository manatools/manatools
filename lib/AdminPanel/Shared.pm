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
                md5sum
                pathList2hash
                distName
                apcat
                find
);


=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';



#=============================================================

=head2 apcat

=head3 PARAMETERS

$filename the name of the file to read

=head3 OUTPUT

$content the content of the selected text file inside

=head3 DESCRIPTION

This function return the content of $filename or false/0
if it fails

=cut

#=============================================================

#sub apcat {
#    my $fn = shift();
#    my $fh = undef;
#    my @content = ();
#    open($fh, "<", $fn) || return 0;
#    while(<$fh>)
#    {
#        push(@content,$_);
#    }
#    return \@content;
#}

sub apcat {
    my $fn = shift();
    my $fh = undef;
    my $content = undef;
    open($fh, "<", $fn) || return 0;
    while(<$fh>)
    {
        $content .= $_;
    }
    return $content;
}


#=============================================================

=head2 find

=head3 PARAMETERS

$code the CODE to search for inside the LIST

=head3 OUTPUT

returns the first element where CODE returns true (or returns undef)

=head3 EXAMPLE

find { /foo/ } "fo", "fob", "foobar", "foobir"
gives "foobar"

=cut

#============================================================

sub find(&@) {
    my $f = shift;
    $f->($_) and return $_ foreach @_;
    undef;
}

#=============================================================

=head2 distName

=head3 OUTPUT

$distname: name of the distributed package

=head3 DESCRIPTION

This function return the distname, useful to retrieve data
with File::ShareDir::dist_file and must be the same as into
Makefile.PL (e.g. adminpanel)

=cut

#=============================================================

sub distName {
    return "adminpanel";
}


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

