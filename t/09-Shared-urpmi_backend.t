use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

BEGIN {
    use_ok( 'ManaTools::Shared::urpmi_backend::DB' ) || print "ManaTools::Shared::urpmi_backend::DB failed!\n";
}

ok ( my $obj = ManaTools::Shared::urpmi_backend::DB->new(), 'new');
is ( ref($obj->open_rpm_db()), 'URPM::DB', 'open_rpm_db');
my $urpm = $obj->open_urpmi_db();
is ( ref($urpm), 'urpm', 'open_urpmi_db');
is ( $obj->lock($urpm), 0, 'lock(already locked)');
undef ($urpm->{lock});
$urpm = $obj->fast_open_urpmi_db();
is ( ref($urpm), 'urpm', 'fast_open_urpmi_db');
is ( $obj->lock($urpm), 1, 'lock(locked)');
is ( $obj->unlock($urpm), undef, 'unlock');


ok ( my $resp = ($obj->is_it_a_devel_distro() ? 'yes' : 'no'), 'is_it_a_devel_distro');
diag "\tis_it_a_devel_distro? < " . $resp . " >";
ok ( $resp = $obj->get_backport_media($urpm), 'get_backport_media');
diag "\tfound < " . $resp . " > backport media";
ok ( $resp = $obj->get_inactive_backport_media($urpm), 'get_inactive_backport_media');
diag "\tfound < " . $resp . " > inactive backport media";
ok ( $resp = $obj->get_update_medias($urpm), 'get_update_medias');
diag "\tfound < " . $resp . " > update media";

done_testing;
