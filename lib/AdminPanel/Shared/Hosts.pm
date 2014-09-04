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
package AdminPanel::Shared::Hosts; 

use Moose;
use diagnostics;
use Config::Hosts;
use utf8;

# costants by Config::Hosts
my $is_ip = 1;
my $is_host = -1;
my $is_none = 0;

has 'configHosts' => (
	is => 'rw',
	init_arg => undef,
	builder => '_initialize'
);

sub _initialize {
	my $self = shift();
	$self->configHosts(Config::Hosts->new());
}

=pod

=head2 _getHosts

=head3 OUTPUT

    @result: array of hashes; each one of them represent a host definition from the hosts configuration file
    
    NOTE: the 'hosts' item into each hash is an array: it contains the hostname and -eventually- the aliases

=head3 DESCRIPTION

retrieve data from the hosts file (/etc/hosts) using the Config::Hosts module

=cut

sub _getHosts {
	my $self = shift();
	# $self->configHosts(Config::Hosts->new());
	my $hosts = $self->configHosts->read_hosts();
	my @result = ();
	while( my ($key, $value) = each(%{$hosts})){
		if($self->configHosts->determine_ip_or_host($key) == $is_ip){
			my $tmp = {};
			$tmp = $self->configHosts->query_host($key);
			$tmp->{'ip'} = $key;
			push @result,$tmp; 
		}
	}
	return @result;
}

sub _insertHost {
	my $self = shift();
	# remember that the order matters!
	my $ip = shift();
	my @host_definitions = @_;
	# $self->configHosts = Config::Hosts->new();
	return $self->configHosts->insert_host(ip => $ip, hosts => @host_definitions);
}

sub _dropHost {
	my $self = shift();
	my $host_ip = shift();
	return $self->configHosts->delete_host($host_ip);
}

sub _modifyHost {
    my $self = shift();
    my $host_ip = shift();
    my @host_definitions = @_;
    return $self->configHosts->update_host($host_ip, hosts => @host_definitions);
}

sub _writeHosts {
	my $self = shift();
	return $self->configHosts->write_hosts();
}

1;
