# vim: set et ts=4 sw=4:
package AdminPanel::Shared::Users;
#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Shared::Users - backend to manage users

=head1 SYNOPSIS

    my $userBackEnd = AdminPanel::Shared::Users->new();
    my $userInfo    = $userManager->getUserInfo('username');

=head1 DESCRIPTION

This module gives a low level access to the system user management it uses libUSER module.


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::Shared::Users

=head1 SEE ALSO

libUSER

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014, Angelo Naselli.

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

=head1 METHODS

=cut



use diagnostics;
use strict;

use Config::Auto;
use Data::Password::Meter;
use IO::All;
use File::Basename;
use File::Copy;
use File::Remove 'remove';

use AdminPanel::Shared::Locales;
use AdminPanel::Shared;

use Moose;

#=============================================================

=head2 new - optional parameters

=head3 face_dir

    optional parameter to set the system face icon directory,
    default value is /usr/share/mga/faces/

=cut

#=============================================================

has 'face_dir' => (
    is => 'rw',
    isa => 'Str',
    default => "/usr/share/mga/faces/",
);

#=============================================================

=head2 new - optional parameters

=head3 user_face_dir

    optional parameter to set the user face icon directory,
    default value is /usr/share/mga/faces/

=cut

#=============================================================
has 'user_face_dir' => (
    is => 'rw',
    isa => 'Str',
    default => "/usr/share/faces/",
);


has 'loc' => (
        is => 'rw',
        init_arg => undef,
        builder => '_localeInitialize'
);


sub _localeInitialize {
    my $self = shift();

    # TODO fix domain binding for translation
    $self->loc(AdminPanel::Shared::Locales->new(domain_name => 'userdrake') );
    # TODO if we want to give the opportunity to test locally add dir_name => 'path'
}


#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    Into this method new optional parameters are tested once,
    instead of into any other methods.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    die "Missing face directory" if (! -d $self->face_dir);
    die "Missing user face directory" if (! -d $self->user_face_dir);

    $self->face_dir($self->face_dir . "/") if (substr($self->face_dir, -1) ne "/");
    $self->user_face_dir($self->user_face_dir . "/") if (substr($self->user_face_dir, -1) ne "/");

}


=head2 facedir

=head3 OUTPUT

        path to directory containing face icon

=head3 DESCRIPTION

    Return the directory containing face icons.

=cut

#=============================================================

sub facedir {
    my $self = shift;

    return $self->face_dir;
}


#=============================================================

=head2 userfacedir

=head3 OUTPUT

    path to directory containing user face icons

=head3 DESCRIPTION

    Return the directory containing user face icons.

=cut

#=============================================================

sub userfacedir {
    my $self = shift;

    return $self->user_face_dir;
}


#=============================================================

=head2 face2png

=head3 INPUT

   $face: face icon name (usually username)

=head3 OUTPUT

    pathname to $face named icon with png extension

=head3 DESCRIPTION

    This method returns the face icon pathname related to username

=cut

#=============================================================

sub face2png {
    my ($self, $face) = @_;

    return $self->face_dir . $face . ".png" if $face;
}

#=============================================================

=head2 facenames


=head3 OUTPUT

    \@namelist: ARRAY reference containing the face name list

=head3 DESCRIPTION

    Retrieves the list of icon name from facesdir() 

=cut

#=============================================================

sub facenames() {
    my $self = shift;

    my $dir = $self->face_dir;
    my @files    = io->dir($dir)->all_files;
    my @l = grep { /^[A-Z]/ } @files;
    my @namelist = map { my $f =fileparse($_->filename, qr/\Q.png\E/) } (@l ? @l : @files);

    return \@namelist;
}

#=============================================================

=head2 addKdmIcon

=head3 INPUT

    $user: username to add
    $icon: chosen icon for username $user


=head3 DESCRIPTION

    Add a $user named icon to $self->user_face_dir. It just copies 
    $icon to $self->user_face_dir, naming it as $user

=cut

#=============================================================

sub addKdmIcon {
    my ($self, $user, $icon) = @_;

    if ($icon && $user) {
        my $icon_name = $self->face_dir . $icon . ".png";
        my $dest   = $self->user_face_dir . $user . ".png";

        eval { copy($icon_name, $dest) } ;
    }
}

#=============================================================

=head2 removeKdmIcon

=head3 INPUT

    $user: username icon to remove

=head3 DESCRIPTION

    Remove a $user named icon from $self->user_face_dir

=cut

#=============================================================
sub removeKdmIcon {
    my ($self, $user) = @_;

    if ($user) {
        my $icon_name   = $self->user_face_dir . $user . ".png";
        eval { remove($icon_name) } ;
    }
}


#=============================================================

=head2 _valid

=head3 INPUT

    $name:        User or Group name
    $name_length: Max length of $name (default 32)

=head3 OUTPUT

    1, locale "Ok" if valid
    0, and explanation string if not valid:
        - Name field is empty please provide a name
        - The name must contain only lower cased latin letters, numbers, '.', '-' and '_'
        - Name is too long

=head3 DESCRIPTION

    this internal method return if a name is compliant to
    a group or user name.

