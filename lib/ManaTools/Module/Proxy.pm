# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2013-2016 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package ManaTools::Module::Proxy;

use Modern::Perl '2011';
use autodie;
use Moose;
use POSIX qw(ceil);
use English;
use utf8;
use File::ShareDir ':ALL';

use yui;
use ManaTools::Shared qw(trim);
use ManaTools::Shared::GUI;
use ManaTools::Shared::Proxy;

# TODROP but provides network::network
use lib qw(/usr/lib/libDrakX);
use network::network;
use MDK::Common::System qw(getVarsFromSh);

extends qw( ManaTools::Module );


has '+icon' => (
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/manaproxy.png'),
);

has '+name' => (
    lazy     => 1,
    builder => '_nameInitializer',
);

sub _nameInitializer {
    my $self = shift;

    return ($self->loc->N("manaproxy - Proxy configuration"));
};

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

has 'table' => (
    is => 'rw',
    init_arg => undef
);

has 'proxy' => (
    is      => 'rw',
    isa     => 'HashRef',
    builder => "init_proxy"
);

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);


sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui( ManaTools::Shared::GUI->new() );
}

#=============================================================

=head2 init_proxy

=head3 DESCRIPTION

=over 4

=item This method does initialize the proxy attribute provided by this class.

=item $self->proxy is structured as follows:

=over 6

=item B<no_proxy>    the string with the list of the excluded domains/addresses

=item B<http_proxy>  the url of the http proxy

=item B<https_proxy> the url of the https proxy

=item B<ftp_proxy>   the url for the ftp proxy

=back

=back

=cut

#=============================================================

sub init_proxy {
    my %p = (
                'no_proxy'    => '',
                'http_proxy'  => '',
                'https_proxy' => '',
                'ftp_proxy'   => '',
            );
    return \%p;
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

    if ($EUID != 0) {
        $self->sh_gui->warningMsgBox({
                                title => $self->name,
                                text  => $self->loc->N("root privileges required"),
                                });
        return;
    }

    $self->_manageProxyDialog();
};

#=============================================================

=head2 ask_for_X_restart

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method shows a message box warning the user
    that a X server restart is required

=cut

#=============================================================

sub ask_for_X_restart {
    my $self = shift;

    $self->sh_gui->warningMsgBox({title=>$self->loc->N("X Restart Required"),text=>$self->loc->N("You need to log out and back in again for changes to take effect"),richtext=>1});
}

#=============================================================

=head2 validate

=head3 INPUT

    $self: this object

    $proxy: the hash containing what returns from getVarFromSh
            eventually modified by the user

=head3 DESCRIPTION

    This method returns true if the each value match
    certain conditions like the leading http:// for http proxy
    or https:// for the https proxy, etc.

    $proxy is passed by reference thus $proxy->{no_proxy} value
    is sanitized (trimmed).

=cut

#=============================================================

