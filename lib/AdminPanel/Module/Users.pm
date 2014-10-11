# vim: set et ts=4 sw=4:

package AdminPanel::Module::Users;

#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Module::Users - This module aims to manage service 
                               with GUI

=head1 SYNOPSIS

    my $userManager = AdminPanel::Module::Users->new();
    $userManager->start();

=head1 DESCRIPTION

    This module is a tool to manage users on the system.
    
    From the original code adduserdrake and userdrake.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc AdminPanel::Module::Users

=head1 SEE ALSO
   
   AdminPanel::Module

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2013, Angelo Naselli.

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

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';


###############################################
##
## graphic related routines for managing user
##
###############################################

use Moose;

use POSIX qw(ceil);
use Config::Auto;
use File::ShareDir ':ALL';

use utf8;
use Sys::Syslog;
use Glib;
use English;
use yui;
use AdminPanel::Shared;
use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Locales;
use AdminPanel::Shared::Users;
use MDK::Common::DataStructure qw(member);

extends qw( AdminPanel::Module );

has '+icon' => (
    default => "/usr/share/icons/userdrake.png",
);


# main dialog
has 'dialog'     => (
    is        => 'rw',
    init_arg  => undef,
);

has 'widgets' => ( 
    traits    => ['Hash'],
    default   => sub { {} },
    is        => 'rw',
    isa       => 'HashRef',
    handles   => {
        set_widget     => 'set',
        get_widget     => 'get',
        widget_pairs   => 'kv',
    },
    init_arg  => undef,
);

has 'action_menu' => (
    traits    => ['Hash'],
    default   => sub { {} },
    is        => 'rw',
    isa       => 'HashRef',
    handles   => {
        set_action_menu     => 'set',
        get_action_menu     => 'get',
        action_menu_pairs   => 'kv',
    },
    init_arg  => undef, 
);


has 'edit_tab_widgets' => ( 
    traits    => ['Hash'],
    default   => sub { {} },
    is        => 'rw',
    isa       => 'HashRef',
    handles   => {
        set_edit_tab_widget => 'set',
        get_edit_tab_widget => 'get',
        edit_tab_pairs      => 'kv',
    },
    init_arg  => undef,
);

has 'sh_users' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUsersInitialize'
);

sub _SharedUsersInitialize {
    my $self = shift();

    $self->sh_users(AdminPanel::Shared::Users->new() );
}

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(AdminPanel::Shared::GUI->new() );
}

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

=head1 METHODS

=cut

=head2 new - additional parameters

=head3 config_file

    optional parameter to set the configuration file name

=cut

has 'config_file' => ( 
    is      => 'rw',
    isa     => 'Str',
    default => '/etc/sysconfig/adminuser',
);



#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start  adminService

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_manageUsersDialog();
};

# TODO move to Shared?
sub _labeledFrameBox {
    my ($parent, $label) = @_;

    my $factory  = yui::YUI::widgetFactory;

    my $frame    = $factory->createFrame($parent, $label);
    $frame->setWeight( $yui::YD_HORIZ, 1);
    $frame->setWeight( $yui::YD_VERT, 2);
    $frame       = $factory->createHVCenter( $frame );
    $frame       = $factory->createVBox( $frame );
  return $frame;
}

# usefull local variable to avoid duplicating
# translation point for user edit labels
my %userEditLabel;
# usefull local variable to avoid duplicating
# translation point for group edit labels
my %groupEditLabel;


#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    Into this method additional data are initialized.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    if (! $self->name) {
        $self->name ($self->loc->N("adminUser"));
    }

    %userEditLabel = (
        user_data     => $self->loc->N("User Data"),
        account_info  => $self->loc->N("Account Info"),
        password_info => $self->loc->N("Password Info"),
        groups        => $self->loc->N("Groups"),
    );
    %groupEditLabel = (
        group_data    => $self->loc->N("Group Data"),
        group_users   => $self->loc->N("Group Users"),
    );
}


#=============================================================

=head2 ChooseGroup

=head3 INPUT

    $self: this object

=head3 OUTPUT

    $choice: 0 or 1 (choice)
            -1 cancel or exit

=head3 DESCRIPTION

creates a popup dialog to ask if adding user to an existing 
group or to the 'users' group

=cut

#=============================================================
sub ChooseGroup {
    my $self = shift;

    my $choice = -1;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Choose group"));
    
    my $factory  = yui::YUI::widgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);


    my $frame    = _labeledFrameBox($layout,  $self->loc->N("A group with this name already exists.  What would you like to do?"));

    my $rbg      = $factory->createRadioButtonGroup( $frame );
    $frame       = $factory->createVBox( $rbg );
    my $align    = $factory->createLeft($frame);

    my $rb1      = $factory->createRadioButton( $align, $self->loc->N("Add to the existing group"), 1);
    $rb1->setNotify(1);
    $rbg->addRadioButton( $rb1 );
    $align        = $factory->createLeft($frame);
    my $rb2 = $factory->createRadioButton( $align, $self->loc->N("Add to the 'users' group"), 0);
    $rb2->setNotify(1);
    $rbg->addRadioButton( $rb2 );

    my $hbox         = $factory->createHBox($layout);
    $align           = $factory->createRight($hbox);
    my $cancelButton = $factory->createPushButton($align, $self->loc->N("Cancel"));
    my $okButton     = $factory->createPushButton($hbox,  $self->loc->N("Ok"));
    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            if ($widget == $okButton) {
                $choice = $rb1->value() ? 0 : 1 ;
                last;
            }
        }
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

    return $choice;
}

#=============================================================

=head2 _deleteGroupDialog

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method open a dialog to delete the selected group.

=cut

#=============================================================
sub _deleteGroupDialog {
    my $self = shift;

    my $item = $self->get_widget('table')->selectedItem();
    if (! $item) {
       return;
    }

    my $groupname = $item->label(); 
    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Warning"));

    my $factory  = yui::YUI::widgetFactory;
    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);

    my $align    = $factory->createLeft($layout);

    $factory->createLabel($align, $self->loc->N("Do you really want to delete the group %s?", 
                                    $groupname));

    $align    = $factory->createRight($layout);
    my $hbox  = $factory->createHBox($align);
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));
    my $deleteButton = $factory->createPushButton($hbox,  $self->loc->N("Delete"));

    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $deleteButton) {
                my $username = $self->sh_users->isPrimaryGroup($groupname);
                if (defined($username)) {
                    $self->sh_gui->msgBox({
                        text => $self->loc->N("%s is a primary group for user %s\n Remove the user first",
                                              $groupname, $username
                        )
                    });
                }
                else {
                    if ($self->sh_users->deleteGroup($groupname)) {
                        Sys::Syslog::syslog('info|local1', $self->loc->N("Removing group: %s", $groupname));
                    }
                    $self->_refresh();
                }
                last;
            }
        }
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

#=============================================================

=head2 _deleteUserDialog

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method open a dialog to delete the selected user.
    It also asks for additional information to be removed.

=cut

#=============================================================
sub _deleteUserDialog {
    my $self = shift;

    my $item = $self->get_widget('table')->selectedItem();
    if (! $item) {
       return;
    } 
    my $username = $item->label(); 

    my $homedir = $self->sh_users->getUserHome($username);
    return if !defined($homedir);


    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Delete files or not?"));

    my $factory  = yui::YUI::widgetFactory;
    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);

    my $align    = $factory->createLeft($layout);
    $factory->createLabel($align, $self->loc->N("Deleting user %s\nAlso perform the following actions\n",
                                   $username));
    $align    = $factory->createLeft($layout);
    my $checkhome  = $factory->createCheckBox($align, $self->loc->N("Delete Home Directory: %s", $homedir), 0);
    $align    = $factory->createLeft($layout);
    my $checkspool = $factory->createCheckBox($align, $self->loc->N("Delete Mailbox: /var/spool/mail/%s",
                                                        $username), 0);
    $align    = $factory->createRight($layout);
    my $hbox  = $factory->createHBox($align);
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));
    my $deleteButton = $factory->createPushButton($hbox,  $self->loc->N("Delete"));
    
    if ($homedir !~ m!(?:/home|/var/spool)!) { 
        $checkhome->setDisabled(); 
        $checkspool->setDisabled(); 
    }

    
    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $deleteButton) {
                Sys::Syslog::syslog('info|local1', $self->loc->N("Removing user: %s", $username));
                my $option = undef;
                $option->{clean_home} = $checkhome->isChecked() if $checkhome->isChecked();
                $option->{clean_spool} = $checkspool->isChecked() if $checkspool->isChecked();

                my $err = $self->sh_users->deleteUser($username, $option);
                $self->sh_gui->msgBox({text => $err}) if (defined($err));

                #remove added icon
                $self->sh_users->removeKdmIcon($username);
                $self->_refresh();
                last;
            }
        }
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

}


