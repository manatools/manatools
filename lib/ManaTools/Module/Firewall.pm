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

package ManaTools::Module::Firewall;

use Modern::Perl '2011';
use autodie;
use Moose;
use Moose::Autobox;
use utf8;

use yui;
use ManaTools::Shared qw(trim);
use ManaTools::Shared::GUI;
use ManaTools::Shared::Firewall;
use ManaTools::Shared::Shorewall;
use ManaTools::Shared::Services;

use MDK::Common::Func qw(if_ partition);
use MDK::Common::System qw(getVarsFromSh);
use MDK::Common::Various qw(text2bool to_bool);
use MDK::Common::DataStructure qw(intersection);
use MDK::Common::File qw(substInFile output_with_perm);

use List::Util qw(any);
use List::MoreUtils qw(uniq);

use XML::Simple;

extends qw( ManaTools::Module );

has '+icon' => (
    default => "/usr/share/icons/manawall.png",
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

has 'unlisted' => (
    is => 'rw',
    init_arg => undef,
    isa => 'ArrayRef',
    builder => '_initUnlisted',
);

has 'log_net_drop' => (
    is => 'rw',
    isa => 'Bool',
    default => sub { return 1; }
);

has 'aboutDialog' => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    builder => '_setupAboutDialog',
);

has 'conf' => (
    is => 'ro',
    isa => 'Str',
    default => sub { return $::prefix."/etc/manatools/manawall/spec.conf" },
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

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

sub _initAllServers {
    my $self = shift();
    my @all_servers = @{$self->get_servers()};
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

sub _initUnlisted {
    my $self = shift();
    my @unlisted = ();
    return \@unlisted;
}

#=============================================================

sub get_servers {
    my $self = shift();
    my $fh = undef;
    my @all_servers = ();
    my $xml = XML::Simple->new();
    my $data = $xml->XMLin($self->conf());
    foreach my $server (keys %{$data->{server}})
    {
        push(@all_servers, {
               id => $server,
               name => $data->{server}->{$server}->{description},
               pkg => $data->{server}->{$server}->{packages},
               ports => $data->{server}->{$server}->{ports},
               hide => (defined($data->{server}->{$server}->{hide}) ? 1 : 0),
               default => (defined($data->{server}->{$server}->{default}) ? 1 : 0),
               pos => (defined($data->{server}->{$server}->{pos}) ? $data->{server}->{$server}->{pos} : 0),
        });
    }
    my @sorted = sort { ${a}->{pos} <=> ${b}->{pos} } @all_servers;
    return \@sorted;
}

#=============================================================

sub check_ports_syntax {
    my ($ports) = @_;
    foreach (split ' ', $ports) {
        my ($nb, $range, $nb2) = m!^(\d+)(:(\d+))?/(tcp|udp|icmp)$! or return $_;
        foreach my $port ($nb, if_($range, $nb2)) {
            1 <= $port && $port <= 65535 or return $_;
        }
        $nb < $nb2 or return $_ if $range;
    }
    return '';
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

=head3 DESCRIPTION

    This method converts from server definitions to port definitions

=cut

#=============================================================

sub to_ports {
    my ($self, $servers) = @_;
    my $ports = join(' ', (map { $_->{ports} } @$servers), @{$self->unlisted()});
    return $ports;
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
    foreach (split ' ', $ports) {
        if (my $s = $self->port2server($_)) {
            push @l, $s;
        } else {
            push (@{$self->unlisted()}, $_);
        }
    }
    my @result = [ uniq(@l) ], join(' ', @{$self->unlisted()});
    return \@result;
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
    my $conf = ManaTools::Shared::Shorewall::read_();
    my $shorewall = (ManaTools::Shared::Shorewall::get_config_file('zones', '') && $conf);

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
        my $ports_by_proto = ManaTools::Shared::Shorewall::ports_by_proto($ports);
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
    ManaTools::Shared::Shorewall::set_in_file('start', $enabled, "INCLUDE /etc/ifw/start", "INCLUDE /etc/ifw/rules", "iptables -I INPUT 1 -j Ifw");
    ManaTools::Shared::Shorewall::set_in_file('stop', $enabled, "iptables -D INPUT -j Ifw", "INCLUDE /etc/ifw/stop");
}

#=============================================================

=head2 choose_watched_services

=head3 INPUT

    $self: this object

    $servers: array of hashes representing servers

=head3 DESCRIPTION

    This method shows the main dialog to let users choose the allowed services

=cut

#=============================================================

sub choose_watched_services {
    my ($self, $servers) = @_;

    my @l = (@{$self->ifw_rules()}, @$servers, map { { ports => $_ } } @{$self->unlisted()});

    my $enabled = 1;
    $_->{ifw} = 1 foreach @l;

    my $retval = $self->ask_WatchedServices({
        title => $self->loc->N("Interactive Firewall"),
        icon => $self->icon(),
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

    return if($retval == 0);

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
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("&About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&OK"));

    my $retval = 0;

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
                last;
            }elsif ($widget == $aboutButton) {
                my $abtdlg = $self->aboutDialog();
                $abtdlg->{name} = $dlg_data->{title};
                $abtdlg->{description} = $self->loc->N("Graphical manager for interactive firewall rules");
                $self->sh_gui->AboutDialog($abtdlg
                );
            }elsif ($widget == $okButton) {
                $retval = 1;
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

=head3 DESCRIPTION

    This method shows the main dialog to let users choose the allowed services

=cut

#=============================================================

sub choose_allowed_services {
    my ($self, $disabled, $servers) = @_;

    $_->{on} = 0 foreach @{$self->all_servers()};
    $_->{on} = 1 foreach @$servers;
    my @l = grep { $_->{on} || !$_->{hide} } @{$self->all_servers()};

    my $dialog_data = {
        title => $self->loc->N("Firewall"),
        icon => $self->icon(),
        # if_(!$::isEmbedded, banner_title => $self->loc->N("Firewall")),
        banner_title => $self->loc->N("Firewall"),
    };

    my $items = [
        { label => $self->loc->N("Which services would you like to allow the Internet to connect to?"), title => 1 },
        if_($self->net()->{PROFILE} && network::network::netprofile_count() > 0, { label => $self->loc->N("Those settings will be saved for the network profile <b>%s</b>", $self->net()->{PROFILE}) }),
        { text => $self->loc->N("Everything (no firewall)"), val => \$disabled, type => 'bool' },
        (map { { text => $_->{name}, val => \$_->{on}, type => 'bool', disabled => sub { $disabled }, id => $_->{id} } } @l),
    ];

    return if(!$self->ask_AllowedServices($dialog_data, $items));

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
            else
            {
                # fake server, the checkbox allowing the user to disable the firewall
                # if Everything checkbox is selected, value = 1 then firewall disabled = 1
                $disabled = ${$server->{value}};
                last;
            }
        }
    }

    return ($disabled, [ grep { $_->{on} } @l ]);
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

    my $evry = undef;

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
            if(!defined($item->{id}))
            {
                $evry = $ckbox;
            }
            if(defined($item->{disabled}))
            {
                $ckbox->setEnabled(!$item->{disabled}->());
            }
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
    my $advButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("A&dvanced"));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("&About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&OK"));

    my $retval = 0;

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
                last;
            }elsif ($widget == $aboutButton) {
                my $abtdlg = $self->aboutDialog();
                $abtdlg->{name} = $dlg_data->{title};
                $abtdlg->{description} = $self->loc->N("Graphical manager for firewall rules");
                $self->sh_gui->AboutDialog($abtdlg);
            }elsif ($widget == $okButton) {
                $retval = 1;
                last;
            }
            elsif ($widget == $advButton) {
                $self->ask_CustomPorts();
            }
            elsif ($widget == $evry) {
                foreach my $wdg_ckbox(@{$self->wdg_servers()})
                {
                    if(defined($wdg_ckbox->{id}))
                    {
                        ${$wdg_ckbox->{widget}}->setEnabled(!${$wdg_ckbox->{widget}}->isEnabled());
                    }
                }
            }
        }
    }

    $self->dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($old_title);

    return $retval;
}

