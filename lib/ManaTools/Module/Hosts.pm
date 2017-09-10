# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2013-2017 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package ManaTools::Module::Hosts;

use Modern::Perl '2011';
use autodie;
use Moose;
use POSIX qw(ceil);
use utf8;
use File::ShareDir ':ALL';

use Glib;
use yui;
use ManaTools::Shared qw(trim);
use ManaTools::Shared::GUI;
use ManaTools::Shared::Hosts;

extends qw( ManaTools::Module );


has '+name' => (
    default => 'manahost',
    required => 0,
    init_arg => undef,
);

sub _titleInitializer {
    my $self = shift;

    return ($self->loc->N("%s - manage hosts definitions", $self->name()));
}

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

has 'table' => (
    is => 'rw',
    init_arg => undef
);

has 'cfgHosts' => (
    is => 'rw',
    init_arg => undef
);

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start  host manager

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_manageHostsDialog();
};

#=============================================================

=head2 _changeHostNameDialog

=head3 INPUT

    $self: this object

    $headerString: a title for the dialog

=head3 DESCRIPTION

    This method display a dialog allowing the user
    to change the hostname

=cut

#=============================================================
sub _changeHostNameDialog {
    my $self = shift;

    my $headerString = shift();

    my $factory  = yui::YUI::widgetFactory;
    my $dlg = $factory->createPopupDialog();
    my $layout = $factory->createVBox($dlg);

    my $hbox_header = $factory->createHBox($layout);
    my $vbox_content = $factory->createVBox($layout);
    my $hbox_footer = $factory->createHBox($layout);

    # header
    my $labelDescription = $factory->createLabel($hbox_header,$headerString);

    # content
    my $firstHbox = $factory->createHBox($vbox_content);
    my $secondHbox = $factory->createHBox($vbox_content);
    my $thirdHbox = $factory->createHBox($vbox_content);
    my $fourthHbox = $factory->createHBox($vbox_content);
    my $fifthHbox = $factory->createHBox($vbox_content);
    my $sixthHbox = $factory->createHBox($vbox_content);

    my $labelHostName  = $factory->createLabel($secondHbox,$self->loc->N("Hostname"));
    $labelHostName->setWeight($yui::YD_HORIZ, 10);
    my $textHostName = $factory->createInputField($secondHbox,"");
    $textHostName->setWeight($yui::YD_HORIZ, 30);

    my $labelPrettyHostName  = $factory->createLabel($thirdHbox,$self->loc->N("Pretty Hostname"));
    $labelPrettyHostName->setWeight($yui::YD_HORIZ, 10);
    my $textPrettyHostName = $factory->createInputField($thirdHbox,"");
    $textPrettyHostName->setWeight($yui::YD_HORIZ, 30);

    my $labelStaticHostName  = $factory->createLabel($fourthHbox,$self->loc->N("Static Hostname"));
    $labelStaticHostName->setWeight($yui::YD_HORIZ, 10);
    my $textStaticHostName = $factory->createInputField($fourthHbox,"");
    $textStaticHostName->setWeight($yui::YD_HORIZ, 30);

    my $labelChassis  = $factory->createLabel($fifthHbox,$self->loc->N("Chassis"));
    $labelChassis->setWeight($yui::YD_HORIZ, 10);
    my $textChassis = $factory->createInputField($fifthHbox,"");
    $textChassis->setWeight($yui::YD_HORIZ, 30);

    my $labelIconName  = $factory->createLabel($sixthHbox,$self->loc->N("Icon Name"));
    $labelIconName->setWeight($yui::YD_HORIZ, 10);
    my $textIconName = $factory->createInputField($sixthHbox,"");
    $textIconName->setWeight($yui::YD_HORIZ, 30);

    $textHostName->setValue($self->cfgHosts->_getLocalHostName());
    $textPrettyHostName->setValue($self->cfgHosts->_getLocalPrettyHostName());
    $textStaticHostName->setValue($self->cfgHosts->_getLocalStaticHostName());
    $textChassis->setValue($self->cfgHosts->_getLocalChassis());
    $textIconName->setValue($self->cfgHosts->_getLocalIconName());

    # footer
    my $cancelButton = $factory->createPushButton($factory->createLeft($hbox_footer),$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($factory->createRight($hbox_footer),$self->loc->N("&OK"));

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
            elsif($widget == $okButton) {
		$self->cfgHosts->_setLocalHostName($textHostName->value());
		$self->cfgHosts->_setLocalPrettyHostName($textPrettyHostName->value());
		$self->cfgHosts->_setLocalStaticHostName($textStaticHostName->value());
		$self->cfgHosts->_setLocalChassis($textChassis->value());
		$self->cfgHosts->_setLocalIconName($textIconName->value());
                last;
            }
        }
    }

    destroy $dlg;
}