=cut

#=============================================================

sub _valid {
    my ($self, $name, $name_length) = @_;

    return (0, $self->loc->N("Name field is empty please provide a name")) if (!$name );

    $name_length = 32 if !$name_length;

    $name =~ /^[a-z]+?[a-z0-9_\-\.]*?$/ or do {
        return (0, $self->loc->N("The name must start with a letter and contain only lower cased latin letters, numbers, '.', '-' and '_'"));
    };

    return (0, $self->loc->N("Name is too long. Maximum length is %d", $name_length)) if (! (length($name) <= $name_length));

    return (1, $self->loc->N("Ok"));
}

#=============================================================

=head2 valid_username

=head3 INPUT

$username: user name to check

=head3 OUTPUT

    1 if valid, 0 if not (see _valid)

=head3 DESCRIPTION

    Checks the valididty of the string $username

=cut

#=============================================================

sub valid_username {
    my ($self, $username) = @_;

    return $self->_valid($username, 32);
}

#=============================================================

=head2 valid_groupname

=head3 INPUT

$groupname: user name to check

=head3 OUTPUT

    1 if valid, 0 if not (see _valid)

=head3 DESCRIPTION

    Checks the valididty of the string $groupname

=cut

#=============================================================
sub valid_groupname {
    my ($self, $groupname) = @_;

    return $self->_valid($groupname, 16);
}


#=============================================================

=head2 GetFaceIcon

=head3 INPUT

    $name: icon name for the given username
    $next: if passed means getting next icon from the given $name 

=head3 OUTPUT

    $user_icon: icon name

=head3 DESCRIPTION

    This method returns the icon for the given user ($name) or the
    following one if $next is passed

=cut

#=============================================================
sub GetFaceIcon {
    my ($self, $name, $next) = @_;
    my $icons = $self->facenames();
    my $i;
    my $current_icon;
    # remove shortcut "&" from label
    $name =~ s/&// if ($name); 
    my $user_icon = $self->user_face_dir . $name . ".png" if ($name);
    if ($name) {
        $user_icon    = $self->face2png($name) unless(-e $user_icon);
    }
    if ($name && -e $user_icon) {
        my $current_md5 = AdminPanel::Shared::md5sum($user_icon);
        my $found = 0;
        for ($i = 0; $i < scalar(@$icons); $i++) {
            if (AdminPanel::Shared::md5sum($self->face2png($icons->[$i])) eq $current_md5) {
                $found = 1;
                last;
            }
        }
        if ($found) { #- current icon found in @icons, select it
            $current_icon = $icons->[$i];
        } else { #- add and select current icon in @icons
            push @$icons, $user_icon;
            $current_icon = $user_icon;
            $i = scalar(@$icons) - 1;
        }
    } else {
        #- no icon yet, select a random one
        $current_icon = $icons->[$i = rand(scalar(@$icons))];
    }

    if ($next) {
        $current_icon = $icons->[$i = defined $icons->[$i+1] ? $i+1 : 0];
    }
    return $current_icon;
}


#=============================================================

=head2 strongPassword

=head3 INPUT

    $passwd: password to be checked

=head3 OUTPUT

    1: if password is strong
    0: if password is weak

=head3 DESCRIPTION

    Check for a strong password

=cut

#=============================================================
sub strongPassword {
    my ($self, $passwd, $threshold) = @_;
    
    return 0 if !$passwd;
    
    my $pwdm = $threshold ? Data::Password::Meter->new($threshold) : Data::Password::Meter->new();

    # Check a password
    return $pwdm->strong($passwd);
}


# TODO methods not tested in Users.t

#=============================================================

=head2 weakPasswordForSecurityLevel

=head3 INPUT

    $passwd: password to check

=head3 OUTPUT

    1: if the password is too weak for security level

=head3 DESCRIPTION

    Check the security level set if /etc/security/msec/security.conf
    exists and the level is not 'standard' and if the password
    is not at least 6 characters return true

=cut

#=============================================================

sub weakPasswordForSecurityLevel {
     my ($self, $passwd) = @_;

     my $sec_conf_file = "/etc/security/msec/security.conf";
     if (-e $sec_conf_file) {
        my $prefs  = Config::Auto::parse($sec_conf_file);
        my $level = $prefs->{BASE_LEVEL};
        if ($level eq 'none' or $level eq 'standard') {
            return 0;
        }
        elsif (length($passwd) < 6) {
            return 1;
        }
     }

     return 0;
}


#=============================================================

=head2 Add2UsersGroup

=head3 INPUT

    $name: username
    $ctx: USER::ADMIN object

=head3 OUTPUT

    $gid: group id

=head3 DESCRIPTION

Adds the given username $name to 'users' group

=cut

#=============================================================
sub Add2UsersGroup {
    my ($self, $name, $ctx) = @_;
    my $GetValue = -65533; ## Used by USER (for getting values? TODO need explanations, where?)

    my $usersgroup = $ctx->LookupGroupByName('users');
    $usersgroup->MemberName($name, 1);
    return $usersgroup->Gid($GetValue);
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
