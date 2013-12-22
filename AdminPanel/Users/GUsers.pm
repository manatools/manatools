# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013 Angelo Naselli <anaselli@linux.it>
#  from adduserdrake and userdrake
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

package AdminPanel::Users::GUsers;

###############################################
##
## graphic related routines for managing user
##
###############################################


use strict;
use common qw(N);
use security::level;
use run_program;
## USER is from userdrake
use USER;
use utf8;
use log;

use Glib;
use yui;
use AdminPanel::Shared;
use AdminPanel::Users::users;

use base qw(Exporter);

our @EXPORT = qw(addUserDialog    
                 manageUsersDialog     
              );

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';


sub labeledFrameBox {
    my ($parent, $label) = @_;

    my $factory  = yui::YUI::widgetFactory;

    my $frame    = $factory->createFrame($parent, $label);
    $frame->setWeight( $yui::YD_HORIZ, 1);

    $frame       = $factory->createHVCenter( $frame );
    $frame       = $factory->createVBox( $frame );
  return $frame;
}

######################################
##
## ChooseGroup
##
## creates a popup dialog to ask if
##  adding user to existing group or
##  to 'users' group.
##
## returns 0 or 1 (choice done)
##         -1 cancel, or exit
## 
sub ChooseGroup() {
    my $choice = -1;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Choose group"));
    
    my $factory  = yui::YUI::widgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);


    my $frame    = labeledFrameBox($layout,  N("A group with this name already exists.  What would you like to do?"));

    my $rbg      = $factory->createRadioButtonGroup( $frame );
    $frame       = $factory->createVBox( $rbg );
    my $align    = $factory->createLeft($frame);

    my $rb1      = $factory->createRadioButton( $align, N("Add to the existing group"), 1);
    $rb1->setNotify(1);
    $rbg->addRadioButton( $rb1 );
    $align        = $factory->createLeft($frame);
    my $rb2 = $factory->createRadioButton( $align, N("Add to the 'users' group"), 0);
    $rb2->setNotify(1);
    $rbg->addRadioButton( $rb2 );

    my $hbox            = $factory->createHBox($layout);
    $align           = $factory->createRight($hbox);
    my $cancelButton = $factory->createPushButton($align, N("Cancel"));
    my $okButton     = $factory->createPushButton($hbox,  N("Ok"));
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

