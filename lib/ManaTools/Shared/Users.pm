# vim: set et ts=4 sw=4:
package ManaTools::Shared::Users;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Shared::Users - backend to manage users

=head1 SYNOPSIS

    my $userBackEnd = ManaTools::Shared::Users->new();
    my $userInfo    = $userManager->getUserInfo('username');

=head1 DESCRIPTION

This module gives a low level access to the system user management it uses libUSER module.


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Shared::Users

=head1 SEE ALSO

libUSER

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2016, Angelo Naselli.

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

use Moose;
use diagnostics;

use Config::Auto;
use Data::Password::Meter;
use IO::All;
use File::Basename;
use File::Copy;
use File::Remove 'remove';

## USER is from userdrake
use USER;
use English;
use POSIX qw/ceil/;

use ManaTools::Shared::Locales;
use ManaTools::Shared;


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


## Used by USER (for getting values? TODO need explanations, where?)
has 'USER_GetValue' => (
    default   => -65533,
    is        => 'ro',
    isa       => 'Int',
    init_arg  => undef,
);

## Used by USER (for getting values? TODO need explanations, where?)
has 'ctx' => (
    is        => 'ro',
    init_arg  => undef,
    builder => '_USERInitialize',
);

sub _USERInitialize {
    my $self = shift;

    # $EUID:  effective user identifier
    if ($EUID == 0) {
        return USER::ADMIN->new;
    }

    return undef;
}

## min (custom) UID was 500 now is 1000, let's change in a single point
has 'min_UID' => (
    default   => 1000,
    is        => 'ro',
    isa       => 'Int',
    init_arg  => undef,
);

## min (custom) GID was 500 now should be 1000 as for users
has 'min_GID' => (
    default   => 1000,
    is        => 'ro',
    isa       => 'Int',
    init_arg  => undef,
);

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

    $namelist: ARRAY reference containing the face name list

=head3 DESCRIPTION

    Retrieves the list of icon name from facesdir()

=cut

#=============================================================