sub _addGroupDialog {
    my $self = shift;

    my $is_system = 0;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Create New Group"));
    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);

    ## 'group name'
    my $align        = $factory->createRight($layout);
    my $hbox         = $factory->createHBox($align);
    my $label        = $factory->createLabel($hbox, $self->loc->N("Group Name:") );
    my $groupName    = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $groupName->setWeight($yui::YD_HORIZ, 2);

    $factory->createVSpacing($layout, 1);

    # Specify group id manually
    $align           = $factory->createLeft($layout);
    $hbox            = $factory->createHBox($align);
    my $gidManually  = $factory->createCheckBox($hbox, $self->loc->N("Specify group ID manually"), 0);
    $factory->createHSpacing($hbox, 2);
    my $GID = $factory->createIntField($hbox, $self->loc->N("GID"), 1, 65000, $self->sh_users->min_GID);
    $GID->setEnabled($gidManually->value());
    $gidManually->setNotify(1);

    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createRight($hbox);
    my $cancelButton = $factory->createPushButton($align, $self->loc->N("Cancel"));
    my $okButton     = $factory->createPushButton($hbox,  $self->loc->N("Ok"));
    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $gidManually) {
                # GID inserction enabled?
                $GID->setEnabled($gidManually->value());
            }
            elsif ($widget == $okButton) {
                ## check data
                my $groupname = $groupName->value();
                my ($continue, $errorString) = $self->sh_users->valid_groupname($groupname);
                my $nm = $continue && $self->sh_users->groupNameExists($groupname);
                if ($nm) {
                    $groupName->setValue("");
                    $errorString = $self->loc->N("Group already exists, please choose another Group Name");
                    $continue = 0;
                }

                my $gid = -1;
                if ($continue && $gidManually->value()) {
                    if (($gid = $GID->value()) < $self->sh_users->min_GID) {
                        $errorString = "";
                        my $gidchoice = $self->sh_gui->ask_YesOrNo({ title => $self->loc->N(" Group Gid is < %n", $self->sh_users->min_GID),
                                        text => $self->loc->N("Creating a group with a GID less than %d is not recommended.\n Are you sure you want to do this?\n\n",
                                                              $self->sh_users->min_GID
                                        )
                        });
                        $continue = $gidchoice;
                    } else {
                        if ($self->sh_users->groupIDExists($gid)) {
                            $errorString = "";
                            my $gidchoice = $self->sh_gui->ask_YesOrNo({title => $self->loc->N(" Group ID is already used "),
                                        text => $self->loc->N("Creating a group with a non unique GID?\n\n")});
                            $continue = $gidchoice;
                        }
                    }
                }


                if (!$continue) {
                    #--- raise error
                    $self->sh_gui->msgBox({text => $errorString}) if ($errorString);
                }
                else {
                    Sys::Syslog::syslog('info|local1', $self->loc->N("Adding group: %s ", $groupname));
                    my $groupParams = {
                        groupname  => $groupname,
                        is_system  => $is_system,
                    };
                    $groupParams->{gid} = $gid if $gid != -1;
                    $self->sh_users->addGroup($groupParams);
                    $self->_refresh();
                    last;
                }
            }
        }
    }
    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}


#=============================================================

=head2 _buildUserData

=head3 INPUT

    $self:    this object
    $layout : layout in wich drawing graphic user data
 
=head3 OUTPUT

    %userData: hash containing reference to graphical object 
               such as:
               full_name, login_name, password, password1,
               login_shell
               full_name, login_name, password, password1,
               weakness (icon), login_shell

=head3 DESCRIPTION

    This method is used by addUserDialog and _editUserDialog
    to create User Data dialog
=cut

#=============================================================
sub _buildUserData {
    my ($self, $layout, $selected_shell) = @_;


    my @shells = @{$self->sh_users->getUserShells()};

    my $factory  = yui::YUI::widgetFactory;

    ## user 'full name'
    my $align        = $factory->createRight($layout);
    my $hbox         = $factory->createHBox($align);
    my $label        = $factory->createLabel($hbox, $self->loc->N("Full Name:") );
    $factory->createHSpacing($hbox, 2.0);
    my $fullName     = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $fullName->setWeight($yui::YD_HORIZ, 2);

    ## user 'login name'
    $align           = $factory->createRight($layout);
    $hbox            = $factory->createHBox($align);
    $label           = $factory->createLabel($hbox, $self->loc->N("Login:") );
    $factory->createHSpacing($hbox, 2.0);
    my $loginName    = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $loginName->setWeight($yui::YD_HORIZ, 2);
    $loginName->setNotify(1);

    ## user 'Password'
    $align           = $factory->createRight($layout);
    $hbox            = $factory->createHBox($align);
    $label           = $factory->createLabel($hbox, $self->loc->N("Password:") );
    my $weakness = undef;
    if (yui::YUI::app()->hasImageSupport()) {
        $factory->createHSpacing($hbox, 2.0);
        my $file = File::ShareDir::dist_file(AdminPanel::Shared::distName(), 'images/Blank16x16.png');
        $weakness = $factory->createImage($hbox, $file);
    }
    else {
        $factory->createHSpacing($hbox, 1.0);
        $weakness = $factory->createLabel($hbox, "        ");
        $factory->createHSpacing($hbox, 1.0);
    }
    my $password     = $factory->createInputField($hbox, "", 1);
    $weakness->setWeight($yui::YD_HORIZ, 1);
    $label->setWeight($yui::YD_HORIZ, 1);
    $password->setWeight($yui::YD_HORIZ, 4);
    # notify input to check weakness
    $password->setNotify(1);
        
    ## user 'confirm Password'
    $align           = $factory->createRight($layout);
    $hbox            = $factory->createHBox($align);
    $label           = $factory->createLabel($hbox, $self->loc->N("Confirm Password:") );
    $factory->createHSpacing($hbox, 2.0);
    my $password1    = $factory->createInputField($hbox, "", 1);
    $label->setWeight($yui::YD_HORIZ, 1);
    $password1->setWeight($yui::YD_HORIZ, 2);
    
    ## user 'Login Shell'
    $align           = $factory->createRight($layout);
    $hbox            = $factory->createHBox($align);
    $label           = $factory->createLabel($hbox, $self->loc->N("Login Shell:") );
    $factory->createHSpacing($hbox, 2.0);
    my $loginShell   = $factory->createComboBox($hbox, "", 0);
    my $itemColl = new yui::YItemCollection;
    foreach my $shell (@shells) {
            my $item = new yui::YItem ($shell, 0);
            $item->setSelected(1) if ($selected_shell && $selected_shell eq $shell);
            $itemColl->push($item);
            $item->DISOWN();
    }
    $loginShell->addItems($itemColl);
    $label->setWeight($yui::YD_HORIZ, 1);
    $loginShell->setWeight($yui::YD_HORIZ, 2);
    
    my %userData = (
        full_name   => $fullName,
        login_name  => $loginName,
        password    => $password,
        password1   => $password1,
        weakness    => $weakness,
        login_shell => $loginShell,
    );
    
    return ( %userData );
}

#=============================================================

=head2 addUserDialog

=head3 INPUT

    $self:       this object
    $standalone: if set the application title is set
                 from the name set in costructor

=head3 DESCRIPTION

    This method creates and manages the dialog to add a new
    user.

=cut

#=============================================================
sub addUserDialog {
    my $self = shift;
    my $standalone = shift;

    if ($EUID != 0) {
        $self->sh_gui->warningMsgBox({
            title => $self->name, 
            text  => $self->loc->N("root privileges required"),
        });
        return;
    }

    my $dontcreatehomedir = 0; 
    my $is_system = 0;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    if ($standalone) {
        yui::YUI::app()->setApplicationTitle($self->name);
    }
    else {
        yui::YUI::app()->setApplicationTitle($self->loc->N("Create New User"));
    }
    
    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);
    
    my %userData = $self->_buildUserData($layout);
    
    ##### add a separator
    ## Create Home directory
    my $align           = $factory->createLeft($layout);
    my $hbox            = $factory->createHBox($align);
    my $createHome = $factory->createCheckBox($hbox, $self->loc->N("Create Home Directory"), 1);
    ## Home directory
    $align           = $factory->createLeft($layout);
    $hbox            = $factory->createHBox($align);
    my $label        = $factory->createLabel($hbox, $self->loc->N("Home Directory:") );
    $factory->createHSpacing($hbox, 2.0);
    my $homeDir      = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $homeDir->setWeight($yui::YD_HORIZ, 2);

    # Create private group
    $align           = $factory->createLeft($layout);
    $hbox            = $factory->createHBox($align);
    my $createGroup  = $factory->createCheckBox($hbox, $self->loc->N("Create a private group for the user"), 1);
    
    # Specify user id manually
    $align           = $factory->createRight($layout);
    $hbox            = $factory->createHBox($align);
    my $uidManually  = $factory->createCheckBox($hbox, $self->loc->N("Specify user ID manually"), 0);
    $factory->createHSpacing($hbox, 2.0);
    my $UID = $factory->createIntField($hbox, $self->loc->N("UID"), 1, 65000, $self->sh_users->min_UID);
    $UID->setEnabled($uidManually->value());
    $uidManually->setNotify(1);
