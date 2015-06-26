use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::rpmdragora' ) || print "ManaTools::rpmdragora failed!\n";
    use_ok( 'ManaTools::Rpmdragora::DB' ) || print "ManaTools::Rpmdragora::DB failed!\n";
}

ok ( my $obj = ManaTools::Rpmdragora::DB->new(), 'db_new');
is ( ref($obj->open_rpm_db()), 'URPM::DB', 'open_rpm_db');
is ( ref($obj->fast_open_urpmi_db()), 'urpm', 'fast_open_urpmi_db');
is ( ref($obj->open_urpmi_db()), 'urpm', 'open_urpmi_db');

SKIP: {
    #remember to skip the righ number of tests
    skip "To enable dialog tests set TEST_GUI", 1, unless $ENV{TEST_GUI};

    ok( interactive_msg( "Interactive msg title",
                    join(
                        "\n\n",
                        "text line 1",
                        "text line 2",
                        "text line 3",
                         "set yesno => 1 to have a yesno dialog otherwhise just ok button is shown",
                        "press ok to continue"),
                     scroll => 1,
                     min_size => {lines => 18,}
        ),
        'interactive_msg',
    );
}


done_testing;
