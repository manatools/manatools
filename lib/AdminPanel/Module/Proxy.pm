# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013-2014 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package AdminPanel::Module::Proxy;

use Modern::Perl '2011';
use autodie;
use Moose;
use POSIX qw(ceil);
use utf8;

use yui;
use AdminPanel::Shared qw(trim);
use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Proxy;

extends qw( AdminPanel::Module );


has '+icon' => (
    default => "/usr/share/mcc/themes/default/drakproxy-mdk.png"
);

has '+name' => (
    default => "Proxymanager",
);

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

has 'networkObj' => (
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

    $self->sh_gui(AdminPanel::Shared::GUI->new() );
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start proxy manager

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_manageProxyDialog();
};


sub _manageProxyDialog {
    my $self = shift;

    my $httpsProxyEqualToHttpProxy = 0;
    ## TODO fix for adminpanel
    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = "Proxies configuration";
    yui::YUI::app()->setApplicationTitle($newTitle);

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;
    
    my $label_width = 25;
    my $inputfield_width = 45;
    #
    # @layout
    #
    # +--------------------------------+
    # |            HEADER              |
    # |--------------------------------+
    # |            CONTENT             |
    # |--------------------------------+
    # |          OTHER OPTIONS         |
    # |                                |
    # +--------------------------------+

    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_header = $factory->createHBox($layout);
    my $headLeft = $factory->createHBox($factory->createLeft($hbox_header));
    my $headRight = $factory->createHBox($factory->createRight($hbox_header));

    my $logoImage = $factory->createImage($headLeft, $appIcon);
    my $labelAppDescription = $factory->createLabel($headRight,$newTitle); 
    $logoImage->setWeight($yui::YD_HORIZ,0);
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    # app description
    my $hbox_content = $factory->createHBox($layout);
    $factory->createLabel($hbox_content, "Here you can set up your proxies configuration (eg: http://my_caching_server:8080)");

    $hbox_content = $factory->createHBox($layout);

    my $vbox_labels_flags = $factory->createVBox($hbox_content);
    my $vbox_inputfields = $factory->createVBox($hbox_content);

    # http proxy section
    my $httpproxy_label = $factory->createLabel($vbox_labels_flags, "HTTP proxy");
    my $http_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $http_proxy->setWeight($yui::YD_HORIZ, 30);

    # flag to setup the https proxy with the same value of the http proxy
    $factory->createCheckBox($vbox_labels_flags, "Use HTTP proxy for HTTPS connections",$httpsProxyEqualToHttpProxy);
    # add a spacing as we have 
    $factory->createLabel($factory->createHBox($vbox_inputfields)," ");

    # https proxy
    $factory->createLabel($vbox_labels_flags, "HTTPS proxy");
    my $https_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $https_proxy->setWeight($yui::YD_HORIZ, 30);

    # ftp proxy
    $factory->createLabel($vbox_labels_flags, "FTP proxy");
    my $ftp_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $ftp_proxy->setWeight($yui::YD_HORIZ, 30);

    # no-proxy list
    $factory->createLabel($vbox_labels_flags, "No proxy for (comma separated list):");
    my $no_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $no_proxy->setWeight($yui::YD_HORIZ, 30);

    my $hbox_filler = $factory->createHBox($layout);
    $factory->createSpacing($hbox_filler,$yui::YD_VERT,2);

    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,"About");
    my $cancelButton = $factory->createPushButton($vbox_foot_right,"Cancel");
    my $okButton = $factory->createPushButton($vbox_foot_right,"OK");

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
            }elsif ($widget == $aboutButton) {
                $self->sh_gui->AboutDialog({
                    name => $appTitle,
                    version => $VERSION,
                    credits => "Copyright (c) 2013-2014 by Matteo Pasotti",
                    license => "GPLv2",
                    description => "Graphical manager for proxies",
                    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
                    }
                );
            }elsif ($widget == $okButton) {
                # save changes
                last;
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

1;
