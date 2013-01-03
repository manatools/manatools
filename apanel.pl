#!/usr/bin/perl
# vim: set et ts=4 sw=4:
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
use AdminPanel::Privileges;
use FindBin;
use lib "$FindBin::RealBin";
use MainDisplay;
use yui;

my $cmdline = new yui::YCommandLine;

usage() if($cmdline->find("--help") > 0 || $cmdline->find("-h") > 0);

ask_for_authentication() if(require_root_capability());

my $mainWin = new MainDisplay();
my $launch = $mainWin->start();

while ($launch) {
    $mainWin->destroy();
    undef($mainWin);

    my $err = yui::YUI::app()->runInTerminal("$launch --ncurses");
    if ($err == -1) {
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
## anaselli: --name now is used only to add a path to /etc (e.g. --name mcc2 means /etc/mcc2)
    #          and it is overriden by --conf_dir, so it should be discussed better to understand
    #          if it is really needed any more. 
    #          Window title is got from settings.conf (key title)
    print "\t--name string      specify the window title of the administration panel\n";
    print "\t--conf_dir path    specify the settings.conf file directory\n";
    print "\n";
    exit(0);
}

=pod

=head1 main
       
       main launcher

=cut
