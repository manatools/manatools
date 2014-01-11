# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
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

package AdminPanel::Hosts::GHosts;

###############################################
##
## graphic related routines for managing user
##
###############################################


use Modern::Perl 2011;
use autodie;
# TODO evaluate if Moose is too heavy and use Moo 
# instead
use Moose;
use POSIX qw(ceil);
use utf8;

use Glib;
use yui;
use AdminPanel::Shared;
use AdminPanel::Hosts::hosts;


=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

sub start {
    my $self = shift;

    $self->manageHostsDialog();
};


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
sub _addHostDialog {
    my $self = shift;

    my $factory  = yui::YUI::widgetFactory;
    my $dlg = $factory->createPopupDialog();
    my $layout = $factory->createVBox($dlg);

    my $hbox_header = $factory->createHBox($layout);
    my $hbox_content = $factory->createHBox($layout);
    my $leftContent = $factory->createVBox($hbox_content);
    my $rightContent = $factory->createVBox($hbox_content);
    my $hbox_footer = $factory->createHBox($layout);

    $leftContent->setWeight($yui::YD_HORIZ, 1);
    $rightContent->setWeight($yui::YD_HORIZ, 2);

    # header
    my $labelDescription = $factory->createLabel($hbox_header,"Add the informations");

    # content
    my $labelIPAddress = $factory->createLabel($leftContent,"IP Address");
    my $labelHostName = $factory->createLabel($leftContent,"Hostname");
    my $labelHostAlias = $factory->createLabel($leftContent,"Host aliases");
    $labelIPAddress->setWeight($yui::YD_HORIZ, 1);
    $labelHostName->setWeight($yui::YD_HORIZ, 1);
    $labelHostAlias->setWeight($yui::YD_HORIZ, 1);

    my $textIPAddress = $factory->createInputField($rightContent,"");
    my $textHostName = $factory->createInputField($rightContent,"");
    my $textHostAlias = $factory->createInputField($rightContent,"");
    $textIPAddress->setWeight($yui::YD_HORIZ, 2);
    $textHostName->setWeight($yui::YD_HORIZ, 2);
    $textHostAlias->setWeight($yui::YD_HORIZ, 2);

    # footer
    my $cancelButton = $factory->createPushButton($factory->createLeft($hbox_footer),"Cancel");
    my $okButton = $factory->createPushButton($factory->createRight($hbox_footer),"OK");

    while(1){
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
        }
    }

    destroy $dlg;
}

sub manageHostsDialog {
    my $self = shift;

    ## TODO fix for adminpanel
    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = "Manage hosts descriptions";
    yui::YUI::app()->setApplicationTitle($newTitle);

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;
    

    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_headbar = $factory->createHBox($layout);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headLeft = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);

    my $logoImage = $factory->createImage($headLeft, $appIcon);
    my $labelAppDescription = $factory->createLabel($headRight,$newTitle); 

    my $hbox_content = $factory->createHBox($layout);

    my $tableHeader = new yui::YTableHeader();
    $tableHeader->addColumn("IP Address");
    $tableHeader->addColumn("Hostname");
    $tableHeader->addColumn("Host Aliases");
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight(0,45);
    my $tableHosts = $factory->createTable($leftContent,$tableHeader);
    
    my $rightContent = $factory->createRight($hbox_content);
    $rightContent->setWeight(0,10);
    my $topContent = $factory->createTop($rightContent);
    my $vbox_content = $factory->createVBox($topContent);
    my $addButton = $factory->createPushButton($vbox_content,"Add");
    my $edtButton = $factory->createPushButton($vbox_content,"Edit");
    my $remButton = $factory->createPushButton($vbox_content,"Remove");

    my $hbox_foot = $factory->createHBox($layout);
    my $cancelButton = $factory->createPushButton($factory->createLeft($hbox_foot),"Cancel");
    my $okButton = $factory->createPushButton($factory->createRight($hbox_foot),"OK");

    # main loop
    while(1) {
        my $event     = $self->dialog->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
### Buttons and widgets ###
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $addButton) {
                # implement add host dialog
                $self->_addHostDialog();
            }
            elsif ($widget == $edtButton) {
                # implement modification dialog
            }
            elsif ($widget == $remButton) {
                # implement deletion dialog
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
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

1;
