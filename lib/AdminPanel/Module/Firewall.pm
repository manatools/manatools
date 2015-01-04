# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013-2015 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package AdminPanel::Module::Firewall;

use Modern::Perl '2011';
use autodie;
use Moose;
use utf8;

use yui;
use AdminPanel::Shared qw(trim);
use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Firewall;

use List::Util qw(any);
use List::MoreUtils qw(uniq);

use MDK::Common::Func qw(if_);

extends qw( AdminPanel::Module );

has '+icon' => (
    default => "/usr/share/mcc/themes/default/firewall-mdk.png",
);

has '+name' => (
    default => "Firewall Manager",
);

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

has 'loc' => (
        is => 'rw',
        init_arg => undef,
        builder => '_localeInitialize',
        required => 1,
);

has 'all_servers' => (
    is => 'rw',
    init_arg => undef,
    isa => 'ArrayRef',
);

has 'net' => (
    is => 'rw',
    init_arg => undef,
    isa => 'HashRef',
    builder => '_initNet',
);

sub _localeInitialize {
    my $self = shift();

    # TODO fix domain binding for translation
    $self->loc(AdminPanel::Shared::Locales->new(domain_name => 'drakx-net') );
    # TODO if we want to give the opportunity to test locally add dir_name => 'path'
}

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(AdminPanel::Shared::GUI->new() );
}

sub _initAllServers {
    my $self = shift();
    my @all_servers = (
        {
            name => $self->loc->N("Web Server"),
            pkg => 'apache apache-mod_perl boa lighttpd thttpd',
            ports => '80/tcp 443/tcp',
        },
        {
            name => $self->loc->N("Domain Name Server"),
            pkg => 'bind dnsmasq mydsn',
            ports => '53/tcp 53/udp',
        },
        {
            name => $self->loc->N("SSH server"),
            pkg => 'openssh-server',
            ports => '22/tcp',
        },
        {
            name => $self->loc->N("FTP server"),
            pkg => 'ftp-server-krb5 wu-ftpd proftpd pure-ftpd',
            ports => '20/tcp 21/tcp',
        },
        {
            name => $self->loc->N("DHCP Server"),
            pkg => 'dhcp-server udhcpd',
            ports => '67/udp 68/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("Mail Server"),
            pkg => 'sendmail postfix qmail exim',
            ports => '25/tcp 465/tcp 587/tcp',
        },
        {
            name => $self->loc->N("POP and IMAP Server"),
            pkg => 'imap courier-imap-pop',
            ports => '109/tcp 110/tcp 143/tcp 993/tcp 995/tcp',
        },
        {
            name => $self->loc->N("Telnet server"),
            pkg => 'telnet-server-krb5',
            ports => '23/tcp',
            hide => 1,
        },
        {
            name => $self->loc->N("NFS Server"),
            pkg => 'nfs-utils nfs-utils-clients',
            ports => '111/tcp 111/udp 2049/tcp 2049/udp ' . network::nfs::list_nfs_ports(),
            hide => 1,
            prepare => sub { network::nfs::write_nfs_ports(network::nfs::read_nfs_ports()) },
            restart => 'nfs-common nfs-server',
        },
        {
            name => $self->loc->N("Windows Files Sharing (SMB)"),
            pkg => 'samba-server',
            ports => '137/tcp 137/udp 138/tcp 138/udp 139/tcp 139/udp 445/tcp 445/udp 1024:1100/tcp 1024:1100/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("Bacula backup"),
            pkg => 'bacula-fd bacula-sd bacula-dir-common',
            ports => '9101:9103/tcp',
            hide => 1,
        },
        {
            name => $self->loc->N("Syslog network logging"),
            pkg => 'rsyslog syslog-ng',
            ports => '514/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("CUPS server"),
            pkg => 'cups',
            ports => '631/tcp 631/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("MySQL server"),
            pkg => 'mysql',
            ports => '3306/tcp 3306/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("PostgreSQL server"),
            pkg => 'postgresql8.2 postgresql8.3',
            ports => '5432/tcp 5432/udp',
            hide => 1,
        },
        {
            name => $self->loc->N("Echo request (ping)"),
            ports => '8/icmp',
            force_default_selection => 0,
        },
        {
            name => $self->loc->N("Network services autodiscovery (zeroconf and slp)"),
            ports => '5353/udp 427/udp',
            pkg => 'avahi cups openslp',
        },
        {
            name => $self->loc->N("BitTorrent"),
            ports => '6881:6999/tcp 6881:6999/udp',
            hide => 1,
            pkg => 'bittorrent deluge ktorrent transmission vuze rtorrent ctorrent',
        },
        {
            name => $self->loc->N("Windows Mobile device synchronization"),
            pkg => 'synce-hal',
            ports => '990/tcp 999/tcp 5678/tcp 5679/udp 26675/tcp',
            hide => 1,
        },
    );
    return \@all_servers; 
}