#     $uidManually->setWeight($yui::YD_HORIZ, 2);
    $UID->setWeight($yui::YD_HORIZ, 1);

    ## user 'icon'
    $hbox        = $factory->createHBox($layout);
    $factory->createLabel($hbox, $self->loc->N("Click on icon to change it") );
    my $iconFace = $self->sh_users->GetFaceIcon();
    my $icon = $factory->createPushButton($hbox, "");
    $icon->setIcon($self->sh_users->face2png($iconFace)); 
    $icon->setLabel($iconFace);

    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createRight($hbox);
    my $cancelButton = $factory->createPushButton($align, $self->loc->N("Cancel"));
    my $okButton     = $factory->createPushButton($hbox,  $self->loc->N("Ok"));
    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $icon) {
                #remove shortcut from label
                my $iconLabel = $self->_skipShortcut($icon->label());

                my $nextIcon = $self->sh_users->GetFaceIcon($icon->label(), 1);
                $icon->setLabel($nextIcon);
                $icon->setIcon($self->sh_users->face2png($nextIcon));
            }
            elsif ($widget == $uidManually) {
                # UID inserction enabled?
                $UID->setEnabled($uidManually->value());
            }
            elsif ($widget == $userData{ login_name }) {
                my $username = $userData{ login_name }->value();
                $homeDir->setValue("/home/$username");
            }
            elsif ($widget == $userData{password}) {
                my $pass = $userData{ password }->value();
                $self->_checkWeaknessPassword($pass, $userData{ weakness });
            }
            elsif ($widget == $okButton) {
                ## check data
                my $username = $userData{ login_name }->value();
                my ($continue, $errorString) = $self->sh_users->valid_username($username);
                my $nm = $continue && $self->sh_users->userNameExists($username);
                if ($nm) {
                    $userData{ login_name }->setValue("");
                    $homeDir->setValue("");
                    $errorString = $self->loc->N("User already exists, please choose another User Name");
                    $continue = 0;
                }
                my $passwd = $continue && $userData{ password }->value();
                if ($continue && $passwd ne $userData{ password1 }->value()) {
                    $errorString = $self->loc->N("Password Mismatch");
                    $continue = 0;
                }
                if ($self->sh_users->weakPasswordForSecurityLevel($passwd)) {
                    $errorString = $self->loc->N("This password is too simple. \n Good passwords should be > 6 characters");
                    $continue = 0;
                }
                my $homedir;
                if ($continue && $createHome->value()) {
                    $homedir = $homeDir->value();
                    if ( -d $homedir) {
                        $errorString = $self->loc->N("Home directory <%s> already exists.\nPlease uncheck the home creation option, or change the directory path name", $homedir);
                        $continue = 0;
                    }
                    else {
                        $dontcreatehomedir = 0;
                    }
                } else {
                    $dontcreatehomedir = 1;
                }
                my $uid = -1;
                if ($continue && $uidManually->value()) {
                    if (($uid = $UID->value()) < $self->sh_users->min_UID) {
                        $errorString = "";
                        my $uidchoice = $self->sh_gui->ask_YesOrNo({title => $self->loc->N("User Uid is < %d", $self->sh_users->min_UID),
                                        text => $self->loc->N("Creating a user with a UID less than %d is not recommended.\nAre you sure you want to do this?\n\n", $self->sh_users->min_UID)});
                        $continue = $uidchoice;
                    }
                }
                my $gid = undef;
                if ($createGroup->value()) {
                    if ($continue) {
                        #Check if group exist
                        if ($self->sh_users->groupNameExists($username)) {
                            my $groupchoice = $self->ChooseGroup();
                            if ($groupchoice == 0 ) {
                                #You choose to put it in the existing group
                                $gid = $self->sh_users->groupID($username);
                            } elsif ($groupchoice == 1) {
                                # Put it in 'users' group
                                Sys::Syslog::syslog('info|local1', $self->loc->N("Putting %s to 'users' group",
                                                    $username));
                                $gid = $self->sh_users->Add2UsersGroup($username);
                            }
                            else {
                                $errorString = "";
                                $continue = 0;
                            }
                        } else { 
                            #it's a new group: Add it
                            $gid = $self->sh_users->addGroup({
                                groupname => $username,
                                is_system => $is_system,
                            });
                            Sys::Syslog::syslog('info|local1', $self->loc->N("Creating new group: %s", $username));
                        }
                    }
                } else {
                    $continue and $gid = $self->sh_users->Add2UsersGroup($username);
                }

                if (!$continue) {
                    #---rasie error
                    $self->sh_gui->msgBox({text => $errorString}) if ($errorString);
                }
                else {
                    ## OK let's create the user
                    print $self->loc->N("Adding user: ") . $username . " \n";
                    Sys::Syslog::syslog('info|local1', $self->loc->N("Adding user: %s", $username));
                    my $loginshell = $userData{ login_shell }->value();
                    my $fullname   = $userData{ full_name }->value();
                    utf8::decode($fullname);

                    my $userParams = {
                        username        => $username,
                        is_system       => $is_system,
                        donotcreatehome => $dontcreatehomedir,
                        shell           => $loginshell,
                        fullname        => $fullname,
                        gid             => $gid,
                        password  => $passwd,
                    };
                    $userParams->{uid} = $uid if $uid != -1;
                    $userParams->{homedir} = $homedir if !$dontcreatehomedir;
                    $self->sh_users->addUser($userParams);

                    defined $icon->label() and
                         $self->sh_users->addKdmIcon($username, $icon->label());
###  TODO Migration wizard
#                     
#                     Refresh($sysfilter, $stringsearch);
#                     transfugdrake::get_windows_disk()
#                         and $in->ask_yesorno($self->loc->N("Migration wizard"),
#                                             $self->loc->N("Do you want to run the migration wizard in order to import Windows documents and settings in your Mageia distribution?"))
#                             and run_program::raw({ detach => 1 }, 'transfugdrake');


                    last;
                }
            }
        }
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle; 
}

#=============================================================

=head2 _createUserTable

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

This function create the User table to be added to the replace 
point of the tab widget. Note this function is meant for internal 
use only

=cut

#=============================================================
sub _createUserTable {
    my $self = shift;

    $self->dialog->startMultipleChanges();
    $self->get_widget('replace_pnt')->deleteChildren();
    my $parent = $self->get_widget('replace_pnt');
    my $factory      = yui::YUI::widgetFactory;
    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($self->loc->N("User Name"),      $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("User ID"),        $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Primary Group"),  $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Full Name"),      $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Login Shell"),    $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Home Directory"), $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Status"),         $yui::YAlignBegin);
    $yTableHeader->DISOWN();
    
    $self->set_widget(table => $factory->createTable($parent, $yTableHeader));

    $self->get_widget('table')->setImmediateMode(1);
    $self->get_widget('table')->DISOWN();
    $self->get_widget('replace_pnt')->showChild();
    $self->dialog->recalcLayout();
    $self->dialog->doneMultipleChanges();
    $self->_refreshUsers();
}

#=============================================================

=head2 _createGroupTable

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

This function create the Group table to be added to the replace 
point of the tab widget. Note this function is meant for internal 
use only


=cut

#=============================================================
sub _createGroupTable {
    my $self = shift;


    $self->dialog->startMultipleChanges();
    $self->get_widget('replace_pnt')->deleteChildren();
    my $parent = $self->get_widget('replace_pnt');
    my $factory      = yui::YUI::widgetFactory;
    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($self->loc->N("Group Name"),     $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Group ID"),       $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Group Members"),  $yui::YAlignBegin);
    $yTableHeader->DISOWN();

    $self->set_widget(table => $factory->createTable($parent, $yTableHeader));
   
    $self->get_widget('table')->setImmediateMode(1);
    $self->get_widget('table')->DISOWN();
    $self->get_widget('replace_pnt')->showChild();
    $self->dialog->recalcLayout();
    $self->dialog->doneMultipleChanges(); 
    $self->_refreshGroups();
}




#=============================================================

=head2 _refreshUsers

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method refresh user info into User tab widget.
    Note this function is meant for internal use only

=cut

#=============================================================
sub _refreshUsers {
    my $self = shift;

    my $strfilt = $self->get_widget('filter')->value();
    my $filterusers = $self->get_widget('filter_system')->isChecked();

    my $usersInfo = $self->sh_users->getUsersInfo({
        username_filter => $strfilt,
        filter_system   => $filterusers,
    });


    $self->dialog->startMultipleChanges();
    #for some reasons QT send an event using table->selectItem()
    # WA remove notification immediate
    $self->get_widget('table')->setImmediateMode(0);
    $self->get_widget('table')->deleteAllItems();

    my $itemColl = new yui::YItemCollection;
    foreach my $username (keys %{$usersInfo}) {
        my $info = $usersInfo->{$username};
        my $item = new yui::YTableItem (
            "$username",
            "$info->{uid}",
            "$info->{group}",
            "$info->{fullname}",
            "$info->{shell}",
            "$info->{home}",
            "$info->{status}"
        );

        # TODO workaround to get first cell at least until we don't
        # a cast from YItem
        $item->setLabel( $username );
        $itemColl->push($item);
        $item->DISOWN();
    }

    $self->get_widget('table')->addItems($itemColl);
    my $item = $self->get_widget('table')->selectedItem();
    $self->get_widget('table')->selectItem($item, 0) if $item;
    $self->dialog->recalcLayout();
    $self->dialog->doneMultipleChanges(); 
    $self->_refreshActions();
    $self->get_widget('table')->setImmediateMode(1);
}

#=============================================================

=head2 _refreshGroups

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method refresh group info into Group tab widget.
    Note this function is meant for internal use only

=cut

#=============================================================
sub _refreshGroups {
    my $self = shift;

    my $strfilt = $self->get_widget('filter')->value();
    my $filtergroups = $self->get_widget('filter_system')->isChecked();

    $self->dialog->startMultipleChanges();
    #for some reasons QT send an event using table->selectItem()
    # WA remove notification immediate
    $self->get_widget('table')->setImmediateMode(0);
    $self->get_widget('table')->deleteAllItems();    

    my $groupInfo = $self->sh_users->getGroupsInfo({
        groupname_filter => $strfilt,
        filter_system    => $filtergroups,
    });

    my $itemColl = new yui::YItemCollection;
    foreach my $groupname (keys %{$groupInfo}) {
        my $info = $groupInfo->{$groupname};
        my $listUbyG  = join(',', @{$info->{members}});
        my $item = new yui::YTableItem ("$groupname",
                                        "$info->{gid}",
                                        "$listUbyG");
        $item->setLabel( $groupname );
        $itemColl->push($item);
        $item->DISOWN();
    }

    $self->get_widget('table')->addItems($itemColl);
    my $item = $self->get_widget('table')->selectedItem();
    $self->get_widget('table')->selectItem($item, 0) if $item;
    $self->dialog->recalcLayout();
    $self->dialog->doneMultipleChanges(); 
    $self->_refreshActions();
    $self->get_widget('table')->setImmediateMode(1);
}


#=============================================================

=head2 _getUserInfo

=head3 INPUT

    $self: this object

=head3 OUTPUT

    %userData:  selected user info as:
                username:      username
                full_name:      full name of user
                shell:         shell used  
                homedir:       home dir path
                UID:           User identifier
                acc_check_exp: account expiration enabling
                acc_expy:      account expiration year
                acc_expm:      account expiration month
                acc_expd:      account expiration day
                lockuser:      account locked
                pwd_check_exp: password expiration enabling
                pwd_exp_min:   days before changing password 
                               is allowed
                pwd_exp_max:   days before changing password 
                               is required
                pwd_exp_warn:  warning days before changing
                pwd_exp_inact: days before account becomes 
                               inact
                members:       Array containing groups the user
                               belongs to.
                primary_group: primary group ID for the user

=head3 DESCRIPTION

    Retrieves the selected user info from the system
    Note that acc_expy,  acc_expm and acc_expd are valid if 
    acc_check_exp is enabled.
    Note that pwd_exp_min, pwd_exp_max, pwd_exp_warn,
    pwd_exp_inact are valid if pwd_check_exp is enabled.