sub validate {
    my $self = shift;
    my $proxy = shift;
    my $retval = 1;
    $proxy->{no_proxy} =~ s/\s//g;
    # using commas rather than slashes
    if($proxy->{http_proxy} !~ m,^($|http://),)
    {
        $self->sh_gui->warningMsgBox({title=>'Error',text=>$self->loc->N("Proxy should be http://..."),richtext=>0});
        $retval = 0;
    }
    if($proxy->{https_proxy} !~ m,^($|https?://),)
    {
        $self->sh_gui->warningMsgBox({title=>'Error',text=>$self->loc->N("Proxy should be http://... or https://..."),richtext=>0});
        $retval = 0;
    }
    if($proxy->{ftp_proxy} !~ m,^($|ftp://|http://),)
    {
        $self->sh_gui->warningMsgBox({title=>'Error',text=>$self->loc->N("URL should begin with 'ftp:' or 'http:'"),richtext=>0});
        $retval = 0;
    }
    return $retval;
}

sub _manageProxyDialog {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = $self->loc->N("Proxies configuration");

    ## TODO remove title and icon when using Shared::Module::GUI::Dialog
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name());
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon());

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $label_width = 25;
    my $inputfield_width = 45;
    # getVarsFromSh returns an empty hash if no vars are defined
    # possible alternatives:
    # . Config::Auto::parse
    my $proxy_curr_settings = { getVarsFromSh('/etc/profile.d/proxy.sh') };
    my $httpsProxyEqualToHttpProxy = 0;
    if((defined($proxy_curr_settings->{http_proxy}) && defined($proxy_curr_settings->{https_proxy}))&&
        (($proxy_curr_settings->{http_proxy} eq $proxy_curr_settings->{https_proxy}) &&
            ($proxy_curr_settings->{http_proxy} ne ""))){
        $httpsProxyEqualToHttpProxy = 1;
    }

    #
    # @layout
    #
    # +------------------------------+
    # | +------------+-------------+ |
    # | |LABELS      | VALUES      | |
    # | |            |             | |
    # | |            |             | |
    # | |            |             | |
    # | +------------+-------------+ |
    # +------------------------------+

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
    $factory->createLabel($hbox_content, $self->loc->N("Here you can set up your proxies configuration (eg: http://my_caching_server:8080)"));

    $hbox_content = $factory->createHBox($layout);

    my $vbox_labels_flags = $factory->createVBox($hbox_content);
    my $vbox_inputfields = $factory->createVBox($hbox_content);

    # http proxy section
    my $httpproxy_label = $factory->createLabel($vbox_labels_flags, $self->loc->N("HTTP proxy"));
    my $http_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $http_proxy->setValue($proxy_curr_settings->{http_proxy}) if(defined($proxy_curr_settings->{http_proxy}));
    $http_proxy->setWeight($yui::YD_HORIZ, 30);

    # flag to setup the https proxy with the same value of the http proxy
    my $ckbHttpEqHttps = $factory->createCheckBox($vbox_labels_flags, $self->loc->N("Use HTTP proxy for HTTPS connections"),$httpsProxyEqualToHttpProxy);
    $ckbHttpEqHttps->setNotify(1);
    # add a spacing as we have
    $factory->createLabel($factory->createHBox($vbox_inputfields)," ");

    # https proxy
    $factory->createLabel($vbox_labels_flags, $self->loc->N("HTTPS proxy"));
    my $https_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $https_proxy->setValue($proxy_curr_settings->{https_proxy}) if(defined($proxy_curr_settings->{https_proxy}));
    $https_proxy->setWeight($yui::YD_HORIZ, 30);

    # ftp proxy
    $factory->createLabel($vbox_labels_flags, $self->loc->N("FTP proxy"));
    my $ftp_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $ftp_proxy->setValue($proxy_curr_settings->{ftp_proxy}) if(defined($proxy_curr_settings->{ftp_proxy}));
    $ftp_proxy->setWeight($yui::YD_HORIZ, 30);

    # no-proxy list
    $factory->createLabel($vbox_labels_flags, $self->loc->N("No proxy for (comma separated list):"));
    my $no_proxy = $factory->createInputField($factory->createHBox($vbox_inputfields),"",0);
    $no_proxy->setValue($proxy_curr_settings->{no_proxy}) if(defined($proxy_curr_settings->{no_proxy}));
    $no_proxy->setWeight($yui::YD_HORIZ, 30);

    my $hbox_filler = $factory->createHBox($layout);
    $factory->createSpacing($hbox_filler,$yui::YD_VERT,2);

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
            }elsif ($widget == $aboutButton) {
                $self->sh_gui->AboutDialog({
                    name => $appTitle,
                    version => $self->Version(),
                    credits => "Copyright (c) 2013-2014 by Matteo Pasotti",
                    license => "GPLv2",
                    description => $self->loc->N("Graphical manager for proxies"),
                    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
                    }
                );
            }elsif ($widget == $okButton) {
                # setup proxy attribute
                my %_proxy = (
                    no_proxy    => $no_proxy->value(),
                    http_proxy  => $http_proxy->value(),
                    https_proxy => $https_proxy->value(),
                    ftp_proxy   => $ftp_proxy->value()
                );
                if($self->validate(\%_proxy)) {
                    # validation succeded
                    $self->proxy(\%_proxy);
                    # save changes
                    network::network::proxy_configure($self->proxy);
                    $self->ask_for_X_restart();
                    last;
                }
                # validation failed
                next;
            }elsif ($widget == $ckbHttpEqHttps){
                $https_proxy->setEnabled(!$ckbHttpEqHttps->isChecked());
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

1;
