#!/usr/bin/perl

# we remove old translations (#~ stuff) because some id's may be shared
# with what's extracted from the compss, and in such case msgfmt will
# not put the translations in the mo :(

use MDK::Common;

my $line_number = 0;
my @contents = cat_($ARGV[0]);

foreach (@contents) {
      $line_number++;
      /^#, fuzzy/ && $contents[$line_number+1] =~ /^#~/ and next;
      /^#~/ and next;
      print;
}
