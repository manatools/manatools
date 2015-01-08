package AdminPanel::Shared::Shorewall; # $Id: shorewall.pm 254244 2009-03-18 22:54:32Z eugeni $

use lib qw(/usr/lib/libDrakX);   # helps perl_checker
use detect_devices;
use network::network;
use AdminPanel::Shared::RunProgram;
use MDK::Common::Func qw(if_ partition);
use MDK::Common::File qw(cat_);
use List::Util qw(any);
use List::MoreUtils qw(uniq);
use log;

my $shorewall_root = "/etc/shorewall";
our $firewall_icon = $::isInstall ? 'banner-security' : '/usr/share/mcc/themes/default/firewall-mdk.png';

sub check_iptables() {
    -f "$::prefix/etc/sysconfig/iptables" ||
    $::isStandalone && do {
	system('modprobe iptable_nat');
	-x '/sbin/iptables' && listlength(`/sbin/iptables -t nat -nL`) > 8;
    };
}

sub set_config_file {
    my ($file, $ver, @l) = @_;

    my $done;
    substInFile {
	my $last_line = /^#LAST LINE/ && $_;
	if (!$done && ($last_line || eof)) {
	    $_ = join('', map { join("\t", @$_) . "\n" } @l);
	    $_ .= $last_line if $last_line;
	    $done = 1;
	} else {
	    $_ = '' unless
	      /^#/ || $file eq 'rules' && /^SECTION/;
	}
    } "$::prefix${shorewall_root}${ver}/$file";
}