=cut

#=============================================================

sub _getUserInfo {
    my $self = shift;

    my $label = $self->_skipShortcut($self->get_widget('tabs')->selectedItem()->label());
    if ($label ne $self->loc->N("Users") ) {
        return undef;
    }

    my $item = $self->get_widget('table')->selectedItem();
    if (! $item) {
       return undef;
    }
    
    my %userData;
    $userData{username}  = $item->label(); 
    my $userEnt = $self->sh_users->ctx->LookupUserByName($userData{username});

    my $s                = $userEnt->Gecos($self->sh_users->USER_GetValue);
    utf8::decode($s);
    $userData{full_name} = $s;
    $userData{shell}     = $userEnt->LoginShell($self->sh_users->USER_GetValue);
    $userData{homedir}   = $userEnt->HomeDir($self->sh_users->USER_GetValue);
    $userData{UID}       = $userEnt->Uid($self->sh_users->USER_GetValue);

    # default expiration time
    my ($day, $mo, $ye)      = (localtime())[3, 4, 5];
    $userData{acc_expy}      = $ye+1900;
    $userData{acc_expm}      = $mo+1;
    $userData{acc_expd}      = $day;
    $userData{acc_check_exp} = 0;
    my $expire               = $userEnt->ShadowExpire($self->sh_users->USER_GetValue);
    if ($expire && $expire != -1) {
        my $times                = _TimeOfArray($expire, 1); 
        $userData{acc_expy}      = $times->{year};
        $userData{acc_expm}      = $times->{month};
        $userData{acc_expd}      = $times->{dayint};
        $userData{acc_check_exp} = 1;
    }

    # user password are not retrieved if admin wants
    # to change it has to insert a new one
    $userData{password}      = undef;
    $userData{password1}     = undef;
    # Check if user account is locked 

    $userData{lockuser}      = $self->sh_users->ctx->IsLocked($userEnt);

    $userData{icon_face}     = $self->sh_users->GetFaceIcon($userData{username});
    $userData{pwd_check_exp} = 0;
    $userData{pwd_exp_min}   = $userEnt->ShadowMin($self->sh_users->USER_GetValue);
    $userData{pwd_exp_max}   = $userEnt->ShadowMax($self->sh_users->USER_GetValue);
    $userData{pwd_exp_warn}  = $userEnt->ShadowWarn($self->sh_users->USER_GetValue);
    $userData{pwd_exp_inact} = $userEnt->ShadowInact($self->sh_users->USER_GetValue);
 
    if ($userData{pwd_exp_min} && $userData{pwd_exp_min} != -1 || 
        $userData{pwd_exp_max} && $userData{pwd_exp_max} != 99999 || 
        $userData{pwd_exp_warn} && $userData{pwd_exp_warn} != 7 && $userData{pwd_exp_warn} != -1 || 
        $userData{pwd_exp_inact} && $userData{pwd_exp_inact} != -1) {
        $userData{pwd_check_exp} = 1;
    }

    $userData{members}       = $self->sh_users->ctx->EnumerateGroupsByUser($userData{username});
    $userData{primary_group} = $userEnt->Gid($self->sh_users->USER_GetValue);
    
    return %userData;

}

#=============================================================

=head2 _getUserInfo

=head3 INPUT

    $self: this object

=head3 OUTPUT

    %groupData:  selected group info as:
    $groupname:  group name
    $members:    users that are members of this group

=head3 DESCRIPTION

    Retrieves the selected group info from the system

=cut

#=============================================================

sub _getGroupInfo {
    my $self = shift;

    my $label = $self->_skipShortcut($self->get_widget('tabs')->selectedItem()->label());
    if ($label ne $self->loc->N("Groups") ) {
        return undef;
    }

    my $item = $self->get_widget('table')->selectedItem();
    if (! $item) {
       return undef;
    }
    
    my %groupData;
    $groupData{start_groupname} = $item->label();
    $groupData{groupname}       = $item->label();

    my $groupEnt = $self->sh_users->ctx->LookupGroupByName($groupData{groupname});
    $groupData{members} = $self->sh_users->ctx->EnumerateUsersByGroup($groupData{groupname});
    
    return %groupData;

}

sub _storeDataFromGroupEditPreviousTab {
    my ($self, %groupData) = @_;

    my $previus_tab = $self->get_edit_tab_widget('edit_tab_label');
    if (!$previus_tab) {
        return %groupData;
    }
    elsif ($previus_tab eq $groupEditLabel{group_data}) {
        $groupData{groupname} = $self->get_edit_tab_widget('groupname')->value();
    }
    elsif ($previus_tab eq $groupEditLabel{group_users}) {
        my $tbl = $self->get_edit_tab_widget('members');
        $groupData{members} = undef;
        my @members; 
        my $i;
        for($i=0;$i<$tbl->itemsCount();$i++) {
            push (@members, $tbl->item($i)->label()) if $tbl->toCBYTableItem($tbl->item($i))->checked();
        }
        $groupData{members} = [ @members ];
    }

    return %groupData;       
}


sub _storeDataFromUserEditPreviousTab {
    my ($self, %userData) = @_;

    my $previus_tab = $self->get_edit_tab_widget('edit_tab_label');
    if (!$previus_tab) {
        return %userData;
    }
    elsif ($previus_tab eq $userEditLabel{user_data}) {
        $userData{full_name} = $self->get_edit_tab_widget('full_name')->value();
        $userData{username}  = $self->get_edit_tab_widget('login_name')->value() ; 
        $userData{shell}     = $self->get_edit_tab_widget('login_shell')->value();
        $userData{homedir}   = $self->get_edit_tab_widget('homedir')->value();
        my $passwd           = $self->get_edit_tab_widget('password')->value();
        $userData{password}  = $passwd;
        $passwd              = $self->get_edit_tab_widget('password1')->value();
        $userData{password1} = $passwd;
    }
    elsif ($previus_tab eq $userEditLabel{account_info}) {
        $userData{acc_check_exp} = $self->get_edit_tab_widget('acc_check_exp')->value();
        $userData{acc_expy}      = $self->get_edit_tab_widget('acc_expy')->value();
        $userData{acc_expm}      = $self->get_edit_tab_widget('acc_expm')->value();
        $userData{acc_expd}      = $self->get_edit_tab_widget('acc_expd')->value();
        $userData{lockuser}      = $self->get_edit_tab_widget('lockuser')->value();
        $userData{icon_face}     = $self->get_edit_tab_widget('icon_face')->label();
    }
    elsif ($previus_tab eq $userEditLabel{password_info}) {
        $userData{pwd_check_exp} = $self->get_edit_tab_widget('pwd_check_exp')->value();
        $userData{pwd_exp_min}   = $self->get_edit_tab_widget('pwd_exp_min')->value(); 
        $userData{pwd_exp_max}   = $self->get_edit_tab_widget('pwd_exp_max')->value();
        $userData{pwd_exp_warn}  = $self->get_edit_tab_widget('pwd_exp_warn')->value();
        $userData{pwd_exp_inact} = $self->get_edit_tab_widget('pwd_exp_inact')->value();
    }
    elsif ($previus_tab eq $userEditLabel{groups}) {
        my $tbl = $self->get_edit_tab_widget('members');
        $userData{members} = undef;
        my @members; 
        my $i;
        for($i=0;$i<$tbl->itemsCount();$i++) {
            push (@members, $tbl->item($i)->label()) if $tbl->toCBYTableItem($tbl->item($i))->checked();
        }
        $userData{members} = [ @members ];

        if ($self->get_edit_tab_widget('primary_group')->selectedItem()) {
            my $Gent      = $self->sh_users->ctx->LookupGroupByName($self->get_edit_tab_widget('primary_group')->selectedItem()->label());
            my $primgroup = $Gent->Gid($self->sh_users->USER_GetValue);

            $userData{primary_group} = $primgroup;
        }
        else {
            $userData{primary_group} = -1;
        }
    }

    return %userData;       
}

#=============================================================

=head2 _userDataTabWidget

=head3 INPUT

    $self:        this object
    $dialog:      YUI dialog that owns the YUI replace point
    $replace_pnt: YUI replace point, needed to add a new tab
                  widget
    %userData:    hash containing user data info, tabs are 
                  removed and added again on selection, so
                  data must be saved outside of widgets.
    $previus_tab: previous tab widget label, needed to store
                  user data from the old tab before removing
                  it, if user changed something. 

=head3 OUTPUT

    %userDataWidget: hash containing new YUI widget objects
                     such as:
                     returned onject from _buildUserData and
                     homedir. 

=head3 DESCRIPTION

    This internal method removes old tab widget saving its
    relevant data into userData and creates new selected table
    to be shown.

=cut

#=============================================================
sub _userDataTabWidget {
    my ($self, $dialog, $replace_pnt, %userData) = @_;
     
    my $factory  = yui::YUI::widgetFactory;

    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();
    my $layout         = $factory->createVBox($replace_pnt);
    my %userDataWidget = $self->_buildUserData($layout, $userData{shell});

    ## user 'login name'
    my $align                = $factory->createRight($layout);
    my $hbox                 = $factory->createHBox($align);
    my $label                = $factory->createLabel($hbox, $self->loc->N("Home:") );
    $factory->createHSpacing($hbox, 2.0);
    $userDataWidget{homedir} = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $userDataWidget{homedir}->setWeight($yui::YD_HORIZ, 2);

    # fill data into widgets
    ##
    # full_name, login_name, password, password1,
    #                login_shell
    $userDataWidget{full_name}->setValue($userData{full_name});
    $userDataWidget{login_name}->setValue($userData{username});
    yui::YUI::ui()->blockEvents();
    $userDataWidget{password}->setValue($userData{password})  if $userData{password};
    yui::YUI::ui()->unblockEvents();
    $userDataWidget{password1}->setValue($userData{password1}) if $userData{password1};
    $userDataWidget{homedir}->setValue($userData{homedir});

    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %userDataWidget;
}