sub facenames {
    my $self = shift;

    my $dir = $self->face_dir;
    my @files    = io->dir($dir)->all_files;
    my @l = grep { /^[A-Z]/ } @files;
    my @namelist = map { my $f = fileparse($_->filename, qr/\Q.png\E/) } (@l ? @l : @files);

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

=head2 updateOrDelUsersInGroup

=head3 INPUT

    $name:   username

=head3 DESCRIPTION

    Fixes user deletion into groups.

=cut

#=============================================================
sub updateOrDelUserInGroup {
    my ($self, $name) = @_;
    my $groups = $self->ctx->GroupsEnumerateFull;
    foreach my $g (@$groups) {
        my $members = $g->MemberName(1, 0);
        if (ManaTools::Shared::inArray($name, $members)) {
            eval { $g->MemberName($name, 2) };
            eval { $self->ctx->GroupModify($g) };
        }
    }
}


#=============================================================

=head2 getGoups

=head3 OUTPUT

    $groups: ARRAY reference containing all the groups

=head3 DESCRIPTION

    This method return the configured groups

=cut

#=============================================================
sub getGoups {
    my $self = shift;

    return $self->ctx->GroupsEnumerate;
}


#=============================================================

=head2 groupNameExists

=head3 INPUT

    $groupname: the name of the group to check

=head3 OUTPUT

    if group exists

=head3 DESCRIPTION

    This method return if a given group exists

=cut

#=============================================================
sub groupNameExists {
    my ($self, $groupname) = @_;

    return 0 if (!defined($groupname));

    return (defined($self->ctx->LookupGroupByName($groupname)));
}

#=============================================================

=head2 groupIDExists

=head3 INPUT

    $group: the id of the group to check

=head3 OUTPUT

    if group exists

=head3 DESCRIPTION

    This method return if a given group exists

=cut

#=============================================================
sub groupIDExists {
    my ($self, $group) = @_;

    return 0 if (!defined($group));

    return (defined($self->ctx->LookupGroupById($group)));
}


#=============================================================

=head2 groupID

=head3 INPUT

    $groupname: group name

=head3 OUTPUT

    groupid or undef

=head3 DESCRIPTION

    This method returns the group id for the group name

=cut

#=============================================================
sub groupID {
    my ($self, $groupname) = @_;

    my $gr = $self->ctx->LookupGroupByName($groupname);
    return $gr->Gid($self->USER_GetValue) if ($gr);

    return undef;
}

#=============================================================

=head2 groupName

=head3 INPUT

    $gid group identifier

=head3 OUTPUT

    group name or undef

=head3 DESCRIPTION

    This method returns the group name for the given group
    identifier

=cut

#=============================================================
sub groupName {
    my ($self, $gid) = @_;

    my $gr = $self->ctx->LookupGroupById($gid);
    return $gr->GroupName($self->USER_GetValue) if ($gr);

    return undef;
}


#=============================================================

=head2 addGroup

=head3 INPUT

    $params: HASH reference containing:
        groupname => name of teh group to be added
        gid       => group id of the group to be added
        is_system => is a system group?

=head3 OUTPUT

    $gid the actual group id

=head3 DESCRIPTION

    This method add a group to system

=cut

#=============================================================
sub addGroup {
    my ($self, $params) = @_;

    my $is_system = defined($params->{is_system}) ?
                    $params->{is_system}          :
                    0;

    return -1 if !defined($params->{groupname});

    my $groupEnt = $self->ctx->InitGroup($params->{groupname}, $is_system);

    return -1 if !defined($groupEnt);

    $groupEnt->Gid($params->{gid}) if defined($params->{gid});

    $self->ctx->GroupAdd($groupEnt);

    return $groupEnt->Gid($self->USER_GetValue);
}

#=============================================================

=head2 groupMembers

=head3 INPUT

    $groupname: The group name

=head3 OUTPUT

    $members: ARRAY reference containing all the user belonging
              to the given $groupname

=head3 DESCRIPTION

    This method gets the group name and returns the users
    belonging to it

=cut

#=============================================================
sub groupMembers {
    my ($self, $groupname) = @_;

    return $groupname if !defined($groupname);

    my $members  = $self->ctx->EnumerateUsersByGroup($groupname);

    return $members;
}


#=============================================================

=head2 isPrimaryGroup

=head3 INPUT

    $groupname: the name of the group

=head3 OUTPUT

    $username: undef if it is primary group or the username for
               which the group is the primary one.

=head3 DESCRIPTION

    This methods check if the given group name is primary group
    for any users belonging to the group

=cut

#=============================================================
sub isPrimaryGroup {
    my ($self, $groupname) = @_;

    return $groupname if !defined($groupname);

    my $groupEnt = $self->ctx->LookupGroupByName($groupname);
    my $members  = $self->ctx->EnumerateUsersByGroup($groupname);
    foreach my $username (@$members) {
        my $userEnt = $self->ctx->LookupUserByName($username);
        if ($userEnt && $userEnt->Gid($self->USER_GetValue) == $groupEnt->Gid($self->USER_GetValue)) {
            return $username;
        }
    }
    return undef;
}


#=============================================================

=head2 deleteGroup

=head3 INPUT

    $groupname: in_par_description

=head3 OUTPUT

    0: if error occurred
    1: if removed

=head3 DESCRIPTION

    This method remove the group from the system

=cut

#=============================================================
sub deleteGroup {
     my ($self, $groupname) = @_;

     return 0 if !defined($groupname);

     my $groupEnt = $self->ctx->LookupGroupByName($groupname);
     eval { $self->ctx->GroupDel($groupEnt) };
     return 0 if $@;

     return 1;
}



#=============================================================

=head2 modifyGroup

=head3 INPUT

    $groupInfo: HASH reference containing:
        old_groupname => old name of the group (if renaming)
        groupname     => group name
        members       => users belonging to the group

=head3 OUTPUT

    $retval => HASH reference
        status => 1 (ok) 0 (error)
        error  => error message if status is 0

=head3 DESCRIPTION

    This method modifies the group groupname

=cut

#=============================================================
sub modifyGroup {
    my ($self, $groupInfo) = @_;

    die "group name is mandatory" if !defined($groupInfo->{groupname});

    my $groupEnt = defined($groupInfo->{old_groupname}) ?
                   $self->ctx->LookupGroupByName($groupInfo->{old_groupname}) :
                   $self->ctx->LookupGroupByName($groupInfo->{groupname});

    my $orig_groupname = $groupInfo->{groupname};
    if (defined($groupInfo->{old_groupname}) &&
        $groupInfo->{old_groupname} ne $groupInfo->{groupname}) {
        $groupEnt->GroupName($groupInfo->{groupname});
        $orig_groupname = $groupInfo->{old_groupname};
    }

    my $members = $groupInfo->{members};
    my $gid     = $groupEnt->Gid($self->USER_GetValue);
    my $users   = $self->getUsers();
    my @susers  = sort(@{$users});

    foreach my $user (@susers) {
        my $uEnt = $self->ctx->LookupGroupByName($user);
        if ($uEnt) {
            my $ugid = $uEnt->Gid($self->USER_GetValue);
            my $m    = $self->ctx->EnumerateUsersByGroup($orig_groupname);
            if (MDK::Common::DataStructure::member($user, @{$members})) {
                if (!ManaTools::Shared::inArray($user, $m)) {
                    if ($ugid != $gid) {
                        eval { $groupEnt->MemberName($user, 1) };
                    }
                }
            }
            else {
                if (ManaTools::Shared::inArray($user, $m)) {
                    if ($ugid == $gid) {
                        return {
                            status => 0,
                            error =>$self->loc->N("You cannot remove user <%s> from their primary group", $user)
                        };
                    }
                    else {
                        eval { $groupEnt->MemberName($user, 2) };
                    }
                }
            }
        }
    }

    $self->ctx->GroupModify($groupEnt);

    return {status => 1,};
}

#=============================================================

=head2 getGroupsInfo

    $options: HASH reference containing
            groupname_filter => groupname search string
            filter_system   => hides system groups

=head3 OUTPUT

    $groupsInfo: HASH reference containing
        groupname-1 => {
            gid    => group identifier
            members  => ARRAY of username
        }
        groupname-2 => {
            ...
        }

=head3 DESCRIPTION

    This method get group information (all groups or the
    filtered ones)

=cut

#=============================================================
sub getGroupsInfo {
    my ($self, $options) = @_;

    my $groupsInfo = {};
    return $groupsInfo if !defined $self->ctx;

    my $strfilt = $options->{groupname_filter} if exists($options->{groupname_filter});
    my $filtergroups = $options->{filter_system} if exists($options->{filter_system});

    my $groups = $self->ctx->GroupsEnumerateFull;

    my @GroupReal;
  LOOP: foreach my $g (@{$groups}) {
        my $gid = $g->Gid($self->USER_GetValue);
        if (!defined($gid)) {
            print "Got an unexpected undefined group!\n";
            next LOOP;
        }
        next LOOP if $filtergroups && $gid <= 499 || $gid == 65534;
        if ($filtergroups && $gid > 499 && $gid < $self->min_GID) {
            my $groupname = $g->GroupName($self->USER_GetValue);
            my $l = $self->ctx->LookupUserByName($groupname);
            if (!defined($l)) {
                my $members  = $self->ctx->EnumerateUsersByGroup($groupname);
                next LOOP if !scalar(@{$members});
                foreach my $username (@$members) {
                    my $userEnt = $self->ctx->LookupUserByName($username);
                    next LOOP if $userEnt->HomeDir($self->USER_GetValue) =~ /^\/($|var\/|run\/)/ || $userEnt->LoginShell($self->USER_GetValue) =~ /(nologin|false)$/;
                }
            }
            else {
                next LOOP if $l->HomeDir($self->USER_GetValue) =~ /^\/($|var\/|run\/)/ || $l->LoginShell($self->USER_GetValue) =~ /(nologin|false)$/;
            }
        }
        push @GroupReal, $g if $g->GroupName($self->USER_GetValue) =~ /^\Q$strfilt/;
    }

    foreach my $g (@GroupReal) {
        my $groupname = $g->GroupName($self->USER_GetValue);
        my $u_b_g     = $self->ctx->EnumerateUsersByGroup($groupname);
        my $group_id  = $g->Gid($self->USER_GetValue);

        $groupsInfo->{"$groupname"} = {
            gid      => $group_id,
            members  => $u_b_g,
        };
    }

    return $groupsInfo;
}

#=============================================================

=head2 getUsers

=head3 OUTPUT

    $users: ARRAY reference containing all the users

=head3 DESCRIPTION

    This method return the configured users

=cut

#=============================================================
sub getUsers {
    my $self = shift;

    return $self->ctx->UsersEnumerate;
}

#=============================================================

=head2 getUserInfo

=head3 INPUT

    $username: user name

=head3 OUTPUT

    $userInfo: HASH reference containing
        {
            uid         => user identifier
            gid         => group identifier
            fullname    => user full name
            home        => home directory
            shell       => user shell
            expire      => shadow expire time
            locked      => is locked?
            exp_min     => shadow Min
            exp_max     => shadow Max
            exp_warn    => shadow Warn
            exp_inact   => shadow Inact
            last_change => Shadow last change
            members     => groups the user belongs to
        }

=head3 DESCRIPTION

    This method get all the information for the given user

=cut

#=============================================================
sub getUserInfo {
    my ($self, $username) = @_;

    my $userInfo = {};
    return $userInfo if !defined $self->ctx;

    my $userEnt = $self->ctx->LookupUserByName($username);
    return $userInfo if !defined($userEnt);

    my $fullname             = $userEnt->Gecos($self->USER_GetValue);
    utf8::decode($fullname);
    $userInfo->{fullname}    = $fullname;
    $userInfo->{shell}       = $userEnt->LoginShell($self->USER_GetValue);
    $userInfo->{home}        = $userEnt->HomeDir($self->USER_GetValue);
    $userInfo->{uid}         = $userEnt->Uid($self->USER_GetValue);
    $userInfo->{gid}         = $userEnt->Gid($self->USER_GetValue);
    $userInfo->{expire}      = $userEnt->ShadowExpire($self->USER_GetValue);
    $userInfo->{locked}      = $self->ctx->IsLocked($userEnt);

    $userInfo->{exp_min}     = $userEnt->ShadowMin($self->USER_GetValue);
    $userInfo->{exp_max}     = $userEnt->ShadowMax($self->USER_GetValue);
    $userInfo->{exp_warn}    = $userEnt->ShadowWarn($self->USER_GetValue);
    $userInfo->{exp_inact}   = $userEnt->ShadowInact($self->USER_GetValue);
    $userInfo->{last_change} = $userEnt->ShadowLastChange($self->USER_GetValue);
    $userInfo->{members}     = $self->ctx->EnumerateGroupsByUser($username);

    return $userInfo;
}

#=============================================================

=head2 getUsersInfo

=head3 INPUT

    $options: HASH reference containing
        username_filter => username search string
        filter_system   => hides system users

=head3 OUTPUT

    $usersInfo: HASH reference containing
        username-1 => {
            uid    => user identifier
            group  => primary group name
            gid    => group identifier
            fullname  => user full name
            home   => home directory
            shell  => user shell
            status => login status (locked, expired, etc)
        }
        username-2 => {
            ...
        }

=head3 DESCRIPTION

    This method get user information (all users or filtered ones)

=cut

#=============================================================
sub getUsersInfo {
    my ($self, $options) = @_;

    my $usersInfo = {};
    return $usersInfo if !defined $self->ctx;

    my $strfilt = $options->{username_filter} if exists($options->{username_filter});
    my $filterusers = $options->{filter_system} if exists($options->{filter_system});

    my ($users, $group, $groupnm, $expr);
    $users = $self->ctx->UsersEnumerateFull;

    my @UserReal;
  LOOP: foreach my $l (@{$users}) {
        my $uid = $l->Uid($self->USER_GetValue);
        next LOOP if $filterusers && $uid <= 499 || $uid == 65534;
        next LOOP if $filterusers && $uid > 499 && $uid < $self->min_UID &&
                     ($l->HomeDir($self->USER_GetValue) =~ /^\/($|var\/|run\/)/ || $l->LoginShell($self->USER_GetValue) =~ /(nologin|false)$/);
        push @UserReal, $l if $l->UserName($self->USER_GetValue) =~ /^\Q$strfilt/;
    }
    my $i;
    my $itemColl = new yui::YItemCollection;
    foreach my $l (@UserReal) {
        $i++;
        my $uid = $l->Uid($self->USER_GetValue);
        if (!defined $uid) {
            warn "bogus user at line $i\n";
            next;
        }
        my $gid = $l->Gid($self->USER_GetValue);
        $group = $self->ctx->LookupGroupById($gid);
        $groupnm = '';
        $expr = $self->computeLockExpire($l);
        $group and $groupnm = $group->GroupName($self->USER_GetValue);
        my $fulln = $l->Gecos($self->USER_GetValue);
        utf8::decode($fulln);
        my $username = $l->UserName($self->USER_GetValue);
        my $shell    = $l->LoginShell($self->USER_GetValue);
        my $homedir  = $l->HomeDir($self->USER_GetValue);
        $usersInfo->{"$username"} = {
            uid    => $uid,
            group  => $groupnm,
            gid    => $gid,
         fullname  => $fulln,
            home   => $homedir,
            status => $expr,
            shell  => $shell,
        };
    }

    return $usersInfo;
}

#=============================================================

=head2 getUserHome

=head3 INPUT

    $username: given user name

=head3 OUTPUT

    $homedir: user home directory

=head3 DESCRIPTION

    This method return the home directory belonging to the given
    username

=cut

#=============================================================
sub getUserHome {
    my ($self, $username) = @_;

    return $username if !defined($username);

    my $userEnt = $self->ctx->LookupUserByName($username);
    my $homedir = $userEnt->HomeDir($self->USER_GetValue);

    return $homedir;
}

#=============================================================

=head2 userNameExists

=head3 INPUT

    $username: the name of the user to check

=head3 OUTPUT

    if user exists

=head3 DESCRIPTION

    This method return if a given user exists

=cut

#=============================================================
sub userNameExists {
    my ($self, $username) = @_;

    return 0 if (!defined($username));

    return (defined($self->ctx->LookupUserByName($username)));
}

#=============================================================

=head2 computeLockExpire

=head3 INPUT

    $l: login user info

=head3 OUTPUT

    $status: Locked, Expired, or empty string

=head3 DESCRIPTION

    This method returns if the login is Locked, Expired or ok.
    Note this function is meant for internal use only

=cut

#=============================================================
sub computeLockExpire {
    my ( $self, $l ) = @_;
    my $ep = $l->ShadowExpire($self->USER_GetValue);
    my $tm = ceil(time()/(24*60*60));
    $ep = -1 if !defined($ep) || int($tm) <= $ep;
    my $status = $self->ctx->IsLocked($l) ? $self->loc->N("Locked") : ($ep != -1 ? $self->loc->N("Expired") : '');
    return $status;
}

#=============================================================

=head2 addUser

=head3 INPUT

    $params: HASH reference containing:
        username  => name of teh user to be added
        uid       => user id of the username to be added
        is_system => is a system user?
        homedir   => user home directory
        donotcreatehome => do not create the home directory
        shell => user shall
        fullname => user full name
        gid => group id for the user
        shadowMin => min time password validity
        shadowMax => max time password validity
        shadowInact =>
        shadowWarn  =>
        password  => user password

=head3 OUTPUT

    0 if errors 1 if ok

=head3 DESCRIPTION

    This method add a user to system

=cut

#=============================================================
sub addUser {
    my ($self, $params) = @_;

    return 0 if !defined($params->{username});

    my $is_system = defined($params->{is_system}) ?
                    $params->{is_system}          :
                    0;

    my $userEnt = $self->ctx->InitUser($params->{username}, $is_system);
    return 0 if !defined($userEnt);


    $userEnt->HomeDir($params->{homedir}) if defined($params->{homedir});
    $userEnt->Uid($params->{uid}) if defined($params->{uid});
    $userEnt->Gecos($params->{fullname}) if defined($params->{fullname});
    $userEnt->LoginShell($params->{shell}) if defined($params->{shell});
    $userEnt->Gid($params->{gid}) if defined ($params->{gid});
    my $shd = defined ($params->{shadowMin}) ? $params->{shadowMin} : -1;
    $userEnt->ShadowMin($shd);
    $shd = defined ($params->{shadowMax}) ? $params->{shadowMax} : 99999;
    $userEnt->ShadowMax($shd);
    $shd = defined ($params->{shadowWarn}) ? $params->{shadowWarn} : -1;
    $userEnt->ShadowWarn($shd);
    $shd = defined ($params->{shadowInact}) ? $params->{shadowInact} : -1;
    $userEnt->ShadowInact($shd);
    $self->ctx->UserAdd($userEnt, $is_system, $params->{donotcreatehome});
    $self->ctx->UserSetPass($userEnt, $params->{password});

    return 1;
}


#=============================================================

=head2 modifyUser

=head3 INPUT

    $userInfo: HASH reference containing:
        old_username  => old name of the user (if renaming)
        username      => user name
        fullname      => full name of teh user
        password      => password
        homedir       => home directory
        shell         => user shell
        members       => groups the user belongs to
        gid           => primary group identifier
        lockuser      => lock user
        acc_expires   => account expire time - containing:
                exp_y     => year
                exp_m     => month
                exp_d     => day
     password_expires => password expire time - containing:
                exp_min   => min
                exp_max   => max
                exp_warn  => when warn
                exp_inact => when inactive

=head3 DESCRIPTION

    This method modifies the group groupname

=cut

#=============================================================
sub modifyUser {
    my ($self, $userInfo) = @_;

    die "user name is mandatory" if !defined($userInfo->{username});
    die "primary group identifier is mandatory" if !defined($userInfo->{gid});
    die "a valid group identifier is mandatory" if $userInfo->{gid} < 0;

    if (defined($userInfo->{acc_expires})) {
        die "expiring year is mandatory"  if !defined($userInfo->{acc_expires}->{exp_y});
        die "expiring month is mandatory" if !defined($userInfo->{acc_expires}->{exp_m});
        die "expiring day is mandatory"   if !defined($userInfo->{acc_expires}->{exp_d});
    }
    if (defined($userInfo->{password_expires})) {
        die "password expiring min is mandatory"      if !($userInfo->{password_expires}->{exp_min});
        die "password expiring max is mandatory"      if !($userInfo->{password_expires}->{exp_max});
        die "password expiring warn is mandatory"     if !($userInfo->{password_expires}->{exp_warn});
        die "password expiring inactive is mandatory" if !($userInfo->{password_expires}->{exp_inact});
    }
    my $userEnt = defined($userInfo->{old_username}) ?
                  $self->ctx->LookupUserByName($userInfo->{old_username}) :
                  $self->ctx->LookupUserByName($userInfo->{username});

    my $orig_username = $userInfo->{username};
    if (defined($userInfo->{old_username}) &&
        $userInfo->{old_username} ne $userInfo->{username}) {
        $userEnt->UserName($userInfo->{username});
        $orig_username = $userInfo->{old_username};
    }

    # $userEnt->UserName($userInfo->{username});
    $userEnt->Gecos($userInfo->{fullname})   if defined($userInfo->{fullname});
    $userEnt->HomeDir($userInfo->{homedir})  if defined($userInfo->{homedir});
    $userEnt->LoginShell($userInfo->{shell}) if defined($userInfo->{shell});


    my $username = $userEnt->UserName($self->USER_GetValue);
    my $grps = $self->getGoups();
    my @sgroups = sort @{$grps};

    my $members = $userInfo->{members};
    foreach my $group (@sgroups) {
        my $gEnt = $self->ctx->LookupGroupByName($group);
        my $ugid = $gEnt->Gid($self->USER_GetValue);
        my $m    = $gEnt->MemberName(1,0);
        if (MDK::Common::DataStructure::member($group, @$members)) {
            if (!ManaTools::Shared::inArray($username, $m) && $userInfo->{gid} != $ugid) {
                eval { $gEnt->MemberName($username, 1) };
                $self->ctx->GroupModify($gEnt);
            }
        }
        else {
            if (ManaTools::Shared::inArray($username, $m)) {
                eval { $gEnt->MemberName($username, 2) };
                $self->ctx->GroupModify($gEnt);
            }
        }
    }

    $userEnt->Gid($userInfo->{gid}) if defined($userInfo->{gid});

    if (defined($userInfo->{acc_expires})) {
        my $yr = $userInfo->{acc_expires}->{exp_y};
        my $mo = $userInfo->{acc_expires}->{exp_m};
        my $dy = $userInfo->{acc_expires}->{exp_d};
        my $Exp = _ConvTime($dy, $mo, $yr);
        $userEnt->ShadowExpire($Exp);
    }
    else {
        $userEnt->ShadowExpire(ceil(-1))
    }
    if (defined($userInfo->{password_expires})) {
        my $allowed  = $userInfo->{password_expires}->{exp_min};
        my $required = $userInfo->{password_expires}->{exp_max};
        my $warning  = $userInfo->{password_expires}->{exp_warn};
        my $inactive = $userInfo->{password_expires}->{exp_inact};
        $userEnt->ShadowMin($allowed);
        $userEnt->ShadowMax($required);
        $userEnt->ShadowWarn($warning);
        $userEnt->ShadowInact($inactive);
    }
    else {
        $userEnt->ShadowMin(-1);
        $userEnt->ShadowMax(99999);
        $userEnt->ShadowWarn(-1);
        $userEnt->ShadowInact(-1);
    }

    $self->ctx->UserSetPass($userEnt, $userInfo->{password}) if defined($userInfo->{password});
    $self->ctx->UserModify($userEnt);

    if ($userInfo->{lockuser}) {
        !$self->ctx->IsLocked($userEnt) and $self->ctx->Lock($userEnt);
    }
    else {
        $self->ctx->IsLocked($userEnt) and $self->ctx->UnLock($userEnt);
    }

    return 1;
}


#=============================================================

=head2 deleteUser

=head3 INPUT

    $username: username to be deleted
    $options:  HASH reference containing
            clean_home  => if home has to be removed
            clean_spool => if sppol has to be removed

=head3 OUTPUT

    error string or undef if no errors occurred

=head3 DESCRIPTION

    This method delete a user from the system.

=cut

#=============================================================
sub deleteUser {
    my ($self, $username, $options) = @_;

    return $username if !defined($username);

    my $userEnt = $self->ctx->LookupUserByName($username);

    $self->ctx->UserDel($userEnt);
    $self->updateOrDelUserInGroup($username);
    #Let's check out the user's primary group
    my $usergid = $userEnt->Gid($self->USER_GetValue);
    my $groupEnt = $self->ctx->LookupGroupById($usergid);
    if ($groupEnt) {
        my $member = $groupEnt->MemberName(1, 0);
        # TODO check if 499 is ok nowadays
        if (scalar(@$member) == 0 && $groupEnt->Gid($self->USER_GetValue) > 499) {
            $self->ctx->GroupDel($groupEnt);
        }
    }
    if (defined($options)) {
        ## testing jusr if exists also undef is allowed
        ## as valid option
        if (exists($options->{clean_home})) {
            eval { $self->ctx->CleanHome($userEnt) };
            return $@ if $@;
        }
        if (exists($options->{clean_spool})) {
            eval { $self->ctx->CleanSpool($userEnt) };
            return $@ if $@;
        }
    }
    return undef;
}

#=============================================================

=head2 getUserShells


=head3 OUTPUT

    GetUserShells: from libUSER

=head3 DESCRIPTION

    This method returns the available shell

=cut

#=============================================================

sub getUserShells {
    my $self = shift;

    return $self->ctx->GetUserShells;
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
        my $current_md5 = ManaTools::Shared::md5sum($user_icon);
        my $found = 0;
        for ($i = 0; $i < scalar(@$icons); $i++) {
            if (ManaTools::Shared::md5sum($self->face2png($icons->[$i])) eq $current_md5) {
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

=head3 OUTPUT

    $gid: group id

=head3 DESCRIPTION

    Adds the given username $name to 'users' group

=cut

#=============================================================
sub Add2UsersGroup {
    my ($self, $name) = @_;

    my $usersgroup = $self->ctx->LookupGroupByName('users');
    $usersgroup->MemberName($name, 1);
    return $usersgroup->Gid($self->USER_GetValue);
}

sub _ConvTime {
    my ($day, $month, $year) = @_;
    my ($tm, $days, $mon, $yr);
    $mon = $month - 1; $yr = $year - 1900;
    $tm = POSIX::mktime(0, 0, 0, $day, $mon, $yr);
    $days = ceil($tm / (24 * 60 * 60));
    return $days;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
