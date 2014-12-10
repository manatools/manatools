use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Shared::Locales' ) || print "Locales failed!\n";
}

ok( my $o = AdminPanel::Shared::Locales->new({domain_name => 'test_AdminPanel_Shared_Locales'}), 'create');
is( $o->N_("test"), 'test', 'N' );

done_testing;