#=============================================================

=head2 _groupDataTabWidget

=head3 INPUT

    $self:        this object
    $dialog:      YUI dialog that owns the YUI replace point
    $replace_pnt: YUI replace point, needed to add a new tab
                  widget
    %groupData:   hash containing group data info, tabs are 
                  removed and added again on selection, so
                  data must be saved outside of widgets.
    $previus_tab: previous tab widget label, needed to store
                  group data from the old tab before removing
                  it, if user changed something. 

=head3 OUTPUT

    %groupDataWidget: hash containing new YUI widget objects
                      such as:
                       groupname. 

=head3 DESCRIPTION

    This internal method removes old tab widget saving its
    relevant data into groupData and creates new selected table
    to be shown.

=cut

#=============================================================
sub _groupDataTabWidget {
    my ($self, $dialog, $replace_pnt, %groupData) = @_;
     
    my $factory  = yui::YUI::widgetFactory;

    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();
    my $layout               = $factory->createVBox($replace_pnt);

    my %groupDataWidget;

    ## user 'login name'
    my $align                = $factory->createRight($layout);
    my $hbox                 = $factory->createHBox($align);
    my $label                = $factory->createLabel($hbox, $self->loc->N("Group Name:") );
    $groupDataWidget{groupname} = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $groupDataWidget{groupname}->setWeight($yui::YD_HORIZ, 2);

    $groupDataWidget{groupname}->setValue($groupData{groupname});

    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %groupDataWidget;
}


sub _userAccountInfoTabWidget {
    my ($self, $dialog, $replace_pnt, %userData) = @_;

    my $factory  = yui::YUI::widgetFactory;
    
    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();
    my $layout         = $factory->createVBox($replace_pnt);

    my %userAccountWidget;
    $userAccountWidget{acc_check_exp} = $factory->createCheckBoxFrame($layout, $self->loc->N("Enable account expiration"), 1);
    my $align                         = $factory->createRight($userAccountWidget{acc_check_exp});
    my $hbox                          = $factory->createHBox($align);    
    my $label                         = $factory->createLabel($hbox, $self->loc->N("Account expires (YYYY-MM-DD):"));
    $userAccountWidget{acc_expy}      = $factory->createIntField($hbox, "", 1970, 9999, $userData{acc_expy});
    $userAccountWidget{acc_expm}      = $factory->createIntField($hbox, "", 1, 12, $userData{acc_expm});
    $userAccountWidget{acc_expd}      = $factory->createIntField($hbox, "", 1, 31, $userData{acc_expd});
    $userAccountWidget{acc_check_exp}->setValue($userData{acc_check_exp});
    $label->setWeight($yui::YD_HORIZ, 2);
    $align                            = $factory->createLeft($layout);
    $userAccountWidget{lockuser}      = $factory->createCheckBox($align, $self->loc->N("Lock User Account"), $userData{lockuser});
    
    $align                            = $factory->createLeft($layout);
    $hbox                             = $factory->createHBox($align); 
    $label                            = $factory->createLabel($hbox, $self->loc->N("Click on the icon to change it"));
    $userAccountWidget{icon_face}     = $factory->createPushButton($hbox, "");
    $userAccountWidget{icon_face}->setIcon($self->sh_users->face2png($userData{icon_face})); 
    $userAccountWidget{icon_face}->setLabel($userData{icon_face});
    
    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %userAccountWidget;
}


sub _userPasswordInfoTabWidget {
    my ($self, $dialog, $replace_pnt, %userData) = @_;

    my $factory  = yui::YUI::widgetFactory;
    
    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();
    my $layout  = $factory->createVBox($replace_pnt);

    my %userPasswordWidget;
    my $userEnt = $self->sh_users->ctx->LookupUserByName($userData{username});
    my $lastchg = $userEnt->ShadowLastChange($self->sh_users->USER_GetValue);

    my $align   = $factory->createLeft($layout);
    my $hbox    = $factory->createHBox($align);    
    my $label   = $factory->createLabel($hbox, $self->loc->N("User last changed password on: "));
    my $dayStr  = $factory->createLabel($hbox, "");
    my $month   = $factory->createLabel($hbox, "");
    my $dayInt  = $factory->createLabel($hbox, "");
    my $year    = $factory->createLabel($hbox, "");
    if ($lastchg) {
        my $times = _TimeOfArray($lastchg, 0); 
        $dayStr->setValue($times->{daystr});
        $month->setValue($times->{month});
        $dayInt->setValue($times->{dayint});
        $year->setValue($times->{year});
    }
    
    $userPasswordWidget{pwd_check_exp} = $factory->createCheckBoxFrame($layout, $self->loc->N("Enable Password Expiration"), 1);
    $layout  = $factory->createVBox($userPasswordWidget{pwd_check_exp});
    $align   = $factory->createLeft($layout);
    $hbox    = $factory->createHBox($align);
    $label   = $factory->createLabel($hbox, $self->loc->N("Days before change allowed:"));
    $userPasswordWidget{pwd_exp_min} = $factory->createInputField($hbox, "", 0);
    $userPasswordWidget{pwd_exp_min}->setValue("$userData{pwd_exp_min}");
    $label->setWeight($yui::YD_HORIZ, 1);
    $userPasswordWidget{pwd_exp_min}->setWeight($yui::YD_HORIZ, 2);
    
    $align   = $factory->createLeft($layout);
    $hbox    = $factory->createHBox($align);
    $label   = $factory->createLabel($hbox, $self->loc->N("Days before change required:"));
    $userPasswordWidget{pwd_exp_max} = $factory->createInputField($hbox, "", 0);
    $userPasswordWidget{pwd_exp_max}->setValue("$userData{pwd_exp_max}");
    $label->setWeight($yui::YD_HORIZ, 1);
    $userPasswordWidget{pwd_exp_max}->setWeight($yui::YD_HORIZ, 2);

    $align   = $factory->createLeft($layout);
    $hbox    = $factory->createHBox($align);
    $label   = $factory->createLabel($hbox, $self->loc->N("Days warning before change:"));
    $userPasswordWidget{pwd_exp_warn} = $factory->createInputField($hbox, "", 0);
    $userPasswordWidget{pwd_exp_warn}->setValue("$userData{pwd_exp_warn}");
    $label->setWeight($yui::YD_HORIZ, 1);
    $userPasswordWidget{pwd_exp_warn}->setWeight($yui::YD_HORIZ, 2);

    $align   = $factory->createLeft($layout);
    $hbox    = $factory->createHBox($align);
    $label   = $factory->createLabel($hbox, $self->loc->N("Days before account inactive:"));
    $userPasswordWidget{pwd_exp_inact} = $factory->createInputField($hbox, "", 0);
    $userPasswordWidget{pwd_exp_inact}->setValue("$userData{pwd_exp_inact}");
    $label->setWeight($yui::YD_HORIZ, 1);
    $userPasswordWidget{pwd_exp_inact}->setWeight($yui::YD_HORIZ, 2);

    $userPasswordWidget{pwd_check_exp}->setValue($userData{pwd_check_exp});

    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %userPasswordWidget;
}

sub _groupUsersTabWidget {
    my ($self, $dialog, $replace_pnt, %groupData) = @_;

    my $factory  = yui::YUI::widgetFactory;
    my $mageiaPlugin = "mga";
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);
    
    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();

    my %groupUsersWidget;

    my $layout   = _labeledFrameBox($replace_pnt, $self->loc->N("Select the users to join this group:"));

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn("", $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("User"), $yui::YAlignBegin);

    $groupUsersWidget{members} = $mgaFactory->createCBTable($layout, $yTableHeader, $yui::YCBTableCheckBoxOnFirstColumn);

    my $groupEnt = $self->sh_users->ctx->LookupGroupByName($groupData{groupname});
    my $users  = $self->sh_users->ctx->UsersEnumerate;
    my @susers = sort(@$users);

    my $itemCollection = new yui::YItemCollection;
    my $members = $groupData{members};
    foreach my $user (@susers) {
        my $item = new yui::YCBTableItem($user);
        $item->check(MDK::Common::DataStructure::member($user, @$members));
        $item->setLabel($user);
        $itemCollection->push($item);
        $item->DISOWN();    
    }    
    $groupUsersWidget{members}->addItems($itemCollection);

    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %groupUsersWidget;
}

sub _userGroupsTabWidget {
    my ($self, $dialog, $replace_pnt, %userData) = @_;

    my $factory  = yui::YUI::widgetFactory;
    my $mageiaPlugin = "mga";
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);
    
    $dialog->startMultipleChanges();

    $replace_pnt->deleteChildren();

    my %userGroupsWidget;
    my $userEnt = $self->sh_users->ctx->LookupUserByName($userData{username});
    my $lastchg = $userEnt->ShadowLastChange($self->sh_users->USER_GetValue);

    my $layout   = _labeledFrameBox($replace_pnt, $self->loc->N("Select groups that the user will be member of:"));

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn("", $yui::YAlignBegin);
    $yTableHeader->addColumn($self->loc->N("Group"), $yui::YAlignBegin);

    $userGroupsWidget{members} = $mgaFactory->createCBTable($layout, $yTableHeader, $yui::YCBTableCheckBoxOnFirstColumn);

    my $grps = $self->sh_users->ctx->GroupsEnumerate;
    my @sgroups = sort @$grps;
 
    my $itemCollection = new yui::YItemCollection;
    my $members = $userData{members};
    foreach my $group (@sgroups) {
        my $item = new yui::YCBTableItem($group);
        $item->check(MDK::Common::DataStructure::member($group, @$members));
        $item->setLabel($group);
        $itemCollection->push($item);
        $item->DISOWN();    
    }    
    $userGroupsWidget{members}->addItems($itemCollection);
    $userGroupsWidget{members}->setNotify(1);
    my $primgroup = '';
    if ($userData{primary_group} != -1) {
        my $Gent      = $self->sh_users->ctx->LookupGroupById($userData{primary_group});
        $primgroup    = $Gent->GroupName($self->sh_users->USER_GetValue);
    }

    my $align   = $factory->createLeft($layout);
    my $hbox    = $factory->createHBox($align);    
    my $label   = $factory->createLabel($hbox, $self->loc->N("Primary Group"));
    $userGroupsWidget{primary_group} = $factory->createComboBox($hbox, "", 0);
    my $itemColl = new yui::YItemCollection;
    foreach my $member (@$members) {
            my $item = new yui::YItem ($member, 0);
            $item->setSelected(1) if ($item->label() eq $primgroup);
            $itemColl->push($item);
            $item->DISOWN();
    }
    $userGroupsWidget{primary_group}->addItems($itemColl);
    $label->setWeight($yui::YD_HORIZ, 1);
    $userGroupsWidget{primary_group}->setWeight($yui::YD_HORIZ, 2);

    $replace_pnt->showChild();
    $dialog->recalcLayout();
    $dialog->doneMultipleChanges();
    
    return %userGroupsWidget;
}

