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
    ok (my $services = $tz->ntpServiceList(), 'ntpServiceList');
    diag Dumper($services);
    ok ($tz->refreshNTPServiceList(), 'refreshNTPServiceList');
    ok ($services = $tz->ntpServiceList(), 'ntpServiceList after refresh');
    diag Dumper($services);
    ok (my $currService = $tz->ntp_program(), 'ntp_program');
    diag "ntp_program got: < " . $currService . " >";
    ok (my $a = ($tz->isNTPRunning() ? "running" : "not running"), 'isNTPRunning');
    diag "Check if " . $currService . " is running got: < " . $a . " >";
    ok (my @s = $tz->ntpCurrentServers(), 'currentNTPServers');
    diag "ntpCurrentServers got: < " . join(',', @s) . " >";
    ok (my @pairs = $tz->ntpServiceConfigPairs(), 'ntpServiceConfigPairs');
    diag Dumper(@pairs);
    for my $pair (@pairs) {
        is ($tz->getNTPServiceConfig($pair->[0]), $pair->[1], "ntpServiceConfigPairs $pair->[0]");
    }

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