sub get_config_file {
    my ($file, $o_ver) = @_;
    map { [ split ' ' ] } grep { !/^#/ } cat_("$::prefix${shorewall_root}${o_ver}/$file");
}

# Note: Called from drakguard and drakfirewall.pm...
# Deliberately not adding shorewall6 support here for now
sub set_in_file {
    my ($file, $enabled, @list) = @_;
    my $done;
    substInFile {
	my $last_line = /^#LAST LINE/ && $_;
	foreach my $l (@list) { s|^$l\n|| }
	if (!$done && $enabled && ($last_line || eof)) {
	    $_ = join('', map { "$_\n" } @list);
	    $_ .= $last_line if $last_line;
	    $done = 1;
	}
    } "$::prefix${shorewall_root}/$file";
}

sub dev_to_shorewall {
    my ($dev) = @_;
    $dev =~ /^ippp/ && "ippp+" ||
    $dev =~ /^ppp/ && "ppp+" ||
    $dev;
}

sub get_net_zone_interfaces {
    my ($interfacesfile, $_net, $all_intf) = @_;
    #- read shorewall configuration first
    my @interfaces = map { $_->[1] } grep { $_->[0] eq 'net' } $interfacesfile;
    #- else try to find the best interface available
    @interfaces ? @interfaces : @{$all_intf || []};
}

sub add_interface_to_net_zone {
    my ($conf, $interface) = @_;
    if (!member($interface, @{$conf->{net_zone}})) {
        push @{$conf->{net_zone}}, $interface;
        @{$conf->{loc_zone}} = grep { $_ ne $interface } @{$conf->{loc_zone}};
    }
}

sub read_ {
    my ($o_ver) = @_;
    my $ver = '';
    $ver = $o_ver if $o_ver;
    #- read old rules file if config is not moved to rules.drakx yet
    my @rules = get_config_file(-f "$::prefix${shorewall_root}${ver}/rules.drakx" ? 'rules.drakx' : 'rules', $ver);
    require services;
    my %conf = (disabled => !services::starts_on_boot("shorewall${ver}"),
                version => $ver,
                ports => join(' ', map {
                    my $e = $_;
                    map { "$_/$e->[3]" } split(',', $e->[4]);
                } grep { $_->[0] eq 'ACCEPT' && $_->[1] eq 'net' } @rules),
               );
    push @{$conf{accept_local_users}{$_->[4]}}, $_->[8] foreach grep { $_->[0] eq 'ACCEPT+' } @rules;
    $conf{redirects}{$_->[3]}{$_->[4]} = $_->[2] foreach grep { $_->[0] eq 'REDIRECT' } @rules;

    if (my ($e) = get_config_file('masq', $ver)) {
	($conf{masq}{net_interface}, $conf{masq}{subnet}) = @$e;
    }

    my @policy = get_config_file('policy', $ver);
    $conf{log_net_drop} = @policy ? (any { $_->[0] eq 'net' && $_->[1] eq 'all' && $_->[2] eq 'DROP' && $_->[3] } @policy) : 1;

    return \%conf;
    
    # get_zones(\%conf);
    # get_config_file('zones', $ver) && \%conf;
}

sub ports_by_proto {
    my ($ports) = @_;
    my %ports_by_proto;
    foreach (split ' ', $ports) {
	m!^(\d+(?::\d+)?)/(udp|tcp|icmp)$! or die "bad port $_\n";
	push @{$ports_by_proto{$2}}, $1;
    }
    \%ports_by_proto;
}

sub write {
    my ($conf, $o_in) = @_;
    my $ver = $conf->{version} || '';
    my $use_pptp = any { /^ppp/ && cat_("$::prefix/etc/ppp/peers/$_") =~ /pptp/ } @{$conf->{net_zone}};
    my $ports_by_proto = ports_by_proto($conf->{ports});
    my $has_loc_zone = to_bool(@{$conf->{loc_zone} || []});

    my ($include_drakx, $other_rules) = partition { $_ eq "INCLUDE\trules.drakx\n" } grep { !/^(#|SECTION)/ } cat_("$::prefix${shorewall_root}${ver}/rules");
    #- warn if the config is already in rules.drakx and additionnal rules are configured
    if (!is_empty_array_ref($include_drakx) && !is_empty_array_ref($other_rules)) {
        my %actions = (
            keep => N("Keep custom rules"),
            drop => N("Drop custom rules"),
        );
        my $action = 'keep';
        !$o_in || $o_in->ask_from_(
            {
                messages => N("Your firewall configuration has been manually edited and contains
rules that may conflict with the configuration that has just been set up.
What do you want to do?"),
                title => N("Firewall"),
                icon => 'banner-security',
            },
            [ { val => \$action, type => 'list', list => [ 'keep', 'drop' ], format => sub { $actions{$_[0]} } } ]) or return;
        #- reset the rules files if the user has chosen to drop modifications
        undef $include_drakx if $action eq 'drop';
    }

    my $interface_settings = sub {
        my ($zone, $interface) = @_;
        [ $zone, $interface, 'detect', if_(detect_devices::is_bridge_interface($interface), 'bridge') ];
    };

    set_config_file('zones', $ver,
                    if_($has_loc_zone, [ 'loc', 'ipv' . ($ver || '4') ]),
                    [ 'net', 'ipv' . ($ver || '4') ],
                    [ 'fw', 'firewall' ],
                );
    set_config_file('interfaces',  $ver,
                    (map { $interface_settings->('net', $_) } @{$conf->{net_zone}}),
                    (map { $interface_settings->('loc', $_) } @{$conf->{loc_zone} || []}),
                );
    set_config_file('policy', $ver,
                    if_($has_loc_zone, [ 'loc', 'net', 'ACCEPT' ], [ 'loc', 'fw', 'ACCEPT' ], [ 'fw', 'loc', 'ACCEPT' ]),
                    [ 'fw', 'net', 'ACCEPT' ],
                    [ 'net', 'all', 'DROP', if_($conf->{log_net_drop}, 'info') ],
                    [ 'all', 'all', 'REJECT', 'info' ],
                );
    if (is_empty_array_ref($include_drakx)) {
        #- make sure the rules.drakx config is read, erasing user modifications
        set_config_file('rules', $ver, [ 'INCLUDE', 'rules.drakx' ]);
    }
    output_with_perm("$::prefix${shorewall_root}${ver}/" . 'rules.drakx', 0600, map { join("\t", @$_) . "\n" } (
        if_($use_pptp, [ 'ACCEPT', 'fw', 'loc:10.0.0.138', 'tcp', '1723' ]),
        if_($use_pptp, [ 'ACCEPT', 'fw', 'loc:10.0.0.138', 'gre' ]),
        (map_each { [ 'ACCEPT', 'net', 'fw', $::a, join(',', @$::b), '-' ] } %$ports_by_proto),
        (map_each {
            if_($::b, map { [ 'ACCEPT+', 'fw', 'net', 'tcp', $::a, '-', '-', '-', $_ ] } @$::b);
        } %{$conf->{accept_local_users}}),
        (map {
            my $proto = $_;
            #- WARNING: won't redirect ports from the firewall system if a local zone exists
            #- set redirect_fw_only to workaround
            map_each {
                map { [ 'REDIRECT', $_, $::b, $proto, $::a, '-' ] } 'fw', if_($has_loc_zone, 'loc');
            } %{$conf->{redirects}{$proto}};
        } keys %{$conf->{redirects}}),
    ));
    set_config_file('masq', $ver, if_(exists $conf->{masq}, [ $conf->{masq}{net_interface}, $conf->{masq}{subnet} ]));

    require services;
    if ($conf->{disabled}) {
        services::disable('shorewall', $::isInstall);
        run_program::rooted($::prefix, '/sbin/shorewall', 'clear') unless $::isInstall;
    } else {
        services::enable('shorewall', $::isInstall);
    }
}

sub set_redirected_ports {
    my ($conf, $proto, $dest, @ports) = @_;
    if (@ports) {
        $conf->{redirects}{$proto}{$_} = $dest foreach @ports;
    } else {
        my $r = $conf->{redirects}{$proto};
        @ports = grep { $r->{$_} eq $dest } keys %$r;
        delete $r->{$_} foreach @ports;
    }
}

sub update_interfaces_list {
    my ($o_intf) = @_;
    if (!$o_intf || !member($o_intf, map { $_->[1] } get_config_file('interfaces'))) {
        my $shorewall = network::shorewall::read();
        $shorewall && !$shorewall->{disabled} and network::shorewall::write($shorewall);
    }
    if (!$o_intf || !member($o_intf, map { $_->[1] } get_config_file('interfaces', 6))) {
        my $shorewall6 = network::shorewall::read(undef, 6);
        $shorewall6 && !$shorewall6->{disabled} and network::shorewall::write($shorewall6);
    }
}

1;
