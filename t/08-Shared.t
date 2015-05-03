use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'ManaTools::Shared' ) || print "ManaTools::Shared failed!\n";
}

ok ( ManaTools::Shared::command_line(), 'command_line');
is ( ManaTools::Shared::custom_locale_dir(), undef, 'custom_locale_dir');
is ( ManaTools::Shared::devel_mode(), 0, 'devel_mode');
is ( ManaTools::Shared::help_requested(), 0, 'help_requested');

done_testing;
