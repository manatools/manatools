# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::init;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
#  Copyright (c) 2013 Matteo Pasotti <matteo.pasotti@gmail.com>
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
# $Id: init.pm 263915 2009-12-03 17:41:04Z tv $

use strict;
use MDK::Common::Func 'any';
use lib qw(/usr/lib/libDrakX);
use common;
use English;
BEGIN { $::no_global_argv_parsing = 1 }
require urpm::args;

use AdminPanel::Privileges;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(init
                 warn_about_user_mode
                 $MODE
                 $changelog_first
                 $default_list_mode
                 %rpmdragora_options
                 @ARGV_copy
                 );

our @ARGV_copy =  @ARGV;

BEGIN {  #- we want to run this code before the Gtk->init of the use-my_gtk
    my $basename = sub { local $_ = shift; s|/*\s*$||; s|.*/||; $_ };
    any { /^--?h/ } @ARGV and do {
	printf join("\n", N("Usage: %s [OPTION]...", $basename->($0)),
N("  --auto                 assume default answers to questions"),
N("  --changelog-first      display changelog before filelist in the description window"),
N("  --media=medium1,..     limit to given media"),
N("  --merge-all-rpmnew     propose to merge all .rpmnew/.rpmsave files found"),
N("  --mode=MODE            set mode (install (default), remove, update)"),
N("  --justdb               update the database, but do not modify the filesystem"),
N("  --no-confirmation      don't ask first confirmation question in update mode"),
N("  --no-media-update      don't update media at startup"),
N("  --no-verify-rpm        don't verify package signatures"),
if_($0 !~ /MageiaUpdate/, N("  --parallel=alias,host  be in parallel mode, use \"alias\" group, use \"host\" machine to show needed deps")),
N("  --rpm-root=path        use another root for rpm installation"),
N("  --urpmi-root           use another root for urpmi db & rpm installation"),
N("  --run-as-root          force to run as root"),
N("  --search=pkg           run search for \"pkg\""),
N("  --test                 only verify if the installation can be achieved correctly"),
chomp_(N("  --version              print this tool's version number
")),
""
);
	exit 0;
    };
}

BEGIN { #- for mcc
    if ("@ARGV" =~ /--embedded (\w+)/) {
	$::XID = $1;
	$::isEmbedded = 1;
    }
}


#- This is needed because text printed by Gtk2 will always be encoded
#- in UTF-8; we first check if LC_ALL is defined, because if it is,
#- changing only LC_COLLATE will have no effect.
use POSIX qw(setlocale LC_ALL LC_COLLATE strftime);
use locale;
my $collation_locale = $ENV{LC_ALL};
if ($collation_locale) {
  $collation_locale =~ /UTF-8/ or setlocale(LC_ALL, "$collation_locale.UTF-8");
} else {
  $collation_locale = setlocale(LC_COLLATE);
  $collation_locale =~ /UTF-8/ or setlocale(LC_COLLATE, "$collation_locale.UTF-8");
}

our $version = 1;
our %rpmdragora_options;

my $i;
foreach (@ARGV) {
    $i++;
    /^-?-(\S+)$/ or next;
    my $val = $1;
    if ($val =~ /=/) {
        my ($name, $values) = split /=/, $val;
        my @values = split /,/, $values;
        $rpmdragora_options{$name} = \@values if @values;
    } else {
        if ($val eq 'version') {
            print "$0 $version\n";
            exit(0);
       } elsif ($val =~ /^(test|expert)$/) {
           eval "\$::$1 = 1";
       } elsif ($val =~ /^(q|quiet)$/) {
           urpm::args::set_verbose(-1);
       } elsif ($val =~ /^(v|verbose)$/) {
           urpm::args::set_verbose(1);
       } else {
           $rpmdragora_options{$val} = 1;
       }
    }
}

foreach my $option (qw(media mode parallel rpm-root search)) {
    if (defined $rpmdragora_options{$option} && !ref($rpmdragora_options{$option})) {
        warn qq(wrong usage of "$option" option!\n);
        exit(-1); # too early for my_exit()
    }
}

$urpm::args::options{basename} = 1;

our $MODE = ref $rpmdragora_options{mode} ? $rpmdragora_options{mode}[0] : undef;
our $overriding_config = defined $MODE;
unless ($MODE) {
    $MODE = 'install';
    $0 =~ m|remove$|  and $MODE = 'remove';
    $0 =~ m|update$|i and $MODE = 'update';
}

our $default_list_mode;
$default_list_mode = 'gui_pkgs' if $MODE eq 'install';
if ($MODE eq 'remove') {
    $default_list_mode = 'installed';
} elsif ($MODE eq 'update') {
    $default_list_mode = 'all_updates';
}

$MODE eq 'update' || $rpmdragora_options{'run-as-root'} and AdminPanel::Privileges::require_root_capability();
$::noborderWhenEmbedded = 1;

require AdminPanel::rpmdragora;

our $changelog_first = $rpmdragora::changelog_first_config->[0];
$changelog_first = 1 if $rpmdragora_options{'changelog-first'};

sub warn_about_user_mode() {
    my $title = N("Running in user mode");
    my $msg = N("You are launching this program as a normal user.\n".
                "You will not be able to perform modifications on the system,\n".
                "but you may still browse the existing database.");

    if(($EUID != 0) and (!AdminPanel::rpmdragora::interactive_msg($title, $msg))) {
        return 0;
    }
    return 1;
}

sub init() {
    URPM::bind_rpm_textdomain_codeset();
}

1;
