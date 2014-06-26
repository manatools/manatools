#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Shared::TimeZone' ) || print "AdminPanel::Shared::TimeZone failed!\n";
}

    ok( my $tz = AdminPanel::Shared::TimeZone->new(), 'create');
    is( $tz->get_timezone_prefix(), '/usr/share/zoneinfo', 'get_timezone_prefix' );
    ok (my @l = $tz->getTimeZones(), 'getTimeZones');
    ok (my $h = $tz->readConfiguration(), 'readConfiguration');
    ok (my $s = $tz->ntpCurrentServer(), 'currentNTPServer');
    diag "ntpCurrentServer got: < " . ($s ? $s : "none") . " >";
    ok (my $a = ($tz->isNTPRunning() ? "not running" : "running"), 'isNTPRunning');
    diag "isNTPRunning got: < " . $a . " >";

done_testing;
