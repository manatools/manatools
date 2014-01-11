package AdminPanel::Hosts::hosts; 

use Modern::Perl 2011;
use autodie;
use diagnostics;
use local::lib;
use Config::Hosts;
use utf8;

# costants by Config::Hosts
my $is_ip = 1;
my $is_host = -1;
my $is_none = 0;


=pod

=head2 _getHosts

=head3 OUTPUT

    @result: array of hashes; each one of them represent a host definition from the hosts configuration file
    
    NOTE: the 'hosts' item into each hash is an array: it contains the hostname and -eventually- the aliases

=head3 DESCRIPTION

retrieve data from the hosts file (/etc/hosts) using the Config::Hosts module

=cut

sub _getHosts {
	my $configHosts = Config::Hosts->new();
	my $hosts = $configHosts->read_hosts();
	my @result = ();
	while( my ($key, $value) = each($hosts)){
		if($configHosts->determine_ip_or_host($key) == $is_ip){
			my $tmp = {};
			$tmp = $configHosts->query_host($key);
			$tmp->{'ip'} = $key;
			push @result,$tmp; 
		}
	}
	return @result;
}

1;
