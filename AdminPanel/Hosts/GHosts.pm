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
#use AdminPanel::Shared;
use AdminPanel::Hosts::hosts;

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

has 'table' => (
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
    my $vbox_content = $factory->createVBox($layout);
    my $hbox_footer = $factory->createHBox($layout);

    # header
    my $labelDescription = $factory->createLabel($hbox_header,"Add the information");

    # content
    my $firstHbox = $factory->createHBox($vbox_content);
    my $secondHbox = $factory->createHBox($vbox_content);
    my $thirdHbox = $factory->createHBox($vbox_content);

    my $labelIPAddress = $factory->createLabel($firstHbox,"IP Address");
    my $labelHostName  = $factory->createLabel($secondHbox,"Hostname");
    my $labelHostAlias = $factory->createLabel($thirdHbox,"Host aliases");
    $labelIPAddress->setWeight($yui::YD_HORIZ, 10);
    $labelHostName->setWeight($yui::YD_HORIZ, 10);
    $labelHostAlias->setWeight($yui::YD_HORIZ, 10);

    my $textIPAddress = $factory->createInputField($firstHbox,"");
    my $textHostName = $factory->createInputField($secondHbox,"");
    my $textHostAlias = $factory->createInputField($thirdHbox,"");
    $textIPAddress->setWeight($yui::YD_HORIZ, 30);
    $textHostName->setWeight($yui::YD_HORIZ, 30);
    $textHostAlias->setWeight($yui::YD_HORIZ, 30);

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

sub setupTable {
    my $self = shift();
    my $data = shift();
    
    foreach my $host (@$data){
        my $tblItem;
        my $aliases = join(',',@{$host->{'hosts'}});
        if(scalar(@{$host->{'hosts'}}) > 1){
            $aliases =~s/\,*$host->{'hosts'}[0]\,*//g;
        }elsif(scalar(@{$host->{'hosts'}}) == 1){
            $aliases = "";
        }
        $tblItem = new yui::YTableItem($host->{'ip'},$host->{'hosts'}[0],$aliases);
        $self->table->addItem($tblItem);
    }

}

sub manageHostsDialog {
    my $self = shift;

    ## TODO fix for adminpanel
    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = "Manage hosts definitions";
    yui::YUI::app()->setApplicationTitle($newTitle);

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;
    

    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_header = $factory->createHBox($layout);
    my $headLeft = $factory->createHBox($factory->createLeft($hbox_header));
    my $headRight = $factory->createHBox($factory->createRight($hbox_header));

    my $logoImage = $factory->createImage($headLeft, $appIcon);
    my $labelAppDescription = $factory->createLabel($headRight,$newTitle); 
    $logoImage->setWeight($yui::YD_HORIZ,0);
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    my $hbox_content = $factory->createHBox($layout);

    my $tableHeader = new yui::YTableHeader();
    $tableHeader->addColumn("IP Address");
    $tableHeader->addColumn("Hostname");
    $tableHeader->addColumn("Host Aliases");
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,45);
    $self->table($factory->createTable($leftContent,$tableHeader));

    my @hosts = AdminPanel::Hosts::hosts::_getHosts();
    $self->setupTable(\@hosts);
    
    my $rightContent = $factory->createRight($hbox_content);
    $rightContent->setWeight($yui::YD_HORIZ,10);
    my $topContent = $factory->createTop($rightContent);
    my $vbox_commands = $factory->createVBox($topContent);
    my $addButton = $factory->createPushButton($factory->createHBox($vbox_commands),"Add");
    my $edtButton = $factory->createPushButton($factory->createHBox($vbox_commands),"Edit");
    my $remButton = $factory->createPushButton($factory->createHBox($vbox_commands),"Remove");
    $addButton->setWeight($yui::YD_HORIZ,1);
    $edtButton->setWeight($yui::YD_HORIZ,1);
    $remButton->setWeight($yui::YD_HORIZ,1);

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
