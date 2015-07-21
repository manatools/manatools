use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Time::Piece;

BEGIN {
    use_ok( 'ManaTools::Shared::Services' ) || print "ManaTools::Shared::Services failed!\n";
}

    ok(my $s = ManaTools::Shared::Services->new(), 'create ManaTools::Shared::Services');
    is ($s->include_static_services(), 0, 'include_static_services (false)');
    ok(my $services = $s->service_info(), 'service_info');
    diag "*** Services ***\n" . join (', ', keys %$services);

    # Get static services also
    ok($s = ManaTools::Shared::Services->new(include_static_services => 1), 'create ManaTools::Shared::Services with static services');
    is ($s->include_static_services(), 1, 'include_static_services (true)');
    ok($services = $s->service_info(), 'service_info  with static services');
    diag "*** Static services ***\n" . join (', ', keys %$services);

done_testing;
