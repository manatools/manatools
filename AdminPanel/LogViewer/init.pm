package AdminPanel::LogViewer::init;

use strict;
use warnings;
use diagnostics;
use English;
use lib qw(/usr/lib/libDrakX);
use common;
use AdminPanel::Shared;
use base qw(Exporter);

our @EXPORT = qw(warn_about_user_mode
		interactive_msg);

sub interactive_msg {
	my ($title, $contents) = @_;
	return ask_YesOrNo($title, $contents);
}

sub warn_about_user_mode() {
	my $title = N("Running in user mode");
	my $msg = N("You are launching this program as a normal user.\n".
		    "You will not be able to read system logs which you do not have rights to,\n".
		    "but you may still browse all the others.");
	if(($EUID != 0) and (!interactive_msg($title, $msg))) {
		return 0;
	}
	return 1;
}

1;
