use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

BEGIN {
    use_ok( 'ManaTools::Shared::Logging' ) || print "ManaTools::Shared::Logging failed!\n";
}

ok ( my $obj = ManaTools::Shared::Logging->new(), 'new_logging');
diag Dumper($obj);
# check I,W,E,D
ok ( $obj->I("test info %d", 1), 'info_logging');
ok ( $obj->W("test warning %d", 2), 'warning_logging');
ok ( $obj->E("test err %d", 3), 'err_logging');
ok ( $obj->D("test debug %d", 4), 'debug_logging');

done_testing;
