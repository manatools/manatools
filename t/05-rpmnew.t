use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Rpmdragora::rpmnew' ) || print "AdminPanel::Rpmdragora::rpmnew failed!\n";
}


SKIP: {
    #remember to skip the righ number of tests
    skip "To enable dialog tests set TEST_GUI", 1, unless $ENV{TEST_GUI};

    open (MYFILE, '>/tmp/_rpmnew_test');
        print MYFILE "value = 1\n";
        print MYFILE "value1 = 2\n";
        close (MYFILE);
    open (MYFILE, '>/tmp/_rpmnew_test.rpmnew');
        print MYFILE "value = 2\n";
        print MYFILE "value1 = 1\n";
        close (MYFILE);

    is( AdminPanel::Rpmdragora::rpmnew::rpmnew_dialog("Test rpmnew dialog", (
        test_package  => ["/tmp/_rpmnew_test", "/tmp/rpmnew_test"],
        test_package2 => ["/tmp/tp2"],
    )), 0, 'rpmnew');

}


done_testing;
