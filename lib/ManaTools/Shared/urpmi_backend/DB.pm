# vim: set et ts=4 sw=4:
package ManaTools::Shared::urpmi_backend::DB;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::urpmi_backend::DB - urpm DB object

=head1 SYNOPSIS

    use ManaTools::Shared::urpmi_backend::DB;

    my $db_man = ManaTools::Shared::urpmi_backend::DB->new();
    my $urpm = $db_man->fast_open_urpmi_db();


=head1 DESCRIPTION

    This module is a backend to urpm open db

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Shared::urpmi_backend::DB


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

use Moose;

use MDK::Common::File qw(cat_);
use MDK::Common::Func qw(if_);

use urpm;
use urpm::args;
use urpm::media;
use urpm::select;
use urpm::mirrors;

use URPM;
use feature 'state';

# TODO evaluate if managing urpm object inside
#      left as a parameter to back compatibility by now.
#

#=============================================================

=head2 new - optional parameters

=head3 urpmi_root

    optional parameter urpmi_root directory,
    default value is undef

=cut

#=============================================================
has 'urpmi_root' => (
    is => 'rw',
    isa => 'Str'
);

#=============================================================

=head2 new - optional parameters

=head3 rpm_root

    optional parameter rpm_root directory,
    default value is undef

=cut

#=============================================================
has 'rpm_root'   => (
    is => 'rw',
    isa => 'Str'
);

#=============================================================

=head2 new - optional parameters

=head3 debug

    optional parameter - urpm debug option,
    default value is undef

=cut

#=============================================================
has 'debug'   => (
    is => 'rw',
);

#=============================================================

=head2 new - optional parameters

=head3 wait_lock

    optional parameter - urpm wait_lock option,
    default value is undef

=cut

#=============================================================
has 'wait_lock'   => (
    is => 'rw',
);

#=============================================================

=head2 new - optional parameters

=head3 verify_rpm

    optional parameter - urpm verify_rpm option,
    default value is undef

=cut

#=============================================================
has 'verify_rpm'   => (
    is => 'rw',
);

#=============================================================

=head2 new - optional parameters

=head3 auto

    optional parameter - urpm auto option,
    default value is undef

=cut

#=============================================================
has 'auto'   => (
    is => 'rw',
);

#=============================================================

=head2 new - optional parameters

=head3 set_verbosity

    optional parameter - urpm set_verbosity option,
    default value is undef

=cut

#=============================================================
has 'set_verbosity'   => (
    is => 'rw',
);

#=============================================================

=head2 new - optional parameters

=head3 justdb

    optional parameter - urpm justdb option,
    default value is undef

=cut

#=============================================================
has 'justdb'   => (
    is => 'rw',
);


# product_id contains the product id file pathname
has 'product_id' => (
    is        => 'ro',
    isa       => 'Str',
    init_arg  => undef,
    lazy    => 1,
    builder => '_product_id_init',
);

sub _product_id_init {
    my $self = shift;

    return  ($self->urpmi_root() || '') . '/etc/product.id',
}

#=============================================================

=head2 open_rpm_db

=head3 OUTPUT

    URPM::DB: an URPM opened dataase

=head3 DESCRIPTION

    this method return an URPM::DB object

=cut

#=============================================================
sub open_rpm_db {
    my $self = shift;

    URPM::DB::open($self->rpm_root() ||'')  or die "Couldn't open RPM DB " . ($self->rpm_root() ||'');
}

#=============================================================

=head2 fast_open_urpmi_db

=head3 OUTPUT

urpm: an urpm object

=head3 DESCRIPTION

    this method return an urpm object

=cut

#=============================================================
sub fast_open_urpmi_db {
    my $self = shift;

    my $urpm = urpm->new;

    urpm::set_files($urpm, $self->urpmi_root()) if $self->urpmi_root();
    my $rpm_root = $self->rpm_root() || $self->urpmi_root();
    urpm::args::set_root($urpm, $rpm_root) if $rpm_root;
    urpm::args::set_debug($urpm) if $self->debug();

    $urpm->get_global_options;
    $urpm->{options}{wait_lock} = $self->wait_lock() if $self->wait_lock();
    $urpm->{options}{'verify-rpm'} = $self->verify_rpm() if $self->verify_rpm();
    $urpm->{options}{auto} = $self->auto() if $self->auto();
    urpm::args::set_verbosity() if $self->set_verbosity();
    $urpm::args::options{justdb} = $self->justdb() if $self->justdb();

    urpm::media::read_config($urpm);
    $urpm;
}

