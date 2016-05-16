#!/usr/bin/perl -w

use strict;

use ManaTools::Shared::disk_backend;
use Data::Dumper;

sub sp {
	my $level = shift;
	return '' if ($level <= 0);
	return "  ". sp($level - 1);
}

sub dumpio {
	my ($db_man, $io, $level) = @_;
	print sp($level) ."- IO(". $io->type() ."): ". $io->label() ."\n";
	# indent
	$level = $level + 1;

	print sp($level) ."Properties:\n" if scalar($io->properties()) > 0;
	for my $key (sort $io->properties()) {
		print sp($level) ."- ". $key ." --> ". $io->prop($key) ."\n";
	}

	# find parts that contain this
	my @parts = $db_man->findin($io);
	print sp($level) ."Parts:\n" if scalar(@parts) > 0;
	for my $part (sort { $a->label() cmp $b->label() } @parts) {
		dumppart($db_man, $part, $level);
	}
}

sub dumppart {
	my ($db_man, $part, $level) = @_;
	print sp($level) ."- PART(". $part->type() ."): (". $part->label() .")\n";
	# indent
	$level = $level + 1;

	print sp($level) ."Properties:\n" if scalar($part->properties()) > 0;
	for my $key (sort $part->properties()) {
		print sp($level) ."- ". $key ." --> ". $part->prop($key) ."\n";
	}

	my @ios = $part->get_outs();
	print sp($level) ."IOs:\n" if scalar(@ios) > 0;
	for my $io (sort { $a->label() cmp $b->label() } @ios) {
		dumpio($db_man, $io, $level);
	}
	print sp($level) ."PartLinks: '". join("','", map { "(". ( defined $_ ? join(",", @{$_->tags()}) : '' ) .")" } @{$part->links()}) ."'\n" if scalar(@{$part->links()}) > 0;
	my @parts = $part->find_parts(undef, 'child');
	print sp($level) ."Child links:\n" if scalar(@parts) > 0;
	for my $p (sort { $a->label() cmp $b->label() } @parts) {
		dumppart($db_man, $p, $level);
	}
	if ($part->type() eq 'Mount') {
		my @parts = $db_man->findpartprop('Mount', 'parent', $part->prop('id'));
		print sp($level) ."Child Mounts:\n" if scalar(@parts) > 0;
		for my $part (sort { $a->label() cmp $b->label() } @parts) {
			dumppart($db_man, $part, $level);
		}
	}
}


my $db_man = ManaTools::Shared::disk_backend->new();

#$db_man->logger->trace(1);

$db_man->probe();

my $mode = 'disks';
if (defined $ARGV[0]) {
	$mode = $ARGV[0];
}

if ($mode eq 'fs') {
	my @parts = $db_man->findpart('Mount');
	for my $part (@parts) {
		my $pm = $part->parentmount();
		dumppart($db_man, $part, 0) if !(defined $pm);
	}
}
else {
	if ($mode eq 'old') {
		my @parts = $db_man->findoutnoin();
		for my $part (@parts) {
			dumppart($db_man, $part, 0);
		}
	}
	else {
		my @parts = $db_man->findnopart(undef, 'parent');
		for my $part (@parts) {
			dumppart($db_man, $part, 0);
		}
	}
}

print "End\n";