sub addUserDialog {
    my $GetValue = -65533; ## Used by USER (for getting values? TODO need explanations, where?)
    my $dontcreatehomedir = 0; my $is_system = 0;
    my $ctx = USER::ADMIN->new;
    my @shells = @{$ctx->GetUserShells};

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Create New User"));
    
    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $dlg      = $factory->createPopupDialog();
    my $layout   = $factory->createVBox($dlg);

    ## user 'full name'
    my $hbox         = $factory->createHBox($layout);
    my $align        = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Full Name:") );
    $align           = $factory->createRight($hbox);
    my $fullName     = $factory->createInputField($align, "", 0);

    ## user 'login name'
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Login:") );
    $align           = $factory->createRight($hbox);
    my $loginName    = $factory->createInputField($align, "", 0);
    $loginName->setNotify(1);

    ## user 'Password'
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Password:") );
    $align           = $factory->createRight($hbox);
    my $password     = $factory->createInputField($align, "", 1);

    ## user 'confirm Password'
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Confirm Password:") );
    $align           = $factory->createRight($hbox);
    my $password1    = $factory->createInputField($align, "", 1);

    ## user 'Login Shell'
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Login Shell:") );
    $align           = $factory->createRight($hbox);
    my $loginShell   = $factory->createComboBox($align, "", 0);
    my $itemColl = new yui::YItemCollection;
    foreach my $shell (@shells) {
            my $item = new yui::YItem ($shell, 0);
            $itemColl->push($item);
            $item->DISOWN();
    }
    $loginShell->addItems($itemColl);

    ##### add a separator
    ## Create Home directory
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    my $createHome = $factory->createCheckBox($align, N("Create Home Directory"), 1);
    ## Home directory
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    $factory->createLabel($align, N("Home Directory:") );
    $align           = $factory->createRight($hbox);
    my $homeDir      = $factory->createInputField($align, "", 0);
    
    # Create private group
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    my $createGroup = $factory->createCheckBox($align, N("Create a private group for the user"), 1);
    
    # Specify user id manually
    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createLeft($hbox);
    my $uidManually  = $factory->createCheckBox($align, N("Specify user ID manually"), 0);
    $align           = $factory->createRight($hbox);
   
    my $UID = $factory->createIntField($align, N("UID"), 1, 65000, 500);
    $UID->setEnabled($uidManually->value());
    $uidManually->setNotify(1);

    ## user 'icon'
    $hbox        = $factory->createHBox($layout);
    $factory->createLabel($hbox, N("Click on icon to change it") );
    my $iconFace = AdminPanel::Users::users::GetFaceIcon();
    my $icon = $factory->createPushButton($hbox, "");
    $icon->setIcon(AdminPanel::Users::users::face2png($iconFace)); 
    $icon->setLabel($iconFace);

    $hbox            = $factory->createHBox($layout);
    $align           = $factory->createRight($hbox);
    my $cancelButton = $factory->createPushButton($align, N("Cancel"));
    my $okButton     = $factory->createPushButton($hbox,  N("Ok"));
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
                my $iconLabel = $icon->label();
                $iconLabel =~ s/&//; #remove shortcut from label

                my $nextIcon = GetFaceIcon($icon->label(), 1);
                $icon->setLabel($nextIcon);
                $icon->setIcon(AdminPanel::Users::users::face2png($nextIcon));
            }
            elsif ($widget == $uidManually) {
                # UID inserction enabled?
                $UID->setEnabled($uidManually->value());
            }
            elsif ($widget == $loginName) {
                my $username = $loginName->value();
                $homeDir->setValue("/home/$username");
            }
            elsif ($widget == $okButton) {
                ## check data
                my $username = $loginName->value();
                my ($continue, $errorString) = valid_username($username);
                my $nm = $continue && $ctx->LookupUserByName($username);
                if ($nm) {
                    $loginName->setValue("");
                    $homeDir->setValue("");
                    $errorString = N("User already exists, please choose another User Name");
                    $continue = 0;
                }
                my $passwd = $continue && $password->value();
                if ($continue && $passwd ne $password1->value()) {
                    $errorString = N("Password Mismatch");
                    $continue = 0;
                }
                my $sec = security::level::get();
                if ($sec > 3 && length($passwd) < 6) {
                    $errorString = N("This password is too simple. \n Good passwords should be > 6 characters");
                    $continue = 0;
                }
                my $userEnt = $continue && $ctx->InitUser($username, $is_system);
                if ($continue && $createHome->value()) {
                    $dontcreatehomedir = 0;
                    my $homedir = $homeDir->value();
                    $userEnt and $userEnt->HomeDir($homedir);
                } else {
                    $dontcreatehomedir = 1;
                }
                my $uid = 0;
                if ($continue && $uidManually->value()) {
                    if (($uid = $UID->value()) < 500) {
                        $errorString = "";
                        my $uidchoice = AdminPanel::Shared::ask_YesOrNo(N("User Uid is < 500"),
                                        N("Creating a user with a UID less than 500 is not recommended.\nAre you sure you want to do this?\n\n")); 
                        $continue = $uidchoice and $userEnt->Uid($uid);
                    } else { 
                        $userEnt and $userEnt->Uid($uid);
                    }
                }
                my $gid = 0;
                if ($createGroup->value()) {
                    if ($continue) {
                        #Check if group exist
                        my $gr = $ctx->LookupGroupByName($username);
                        if ($gr) { 
                            my $groupchoice = ChooseGroup();
                            if ($groupchoice == 0 ) {
                                #You choose to put it in the existing group
                                $gid = $gr->Gid($GetValue);
                            } elsif ($groupchoice == 1) {
                                # Put it in 'users' group
                                log::explanations(N("Putting %s to 'users' group",
                                                    $username));
                                $gid = AdminPanel::Users::users::Add2UsersGroup($username, $ctx);
                            }
                            else {
                                $errorString = "";
                                $continue = 0;
                            }
                        } else { 
                            #it's a new group: Add it
                            my $newgroup = $ctx->InitGroup($username,$is_system);
                            log::explanations(N("Creating new group: %s", $username));
                            $gid = $newgroup->Gid($GetValue);
                            $ctx->GroupAdd($newgroup);
                        }
                    }
                } else {
                    $continue and $gid = AdminPanel::Users::users::Add2UsersGroup($username, $ctx);
                }



                if (!$continue) {
                    #---rasie error
                    AdminPanel::Shared::msgBox($errorString) if ($errorString);
                }
                else {
                    ## OK let's create the user
                    print N("Adding user: ") . $username . " \n";
                    log::explanations(N("Adding user: %s"), $username);
                    my $loginshell = $loginShell->value();
                    my $fullname   = $fullName->value();
                    $userEnt->Gecos($fullname);  $userEnt->LoginShell($loginshell);
                    $userEnt->Gid($gid);
                    $userEnt->ShadowMin(-1); $userEnt->ShadowMax(99999);
                    $userEnt->ShadowWarn(-1); $userEnt->ShadowInact(-1);
                    $ctx->UserAdd($userEnt, $is_system, $dontcreatehomedir);
                    $ctx->UserSetPass($userEnt, $passwd);
###  TODO Migration wizard
#                     defined $us->{o}{iconval} and
#                         AdminPanel::Users::users::addKdmIcon($u{username}, $us->{o}{iconval});
#                     Refresh($sysfilter, $stringsearch);
#                     transfugdrake::get_windows_disk()
#                         and $in->ask_yesorno(N("Migration wizard"),
#                                             N("Do you want to run the migration wizard in order to import Windows documents and settings in your Mageia distribution?"))
#                             and run_program::raw({ detach => 1 }, 'transfugdrake');


                    last;
                }
            }
        }
    }

    destroy $dlg;
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

