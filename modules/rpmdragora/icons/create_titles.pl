#!/usr/bin/perl

# For faster multiple execs, start a gimp, and do Xtns/Perl/Server.
# Warning! Error message are the worst ever. Unquote the "set_trace" if you need troubleshooting.

use Gimp qw(:consts main xlfd_size :auto);
use MDK::Common;

Gimp::init();
#Gimp::set_trace(TRACE_ALL);

$| = 1;

sub create_file {
    my ($backimg, $fontname, $text, $outfile) = @_;
    my $img = gimp_file_load($backimg, $backimg);
    gimp_palette_set_foreground([255, 255, 255]);
    my $layer = gimp_text_fontname($img, -1, 0, 10, $text, 0, 1, 250, 1, $fontname);
    my $width = gimp_drawable_width($layer);
    gimp_image_merge_visible_layers($img, 0);
    gimp_crop($img, $width, 40, 0, 0);
    gimp_file_save($img, gimp_image_active_drawable($img), $outfile, $outfile);
}

my $wd = chomp_(`pwd`);

my $font = 'SOME NICE FONT';
my %meuh = (install => 'Software Packages Installation', remove => 'Software Packages Removal', update => 'Mandrake Update');

mkdir "title/en";
create_file("$wd/title-back.png", $font, $meuh{$_}, "$wd/title/en/title-$_.png") foreach keys %meuh;

foreach my $po (glob('../po/*.po')) {
    my ($poname) = $po =~ m|/([^/\.]+)\.po$|;
    print "[$poname] ";
    my $charset;
    my @lines = cat_($po);
    foreach (@lines) {
	/^"Content-Type: .*; charset=(.*)/ and $charset = $1;
    }
    if ($charset =~ /^(iso-8859-15?)|(utf-8)/i) {
	foreach my $k (keys %meuh) {
	    my $str = $meuh{$k};
	    my $i18n;
	    each_index { /^msgid "\Q$str/ && ($lines[$::i-1] !~ /fuzzy/) and $i18n = $lines[$::i+1] } @lines;  
	    if ($i18n =~ /^msgstr "(.+)"$/) {
		$i18n = $1;
		if ($charset =~ /^utf-8/i) {
		    output("/tmp/create_titles_temp", $i18n);
		    $i18n = `iconv -f UTF8 -t iso-8859-1 /tmp/create_titles_temp 2>/dev/null`;
		    $? and next;
		}
		mkdir "title/$poname";
		create_file("$wd/title-back.png",
			    $font,
			    $i18n,
			    "$wd/title/$poname/title-$k.png");
		print ".";
	    }
	}
    } else {
	print "- ignoring, charset is not iso-8859-1 or UTF8\n";
    }
    print "\n";
}

Gimp::end();

