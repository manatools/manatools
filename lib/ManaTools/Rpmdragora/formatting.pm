# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::formatting;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2006 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005, 2006 Mandriva SA
#  Copyright (c) 2013-2016 Matteo Pasotti <matteo.pasotti@gmail.com>
#  Copyright (c) 2014-2016 Angelo Naselli <anaselli@linux.it>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License version 2, as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#*****************************************************************************
#
# $Id: formatting.pm 261189 2009-10-01 14:44:39Z tv $

use strict;
use utf8;
use POSIX qw(strftime);
use MDK::Common::Various qw(internal_error);
use ManaTools::Shared::Locales;
use ManaTools::rpmdragora;
use urpm::msg;


use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                    $spacing
                    ensure_utf8
                    format_changelog_changelogs
                    format_changelog_string
                    format_field
                    format_header
                    format_list
                    format_name_n_summary
                    format_size
                    format_filesize
                    format_update_field
                    my_fullname
                    pkg2medium
                    rpm_description
                    split_fullname
                    urpm_name
            );

my $loc = ManaTools::rpmdragora::locale();

sub escape_text_for_TextView_markup_format {
    my ($str) = @_;
    return '' if !$str;

    my %rules = ('&' => '&amp;',
                 '<' => '&lt;',
                 '>' => '&gt;',
    );
    eval { $str =~ s!([&<>])!$rules{$1}!g }; #^(&(amp|lt|gt);)!!) {
    if (my $err = $@) {
        MDK::Common::Various::internal_error("$err\n$str");
    }
    $str;
}

# from rpmtools, #37482:
sub ensure_utf8 {
    return '' if !$_[0];

    if (utf8::is_utf8($_[0])) {
        utf8::valid($_[0]) and return;
        utf8::encode($_[0]); #- disable utf8 flag
        utf8::upgrade($_[0]);
    } else {
        utf8::decode($_[0]); #- try to set utf8 flag
        utf8::valid($_[0]) and return;
        warn "do not know what to with $_[0]\n";
    }
}

sub rpm_description {
    my ($description) = @_;
    return '' if !$description;

    ensure_utf8($description);
    my $t   = "";
    my $tmp = "";
    foreach (split "\n", $description) {
        s/^\s*//;
        if (/^$/ || /^\s*(-|\*|\+|o)\s/) {
            $t || $tmp and $t .= "$tmp\n";
            $tmp = $_;
        } else {
            $tmp = ($tmp ? "$tmp " : ($t && "\n") . $tmp) . $_;
        }
    }
    "$t$tmp\n";
}

sub split_fullname { $_[0] =~ /^(.*)-([^-]+)-([^-]+)\.([^.-]+)$/ }

sub my_fullname {
    return '?-?-?' unless ref $_[0];
    my ($name, $version, $release) = $_[0]->fullname;
    "$name-$version-$release";
}

sub urpm_name {
    return '?-?-?.?' unless ref $_[0];
    scalar $_[0]->fullname;
}

sub pkg2medium {
    my ($p, $urpm) = @_;
    return if !ref $p;
    return { name => $loc->N("None (installed)") } if !defined($p->id); # if installed
    URPM::pkg2media($urpm->{media}, $p) || { name => $loc->N("Unknown"), fake => 1 };
}

# [ duplicate urpmi's urpm::msg::localtime2changelog() ]
#- strftime returns a string in the locale charset encoding;
#- but gtk2 requires UTF-8, so we use to_utf8() to ensure the
#- output of localtime2changelog() is always in UTF-8
#- as to_utf8() uses LC_CTYPE for locale encoding and strftime() uses LC_TIME,
#- it doesn't work if those two variables have values with different
#- encodings; but if a user has a so broken setup we can't do much anyway
sub localtime2changelog { $loc->to_utf8(POSIX::strftime("%c", localtime($_[0]))) }

our $spacing = "        ";
sub format_changelog_string {
    my ($installed_version, $string) = @_;

    #- preprocess changelog for faster TextView insert reaction
    my $version;
    my $highlight;
    my $chl = [ map {
        my %attrs;
        if (/^\*/) {
            ($version) = /(\S*-\S*)\s*$/;
            $highlight = $installed_version ne $loc->N("(none)") && 0 < URPM::rpmvercmp($version, $installed_version);
            if ($highlight) {
                "<b><i>" . $_ . "</i></b>";
            }
            else {
                "<b>" . $_ . "</b>";
            }
        }
        else {
            "$spacing" . $_ . "\n";
        }
    } split("\n", $string) ];

    return $chl;
}

sub format_changelog_changelogs {
    my ($installed_version, @changelogs) = @_;
    format_changelog_string($installed_version, join("\n", map {
        "* " . localtime2changelog($_->{time}) . " $_->{name}\n\n$_->{text}\n";
    } @changelogs));
}

sub format_update_field {
    my ($name) = @_;
    '<i>' . escape_text_for_TextView_markup_format($name) . '</i>';
}

sub format_name_n_summary {
    my ($name, $summary) = @_;
    join("\n", '<b>' . $name . '</b>', escape_text_for_TextView_markup_format($summary));
}

sub format_header {
    my ($str) = @_;
    '<big>' . escape_text_for_TextView_markup_format($str) . '</big>';
}

sub format_field {
    my ($str) = @_;
    '<b>' . escape_text_for_TextView_markup_format($str) . '</b>';
}

sub format_size {
    my ($size) = @_;
    $size >= 0 ?
      $loc->N("%s of additional disk space will be used.", formatXiB($size)) :
        $loc->N("%s of disk space will be freed.", formatXiB(-$size));
}

sub format_filesize {
    my ($filesize) = @_;
    $filesize ? $loc->N("%s of packages will be retrieved.", formatXiB($filesize)) : ();
}

sub format_list {
    return join("\n", map { s/^(\s)/  $1/mg; "- $_" } sort { uc($a) cmp uc($b) } @_);
}

1;
