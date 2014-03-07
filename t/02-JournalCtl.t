#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Shared::JournalCtl' ) || print "JournalCtl failed!\n";
}

ok( my $o = AdminPanel::Shared::JournalCtl->new(), 'create');
ok( my $c = $o->get(), 'gets_log' );

done_testing;
