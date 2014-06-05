# vim: set et ts=4 sw=4:
#    Copyright 2012-2013 Matteo Pasotti
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

package AdminPanel::Privileges;

use strict;
use warnings;
use diagnostics;
require Exporter;
use base qw(Exporter);
use English qw(-no_match_vars);

our @EXPORT = qw(require_root_capability
         ask_for_authentication);

my $wrappers = { "sudo" => "/usr/bin/sudo",
                 "pkit" => "/usr/bin/pkexec",
                 "chlp" => "/usr/bin/consolehelper"
               };

my $wrapper = 0;

sub require_root_capability {
    return $EUID != 0;
}

sub ask_for_authentication {
    my $wrapper_id = shift;
    $wrapper = $wrappers->{$wrapper_id} if(defined($wrappers->{$wrapper_id}));
    my ($command, @args) = wrap_command($0, @ARGV);
    unshift(@args,$command->[1]);
    unshift(@args, '-n') if($wrapper_id eq "sudo"); # let sudo die if password is needed
    exec { $command->[0] } $command->[1], @args or die ("command %s missing", $command->[0]);
}

sub wrap_command {
    my ($app, @args) = @_;
    return ([$wrapper, $app], @args);
}

sub get_wrapper {
    my $id = shift;
    return $wrappers->{$id} if(defined($wrappers->{$id}));
}

1;
