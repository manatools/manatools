use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::Shared::Locales' ) || print "Locales failed!\n";
}

ok( my $o = ManaTools::Shared::Locales->new({domain_name => 'manatools'}), 'create');
is( $o->N_("test"), 'test', 'N_' );
ok(my $cr = $o->N("Copyright (C) %s Mageia community", '2012-2016'), 'N');
diag "Copyright string is: < " . ($cr ? $cr : "none") . " >";

done_testing;
