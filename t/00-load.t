#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 2;

BEGIN {
    use_ok( 'ManaTools::Shared' ) || print "ManaTools::Shared failed\n";
    use_ok( 'ManaTools::SettingsReader' ) || print "ManaTools::SettingsReader failed\n";
}

diag( "Testing ManaTools::Shared $ManaTools::Shared::VERSION, Perl $], $^X" );
