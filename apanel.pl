#!/usr/bin/perl

#    Copyright 2012 Steven Tucker
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

use strict;
use warnings;
use diagnostics;
use FindBin;
use lib "$FindBin::RealBin";
use Getopt::Long;
use Auth;
use MainDisplay;
use yui;

my $help=0;

my $result = GetOptions ("help" => \$help);

usage() if($help);

ask_for_authentication() if(require_root_capability());

my $mainWin = new MainDisplay();
my $launch = $mainWin->start();

while($launch)
{
    $mainWin->destroy();
    undef($mainWin);

    my $err = yui::YUI::app()->runInTerminal("$launch --ncurses");
    if ($err == -1)
    {
        system($launch);
    }

    $mainWin = new MainDisplay();
    $launch = $mainWin->start();
}

$mainWin->destroy();
undef($mainWin);

sub usage {
	print "\n";
	print "Usage apanel [options...]\n\n";
	print "Options:\n";
	print "\t--help | -h        print this help\n";
	print "\t--name string      specify the window title of the administration panel\n";
	print "\t--conf_dir path    specify the settings.conf file directory\n";
	print "\n";
	exit(0);
}

=pod

=head1 main
       
       main launcher

=cut