sub _initNet {
    my $self = shift();
    my $net = {};
    network::network::read_net_conf($net);
    return $net;
}

#=============================================================

=head2 port2server

=head3 INPUT

    $self: this object
    
    $ports: port object

=head3 DESCRIPTION

    This method retrieves the server from a given port

=cut

#=============================================================

sub port2server {
    my $self = shift();
    my ($port) = @_;
    for my $service(@{$self->all_servers()})
    {
	if(any { $port eq $_ } split(' ', $service->{ports}))
	{
	    return $service;
	}
    }
    return 0;
}

#=============================================================

=head2 from_ports

=head3 INPUT

    $self: this object
    
    $ports: ports object

=head3 DESCRIPTION

    This method does...

=cut

#=============================================================

sub from_ports {
    my $self = shift();
    my ($ports) = @_;

    my @l;
    my @unlisted;
    foreach (split ' ', $ports) {
	if (my $s = $self->port2server($_)) {
	    push @l, $s;
	} else {
	    push @unlisted, $_;
	}
    }
    [ uniq(@l) ], join(' ', @unlisted);
}

#=============================================================

=head2 get_conf

=head3 INPUT

    $self: this object
    
    $disabled: boolean
    
    $o_ports: object representing ports

=head3 DESCRIPTION

    This method retrieves the configuration

=cut

#=============================================================

