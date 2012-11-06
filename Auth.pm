#    Copyright 2012 Matteo Pasotti
#
#    This file is part of AdminPanel
#
#    AdminPanel is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    AdminPanel is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.

package Auth;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(require_root_capability
	     ask_for_authentication);

use strict;
use warnings;
use diagnostics;
use Data::Dumper;


sub require_root_capability {
	return 0 if(!$>);
	return 1;
}

sub ask_for_authentication {
	my @args = @ARGV;
	my $command = wrap_command($0);
	unshift(@args, $command->[2]);
	exec { $command->[0] } $command->[1], @args or die ("command %s missing", $command->[0]);
	die "You must be root to run this program" if $>;
}

sub wrap_command {
	my $currenv = "env";
	my $wrapper = "pkexec";
	my $app = $0;
	my $command = [$wrapper, $currenv, $app];
	($command);
}
