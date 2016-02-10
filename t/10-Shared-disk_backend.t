use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Data::Dumper;

BEGIN {
    use_ok( 'ManaTools::Shared::disk_backend' ) || print "ManaTools::Shared::disk_backend failed!\n";
}

ok ( my $obj = ManaTools::Shared::disk_backend->new(), 'new_disk_backend');
diag Dumper($obj);
# check  load / probe / save
ok ( $obj->load(), 'load_disk_backend');
diag Dumper($obj);
ok ( $obj->probe(), 'probe_disk_backend');
diag Dumper($obj);
ok ( $obj->save(), 'save_disk_backend');
diag Dumper($obj);
# check find* functions too
ok ( my @parts = $obj->findnoin(), 'no_in_disk_backend');
diag Dumper(@parts);
my @ios = ();
if (scalar(@parts) > 0) {
	ok ( my @ios = $parts[0]->out_list(), 'ios_no_out_disk_backend');
}
diag Dumper(@ios);
ok ( @parts = $obj->findnoout(), 'no_out_disk_backend');
diag Dumper(@parts);
@ios = ();
if (scalar(@parts) > 0) {
	ok ( @ios = $parts[0]->in_list(), 'ios_no_in_disk_backend');
}
diag Dumper(@ios);
ok ( @parts = $obj->findpart('Disk'), 'find_part_disk_backend');
diag Dumper(@parts);
ok ( @ios = $obj->findioprop('dev', '8:0'), 'find_io_via_prop_disk_backend');
diag Dumper(@ios);


done_testing;