sub _manipulateHostDialog {
    my $self = shift;

    my $headerString = shift();
    my $boolEdit = shift();

    my $hostIpString = "";
    my $hostNameString = "";
    my $hostAliasesString = "";

    if($boolEdit == 1){
        $hostIpString = shift();
        $hostNameString = shift();
        $hostAliasesString = shift();
    }

    my $factory  = yui::YUI::widgetFactory;
    my $dlg = $factory->createPopupDialog();
    my $layout = $factory->createVBox($dlg);

    my $hbox_header = $factory->createHBox($layout);
    my $vbox_content = $factory->createVBox($layout);
    my $hbox_footer = $factory->createHBox($layout);

    # header
    my $labelDescription = $factory->createLabel($hbox_header,$headerString);

    # content
    my $firstHbox = $factory->createHBox($vbox_content);
    my $secondHbox = $factory->createHBox($vbox_content);
    my $thirdHbox = $factory->createHBox($vbox_content);

    my $labelIPAddress = $factory->createLabel($firstHbox,$self->loc->N("IP Address"));
    my $labelHostName  = $factory->createLabel($secondHbox,$self->loc->N("Hostname"));
    my $labelHostAlias = $factory->createLabel($thirdHbox,$self->loc->N("Host aliases"));
    $labelIPAddress->setWeight($yui::YD_HORIZ, 10);
    $labelHostName->setWeight($yui::YD_HORIZ, 10);
    $labelHostAlias->setWeight($yui::YD_HORIZ, 10);

    my $textIPAddress = $factory->createInputField($firstHbox,"");
    my $textHostName = $factory->createInputField($secondHbox,"");
    my $textHostAlias = $factory->createInputField($thirdHbox,"");
    $textIPAddress->setWeight($yui::YD_HORIZ, 30);
    $textHostName->setWeight($yui::YD_HORIZ, 30);
    $textHostAlias->setWeight($yui::YD_HORIZ, 30);

    if($boolEdit == 1){
        $textIPAddress->setValue($hostIpString);
        $textHostName->setValue($hostNameString);
        $textHostAlias->setValue($hostAliasesString);
    }

    # footer
    my $cancelButton = $factory->createPushButton($factory->createLeft($hbox_footer),$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($factory->createRight($hbox_footer),$self->loc->N("&OK"));

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
            elsif($widget == $okButton) {
                my $res = undef;
                my @hosts_toadd;
                push @hosts_toadd, $textHostName->value();
                if(ManaTools::Shared::trim($textHostAlias->value()) ne ""){
                    push @hosts_toadd, $textHostAlias->value();
                }
                if($boolEdit == 0){
                    $res = $self->cfgHosts->_insertHost($textIPAddress->value(),[@hosts_toadd]);
                }else{
                    $res = $self->cfgHosts->_modifyHost($textIPAddress->value(),[@hosts_toadd]);
                }
                $res = $self->cfgHosts->_writeHosts();
                last;
            }
        }
    }

    destroy $dlg;
}

#=============================================================

=head2 _addHostDialog

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

This subroutine creates the Host dialog to add host definitions

=cut

#=============================================================

sub _addHostDialog {
    my $self = shift();
    return $self->_manipulateHostDialog($self->loc->N("Add the information"),0);
}

#=============================================================

=head2 _edtHostDialog

=head3 INPUT

=over 4

=item $self: this object

=item B<$hostIp> : the ip of the host entry that we want to modify

=item B<$hostName> : the name of the host entry we want to modify

=item B<$hostAliases> : aliases of the host entry we want to modify

=back

=head3 DESCRIPTION

This subroutine creates the Host dialog to modify host definitions

=cut

#=============================================================

sub _edtHostDialog {
    my $self = shift();
    my $hostIp = shift();
    my $hostName = shift();
    my $hostAliases = shift();
    return $self->_manipulateHostDialog($self->loc->N("Modify the information"),1,$hostIp,$hostName,$hostAliases);
}

