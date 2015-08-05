use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

BEGIN {
    use_ok( 'ManaTools::Shared::Logging' ) || print "ManaTools::Shared::Logging failed!\n";
    use_ok( 'ManaTools::Shared::JournalCtl' ) || print "JournalCtl failed!\n";
}

ok ( my $obj = ManaTools::Shared::Logging->new(), 'new_logging');
diag Dumper($obj);
# check I,W,E,D
ok ( $obj->I("test info %d", 1), 'info_logging');
ok ( $obj->W("test warning %d", 2), 'warning_logging');
ok ( $obj->E("test err %d", 3), 'err_logging');
ok ( $obj->D("test debug %d", 4), 'debug_logging');

$obj = undef;
my $o = ManaTools::Shared::JournalCtl->new(this_boot=>1,);
$o->identifier('test_logging');

ok ( $obj = ManaTools::Shared::Logging->new(ident => 'test_logging'), 'new_test_logging');
ok ( $obj->D("test debug %d", 5),   'debug_logging as test_logging');
ok ( $obj->I("test info %d", 6),    'info_logging as test_logging');
ok ( $obj->W("test warning %d", 7), 'warning_logging as test_logging');
ok ( $obj->E("test err %d", 8),     'err_logging as test_logging');
#let's wait journalctl to be updated
sleep 1;
my $c = $o->getLog();
my $str = $c->[-1];
ok($str =~ "test err 8", 'test err found');
$str = $c->[-2];
ok($str =~ "test warning 7", 'test warning found');
$str = $c->[-3];
ok($str =~ "test info 6", 'test info found');
$str = $c->[-4];
ok($str =~ "test debug 5", 'test debug found');

done_testing;