sub _groupEdit_Ok {
    my ($self, %groupData) = @_;

    # update last changes if any 
    %groupData = $self->_storeDataFromGroupEditPreviousTab(%groupData);
    
    my ($continue, $errorString) = $self->sh_users->valid_groupname($groupData{groupname});
    if (!$continue) {
        $self->sh_gui->msgBox({text => $errorString}) if ($errorString);
        return $continue;
    }
    my $groupEnt = $self->sh_users->ctx->LookupGroupByName($groupData{start_groupname});
    if ($groupData{start_groupname} ne $groupData{groupname}) { 
        $groupEnt->GroupName($groupData{groupname}); 
    }

    my $members = $groupData{members};
    my $gid     = $groupEnt->Gid($self->sh_users->USER_GetValue);
    my $users   = $self->sh_users->ctx->UsersEnumerate;
    my @susers  = sort(@$users);

    foreach my $user (@susers) {
        my $uEnt = $self->sh_users->ctx->LookupGroupByName($user);
        if ($uEnt) {
            my $ugid = $uEnt->Gid($self->sh_users->USER_GetValue);
            my $m    = $self->sh_users->ctx->EnumerateUsersByGroup($groupData{start_groupname});
            if (MDK::Common::DataStructure::member($user, @$members)) {
                if (!AdminPanel::Shared::inArray($user, $m)) {
                    if ($ugid != $gid) {
                        eval { $groupEnt->MemberName($user,1) };
                    }
                }
            }
            else {
                if (AdminPanel::Shared::inArray($user, $m)) {
                    if ($ugid == $gid) {
                        $self->sh_gui->msgBox({text => $self->loc->N("You cannot remove user '%s' from their primary group", $user)});
                        return 0;
                    }
                    else {
                        eval { $groupEnt->MemberName($user,2) };
                    }
                }
            }
        }
    }    

    $self->sh_users->ctx->GroupModify($groupEnt);
    $self->_refresh();

    return 1;
}

sub _userEdit_Ok {
    my ($self, %userData) = @_;

    # update last changes if any 
    %userData = $self->_storeDataFromUserEditPreviousTab(%userData);
    
    my ($continue, $errorString) = $self->sh_users->valid_username($userData{username});
    if (!$continue) {
        $self->sh_gui->msgBox({text => $errorString}) if ($errorString);
        return $continue;
    }

    if ( $userData{password} ne $userData{password1}) {
        $self->sh_gui->msgBox({text => $self->loc->N("Password Mismatch")});
        return 0;
    }
    my $userEnt = $self->sh_users->ctx->LookupUserByName($userData{username});
    if ($userData{password} ne '') {
        if ($self->sh_users->weakPasswordForSecurityLevel($userData{password})) {
            $self->sh_gui->msgBox({text => $self->loc->N("This password is too simple. \n Good passwords should be > 6 characters")});
            return 0;
        }
        $self->sh_users->ctx->UserSetPass($userEnt, $userData{password});
    }

    $userEnt->UserName($userData{username});
    $userEnt->Gecos($userData{full_name});
    $userEnt->HomeDir($userData{homedir});
    $userEnt->LoginShell($userData{shell});
    my $username = $userEnt->UserName($self->sh_users->USER_GetValue);
    my $grps = $self->sh_users->ctx->GroupsEnumerate;
    my @sgroups = sort @$grps;
 
    my $members = $userData{members};
    foreach my $group (@sgroups) {

        my $gEnt = $self->sh_users->ctx->LookupGroupByName($group);
        my $ugid = $gEnt->Gid($self->sh_users->USER_GetValue);
        my $m    = $gEnt->MemberName(1,0);
        if (MDK::Common::DataStructure::member($group, @$members)) {
            if (!AdminPanel::Shared::inArray($username, $m) && $userData{primary_group} != $ugid) {
                eval { $gEnt->MemberName($username, 1) };
                $self->sh_users->ctx->GroupModify($gEnt);
            }
        }
        else {
            if (AdminPanel::Shared::inArray($username, $m)) {
                eval { $gEnt->MemberName($username, 2) };
                $self->sh_users->ctx->GroupModify($gEnt);
            }
        }
    }
    if ($userData{primary_group} == -1) {
        $self->sh_gui->msgBox({ text => $self->loc->N("Please select at least one group for the user")});
        return 0;
    }
    $userEnt->Gid($userData{primary_group});

    if ($userData{acc_check_exp}) {
        my $yr = $userData{acc_expy}; 
        my $mo = $userData{acc_expm};
        my $dy = $userData{acc_expd};
        if (!_ValidInt($yr, $dy, $mo)) {
            $self->sh_gui->msgBox({text => $self->loc->N("Please specify Year, Month and Day \n for Account Expiration ")});
            return 0;
        }
        my $Exp = _ConvTime($dy, $mo, $yr);
        $userEnt->ShadowExpire($Exp);
    }
    else { 
        $userEnt->ShadowExpire(ceil(-1)) 
    }

    if ($userData{pwd_check_exp}) {
        my $allowed = int($userData{pwd_exp_min});
        my $required = int($userData{pwd_exp_max});
        my $warning = int($userData{pwd_exp_warn});
        my $inactive = int($userData{pwd_exp_inact});
        if ($allowed && $required && $warning && $inactive) {
            $userEnt->ShadowMin($allowed);
            $userEnt->ShadowMax($required);
            $userEnt->ShadowWarn($warning);
            $userEnt->ShadowInact($inactive);
        }
        else {
            $self->sh_gui->msgBox({text => $self->loc->N("Please fill up all fields in password aging\n")});
            return 0;
        }
    }
    else {
        $userEnt->ShadowMin(-1);
        $userEnt->ShadowMax(99999);
        $userEnt->ShadowWarn(-1);
        $userEnt->ShadowInact(-1); 
    }
   
    $self->sh_users->ctx->UserModify($userEnt);

    if ($userData{lockuser}) {
        !$self->sh_users->ctx->IsLocked($userEnt) and $self->sh_users->ctx->Lock($userEnt);
    } 
    else { 
        $self->sh_users->ctx->IsLocked($userEnt) and $self->sh_users->ctx->UnLock($userEnt);
    }
            
    defined $userData{icon_face} and $self->sh_users->addKdmIcon($userData{username}, $userData{icon_face});
    $self->_refresh();

    return 1;
}


# check the password and set the widget accordingly
sub _checkWeaknessPassword {
    my ($self, $password, $weakness_widget) = @_;

    my $strongp = $self->sh_users->strongPassword($password);
    if (yui::YUI::app()->hasImageSupport()) {
        my $file = File::ShareDir::dist_file(AdminPanel::Shared::distName(), 'images/Warning_Shield_Grey16x16.png');
        if ($strongp) {
            $file =  File::ShareDir::dist_file(AdminPanel::Shared::distName(), 'images/Checked_Shield_Green16x16.png');
        }
        $weakness_widget->setImage($file);
    }
    else {
        # For ncurses set a label
        $weakness_widget->setValue(($strongp ? $self->loc->N("Strong") : $self->loc->N("Weak")));
    }
}

