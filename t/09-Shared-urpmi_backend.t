use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;
use URPM;

BEGIN {
    use_ok( 'ManaTools::Shared::urpmi_backend::DB' ) || print "ManaTools::Shared::urpmi_backend::DB failed!\n";
    use_ok( 'ManaTools::Shared::urpmi_backend::tools' ) || print "ManaTools::Shared::urpmi_backend::tools failed!\n";
}

diag "******* ManaTools::Shared::urpmi_backend::DB *******";

ok ( my $obj = ManaTools::Shared::urpmi_backend::DB->new(), 'new_DB');
is ( ref($obj->open_rpm_db()), 'URPM::DB', 'open_rpm_db');
my $urpm = $obj->open_urpmi_db();
is ( ref($urpm), 'urpm', 'open_urpmi_db');
is ( $obj->lock($urpm), 0, 'lock(already locked)');
undef ($urpm->{lock});
$urpm = $obj->fast_open_urpmi_db();
is ( ref($urpm), 'urpm', 'fast_open_urpmi_db');
is ( $obj->lock($urpm), 1, 'lock(locked)');
is ( $obj->unlock($urpm), undef, 'unlock');

diag "******* ManaTools::Shared::urpmi_backend::tools *******";

ok ( my $tool = ManaTools::Shared::urpmi_backend::tools->new(), 'new_tools');
is ( ref($tool->urpmi_db_backend()), 'ManaTools::Shared::urpmi_backend::DB', 'urpmi_db_backend');
ok (my $resp = $tool->get_update_medias($urpm), 'get_update_medias from tools');
diag "\tfound < " . $resp . " > backport media";
ok ( $tool->is_package_installed('rpm'), 'is_package_installed(rpm)');
ok ( my $fullname = $tool->find_installed_fullname('urpmi'), 'find_installed_fullname');
diag "\turpmi installed package is < " . $fullname . " > ";
ok ( $resp = ($tool->is_mageia() ? "yes" : "no"), 'is_mageia');
diag "\tIs the system mageia? < " . $resp . " > ";
ok ( $resp = $tool->vendor(), 'vendor' );
diag "\tThe vendor is < " . $resp . " > ";

$urpm = $obj->open_urpmi_db();

ok ( $resp = $tool->fullname_to_package_id($fullname), 'fullname_to_package_id' );
ok ( my $pkg = $tool->get_package_by_package_id($urpm, $resp), 'get_package_by_package_id' );
is ($fullname, $pkg->fullname, 'fullname eq pkg->fullname' );
ok ( $resp = $tool->pkg2medium($pkg, $urpm), 'pkg2medium' );
diag "\tThe medium is < " . $resp->{name} . " > ";
ok ( $resp = $tool->get_installed_fullname_pkid($pkg), 'get_installed_fullname' );
diag "\tThe package_id is < " . $resp . " > ";


ok ( $resp = ($obj->is_it_a_devel_distro() ? 'yes' : 'no'), 'is_it_a_devel_distro');
diag "\tis_it_a_devel_distro? < " . $resp . " >";
ok ( $resp = $obj->get_backport_media($urpm) || 'none', 'get_backport_media');
diag "\tfound < " . $resp . " > backport media";
ok ( $resp = $obj->get_inactive_backport_media($urpm) || 'none', 'get_inactive_backport_media');
diag "\tfound < " . $resp . " > inactive backport media";
ok ( $resp = $obj->get_update_medias($urpm) || 'none', 'get_update_medias');
diag "\tfound < " . $resp . " > update media";



done_testing;
