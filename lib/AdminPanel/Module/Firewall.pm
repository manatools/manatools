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
use Moose::Autobox;
use utf8;

use yui;
use AdminPanel::Shared qw(trim);
use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Firewall;
use AdminPanel::Shared::Shorewall;

use MDK::Common::Func qw(if_ partition);
use MDK::Common::System qw(getVarsFromSh);
use MDK::Common::Various qw(text2bool to_bool);
use MDK::Common::DataStructure qw(intersection);
use MDK::Common::File qw(substInFile output_with_perm);

use List::Util qw(any);
use List::MoreUtils qw(uniq);

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

has 'ifw_rules' => (
    is => 'rw',
    init_arg => undef,
    isa => 'ArrayRef',
);

has 'wdg_ifw' => (
    is => 'rw',
    init_arg => undef,
    isa => 'ArrayRef',
    default => sub { [] },
);

has 'wdg_servers' => (
    is => 'rw',
    init_arg => undef,
    isa => 'ArrayRef',
    default => sub { [] },
);

has 'net' => (
    is => 'rw',
    init_arg => undef,
    isa => 'HashRef',
    builder => '_initNet',
);

has 'aboutDialog' => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    builder => '_setupAboutDialog',
);

sub _setupAboutDialog {
  my $self = shift();
  return {
    name => "",
    version => $VERSION,
    credits => "Copyright (c) 2013-2015 by Matteo Pasotti",
    license => "GPLv2",
    description => "",
    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
    };
}

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
            id => 'www',
            name => $self->loc->N("Web Server"),
            pkg => 'apache apache-mod_perl boa lighttpd thttpd',
            ports => '80/tcp 443/tcp',
        },
        {
            id => 'dns',
            name => $self->loc->N("Domain Name Server"),
            pkg => 'bind dnsmasq mydsn',
            ports => '53/tcp 53/udp',
        },
        {
            id => 'ssh',
            name => $self->loc->N("SSH server"),
            pkg => 'openssh-server',
            ports => '22/tcp',
        },
        {
            id => 'ftp',
            name => $self->loc->N("FTP server"),
            pkg => 'ftp-server-krb5 wu-ftpd proftpd pure-ftpd',
            ports => '20/tcp 21/tcp',
        },
        {
            id => 'dhcp',
            name => $self->loc->N("DHCP Server"),
            pkg => 'dhcp-server udhcpd',
            ports => '67/udp 68/udp',
            hide => 1,
        },
        {
            id => 'mail',
            name => $self->loc->N("Mail Server"),
            pkg => 'sendmail postfix qmail exim',
            ports => '25/tcp 465/tcp 587/tcp',
        },
        {
            id => 'popimap',
            name => $self->loc->N("POP and IMAP Server"),
            pkg => 'imap courier-imap-pop',
            ports => '109/tcp 110/tcp 143/tcp 993/tcp 995/tcp',
        },
        {
            id => 'telnet',
            name => $self->loc->N("Telnet server"),
            pkg => 'telnet-server-krb5',
            ports => '23/tcp',
            hide => 1,
        },
        {
            id => 'nfs',
            name => $self->loc->N("NFS Server"),
            pkg => 'nfs-utils nfs-utils-clients',
            ports => '111/tcp 111/udp 2049/tcp 2049/udp ' . network::nfs::list_nfs_ports(),
            hide => 1,
            prepare => sub { network::nfs::write_nfs_ports(network::nfs::read_nfs_ports()) },
            restart => 'nfs-common nfs-server',
        },
        {
            id => 'smb',
            name => $self->loc->N("Windows Files Sharing (SMB)"),
            pkg => 'samba-server',
            ports => '137/tcp 137/udp 138/tcp 138/udp 139/tcp 139/udp 445/tcp 445/udp 1024:1100/tcp 1024:1100/udp',
            hide => 1,
        },
        {
            id => 'bacula',
            name => $self->loc->N("Bacula backup"),
            pkg => 'bacula-fd bacula-sd bacula-dir-common',
            ports => '9101:9103/tcp',
            hide => 1,
        },
        {
            id => 'syslog',
            name => $self->loc->N("Syslog network logging"),
            pkg => 'rsyslog syslog-ng',
            ports => '514/udp',
            hide => 1,
        },
        {
            id => 'cups',
            name => $self->loc->N("CUPS server"),
            pkg => 'cups',
            ports => '631/tcp 631/udp',
            hide => 1,
        },
        {
            id => 'mysql',
            name => $self->loc->N("MySQL server"),
            pkg => 'mysql',
            ports => '3306/tcp 3306/udp',
            hide => 1,
        },
        {
            id => 'postgresql',
            name => $self->loc->N("PostgreSQL server"),
            pkg => 'postgresql8.2 postgresql8.3',
            ports => '5432/tcp 5432/udp',
            hide => 1,
        },
        {
            id => 'echo',
            name => $self->loc->N("Echo request (ping)"),
            ports => '8/icmp',
            force_default_selection => 0,
        },
        {
            id => 'zeroconf',
            name => $self->loc->N("Network services autodiscovery (zeroconf and slp)"),
            ports => '5353/udp 427/udp',
            pkg => 'avahi cups openslp',
        },
        {
            id => 'bittorrent',
            name => $self->loc->N("BitTorrent"),
            ports => '6881:6999/tcp 6881:6999/udp',
            hide => 1,
            pkg => 'bittorrent deluge ktorrent transmission vuze rtorrent ctorrent',
        },
        {
            id => 'wmds',
            name => $self->loc->N("Windows Mobile device synchronization"),
            pkg => 'synce-hal',
            ports => '990/tcp 999/tcp 5678/tcp 5679/udp 26675/tcp',
            hide => 1,
        },
    );
    return \@all_servers; 
}

