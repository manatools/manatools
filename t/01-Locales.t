use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::Shared::Locales' ) || print "Locales failed!\n";
}

ok( my $o = ManaTools::Shared::Locales->new({domain_name => 'test_ManaTools_Shared_Locales'}), 'create');
is( $o->N_("test"), 'test', 'N' );

done_testing;