sub ask_CustomPorts {
    my $self = shift();

    my $adv_msg = $self->loc->N("You can enter miscellaneous ports.
Valid examples are: 139/tcp 139/udp 600:610/tcp 600:610/udp.
Have a look at /etc/services for information.");

    my $old_title = yui::YUI::app()->applicationTitle();
    my $win_title = $self->loc->N("Define miscellaneus ports");

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($win_title);

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $advdlg = $factory->createPopupDialog();
    my $layout    = $factory->createVBox($advdlg);

    my $hbox_header = $factory->createHBox($layout);
    my $headLeft = $factory->createHBox($factory->createLeft($hbox_header));
    my $headRight = $factory->createHBox($factory->createRight($hbox_header));

    my $labelAppDescription = $factory->createLabel($headRight,$self->loc->N("Other ports"));
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    my $hbox_content = $factory->createHBox($layout);
    my $vbox_inputs = $factory->createVBox($hbox_content);
    my $labelAdvMessage = $factory->createLabel($factory->createHBox($vbox_inputs), $adv_msg);
    my $txtPortsList = $factory->createInputField($vbox_inputs,'');
    $txtPortsList->setValue(join(' ',@{$self->unlisted()}));
    my $ckbLogFWMessages = $factory->createCheckBox($factory->createHBox($vbox_inputs), $self->loc->N("Log firewall messages in system logs"), $self->log_net_drop());
    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&OK"));

    my $retval = 0;

    # main loop
    while(1) {
        my $event     = $advdlg->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### Buttons and widgets ###
            my $widget = $event->widget();
            if( $widget == $cancelButton )
            {
                $retval = 0;
                last;
            }
            elsif( $widget == $okButton )
            {
                if(scalar(@{$self->unlisted()}) > 0)
                {
                    $self->unlisted([]);
                }
                my $invalid_ports = check_ports_syntax($txtPortsList->value());
                if(ManaTools::Shared::trim($invalid_ports) eq '')
                {
                    if($txtPortsList->value() =~m/\s+/g)
                    {
                        my @unlstd = split(' ', $txtPortsList->value());
                        foreach my $p(@unlstd)
                        {
                            push(@{$self->unlisted()},$p);
                        }
                    }
                    else
                    {
                        if(ManaTools::Shared::trim($txtPortsList->value()) ne '')
                        {
                            push(@{$self->unlisted()}, ManaTools::Shared::trim($txtPortsList->value()));
                        }
                    }
                    $retval = 1;
                }
 				else
                {
 				    $self->sh_gui->warningMsgBox({
                        title=>$self->loc->N("Invalid port given"),
 				        text=> $self->loc->N("Invalid port given: %s.
The proper format is \"port/tcp\" or \"port/udp\",
where port is between 1 and 65535.

You can also give a range of ports (eg: 24300:24350/udp)", $invalid_ports)
                    });
                    $retval = 0;
                }
                last;
            }
        }
    }

    $advdlg->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($old_title);

    return $retval;
}

sub get_zones {
    my $self = shift();
    my $confref = shift();
    my $disabled = shift();
    my $conf = ${$confref};
    my $interfacesfile = ManaTools::Shared::Shorewall::get_config_file('interfaces', $conf->{version} || '');
    network::network::read_net_conf($self->net());
    #- find all interfaces but alias interfaces
    my @all_intf = grep { !/:/ } uniq(keys(%{$self->net()->{ifcfg}}), detect_devices::get_net_interfaces());
    my %net_zone = map { $_ => undef } @all_intf;
    $net_zone{$_} = 1 foreach ManaTools::Shared::Shorewall::get_net_zone_interfaces($interfacesfile, $self->net(), \@all_intf);

    # if firewall/shorewall is not disabled (i.e. everything has been allowed)
    # then ask for network interfaces to protect
    if(!$disabled)
    {
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

    foreach my $net_int(keys %net_zone)
    {
        push (@{$conf->{net_zone}}, $net_int);
    }
    return keys %net_zone;
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
        my $conf = ManaTools::Shared::Shorewall::read_();
        if(!$self->get_zones(\$conf,$disabled))
        {
            # Cancel button has been pressed, aborting
            return 0;
        }
        my $shorewall = (ManaTools::Shared::Shorewall::get_config_file('zones', '') && $conf);
        if (!$shorewall) {
            print ("unable to read shorewall configuration, skipping installation");
            return 0;
        }

        $shorewall->{disabled} = $disabled;
        $shorewall->{ports} = $ports;
        $shorewall->{log_net_drop} = $log_net_drop;

        print ($disabled ? "disabling shorewall" : "configuring shorewall to allow ports: $ports");

        # NOTE: the 2nd param is undef in this case!
        if(!ManaTools::Shared::Shorewall::write_($shorewall))
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
            ManaTools::Shared::Shorewall::write_($shorewall,$action);
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

    my ($disabled, $servers, $log_net_drop) = $self->get_conf(undef) or return;

    # $log_net_drop: network::shorewall log_net_drop attribute
    $self->log_net_drop($log_net_drop);
    undef($log_net_drop);
    ($disabled, $servers) = $self->choose_allowed_services($disabled, @$servers) or return;

    my $system_file = '/etc/sysconfig/drakx-net';
    my %global_settings = getVarsFromSh($system_file);

    if (!$disabled && (!defined($global_settings{IFW}) || text2bool($global_settings{IFW}))) {
        $self->choose_watched_services($servers) or return;
    }

    # preparing services when required ( look at $self->all_servers() )
    foreach (@$servers) {
        exists $_->{prepare} and $_->{prepare}();
    }

    my $ports = $self->to_ports($servers);

    $self->set_ports($disabled, $ports, $self->log_net_drop()) or return;

    # restart mandi
    my $services = ManaTools::Shared::Services->new();
    $services->is_service_running("mandi") and $services->restart("mandi");

    # restarting services if needed
    foreach my $service (@$servers) {
        if ($service->{restart}) {
            $services->is_service_running($_) and $services->restart($_) foreach split(' ', $service->{restart});
        }
    }

    # clearing pending ifw notifications in net_applet
    system('killall -s SIGUSR1 net_applet');

    return ($disabled, $ports);
};

1;