sub _initIFW {
    my $self = shift();
    my @ifw_rules = (
	{
        id => 'psd',
        name => $self->loc->N("Port scan detection"),
        ifw_rule => 'psd',
	},
    );
    return \@ifw_rules;
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

=head2 to_ports

=head3 INPUT

    $self: this object
    
    $unlisted: unlisted services

=head3 DESCRIPTION

    This method converts from server definitions to port definitions

=cut

#=============================================================

sub to_ports {
    my ($self, $servers, $unlisted) = @_;
    join(' ', (map { $_->{ports} } @$servers), if_($unlisted, $unlisted));
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
    my $conf = AdminPanel::Shared::Shorewall::read_();
    my $shorewall = (AdminPanel::Shared::Shorewall::get_config_file('zones', '') && $conf);
    
    if ($o_ports) {
        return ($disabled, $self->from_ports($o_ports));
    } elsif ($shorewall) {
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

sub set_ifw {
    # my ($do_pkgs, $enabled, $rules, $ports) = @_;
    my $self = shift();
    my ($enabled, $rules, $ports) = @_;
    if ($enabled) 
    {
        my $ports_by_proto = AdminPanel::Shared::Shorewall::ports_by_proto($ports);
        output_with_perm("$::prefix/etc/ifw/rules", 0644,
            (map { ". /etc/ifw/rules.d/$_\n" } @$rules),
             map {
                my $proto = $_;
                map {
                    my $multiport = /:/ && " -m multiport";
                    "iptables -A Ifw -m conntrack --ctstate NEW -p $proto$multiport --dport $_ -j IFWLOG --log-prefix NEW\n";
                } @{$ports_by_proto->{$proto}};
            } intersection([ qw(tcp udp) ], [ keys %$ports_by_proto ]),
        );
    }

    substInFile {
            undef $_ if m!^INCLUDE /etc/ifw/rules|^iptables -I INPUT 2 -j Ifw!;
    } "$::prefix/etc/shorewall/start";
    AdminPanel::Shared::Shorewall::set_in_file('start', $enabled, "INCLUDE /etc/ifw/start", "INCLUDE /etc/ifw/rules", "iptables -I INPUT 1 -j Ifw");
    AdminPanel::Shared::Shorewall::set_in_file('stop', $enabled, "iptables -D INPUT -j Ifw", "INCLUDE /etc/ifw/stop");
}

#=============================================================

=head2 choose_watched_services

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

sub choose_watched_services {
    my ($self, $servers, $unlisted) = @_;

    my @l = (@{$self->ifw_rules()}, @$servers, map { { ports => $_ } } split(' ', $unlisted));
    
    my $enabled = 1;
    $_->{ifw} = 1 foreach @l;

    my $retval = $self->ask_WatchedServices({
        title => $self->loc->N("Interactive Firewall"),
        icon => $AdminPanel::Shared::Shorewall::firewall_icon,
        # if_(!$::isEmbedded, banner_title => N("Interactive Firewall")),
        messages =>
            $self->loc->N("You can be warned when someone accesses to a service or tries to intrude into your computer.
Please select which network activities should be watched."),
	},
        [
        { 
            id=>'useifw', 
            text => $self->loc->N("Use Interactive Firewall"), 
            val => $enabled, 
            type => 'bool' 
        },
        map {
                {
                text => (exists $_->{name} ? $_->{name} : $_->{ports}),
                val => $_->{ifw},
                type => 'bool', 
                id => $_->{id},
                },
        } @l,
        ]);
    
    exit() if($retval == 0);
    
    for my $server(@{$self->wdg_ifw()})
    {
        for my $k(keys @l)
        {
            if(defined($l[$k]->{id}) && defined($server->{id}))
            {
                if($server->{id} eq 'useifw')
                {
                    $enabled = $server->{value};
                }
                else
                {
                    if($l[$k]->{id} eq $server->{id})
                    {
                        $l[$k]->{ifw} = $server->{value};
                        last;
                    }
                }
            }
        }
    }
    
    my ($rules, $ports) = partition { exists $_->{ifw_rule} } grep { $_->{ifw} } @l;
        
    $self->set_ifw($enabled, [ map { $_->{ifw_rule} } @$rules ], $self->to_ports($ports));

    # return something to say that we are done ok
    return ($rules, $ports);
}

#=============================================================

sub ask_WatchedServices {
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
    my $labelAppDescription = $factory->createLabel($headRight,$dlg_data->{messages}); 
    $logoImage->setWeight($yui::YD_HORIZ,0);
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    my $hbox_content = $factory->createHBox($layout);

    my $widgetContainer = $factory->createVBox($hbox_content);
    
    
    foreach my $item(@{$items})
    {
        if(defined($item->{label}))
        {
            $factory->createLabel($factory->createLeft($factory->createHBox($widgetContainer)), $item->{label});
        }
        elsif(defined($item->{text}))
        {
            my $ckbox = $factory->createCheckBox(
                $factory->createLeft($factory->createHBox($widgetContainer)), 
                $item->{text}, 
                $item->{val}
            );
            $ckbox->setNotify(1);
            push @{$self->wdg_ifw()}, {
                id => $item->{id},
                widget => \$ckbox,
                value => $item->{val},
                };
            $ckbox->DISOWN();
        }
    }
    
    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("OK"));

    my $retval = 1;
    
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
            
            # loop on every checkbox representing servers
            foreach my $server(@{$self->wdg_ifw()})
            {
                if($widget == ${$server->{widget}})
                {
                    if($server->{id} eq 'useifw')
                    {
                        if(!${$server->{widget}}->value())
                        {
                            yui::YUI::ui()->blockEvents();
                            foreach my $server(@{$self->wdg_ifw()})
                            {
                                if($server->{id} ne 'useifw')
                                {
                                    ${$server->{widget}}->setValue(0);
                                    $server->{value} = ${$server->{widget}}->value();
                                }
                            }
                            yui::YUI::ui()->unblockEvents();
                            last;
                        }
                    }
                    else
                    {
                        $server->{value} = ${$server->{widget}}->value();
                    }
                }
            }
            if ($widget == $cancelButton) {
                $retval = 0;
                last;
            }elsif ($widget == $aboutButton) {
                my $abtdlg = $self->aboutDialog();
                $abtdlg->{name} = $dlg_data->{title};
                $abtdlg->{description} = $self->loc->N("Graphical manager for interactive firewall rules");
                $self->sh_gui->AboutDialog($abtdlg
                );
            }elsif ($widget == $okButton) {
                last;
            }
        }
    }

    $self->dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($old_title);
    
    return $retval;
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
        icon => $AdminPanel::Shared::Shorewall::firewall_icon,
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
        (map { { text => $_->{name}, val => \$_->{on}, type => 'bool', disabled => sub { $disabled }, id => $_->{id} } } @l),
        { label => $self->loc->N("Other ports"), val => \$unlisted, advanced => 1, disabled => sub { $disabled } },
        { text => $self->loc->N("Log firewall messages in system logs"), val => \$log_net_drop, type => 'bool', advanced => 1, disabled => sub { $disabled } },
    ];
    
    exit() if(!$self->ask_AllowedServices($dialog_data, $items));

    for my $server(@{$self->wdg_servers()})
    {
        for my $k(keys @l)
        {
            if(defined($l[$k]->{id}) && defined($server->{id}))
            {
            if($l[$k]->{id} eq $server->{id})
            {
                $l[$k]->{on} = ${$server->{value}};
                last;
            }
            }
        }
    }
    
    return ($disabled, [ grep { $_->{on} } @l ], $unlisted, $log_net_drop);
}

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
            $factory->createLabel($factory->createLeft($factory->createHBox($widgetContainer)), $item->{label});
        }
        elsif(defined($item->{text}))
        {
            my $ckbox = $factory->createCheckBox(
                    $factory->createLeft($factory->createHBox($widgetContainer)), 
                    $item->{text}, 
                    ${$item->{val}}
            );
            $ckbox->setNotify(1);
            push @{$self->wdg_servers()}, {
                id => $item->{id},
                widget => \$ckbox,
                value => $item->{val},
                };
            $ckbox->DISOWN();
        }
    }
    
    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("OK"));
    
    my $retval = 1;
    
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
            
            # loop on every checkbox representing servers
            foreach my $server(@{$self->wdg_servers()})
            {
                if($widget == ${$server->{widget}})
                {
                ${$server->{value}} = !${$server->{value}};
                }
            }
            
            if ($widget == $cancelButton) {
                $retval = 0;
                last;
            }elsif ($widget == $aboutButton) {
                my $abtdlg = $self->aboutDialog();
                $abtdlg->{name} = $dlg_data->{title};
                $abtdlg->{description} = $self->loc->N("Graphical manager for firewall rules");
                $self->sh_gui->AboutDialog($abtdlg);
            }elsif ($widget == $okButton) {
                last;
            }
        }
    }

    $self->dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($old_title);
    
    return $retval;
}

