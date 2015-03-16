use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;
use Time::Piece;

BEGIN {
    use_ok( 'ManaTools::Shared::TimeZone' ) || print "ManaTools::Shared::TimeZone failed!\n";
}

    ok( my $tz = ManaTools::Shared::TimeZone->new(), 'create');
    is( $tz->get_timezone_prefix(), '/usr/share/zoneinfo', 'get_timezone_prefix' );
    ok (my @l = $tz->getTimeZones(), 'getTimeZones');
    ok (my $h = $tz->readConfiguration(), 'readConfiguration');
    diag Dumper($h);
    ok (my $s = $tz->ntpCurrentServer(), 'currentNTPServer');
    diag "ntpCurrentServer got: < " . ($s ? $s : "none") . " >";
    ok (my $a = ($tz->isNTPRunning() ? "running" : "not running"), 'isNTPRunning');
    diag "isNTPRunning got: < " . $a . " >";

    SKIP: {
        #remember to skip the right number of tests
        skip "To enable dialog tests set TEST_SET_DBUS", 3, unless $ENV{TEST_SET_DBUS};
        eval {$tz->setLocalRTC(!$h->{UTC})};
        is ($@, "", 'setLocalRTC' );
        eval {$tz->setTimeZone($h->{ZONE})};
        is ($@, "", 'setTimeZone');
        my $t = localtime;
        eval {$tz->setTime($t->epoch())};
        is ($@, "", 'setTime');
    }
done_testing;
