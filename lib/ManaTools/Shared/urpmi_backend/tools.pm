# vim: set et ts=4 sw=4:
package ManaTools::Shared::urpmi_backend::tools;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Shared::urpmi_backend::tools - urpmi backend tools object

=head1 SYNOPSIS

    use ManaTools::Shared::urpmi_backend::tools;

    my $urpm_tools = ManaTools::Shared::urpmi_backend::tools->new();


=head1 DESCRIPTION

    This module is a backend to some urpmi funcitionalities

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Shared::urpmi_backend::tools

=head1 SEE also

    ManaTools::Shared::urpmi_backend::DB

=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2015-2017 Angelo Naselli <anaselli@linux.it>
    from Rpmdrake:
     Copyright (c) 2002 Guillaume Cottenceau
     Copyright (c) 2003-2005 MandrakeSoft SA
     Copyright (c) 2005-2007 Mandriva SA
     Copyright (c) 2008 Aurelien Lefebvre <alkh@mandriva.org>
     Copyright (c) 2002-2014 Thierry Vignaud <thierry.vignaud@gmail.com>

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

use strict;
use ManaTools::Shared::urpmi_backend::DB;

use MDK::Common::File qw(cat_);
use URPM;
use urpm::msg;


#=============================================================

=head2 object attribute

=head3 urpmi_db_backend

    a ManaTools::Shared::urpmi_backend::DB object

=cut

#=============================================================
has 'urpmi_db_backend' => (
    is        => 'rw',
    init_arg  => undef,
    lazy    => 1,
    builder => '_urpmi_db_backend_init',
);

sub _urpmi_db_backend_init {
    my $self = shift;

    return  ManaTools::Shared::urpmi_backend::DB->new(),
}


has 'loc' => (
        is => 'rw',
        isa => 'ManaTools::Shared::Locales',
        lazy => 1,
        builder => '_localeInitialize',
);


sub _localeInitialize {
    my $self = shift;

    $self->loc(
        ManaTools::Shared::Locales->new(
            domain_name => 'manatools',
        )
    );
}

#=============================================================

=head2 get_update_media

=head3 INPUT

    $urpm: an urpm object

=head3 DESCRIPTION

    This method returns a list of update media
    (here for convenience, implemented in
    ManaTools::Shared::urpmi_backend::DB)

=cut

#=============================================================
sub get_update_media {
    my ($self, $urpm) = @_;

    $self->urpmi_db_backend()->get_update_media($urpm);
}

#=============================================================

=head2 ensure_utf8

=head3 INPUT

    text: a string that is converted or left to utf8

=head3 DESCRIPTION

    This method ensure the given string is utf8
=cut

#=============================================================
sub ensure_utf8 {
    my ($self, $text) = @_;
    return '' if !$text;

    if (utf8::is_utf8($text)) {
        utf8::valid($text) and return;
        utf8::encode($text); #- disable utf8 flag
        utf8::upgrade($text);
    } else {
        utf8::decode($text); #- try to set utf8 flag
        utf8::valid($text) and return;
        warn "do not know what to with $text\n";
    }
}

#=============================================================

=head2 rpm_description

=head3 INPUT

#     description: package description field

=head3 DESCRIPTION

    Retrieve the rpm desctiption

=cut

