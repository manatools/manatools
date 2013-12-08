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
use common;
use run_program;
## USER is from userdrake
use USER;
use utf8;

use Glib;
use yui;
use AdminPanel::Shared;
use AdminPanel::Users::users;

use base qw(Exporter);

our @EXPORT = qw(addUserDialog         
         );


sub addUserDialog {
    my $secfile = '/etc/sysconfig/msec';
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
    my $UID = 0;
    if ($optional->hasSlider()) {
        $UID = $optional->createSlider($align, N("UID"), 500, 65000, 500);
    }
    else {
        # UID must checked in ncurses, value is entered by keyboard without 
        #     range restriction 
        $UID = $factory->createInputField($align, N("UID"), 0);
    }
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
                my %sec = getVarsFromSh($secfile);
                if ($sec{SECURE_LEVEL} && $sec{SECURE_LEVEL} > 3 && length($passwd) < 6) {
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
                        $errorString = N("User Uid is < 500");
                        $continue = 0;
# TODO uidchoice
#                         my $uidchoice = GimmeChoice(N("User Uid is < 500"),
#                                                     N("Creating a user with a UID less than 500 is not recommended.\n Are you sure you want to do this?\n\n")); 
#                         $uidchoice and $userEnt->Uid($u{uid});
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
# TODO ChooseGroup
#                             my $groupchoice = ChooseGroup();
#                             if ($groupchoice == 0 && !$error) {
#                                 #You choose to put it in the existing group
#                                 $u{gid} = $gr->Gid($GetValue);
#                             } elsif ($groupchoice == 1) {
#                                 # Put it in 'users' group
#                                 log::explanations(N("Putting %s to 'users' group",
#                                                     $u{username}));
#                                 $u{gid} = Add2UsersGroup($u{username});
#                             }
                            $errorString = "TODO " . N("Choose group");
                            $continue = 0;
                        } else { 
                            #it's a new group: Add it
                            my $newgroup = $ctx->InitGroup($username,$is_system);
#                             log::explanations(N("Creating new group: %s", $u{username}));
                            $gid = $newgroup->Gid($GetValue);
                            $ctx->GroupAdd($newgroup);
                        }
                    }
                } else {
                    $continue and $gid = Add2UsersGroup($username);
                }



                if (!$continue) {
                    #---rasie error
                    AdminPanel::Shared::msgBox($errorString);
                }
                else {
                    ## OK let's create the user
                    print N("Adding user: ") . $username . " \n";
#                     log::explanations(N("Adding user: %s", $u{username}));
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

