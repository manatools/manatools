# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::open_db;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2014 Thierry Vignaud <thierry.vignaud@gmail.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
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
# $Id: open_db.pm 268344 2010-05-06 13:06:08Z jvictor $

use strict;
use common;
use AdminPanel::rpmdragora;
use URPM;
use urpm;
use urpm::args;
use urpm::select;
use urpm::media;
use feature 'state';

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(fast_open_urpmi_db
                 get_backport_media
                 get_inactive_backport_media
                 get_update_medias
                 is_it_a_devel_distro
                 open_rpm_db
                 open_urpmi_db
            );

my $loc = AdminPanel::rpmdragora::locale();


# because rpm blocks some signals when rpm DB is opened, we don't keep open around:
sub open_rpm_db {
    my ($o_force) = @_;
    my $host;
    log::explanations("opening the RPM database");
    if ($::rpmdragora_options{parallel} && ((undef, $host) = @{$::rpmdragora_options{parallel}})) {
        state $done;
        my $dblocation = "/var/cache/urpmi/distantdb/$host";
        if (!$done || $o_force) {
            print "syncing db from $host to $dblocation...";
            mkdir_p "$dblocation/var/lib/rpm";
            system "rsync -Sauz -e ssh $host:/var/lib/rpm/ $dblocation/var/lib/rpm";
            $? == 0 or die "Couldn't sync db from $host to $dblocation";
            $done = 1;
            print "done.\n";
        }
        URPM::DB::open($dblocation) or die "Couldn't open RPM DB";
    } else {
        my $db;
        if ($::env) {
	    #- URPM has same methods as URPM::DB and empty URPM will be seen as empty URPM::DB.
	    $db = new URPM;
            $db->parse_synthesis("$::env/rpmdb.cz");
	} else {
            $db = URPM::DB::open($::rpmdragora_options{'rpm-root'}[0]);
        }
        $db or die "Couldn't open RPM DB (" . ($::env ? "$::env/rpmdb.cz" : $::rpmdragora_options{'rpm-root'}[0]) . ")";
    }
}

# do not pay the urpm::media::configure() heavy cost:
sub fast_open_urpmi_db() {
    my $urpm = urpm->new;
    my $error_happened;
    $urpm->{fatal} = sub {
        $error_happened = 1;
        interactive_msg($loc->N("Fatal error"),
                         $loc->N("A fatal error occurred: %s.", $_[1]));
    };

    urpm::set_files($urpm, $::rpmdragora_options{'urpmi-root'}[0]) if $::rpmdragora_options{'urpmi-root'}[0];
    $::rpmdragora_options{'rpm-root'}[0] ||= $::rpmdragora_options{'urpmi-root'}[0];
    urpm::args::set_root($urpm, $::rpmdragora_options{'rpm-root'}[0]) if $::rpmdragora_options{'rpm-root'}[0];
    urpm::args::set_debug($urpm) if $::rpmdragora_options{debug};
    $urpm->get_global_options;
    $urpm->{options}{wait_lock} = $::rpmdragora_options{'wait-lock'};
    $urpm->{options}{'verify-rpm'} = !$::rpmdragora_options{'no-verify-rpm'} if defined $::rpmdragora_options{'no-verify-rpm'};
    $urpm->{options}{auto} = $::rpmdragora_options{auto} if defined $::rpmdragora_options{auto};
    urpm::args::set_verbosity();
    if ($::rpmdragora_options{env} && $::rpmdragora_options{env}[0]) {
        $::env = $::rpmdragora_options{env}[0];
        # prevent crashing in URPM.pm prevent when using --env:
        $::env = "$ENV{PWD}/$::env" if $::env !~ m!^/!;
        urpm::set_env($urpm, $::env);
    }

    $urpm::args::options{justdb} = $::rpmdragora_options{justdb};

    urpm::media::read_config($urpm, 0);
    foreach (@{$urpm->{media}}) {
	    next if $_->{ignore};
	    urpm::media::_tempignore($_, 1) if $ignore_debug_media->[0] && $_->{name} =~ /debug/i;
    }
    # FIXME: seems uneeded with newer urpmi:
    if ($error_happened) {
        touch('/etc/urpmi/urpmi.cfg');
        exec('edit-urpm-sources.pl');
    }
    $urpm;
}

sub is_it_a_devel_distro() {
    state $res;
    return $res if defined $res;

    my $path = '/etc/product.id';
    $path = $::rpmdragora_options{'urpmi-root'}[0] . $path if defined($::rpmdragora_options{'urpmi-root'}[0]);
    $res = common::parse_LDAP_namespace_structure(cat_($path))->{branch} eq 'Devel';
    return $res;
}

sub get_backport_media {
    my ($urpm) = @_;
    grep { $_->{name} =~ /backport/i &&
	       $_->{name} !~ /debug|sources|testing/i } @{$urpm->{media}};
}

sub get_inactive_backport_media {
    my ($urpm) = @_;
    map { $_->{name} } grep { $_->{ignore} } get_backport_media($urpm);
}

sub get_update_medias {
    my ($urpm) = @_;
    if (is_it_a_devel_distro()) {
        grep { !$_->{ignore} } @{$urpm->{media}};
    } else {
        grep { !$_->{ignore} && $_->{update} } @{$urpm->{media}};
    }
}

sub open_urpmi_db {
    my (%urpmi_options) = @_;
    my $urpm = fast_open_urpmi_db();
    my $media = ref $::rpmdragora_options{media} ? join(',', @{$::rpmdragora_options{media}}) : '';

    my $searchmedia = $urpmi_options{update} ? undef : join(',', get_inactive_backport_media($urpm));
    $urpm->{lock} = urpm::lock::urpmi_db($urpm, undef, wait => $urpm->{options}{wait_lock}) if !$::env;
    my $previous = $::rpmdragora_options{'previous-priority-upgrade'};
    urpm::select::set_priority_upgrade_option($urpm, (ref $previous ? join(',', @$previous) : ()));
    urpm::media::configure($urpm, media => $media, if_($searchmedia, searchmedia => $searchmedia), %urpmi_options);
    $urpm;
}

1;
