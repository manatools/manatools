use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

BEGIN {
    use_ok( 'AdminPanel::Shared::Users' ) || print "Users failed!\n";
}

    ok( my $o = AdminPanel::Shared::Users->new({user_face_dir => '/tmp'}), 'create');
    ok( my $facedir = $o->facedir(), 'facedir' );
    diag "facedir got: < " . $facedir . " >";
    ok( my $userfacedir = $o->userfacedir(), 'userfacedir' );
    diag "userfacedir got: < " . $userfacedir . " >";
    ok( my $ipathname = $o->face2png('username'), 'face2png' );
    diag "face2png for user \'username\' got: < " . $ipathname . " >";
    ok( my $facenames = $o->facenames(), 'facenames' );
    diag "facenames got: < " . scalar(@$facenames) . " elements >";
    ok( $o->addKdmIcon('username', $facenames->[0]), 'addKdmIcon' );

    ok( my ($val, $str) = $o->valid_username('username'), 'valid_username' );
    diag "valid_username(username) got: < " . $str . " >";
    ok(($val, $str) = $o->valid_username('3D-user'), 'not_valid_username');
    diag "valid_username(3D-user) got: < " . $str . " >";
    ok( ($val, $str) = $o->valid_groupname('groupname'), 'valid_groupname' );
    diag "valid_groupname(groupname) got: < " . $str . " >";
    ok(($val, $str) = $o->valid_groupname('g1234567890123456'), 'not_valid_groupname');
    diag "valid_groupname(g1234567890123456) got: < " . $str . " >";
    ok( my $face = $o->GetFaceIcon('username', 1), 'GetFaceIcon' );
    diag "GetFaceIcon after '" . $facenames->[0] . "' got: < ". $face ." >";
    ok( $o->strongPassword('S0meWh3r3'), 'strongPassword' );

    ok( $o->removeKdmIcon('username'), 'removeKdmIcon' );


done_testing;