sub _editUserDialog {
    my $self = shift;

    my $dontcreatehomedir = 0; 
    my $is_system = 0;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Edit User"));
    
    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);
    
    my %tabs;
    if ($optional->hasDumbTab()) {
        my $hbox = $factory->createHBox($layout);
        my $align = $factory->createHCenter($hbox);
        $tabs{widget} = $optional->createDumbTab($align);

        $tabs{user_data} = new yui::YItem($userEditLabel{user_data});
        $tabs{user_data}->setSelected();
        $tabs{used}      = $tabs{user_data}->label();
        $tabs{widget}->addItem( $tabs{user_data} );
        $tabs{user_data}->DISOWN();

        $tabs{account_info} = new yui::YItem($userEditLabel{account_info});
        $tabs{widget}->addItem( $tabs{account_info} );
        $tabs{account_info}->DISOWN();

        $tabs{password_info} = new yui::YItem($userEditLabel{password_info});
        $tabs{widget}->addItem( $tabs{password_info} );
        $tabs{password_info}->DISOWN();

        $tabs{groups} = new yui::YItem($userEditLabel{groups});
        $tabs{widget}->addItem( $tabs{groups} );
        $tabs{groups}->DISOWN();

        my $vbox           = $factory->createVBox($tabs{widget});
        $align             = $factory->createLeft($vbox);
        $tabs{replace_pnt} = $factory->createReplacePoint($align);
        
        $hbox            = $factory->createHBox($vbox);
        $align           = $factory->createRight($hbox);
        my $cancelButton = $factory->createPushButton($align, $self->loc->N("Cancel"));
        my $okButton     = $factory->createPushButton($hbox,  $self->loc->N("Ok"));
        
        my %userData        = $self->_getUserInfo();
        # userData here should be tested because it could be undef
        
        # Useful entry point for the current edit user/group tab widget 
        $self->set_edit_tab_widget( $self->_userDataTabWidget($dlg, $tabs{replace_pnt}, %userData) );
        $self->set_edit_tab_widget( edit_tab_label => $userEditLabel{user_data});

        while(1) {
            my $event     = $dlg->waitForEvent();
            my $eventType = $event->eventType();
            
            #event type checking
            if ($eventType == $yui::YEvent::CancelEvent) {
                last;
            }
            elsif ($eventType == $yui::YEvent::MenuEvent) {
                ### MENU ###
                my $item = $event->item();
                if ($item->label() eq $tabs{user_data}->label()) {
                    %userData = $self->_storeDataFromUserEditPreviousTab(%userData);
                    my %edit_tab = $self->_userDataTabWidget($dlg, $tabs{replace_pnt}, %userData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $userEditLabel{user_data});
                }
                elsif ($item->label() eq $tabs{account_info}->label()) {
                    %userData = $self->_storeDataFromUserEditPreviousTab(%userData);
                    my %edit_tab = $self->_userAccountInfoTabWidget($dlg, $tabs{replace_pnt}, %userData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $userEditLabel{account_info});
                }
                elsif ($item->label() eq $tabs{password_info}->label()) {
                    %userData = $self->_storeDataFromUserEditPreviousTab(%userData);
                    my %edit_tab = $self->_userPasswordInfoTabWidget($dlg, $tabs{replace_pnt}, %userData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $userEditLabel{password_info});
                }
                elsif ($item->label() eq $tabs{groups}->label()) {
                    %userData = $self->_storeDataFromUserEditPreviousTab(%userData);
                    my %edit_tab = $self->_userGroupsTabWidget($dlg, $tabs{replace_pnt}, %userData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $userEditLabel{groups});
                }
            }
            elsif ($eventType == $yui::YEvent::WidgetEvent) {
                ### widget 
                my $widget = $event->widget();
                if ($widget == $cancelButton) {
                    last;
                }
                elsif ($widget == $self->get_edit_tab_widget('password')) {
                    my $pass = $self->get_edit_tab_widget('password')->value();
                    $self->_checkWeaknessPassword($pass, $self->get_edit_tab_widget('weakness'));
                }
                elsif ($widget == $okButton) {
                    ## save changes
                    if ($self->_userEdit_Ok(%userData)) {
                        last;
                    }
                }
# last: managing tab widget events
                else {
                    my $current_tab = $self->get_edit_tab_widget('edit_tab_label');
                    if ($current_tab && $current_tab eq $userEditLabel{account_info}) {
                        if ($widget == $self->get_edit_tab_widget('icon_face')) {
                            my $iconLabel = $self->_skipShortcut($self->get_edit_tab_widget('icon_face')->label());
                            my $nextIcon = $self->sh_users->GetFaceIcon($iconLabel, 1);
                            $self->get_edit_tab_widget('icon_face')->setLabel($nextIcon);
                            $self->get_edit_tab_widget('icon_face')->setIcon($self->sh_users->face2png($nextIcon));
                        }
                    }                    
                    elsif ($current_tab && $current_tab eq $userEditLabel{groups}) {
                        if ($widget == $self->get_edit_tab_widget('members')) {
                            my $item = $self->get_edit_tab_widget('members')->changedItem();
                            if ($item) {
                                if ($item->checked()) {
                                    # add it to possible primary groups
                                    my $pgItem = new yui::YItem ($item->label(), 0);
                                    $self->get_edit_tab_widget('primary_group')->addItem($pgItem);
                                }
                                else {
                                    # remove it to possible primary groups
                                    $dlg->startMultipleChanges();
                                    my $itemColl = new yui::YItemCollection;
                                    my $tbl = $self->get_edit_tab_widget('members');
                                    for(my $i=0;$i < $tbl->itemsCount();$i++) {
                                        if ($tbl->toCBYTableItem($tbl->item($i))->checked()) {
                                            my $pgItem = new yui::YItem ($tbl->item($i)->label(), 0);
                                            my $Gent   = $self->sh_users->ctx->LookupGroupById($userData{primary_group});
                                            my $primgroup = $Gent->GroupName($self->sh_users->USER_GetValue);
                                            $pgItem->setSelected(1) if ($pgItem->label() eq $primgroup);

                                            $itemColl->push($pgItem);
                                            $pgItem->DISOWN();
                                        } 
                                    }
                                    $self->get_edit_tab_widget('primary_group')->deleteAllItems();
                                    $self->get_edit_tab_widget('primary_group')->addItems($itemColl);
                                    $dlg->recalcLayout();
                                    $dlg->doneMultipleChanges();
                                }
                            }
                        }                        
                    }
                }
            }
        }

    }
    else {
        $self->sh_gui->warningMsgBox({text => $self->loc->N("Cannot create tab widgets")});
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

}

sub _editGroupDialog {
    my $self = shift;
 
    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->loc->N("Edit Group"));
    
    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);
    
    my %tabs;
    if ($optional->hasDumbTab()) {
        my $hbox = $factory->createHBox($layout);
        my $align = $factory->createHCenter($hbox);
        $tabs{widget} = $optional->createDumbTab($align);

        $tabs{group_data} = new yui::YItem($groupEditLabel{group_data});
        $tabs{group_data}->setSelected();
        $tabs{widget}->addItem( $tabs{group_data} );
        $tabs{group_data}->DISOWN();

        $tabs{group_users} = new yui::YItem($groupEditLabel{group_users});
        $tabs{widget}->addItem( $tabs{group_users} );
        $tabs{group_users}->DISOWN();

        my $vbox           = $factory->createVBox($tabs{widget});
        $align             = $factory->createLeft($vbox);
        $tabs{replace_pnt} = $factory->createReplacePoint($align);
        
        $hbox            = $factory->createHBox($vbox);
        $align           = $factory->createRight($hbox);
        my $cancelButton = $factory->createPushButton($align, $self->loc->N("Cancel"));
        my $okButton     = $factory->createPushButton($hbox,  $self->loc->N("Ok"));
        
        my %groupData        = $self->_getGroupInfo();
        # groupData here should be tested because it could be undef

# %groupData:  selected group info as:
# $groupname:  group name
# $members:    users that are members of this group


        # Useful entry point for the current edit user/group tab widget 
        $self->set_edit_tab_widget( $self->_groupDataTabWidget($dlg, $tabs{replace_pnt}, %groupData) );
        $self->set_edit_tab_widget( edit_tab_label => $groupEditLabel{group_data});

        while(1) {
            my $event     = $dlg->waitForEvent();
            my $eventType = $event->eventType();
            
            #event type checking
            if ($eventType == $yui::YEvent::CancelEvent) {
                last;
            }
            elsif ($eventType == $yui::YEvent::MenuEvent) {
                ### MENU ###
                my $item = $event->item();
                if ($item->label() eq $tabs{group_data}->label()) {
                    %groupData = $self->_storeDataFromGroupEditPreviousTab(%groupData);
                    my %edit_tab = $self->_groupDataTabWidget($dlg, $tabs{replace_pnt}, %groupData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $groupEditLabel{group_data});
                }
                elsif ($item->label() eq $tabs{group_users}->label()) {
                    %groupData = $self->_storeDataFromGroupEditPreviousTab(%groupData);
                    my %edit_tab = $self->_groupUsersTabWidget($dlg, $tabs{replace_pnt}, %groupData );
                    $self->edit_tab_widgets( {} );
                    $self->set_edit_tab_widget(%edit_tab);
                    $self->set_edit_tab_widget( edit_tab_label => $groupEditLabel{group_users});
                }
            }
            elsif ($eventType == $yui::YEvent::WidgetEvent) {
                ### widget 
                my $widget = $event->widget();
                if ($widget == $cancelButton) {
                    last;
                }
                elsif ($widget == $okButton) {
                    ## save changes
                    if ($self->_groupEdit_Ok(%groupData)) {
                        last;
                    }
                }
            }
        }

    }
    else {
        $self->sh_gui->warningMsgBox({text => $self->loc->N("Cannot create tab widgets")});
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

}

sub _editUserOrGroup {
    my $self = shift;

    # TODO item management avoid label if possible
    my $label = $self->_skipShortcut($self->get_widget('tabs')->selectedItem()->label());
    if ($label eq $self->loc->N("Users") ) {
        $self->_editUserDialog(); 
    }
    else {
        $self->_editGroupDialog();
    }
    $self->_refresh();
}


sub _deleteUserOrGroup {
    my $self = shift;

    # TODO item management avoid label if possible
    my $label = $self->_skipShortcut($self->get_widget('tabs')->selectedItem()->label());
    if ($label eq $self->loc->N("Users") ) {
        $self->_deleteUserDialog();
        $self->_refresh();
    }
    else {
        $self->_deleteGroupDialog();
        $self->_refresh();
    }
}


sub _refresh {
    my $self = shift;

    # TODO item management avoid label if possible
    my $label = $self->_skipShortcut($self->get_widget('tabs')->selectedItem()->label());
    if ($label eq $self->loc->N("Users") ) {
        $self->_refreshUsers(); 
    }
    else {
        $self->_refreshGroups();
    }
# TODO xguest
#     RefreshXguest(1);
}

# TODO context menu creation is missed in libyui 
sub _contextMenuActions {
    my $self = shift;

    my $item = $self->get_widget('table')->selectedItem();
    if ($item) {
    }
}