#=============================================================

=head2 is_it_a_devel_distro

=head3 DESCRIPTION

    This method returns if current distro is not stable

=cut

#=============================================================
sub is_it_a_devel_distro {
    my $self = shift;
    state $res;

    return $res if defined $res;
    $res = urpm::mirrors::parse_LDAP_namespace_structure(cat_($self->product_id()))->{branch} eq 'Devel';
    return $res;
}

#=============================================================

=head2 get_backport_media

=head3 INPUT

    $urpm: an urpm object

=head3 DESCRIPTION

    This method returns a list of backport media

=cut

#=============================================================
sub get_backport_media {
    my ($self, $urpm) = @_;

    grep { $_->{name} =~ /backport/i &&
           $_->{name} !~ /debug|sources|testing/i } @{$urpm->{media}};
}


#=============================================================

=head2 get_inactive_backport_media

=head3 INPUT

    $urpm: an urpm object

=head3 DESCRIPTION

    This method returns a list of inactive backport media

=cut

#=============================================================
sub get_inactive_backport_media {
    my ($self, $urpm) = @_;
    map { $_->{name} } grep { $_->{ignore} } $self->get_backport_media($urpm);
}

#=============================================================

=head2 get_update_media

=head3 INPUT

    $urpm: an urpm object

=head3 DESCRIPTION

    This method returns a list of update media

=cut

#=============================================================
sub get_update_media {
    my ($self, $urpm) = @_;
    if ($self->is_it_a_devel_distro()) {
        grep { !$_->{ignore} } @{$urpm->{media}};
    } else {
        grep { !$_->{ignore} && $_->{update} } @{$urpm->{media}};
    }
}

#=============================================================

=head2 get_active_media

=head3 INPUT

    $urpm: an urpm object

=head3 DESCRIPTION

    This method returns a list of active media

=cut

#=============================================================
sub get_active_media {
    my ($self, $urpm) = @_;
    grep { $_->{name} !~ /debug|testing|backport/i } @{$urpm->{media}};
}

#=============================================================

=head2 open_urpmi_db

=head3 INPUT

    %urpmi_options: urpmi options used to open and lock urpmi
                    db.

=head3 DESCRIPTION

    This method returns an urpm option with a lock on db

=cut

#=============================================================
sub open_urpmi_db {
    my ($self, %urpmi_options) = @_;
    my $urpm = $self->fast_open_urpmi_db();

    my $searchmedia = $urpmi_options{update} ? undef : join(',', $self->get_inactive_backport_media($urpm));

    $self->lock($urpm);

    #next part could be changed in extended implementation on media and priority
    urpm::select::set_priority_upgrade_option($urpm, ());
    urpm::media::configure($urpm, media => '', if_($searchmedia, searchmedia => $searchmedia), %urpmi_options);

    $urpm;
}


#=============================================================

=head2 lock

=head3 INPUT

    $urpm: urpm object

=head3 OUTPUT

    0 if already locked, 1 otherwhise

=head3 DESCRIPTION

    This method locks the db passed into urpm object

=cut

#=============================================================
sub lock {
    my ($self, $urpm) = @_;

    return 0 if $urpm->{lock}; # already locked

    $urpm->{lock} = urpm::lock::urpmi_db($urpm, undef, wait => $urpm->{options}{wait_lock});

    return 1;
}

#=============================================================

=head2 unlock

=head3 INPUT

    $urpm: urpm object

=head3 DESCRIPTION

    This method unlocks the db passed into urpm object

=cut

#=============================================================
sub unlock {
    my ($self, $urpm) = @_;

    $urpm->{lock} = undef;

    return;
}

1;


