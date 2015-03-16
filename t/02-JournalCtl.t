use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::Shared::JournalCtl' ) || print "JournalCtl failed!\n";
}

    ok( my $o = ManaTools::Shared::JournalCtl->new(this_boot=>1,), 'create');
    ok( my $c = $o->getLog(), 'gets_log' );

done_testing;