sub get_conf {
    my $self = shift();
    my ($disabled, $o_ports) = @_;
    my $possible_servers = undef;
    
    if ($o_ports) {
	return ($disabled, from_ports($o_ports));
    } elsif (my $shorewall = network::shorewall::read()) {
	# WARNING: this condition fails (the method fails)
	#          if manawall runs as unprivileged user
	#          cause it can't read the interfaces file
	return ($shorewall->{disabled}, $self->from_ports($shorewall->{ports}), $shorewall->{log_net_drop});
    } else {
	$self->sh_gui->ask_OkCancel({
	  title => $self->loc->N("Firewall configuration"), 
	  text => $self->loc->N("drakfirewall configurator
				 This configures a personal firewall for this Mageia machine."), 
	  richtext => 1
	  }) or return;

	$self->sh_gui->ask_OkCancel({
	  title => $self->loc->N("Firewall configuration"), 
	  text => $self->loc->N("drakfirewall configurator
Make sure you have configured your Network/Internet access with
drakconnect before going any further."), 
	  richtext => 1
	  }) or return;

	return($disabled, $possible_servers, '');
    }
}

#=============================================================

=head2 choose_allowed_services

=head3 INPUT

    $self: this object
    
    $disabled: boolean
    
    $servers: array of hashes representing servers
    
    $unlisted: array of hashes with the port not listed (???)
    
    $log_net_drop: network::shorewall log_net_drop attribute

=head3 DESCRIPTION

    This method shows the main dialog to let users choose the allowed services

=cut

#=============================================================

sub choose_allowed_services {
    my ($self, $disabled, $servers, $unlisted, $log_net_drop) = @_;

    $_->{on} = 0 foreach @{$self->all_servers()};
    $_->{on} = 1 foreach @$servers;
    my @l = grep { $_->{on} || !$_->{hide} } @{$self->all_servers()};
    
    my $dialog_data = {
	title => $self->loc->N("Firewall"),
	icon => $network::shorewall::firewall_icon,
	# if_(!$::isEmbedded, banner_title => $self->loc->N("Firewall")),
	banner_title => $self->loc->N("Firewall"),
	advanced_messages => $self->loc->N("You can enter miscellaneous ports. 
Valid examples are: 139/tcp 139/udp 600:610/tcp 600:610/udp.
Have a look at /etc/services for information."),
#		    callbacks => {
# 			complete => sub {
# 			    if (my $invalid_port = check_ports_syntax($unlisted)) {
# 				$in->ask_warn('', $self->loc->N("Invalid port given: %s.
# The proper format is \"port/tcp\" or \"port/udp\", 
# where port is between 1 and 65535.
# 
# You can also give a range of ports (eg: 24300:24350/udp)", $invalid_port));
# 				return 1;
# 			    }
# 			},
#		   } 
    };
    
    my $items = [
	{ label => $self->loc->N("Which services would you like to allow the Internet to connect to?"), title => 1 },
	if_($self->net()->{PROFILE} && network::network::netprofile_count() > 0, { label => $self->loc->N("Those settings will be saved for the network profile <b>%s</b>", $self->net()->{PROFILE}) }),
	{ text => $self->loc->N("Everything (no firewall)"), val => \$disabled, type => 'bool' },
	(map { { text => $_->{name}, val => \$_->{on}, type => 'bool', disabled => sub { $disabled } } } @l),
	{ label => $self->loc->N("Other ports"), val => \$unlisted, advanced => 1, disabled => sub { $disabled } },
	{ text => $self->loc->N("Log firewall messages in system logs"), val => \$log_net_drop, type => 'bool', advanced => 1, disabled => sub { $disabled } },
    ];
    
    $self->ask_AllowedServices($dialog_data, $items) or return;

    return ($disabled, [ grep { $_->{on} } @l ], $unlisted, $log_net_drop);
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
    
    $self->all_servers($self->_initAllServers());
    
    
    
    my ($disabled, $servers, $unlisted, $log_net_drop) = $self->get_conf(undef) or return;
    ($disabled, $servers, $unlisted, $log_net_drop) = $self->choose_allowed_services($disabled, $servers, $unlisted, $log_net_drop) or return;
    
};

#=============================================================

sub ask_AllowedServices {
    my $self = shift;

    my ($dlg_data,
	$items) = @_;

    my $old_title = yui::YUI::app()->applicationTitle();
	
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($dlg_data->{title});

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;
    
    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_header = $factory->createHBox($layout);
    my $headLeft = $factory->createHBox($factory->createLeft($hbox_header));
    my $headRight = $factory->createHBox($factory->createRight($hbox_header));

    my $logoImage = $factory->createImage($headLeft, $dlg_data->{icon});
    my $labelAppDescription = $factory->createLabel($headRight,$dlg_data->{title}); 
    $logoImage->setWeight($yui::YD_HORIZ,0);
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    my $hbox_content = $factory->createHBox($layout);

    my $widgetContainer = $factory->createVBox($hbox_content);
    
    foreach my $item(@{$items})
    {
	if(defined($item->{label}))
	{
	    $factory->createLabel($widgetContainer, $item->{label});
	}
	elsif(defined($item->{text}))
	{
	    $factory->createLabel($widgetContainer, $item->{text} . " - ". $item->{val} . " - " . $item->{type});
	}
    }

    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("OK"));

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
                    name => $dlg_data->{title},
                    version => $VERSION,
                    credits => "Copyright (c) 2013-2015 by Matteo Pasotti",
                    license => "GPLv2",
                    description => $self->loc->N("Graphical manager for firewall rules"),
                    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
                    }
                );
            }elsif ($widget == $okButton) {
                # write changes
                return 
                last;
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($old_title);
}

1;