sub _refreshActions {
    my $self = shift;
    
    my $item = $self->get_widget('table')->selectedItem();
    $self->dialog->startMultipleChanges();
    $self->get_widget('action_menu')->deleteAllItems();
    
    # do we need to undef them first?
    $self->set_action_menu(
            add_user  => undef, 
            add_group => undef,
            edit      => undef,
            del       => undef,
            inst      => undef,
    );
    $self->set_action_menu(
            add_user  => new yui::YMenuItem($self->loc->N("Add User")), 
            add_group => new yui::YMenuItem($self->loc->N("Add Group")),
            edit      => new yui::YMenuItem($self->loc->N("&Edit")),
            del       => new yui::YMenuItem($self->loc->N("&Delete")),
            inst      => new yui::YMenuItem($self->loc->N("Install guest account")),
    );

    my $itemColl = new yui::YItemCollection;
    for my $pair ( $self->action_menu_pairs ) {
        my $menuItem = $pair->[1];
        if ($pair->[0] eq 'edit' || $pair->[0] eq 'del') {
            if ($item) {
                $itemColl->push($menuItem);
            }
        }
        else {
            $itemColl->push($menuItem);           
        }
        $menuItem->DISOWN();
    }
    $self->get_widget('action_menu')->addItems($itemColl);
    $self->get_widget('action_menu')->rebuildMenuTree();
    if ($item) {
        $self->get_widget('edit')->setEnabled();
        $self->get_widget('del')->setEnabled();
    }
    else {
        $self->get_widget('edit')->setDisabled();
        $self->get_widget('del')->setDisabled();
    }

    $self->dialog->doneMultipleChanges();
}


sub _manageUsersDialog {
    my $self = shift;

    if ($EUID != 0) {
        $self->sh_gui->warningMsgBox({
            title => $self->name, 
            text  => $self->loc->N("root privileges required"),
        });
        return;
    }

    ## TODO fix for adminpanel
    my $pixdir = '/usr/share/userdrake/pixmaps/';
    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);


    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;
    

    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_headbar = $factory->createHBox($layout);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headbar = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);

    my %fileMenu = (
            widget  => $factory->createMenuButton($headbar,$self->loc->N("File")),
            refresh => new yui::YMenuItem($self->loc->N("Refresh")), 
            quit    => new yui::YMenuItem($self->loc->N("&Quit")),
    );

    $fileMenu{ widget }->addItem($fileMenu{ refresh });
    $fileMenu{ widget }->addItem($fileMenu{ quit });
    $fileMenu{ widget }->rebuildMenuTree();
   
    my $actionMenu = $factory->createMenuButton($headbar, $self->loc->N("Actions"));
    $actionMenu->DISOWN();
    
    my %helpMenu = (
            widget     => $factory->createMenuButton($headRight, $self->loc->N("&Help")),
            help       => new yui::YMenuItem($self->loc->N("Help")), 
            report_bug => new yui::YMenuItem($self->loc->N("Report Bug")),
            about      => new yui::YMenuItem($self->loc->N("&About")),
    );

    while ( my ($key, $value) = each(%helpMenu) ) {
        if ($key ne 'widget' ) {
            $helpMenu{ widget }->addItem($value);
        }
    }
    $helpMenu{ widget }->rebuildMenuTree();

    my $hbox    = $factory->createHBox($layout);
    $hbox       = $factory->createHBox($factory->createLeft($hbox));
    $self->set_widget(
        add_user    => $factory->createIconButton($hbox, $pixdir . 'user_add.png', $self->loc->N("Add User")),
        add_group   => $factory->createIconButton($hbox, $pixdir . 'group_add.png', $self->loc->N("Add Group")),
        edit        => $factory->createIconButton($hbox, $pixdir . 'user_conf.png', $self->loc->N("Edit")),
        del         => $factory->createIconButton($hbox, $pixdir . 'user_del.png', $self->loc->N("Delete")),
        refresh     => $factory->createIconButton($hbox, $pixdir . 'refresh.png', $self->loc->N("Refresh")),
        action_menu => $actionMenu,
    );
    

    $hbox                   = $factory->createHBox($layout);
    $head_align_left        = $factory->createLeft($hbox);
    
    my $sysfilter = 1;
    if (-e $self->config_file) {
        my $prefs  = Config::Auto::parse($self->config_file);
        $sysfilter = ($prefs->{FILTER} eq 'true' or $prefs->{FILTER} eq 'true' or $prefs->{FILTER} eq '1');
    }
    $self->set_widget(filter_system => $factory->createCheckBox($head_align_left, $self->loc->N("Filter system users"), 
                                                                $sysfilter));
                              $factory->createHSpacing($hbox, 3);
    $head_align_right       = $factory->createRight($hbox);
    $headRight              = $factory->createHBox($head_align_right);
                              $factory->createLabel($headRight, $self->loc->N("Search:"));
    $self->set_widget(filter         => $factory->createInputField($headRight, "", 0));
    $self->set_widget(apply_filter  => $factory->createPushButton($headRight, $self->loc->N("Apply filter")));
    $self->get_widget('filter')->setWeight($yui::YD_HORIZ, 2);
    $self->get_widget('apply_filter')->setWeight($yui::YD_HORIZ, 1);
    $self->get_widget('filter_system')->setNotify(1);

    my %tabs;
    if ($optional->hasDumbTab()) {
        $hbox = $factory->createHBox($layout);
        my $align = $factory->createHCenter($hbox);
        $self->set_widget(tabs => $optional->createDumbTab($align));
        $tabs{users} = new yui::YItem($self->loc->N("Users"));
        $tabs{users}->setSelected();
        $self->get_widget('tabs')->addItem( $tabs{users} );
        $tabs{users}->DISOWN();
        $tabs{groups} = new yui::YItem($self->loc->N("Groups"));
        $self->get_widget('tabs')->addItem( $tabs{groups} );
        $tabs{groups}->DISOWN();
        my $vbox        = $factory->createVBox($self->get_widget('tabs'));
        $align          = $factory->createLeft($vbox);
        $self->set_widget(replace_pnt =>  $factory->createReplacePoint($align));
        $self->_createUserTable();
        $self->get_widget('table')->setImmediateMode(1);
        $self->get_widget('table')->DISOWN();
    }
    
    $self->_refreshActions();
    
    # main loop
    while(1) {
        my $event     = $self->dialog->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::MenuEvent) {
### MENU ###
            my $item = $event->item();
            my $menuLabel = $item->label();
            if ($menuLabel eq $fileMenu{ quit }->label())  {
                last;
            }
            elsif ($menuLabel eq $helpMenu{about}->label())  {
                my $translators = $self->loc->N("_: Translator(s) name(s) & email(s)\n");
                $translators =~ s/\</\&lt\;/g;
                $translators =~ s/\>/\&gt\;/g;
                $self->sh_gui->AboutDialog({ name => $self->loc->N("AdminUser"),
                                             version => $self->VERSION,
                            credits => $self->loc->N("Copyright (C) %s Mageia community", '2013-2014'),
                            license => $self->loc->N("GPLv2"),
                            description => $self->loc->N("AdminUser is a Mageia user management tool \n(from the original idea of Mandriva userdrake)."),
                             authors => $self->loc->N("<h3>Developers</h3>
                                                       <ul><li>%s</li>
                                                           <li>%s</li>
                                                       </ul>
                                                       <h3>Translators</h3>
                                                       <ul><li>%s</li></ul>",
                                                      "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                                      "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;",
                                                      $translators
                                                     ),
                            }
                );
            }
            elsif ($menuLabel eq $self->get_action_menu('add_user')->label())  {
                $self->addUserDialog();
                $self->_refresh();
            }
            elsif ($menuLabel eq $self->get_action_menu('add_group')->label()) {
                $self->_addGroupDialog();
                $self->_refresh();
            }
            elsif ($menuLabel eq $self->get_action_menu('del')->label())  {
                $self->_deleteUserOrGroup();
            }
            elsif ($menuLabel eq $self->get_action_menu('edit')->label())  {
                $self->_editUserOrGroup();
            }
            elsif ($self->get_widget('tabs') && $menuLabel eq  $tabs{groups}->label()) {
                $self->_createGroupTable();
            }
            elsif ($self->get_widget('tabs') && $menuLabel eq  $tabs{users}->label()) {
                $self->_createUserTable();
            }
            elsif ($menuLabel eq  $fileMenu{refresh}->label()) {
                $self->_refresh();
            }
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
### Buttons and widgets ###
            my $widget = $event->widget();
            if ($widget == $self->get_widget('add_user')) {
                $self->addUserDialog();
                $self->_refresh();
            }
            elsif ($widget == $self->get_widget('del')) {
                $self->_deleteUserOrGroup();
            }
            elsif ($widget == $self->get_widget('table')) {
                $self->_refreshActions();
                my $wEvent = yui::YMGAWidgetFactory::getYWidgetEvent($event);
                if ($wEvent && $wEvent->reason() == $yui::YEvent::Activated) {
                    $self->_editUserOrGroup();
                }
            }
            elsif ($widget == $self->get_widget('add_group')) {
                $self->_addGroupDialog();
                $self->_refresh();
            }
            elsif ($widget == $self->get_widget('edit')) {
                $self->_editUserOrGroup();                
            }
            elsif ( $widget == $self->get_widget('filter_system') || 
                    $widget == $self->get_widget('refresh') || 
                    $widget == $self->get_widget('apply_filter') ) {
                $self->_refresh();
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;
}

#=============================================================

=head2 _skipShortcut

=head3 INPUT

    $self:  this object
    $label: an item label to be cleaned by keyboard shortcut "&"

=head3 OUTPUT

    $label: cleaned label 

=head3 DESCRIPTION

    This internal method is a workaround to label that are
    changed by "&" due to keyborad shortcut.

=cut

#=============================================================
sub _skipShortcut {
    my ($self, $label) = @_;

    $label =~ s/&// if ($label);

    return ($label);
}


sub _ValidInt {
    foreach my $i (@_) { $i =~ /\d+/ or return 0 }
    return 1;
}

sub _ConvTime {
    my ($day, $month, $year) = @_;
    my ($tm, $days, $mon, $yr);
    $mon = $month - 1; $yr = $year - 1900;
    $tm = POSIX::mktime(0, 0, 0, $day, $mon, $yr);
    $days = ceil($tm / (24 * 60 * 60));
    return $days;
}

sub _TimeOfArray {
    my ($reltime, $cm) = @_;
    my $h; my %mth = (Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6, Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12);
    my $_t = localtime($reltime * 24 * 60 * 60) =~ /(\S+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\d+)/;
    $h->{daystr} = $1;
    $h->{month} = $2;
    $h->{dayint} = $3;
    $h->{year} = $5;
    $cm and $h->{month} = $mth{$2}; 
    $h;
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