#=============================================================

=head2 setupTable

=head3 INPUT

    $self: this object

    $data: reference to the array containaing the host data to show into the table

=head3 DESCRIPTION

This subroutine populates a previously created YTable with the hosts data
retrieved by the Config::Hosts module

=cut

#=============================================================
sub setupTable {
    my $self = shift();

    my @hosts = $self->cfgHosts->_getHosts();
    # clear table
    $self->table->deleteAllItems();
    foreach my $host (@hosts){
        my $tblItem;
        my $aliases = join(',',@{$host->{'hosts'}});
        if(scalar(@{$host->{'hosts'}}) > 1){
            $aliases =~s/^$host->{'hosts'}[0]\,*//g;
        }elsif(scalar(@{$host->{'hosts'}}) == 1){
            $aliases = "";
        }
        $tblItem = new yui::YTableItem($host->{'ip'},$host->{'hosts'}[0],$aliases);
        $self->table->addItem($tblItem);
    }
}

sub _manageHostsDialog {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = $self->loc->N("Manage hosts definitions");

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

## TODO remove title and icon when using Shared::Module::GUI::Dialog
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name());
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon());

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
    $tableHeader->addColumn($self->loc->N("IP Address"));
    $tableHeader->addColumn($self->loc->N("Hostname"));
    $tableHeader->addColumn($self->loc->N("Host Aliases"));
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,45);
    $self->table($factory->createTable($leftContent,$tableHeader));

    # initialize Config::Hosts
    $self->cfgHosts(ManaTools::Shared::Hosts->new());
    $self->setupTable();

    my $rightContent = $factory->createRight($hbox_content);
    $rightContent->setWeight($yui::YD_HORIZ,10);
    my $topContent = $factory->createTop($rightContent);
    my $vbox_commands = $factory->createVBox($topContent);
    my $addButton = $factory->createPushButton($factory->createHBox($vbox_commands),$self->loc->N("A&dd"));
    my $edtButton = $factory->createPushButton($factory->createHBox($vbox_commands),$self->loc->N("&Edit"));
    my $remButton = $factory->createPushButton($factory->createHBox($vbox_commands),$self->loc->N("&Remove"));
    my $hnButton = $factory->createPushButton($factory->createHBox($vbox_commands),$self->loc->N("&Hostname"));
    $addButton->setWeight($yui::YD_HORIZ,1);
    $edtButton->setWeight($yui::YD_HORIZ,1);
    $remButton->setWeight($yui::YD_HORIZ,1);
    $hnButton->setWeight($yui::YD_HORIZ,1);

    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("&About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&OK"));

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
                $self->_addHostDialog();
                $self->setupTable();
            }
            elsif ($widget == $edtButton) {
                my $tblItem = yui::toYTableItem($self->table->selectedItem());
                if($tblItem->cellCount() >= 3){
                    $self->_edtHostDialog($tblItem->cell(0)->label(),$tblItem->cell(1)->label(),$tblItem->cell(2)->label());
                }else{
                    $self->_edtHostDialog($tblItem->cell(0)->label(),$tblItem->cell(1)->label(),"");
                }
                $self->setupTable();
            }
            elsif ($widget == $remButton) {
                # implement deletion dialog
                if($self->sh_gui->ask_YesOrNo({title => $self->loc->N("Confirmation"), text => $self->loc->N("Are you sure to drop this host?")}) == 1){
                    my $tblItem = yui::toYTableItem($self->table->selectedItem());
                    # drop the host using the ip
                    $self->cfgHosts->_dropHost($tblItem->cell(0)->label());
                    # write changes
                    $self->cfgHosts->_writeHosts();
                    $self->setupTable();
                }
            }elsif ($widget == $hnButton) {
                $self->_changeHostNameDialog("Change the HostName FQDN");
                $self->setupTable();
            }elsif ($widget == $aboutButton) {
                $self->sh_gui->AboutDialog({
                    name => $appTitle,
                    version => $self->Version(),
                    credits => $self->loc->N("Copyright (C) %s by Matteo Pasotti", '2013-2017'),
                    license => "GPLv2",
                    description => $self->loc->N("Graphical manager for hosts definitions"),
                    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
                    }
                );
            }elsif ($widget == $okButton) {
                # write changes
                $self->cfgHosts->_writeHosts();
                last;
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

1;
