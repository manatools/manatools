#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'AdminPanel::Shared' ) || print "AdminPanel::Shared failed\n";
    use_ok( 'AdminPanel::SettingsReader' ) || print "AdminPanel::SettingsReader failed\n";
}

diag( "Testing AdminPanel::Shared $AdminPanel::Shared::VERSION, Perl $], $^X" );