sub get_zones {
    my $self = shift();
    my $confref = shift();
    my $conf = ${$confref};
    my $interfacesfile = AdminPanel::Shared::Shorewall::get_config_file('interfaces', $conf->{version} || '');
    network::network::read_net_conf($self->net());
    #- find all interfaces but alias interfaces
    my @all_intf = grep { !/:/ } uniq(keys(%{$self->net()->{ifcfg}}), detect_devices::get_net_interfaces());
    my %net_zone = map { $_ => undef } @all_intf;
    $net_zone{$_} = 1 foreach AdminPanel::Shared::Shorewall::get_net_zone_interfaces($interfacesfile, $self->net(), \@all_intf);
    my $retvals = $self->sh_gui->ask_multiple_fromList({
        title => $self->loc->N("Firewall configuration"),
        header => $self->loc->N("Please select the interfaces that will be protected by the firewall.

All interfaces directly connected to Internet should be selected,
while interfaces connected to a local network may be unselected.

If you intend to use Mageia Internet Connection sharing,
unselect interfaces which will be connected to local network.

Which interfaces should be protected?
"),
    list => [
        map {
            {
            id => $_,
            text => network::tools::get_interface_description($self->net(), $_), 
            val => \$net_zone{$_}, 
            type => 'bool' 
            };
        } (sort keys %net_zone) ]
        });
    
    if(!defined($retvals))
    {
        return 0;
    }
    else
    {
        # it was: ($conf->{net_zone}, $conf->{loc_zone}) = partition { $net_zone{$_} } keys %net_zone;
        foreach my $net_int (@{$retvals})
        {
            push (@{$conf->{net_zone}}, $net_int);
        }
        return $retvals;
    }
}

#=============================================================

=head2 set_ports

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start  host manager

=cut

#=============================================================

sub set_ports {
    my ($self, $disabled, $ports, $log_net_drop) = @_;
        
    if (!$disabled || -x "$::prefix/sbin/shorewall") {
        # $do_pkgs->ensure_files_are_installed([ [ qw(shorewall shorewall) ], [ qw(shorewall-ipv6 shorewall6) ] ], $::isInstall) or return;
        my $conf = AdminPanel::Shared::Shorewall::read_();
        if(!$self->get_zones(\$conf))
        {
            # Cancel button has been pressed, aborting
            return 0;
        }
        my $shorewall = (AdminPanel::Shared::Shorewall::get_config_file('zones', '') && $conf);
        if (!$shorewall) {
            print ("unable to read shorewall configuration, skipping installation");
            return 0;
        }

        $shorewall->{disabled} = $disabled;
        $shorewall->{ports} = $ports;
        $shorewall->{log_net_drop} = $log_net_drop;
        
        print ($disabled ? "disabling shorewall" : "configuring shorewall to allow ports: $ports");

        # NOTE: the 2nd param is undef in this case!
        if(!AdminPanel::Shared::Shorewall::write_($shorewall))
        {
            # user action request
            my $action = $self->sh_gui->ask_fromList({
            title => $self->loc->N("Firewall"),
            header => $self->loc->N("Your firewall configuration has been manually edited and contains
    rules that may conflict with the configuration that has just been set up.
    What do you want to do?"),
            list => [ "keep", "drop"],
            default => "keep",
            });
            AdminPanel::Shared::Shorewall::write_($shorewall,$action);
            return 1;
        }
    }
    return 0;
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
    
    my @server = ();
    $self->wdg_servers(@server);
    
    # init servers definitions
    $self->all_servers($self->_initAllServers());
    
    # initialize ifw_rules here
    $self->ifw_rules($self->_initIFW());
    
    my ($disabled, $servers, $unlisted, $log_net_drop) = $self->get_conf(undef) or return;
    ($disabled, $servers, $unlisted, $log_net_drop) = $self->choose_allowed_services($disabled, $servers, $unlisted, $log_net_drop) or return;
    
    my $system_file = '/etc/sysconfig/drakx-net';
    my %global_settings = getVarsFromSh($system_file);
    
    if (!$disabled && (!defined($global_settings{IFW}) || text2bool($global_settings{IFW}))) {
        $self->choose_watched_services($servers, $unlisted) or return;
    }
    
    # preparing services when required ( look at $self->all_servers() )
    foreach (@$servers) {
        exists $_->{prepare} and $_->{prepare}();
    }
    
    my $ports = $self->to_ports($servers, $unlisted);
    
    $self->set_ports($disabled, $ports, $log_net_drop) or return;
    
    # restart mandi
    require services;
    services::is_service_running("mandi") and services::restart("mandi");

    # restarting services if needed
    foreach my $service (@$servers) {
        if ($service->{restart}) {
            services::is_service_running($_) and services::restart($_) foreach split(' ', $service->{restart});
        }
    }

    # clearing pending ifw notifications in net_applet
    system('killall -s SIGUSR1 net_applet');

    return ($disabled, $ports);
};

sub ask_from_ {
    my $self = shift();

    my ($dlg_data,
	$items) = @_;

    my @buttons = ();
    my @list = ();
    my $val = undef;
    
    foreach my $item(@{$items})
    {
	push @list, {
	  text => $item->{text},
	  value => ${$item->{val}},
	  };
    }
    
    
    my @retval = $self->sh_gui->ask_multiple_fromList({
	  title => $dlg_data->{title},
	  header => $dlg_data->{messages},
	  list => \@list});
    
    return @retval;
}

1;