#=============================================================
sub rpm_description {
    my ($self, $description) = @_;
    ensure_utf8($description);
    my ($t, $tmp);
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

#=============================================================

=head2 urpm_name

=head3 INPUT

    $pkg: package

=head3 DESCRIPTION

    This method returns the urpm format name e.g.
    name-version-release.arch

=cut

#=============================================================
sub urpm_name {
    my ($self, $pkg) = @_;

    return '?-?-?.?' unless ref($pkg) eq 'URPM::Package';
#     my ($name, $version, $release, $arch) = $pkg->fullname;
#     return "$name-$version-$release.$arch";

    return scalar $pkg->fullname;
}

#=============================================================

=head2 is_package_installed

=head3 INPUT

    $package: package to find (URPM::Package) or package name

=head3 DESCRIPTION

    This method returns if a package is installed

=cut

#=============================================================
sub is_package_installed {
    my ($self, $pkg) = @_;

    my $installed = 0;
    my $db = $self->urpmi_db_backend()->open_rpm_db();
    if (ref($pkg) eq 'URPM::Package') {
        $installed = URPM::is_package_installed(URPM::DB::open(), $pkg);
    }
    else {
        my $version = 0;
        $db->traverse_tag_find('name', $pkg, sub { $version = $_[0]->EVR; return ($version ? 1 : 0) });
        $installed = $version ? 1 : 0;
    }

    return $installed;
}

#=============================================================

=head2 find_installed_fullname

=head3 INPUT

    $package: package to find (URPM::Package) or package name

=head3 DESCRIPTION

    This method returns the full name of the package if installed

=cut

#=============================================================
sub find_installed_fullname {
  my ($self, $p) = @_;

  # we can call it with the name or packge
  my $name = ref($p) eq 'URPM::Package' ? $p->name : $p;

  my @fullname;
  my $db = $self->urpmi_db_backend()->open_rpm_db();
  $db->traverse_tag('name', [ $name ], sub { push @fullname, scalar($_[0]->fullname) });

  return @fullname ? join(',', sort @fullname) : "";
}


#=============================================================

=head2 is_mageia

=head3 DESCRIPTION

    This method returns if the system is mageia linux

=cut

#=============================================================
sub is_mageia {
    my $self = shift;

    return cat_('/etc/release') =~ /Mageia/;
}

#=============================================================

=head2 vendor

=head3 DESCRIPTION

    This method returns if the vendor is mageia or mandriva

=cut

#=============================================================
sub vendor {
    my $self = shift;

    return $self->is_mageia() ? "mageia" : "mandriva";
}


#=============================================================

=head2 get_package_id

=head3 INPUT

    $package: package (URPM::Package)

=head3 DESCRIPTION

    This method returns the package id meant as
    (name;version-release;arch;vendor)

=cut

#=============================================================
sub get_package_id {
  my ($self, $pkg) = @_;

  return '?;?-?;?;?' unless ref($pkg) eq 'URPM::Package';

  return join(';', $pkg->name, $pkg->version . "-" . $pkg->release, $pkg->arch, $self->vendor());
}


#=============================================================

=head2 pkg2medium

=head3 INPUT

    $p:     package (URPM::Package)
    $urpm:  urpm object

=head3 DESCRIPTION

    Returns the medium that contains the URPM::Package $pkg

=cut

#=============================================================
sub pkg2medium {
    my ($self, $p, $urpm) = @_;

    return if ref($p) ne 'URPM::Package';

    return {
        name => $self->loc->N_("None (installed)")
    } if !defined($p->id); # if installed

    return URPM::pkg2media($urpm->{media}, $p) || {
        name => $self->loc->N("Unknown"), fake => 1
    };
}

#=============================================================

=head2 fullname_to_package_id

=head3 INPUT

    $pkg_string: package fullname

=head3 DESCRIPTION

    Returns package id meant as "name;varsion-release;arch;vendor"

=cut

#=============================================================
sub fullname_to_package_id {
    # fullname, ie 'xeyes-1.0.1-5mdv2008.1.i586'
    my ($self, $pkg_string) = @_;
    chomp($pkg_string);
    if ($pkg_string =~ /^(.*)-([^-]*)-([^-]*)\.([^\.]*)$/) {
# TODO NOTE check package kit backend it seems the urpm package_id is "name;varsion-release;arch;vendor"
        return join(';', $1, "$2-$3", $4, $self->vendor());
    }
}

#=============================================================

=head2 get_package_by_package_id

=head3 INPUT

    $urpm:  urpm object
    $package_id: package id (see fullname_to_package_id)

=head3 DESCRIPTION

    Returns URPM::Package package

=cut

#=============================================================
sub get_package_by_package_id {
    my ($self, $urpm, $package_id) = @_;
    my @depslist = @{$urpm->{depslist}};
    foreach (@depslist) {
        if ($self->get_package_id($_) eq $package_id) {
            return $_;
        }
    }

    return;
}

#=============================================================

=head2 get_installed_fullname_pkid

    $pkg:     package (URPM::Package) or package name (string)


=head3 DESCRIPTION

    Returns package id of the given package

=cut

#=============================================================
sub get_installed_fullname_pkid {
    my ($self, $pkg) = @_;
    my $pkgname = ref($pkg) eq 'URPM::Package' ? $pkg->name : $pkg;
    my $db = $self->urpmi_db_backend()->open_rpm_db();
    my $installed_pkid;
    $db->traverse_tag_find('name', $pkgname, sub {
        my ($p) = @_;
        $installed_pkid = $self->get_package_id($p);
        return $installed_pkid ? 1 : 0;
    });
    return $installed_pkid;
}

#=============================================================

=head2 get_package_upgrade

    $urpm:  urpm object
    $pkg:   package (URPM::Package) or package name (string)


=head3 DESCRIPTION

    Returns package to upgrade

=cut

#=============================================================
sub get_package_upgrade {
    my ($self, $urpm, $pkg) = @_;

    my $db = $self->urpmi_db_backend()->open_rpm_db();
    $urpm->compute_installed_flags($db);
    my @depslist = @{$urpm->{depslist}};
    my $pkgname = ref($pkg) eq 'URPM::Package' ? $pkg->name : $pkg;

    foreach (@depslist) {
        if ($_->name =~ /^$pkgname$/ && $_->flag_upgrade) {
            return $_;
        }
    }

    return;
}


1;

