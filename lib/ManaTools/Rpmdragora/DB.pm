# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::DB;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Rpmdragora::DB - Rpmdragora extension of urpm DB object

=head1 SYNOPSIS

    use ManaTools::Rpmdragora::DB;

    my $db_man = ManaTools::Rpmdragora::DB->new();
    my $urpm = $db_man->fast_open_urpmi_db();


=head1 DESCRIPTION

    This module is the Rpmdragora extension for the backend to urpm open db

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Rpmdragora::DB

=head1 SEE also

    ManaTools::Shared::urpmi_backend::DB


=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015-2016 Angelo Naselli <anaselli@linux.it>
    from Rpmdrake::open_db:
     Copyright (c) 2002 Guillaume Cottenceau
     Copyright (C) 2008 Aurelien Lefebvre <alkh@mandriva.org>
     Copyright (c) 2002-2014 Thierry Vignaud <thierry.vignaud@gmail.com>
     Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
     Copyright (c) 2005-2007 Mandriva SA

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=head1 METHODS

=cut

use Sys::Syslog;
use MDK::Common::File qw(cat_ mkdir_p);use ManaTools::rpmdragora;
use MDK::Common::Func qw(if_);

use Moose;
extends 'ManaTools::Shared::urpmi_backend::DB';
use feature 'state';

#=============================================================

=head2 open_rpm_db

=head3 OUTPUT

    URPM::DB: an URPM opened dataase

=head3 DESCRIPTION

    this method return an URPM::DB object

=cut

#=============================================================
override 'open_rpm_db' => sub {
    my ($self, $o_force) = @_;

    $self->rpm_root($::rpmdragora_options{'rpm-root'}[0]) if $::rpmdragora_options{'rpm-root'}[0];

    my $host;
    Sys::Syslog::syslog('info|local1', "opening the RPM database");
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
            $db = super();
        }
        $db or die "Couldn't open RPM DB (" . ($::env ? "$::env/rpmdb.cz" : $::rpmdragora_options{'rpm-root'}[0]) . ")";
    }
};

#=============================================================

=head2 fast_open_urpmi_db

=head3 OUTPUT

urpm: an urpm object

=head3 DESCRIPTION

    this method return an urpm object

=cut

#=============================================================
override 'fast_open_urpmi_db' => sub  {
    my $self = shift;

    $self->urpmi_root($::rpmdragora_options{'urpmi-root'}[0]) if $::rpmdragora_options{'urpmi-root'}[0];
    $self->rpm_root($::rpmdragora_options{'rpm-root'}[0]) if $::rpmdragora_options{'rpm-root'}[0];
    $self->wait_lock($::rpmdragora_options{'wait-lock'}) if $::rpmdragora_options{'wait-lock'};
    $self->verify_rpm(!$::rpmdragora_options{'no-verify-rpm'}) if defined $::rpmdragora_options{'no-verify-rpm'};
    $self->auto($::rpmdragora_options{auto}) if $::rpmdragora_options{auto};
    $self->set_verbosity(1);
    $self->justdb($::rpmdragora_options{justdb}) if $::rpmdragora_options{justdb};

    my $urpm = super();

    if ($::rpmdragora_options{env} && $::rpmdragora_options{env}[0]) {
        $::env = $::rpmdragora_options{env}[0];
        # prevent crashing in URPM.pm prevent when using --env:
        $::env = "$ENV{PWD}/$::env" if $::env !~ m!^/!;
        urpm::set_env($urpm, $::env);
    }

    foreach (@{$urpm->{media}}) {
            next if $_->{ignore};
            urpm::media::_tempignore($_, 1) if $ignore_debug_media->[0] && $_->{name} =~ /debug/i;
    }

    # TODO check if no media present and find a way to run edit urpm media

    return $urpm;
};

#=============================================================

=head2 open_urpmi_db

=head3 INPUT

    %urpmi_options: urpmi options used to open and lock urpmi
                    db.

=head3 DESCRIPTION

    This method returns an urpm option with a lcok on db,
    this method totally overrides the super class

=cut

#=============================================================
override 'open_urpmi_db' => sub {
    my ($self, %urpmi_options) = @_;
    my $urpm = $self->fast_open_urpmi_db();

    my $searchmedia = $urpmi_options{update} ? undef : join(',', $self->get_inactive_backport_media($urpm));
    my $media = ref $::rpmdragora_options{media} ? join(',', @{$::rpmdragora_options{media}}) : '';

    $self->lock($urpm) if !$::env;

    my $previous = $::rpmdragora_options{'previous-priority-upgrade'};
    urpm::select::set_priority_upgrade_option($urpm, (ref $previous ? join(',', @$previous) : ()));
    urpm::media::configure($urpm, media => $media, MDK::Common::Func::if_($searchmedia, searchmedia => $searchmedia), %urpmi_options);

    return $urpm;
};


1;
