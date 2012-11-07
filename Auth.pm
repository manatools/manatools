# vim: set et ts=4 sw=4:
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
use base qw(Exporter);
use strict;
use warnings;
use diagnostics;
use Data::Dumper;

our @EXPORT = qw(require_root_capability
         ask_for_authentication);

sub require_root_capability {
    return 0 if(!$>);
    return 1;
}

sub ask_for_authentication {
    my ($command, @args) = wrap_command($0, @ARGV);
    unshift(@args,$command->[1]);
    exec { $command->[0] } $command->[1], @args or die ("command %s missing", $command->[0]);
}

sub wrap_command {
    my $wrapper = "pkexec";
    my ($app, @args) = @_;
    return ([$wrapper, $app], @args);
}