sub manageUsersDialog {

    ## TODO fix for adminpanel
    my $pixdir = '/usr/share/userdrake/pixmaps/';
    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Mageia Users Management Tool"));

    my $factory  = yui::YUI::widgetFactory;

    my $dlg      = $factory->createMainDialog();
    my $layout   = $factory->createVBox($dlg);

    my $hbox_headbar = $factory->createHBox($layout);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headbar = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);

    my %fileMenu = (
            widget  => $factory->createMenuButton($headbar,N("File")),
            refresh => new yui::YMenuItem(N("Refresh")), 
            quit    => new yui::YMenuItem(N("Quit")),
    );

    $fileMenu{ widget }->addItem($fileMenu{ refresh });
    $fileMenu{ widget }->addItem($fileMenu{ quit });
    $fileMenu{ widget }->rebuildMenuTree();
   
    my %actionMenu = (
            widget    => $factory->createMenuButton($headbar, N("Actions")),
            add_user  => new yui::YMenuItem(N("Add User")), 
            add_group => new yui::YMenuItem(N("Add Group")),
            edit      => new yui::YMenuItem(N("Edit")),
            del       => new yui::YMenuItem(N("Delete")),
            inst      => new yui::YMenuItem(N("Install guest account")),
    );

    while ( my ($key, $value) = each(%actionMenu) ) {
        if ($key ne 'widget' ) {
            $actionMenu{ widget }->addItem($value);
        }
    }
    $actionMenu{ widget }->rebuildMenuTree();

    my %optionMenu = (
            widget     => $factory->createMenuButton($headbar, N("Option")),
            option     => new yui::YMenuItem(N("Option")), 
    );

    while ( my ($key, $value) = each(%optionMenu) ) {
        if ($key ne 'widget' ) {
            $optionMenu{ widget }->addItem($value);
        }
    }
    $optionMenu{ widget }->rebuildMenuTree();

    my %helpMenu = (
            widget     => $factory->createMenuButton($headRight, N("Help")),
            help       => new yui::YMenuItem(N("Help")), 
            report_bug => new yui::YMenuItem(N("Report Bug")),
            about      => new yui::YMenuItem(N("About")),
    );

    while ( my ($key, $value) = each(%helpMenu) ) {
        if ($key ne 'widget' ) {
            $helpMenu{ widget }->addItem($value);
        }
    }
    $helpMenu{ widget }->rebuildMenuTree();

    my $hbox    = $factory->createHBox($layout);
    $hbox       = $factory->createHBox($factory->createLeft($hbox));
    my %buttons = (
           add_user  => $factory->createIconButton($hbox, $pixdir . 'user_add.png', N("Add User")),
           add_group => $factory->createIconButton($hbox, $pixdir . 'group_add.png', N("Add Group")),
           edit      => $factory->createIconButton($hbox, $pixdir . 'user_conf.png', N("Edit")),
           del       => $factory->createIconButton($hbox, $pixdir . 'user_del.png', N("Delete")),
           refresh   => $factory->createIconButton($hbox, $pixdir . 'refresh.png', N("Refresh")),
    );

    # main loop
    while(1) {
        my $event     = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::MenuEvent) {
            my $item = $event->item();
            if ($item->label() eq $fileMenu{ quit }->label())  {
                last;
            }
        }
    }

    destroy $dlg;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}
