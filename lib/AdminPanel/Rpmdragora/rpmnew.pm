# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::rpmnew;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License version 2, as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
#*****************************************************************************
#
# $Id: rpmnew.pm 263914 2009-12-03 17:41:02Z tv $

use strict;
use lib qw(/usr/lib/libDrakX);
use common;
use AdminPanel::rpmdragora;
use AdminPanel::Rpmdragora::init;
use AdminPanel::Rpmdragora::pkg;
use AdminPanel::Rpmdragora::open_db;
use AdminPanel::Rpmdragora::formatting;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(dialog_rpmnew do_merge_if_needed);

# /var/lib/nfs/etab /var/lib/nfs/rmtab /var/lib/nfs/xtab /var/cache/man/whatis
my %ignores_rpmnew = map { $_ => 1 } qw(
    /etc/adjtime
    /etc/fstab
    /etc/group
    /etc/ld.so.conf
    /etc/localtime
    /etc/modules
    /etc/passwd
    /etc/security/fileshare.conf
    /etc/shells
    /etc/sudoers
    /etc/sysconfig/alsa
    /etc/sysconfig/autofsck
    /etc/sysconfig/harddisks
    /etc/sysconfig/harddrake2/previous_hw
    /etc/sysconfig/init
    /etc/sysconfig/installkernel
    /etc/sysconfig/msec
    /etc/sysconfig/nfs
    /etc/sysconfig/pcmcia
    /etc/sysconfig/rawdevices
    /etc/sysconfig/saslauthd
    /etc/sysconfig/syslog
    /etc/sysconfig/usb
    /etc/sysconfig/xinetd
);

sub inspect {
	my ($file) = @_;
	my ($rpmnew, $rpmsave) = ("$file.rpmnew", "$file.rpmsave");
	my @inspect_wsize = ($typical_width*2.5, 500);
	my $rpmfile = 'rpmnew';
	-r $rpmnew or $rpmfile = 'rpmsave';
	-r $rpmnew && -r $rpmsave && (stat $rpmsave)[9] > (stat $rpmnew)[9] and $rpmfile = 'rpmsave';
	$rpmfile eq 'rpmsave' and $rpmnew = $rpmsave;

	foreach (qw(LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL)) {
            local $ENV{$_} = $ENV{$_} . '.UTF-8' if $ENV{$_} && $ENV{$_} !~ /UTF-8/;
	}
	my @diff = map { ensure_utf8($_); $_ } `/usr/bin/diff -u '$file' '$rpmnew'`;
	@diff = N("(none)") if !@diff;
	my $d = ugtk2->new(N("Inspecting %s", $file), grab => 1, transient => $::main_window);
	my $save_wsize = sub { @inspect_wsize = $d->{rwindow}->get_size };
	my %texts;
	require Gtk2::SourceView2;
	my $lang_manager = Gtk2::SourceView2::LanguageManager->get_default;
	gtkadd(
	    $d->{window},
	    gtkpack_(
		gtknew('VBox', spacing => 5),
		1, create_vpaned(
		    create_vpaned(
			gtkpack_(
			    gtknew('VBox'),
			    0, gtknew('Label', text_markup => qq(<span font_desc="monospace">$file:</span>)),
			    1, gtknew('ScrolledWindow', child => $texts{file} = Gtk2::SourceView2::View->new),
			),
			gtkpack_(
			    gtknew('VBox'),
			    0, gtknew('Label', text_markup => qq(<span font_desc="monospace">$rpmnew:</span>)),
			    1, gtknew('ScrolledWindow', child => $texts{rpmnew} = Gtk2::SourceView2::View->new),
			),
			resize1 => 1,
		    ),
		    gtkpack_(
			gtknew('VBox'),
			0, gtknew('Label', text => N("Changes:")),
			1, gtknew('ScrolledWindow', child => $texts{diff} = Gtk2::SourceView2::View->new),
		    ),
		    resize1 => 1,
		),
		0, Gtk2::HSeparator->new,
		0, gtknew('WrappedLabel',
                    # prevent bad sizing of Gtk2::WrappedLabel:
                    width => $inspect_wsize[0],
                    text => N("You can either remove the .%s file, use it as main file or do nothing. If unsure, keep the current file (\"%s\").",
                              $rpmfile, N("Remove .%s", $rpmfile)),
                    ),
		0, gtkpack__(
		    gtknew('HButtonBox'),
		    gtksignal_connect(
			gtknew('Button', text => N("Remove .%s", $rpmfile)),
			clicked => sub { $save_wsize->(); unlink $rpmnew; Gtk2->main_quit },
		    ),
		    gtksignal_connect(
			gtknew('Button', text => N("Use .%s as main file", $rpmfile)),
			clicked => sub { $save_wsize->(); renamef($rpmnew, $file); Gtk2->main_quit },
		    ),
		    gtksignal_connect(
			gtknew('Button', text => N("Do nothing")),
			clicked => sub { $save_wsize->(); Gtk2->main_quit },
		    ),
		)
	    )
	);
	my %files = (file => $file, rpmnew => $rpmnew);
     foreach (keys %files) {
         gtktext_insert($texts{$_}, [ [ scalar(cat_($files{$_})), { 'font' => 'monospace' } ] ]);
         my $lang = $lang_manager->guess_language($files{$_});
         $lang ||= $lang_manager->get_language('sh');
         my $buffer = $texts{$_}->get_buffer;
         $buffer->set_language($lang) if $lang;
     }
	gtktext_insert($texts{diff}, [ [ join('', @diff), { 'font' => 'monospace' } ] ]);
	my $buffer = $texts{diff}->get_buffer;
	my $lang = $lang_manager->get_language('diff');
	$buffer->set_language($lang) if $lang;
	$d->{rwindow}->set_default_size(@inspect_wsize);
	$d->main;
}

sub dialog_rpmnew {
    my ($msg, %p2r) = @_;
    @{$p2r{$_}} = grep { !$ignores_rpmnew{$_} } @{$p2r{$_}} foreach keys %p2r;
    my $sum_rpmnew = sum(map { int @{$p2r{$_}} } keys %p2r);
    $sum_rpmnew == 0 and return 1;
    interactive_packtable(
	N("Installation finished"),
	$::main_window,
	$msg,
	[ map { my $pkg = $_;
	    map {
		my $f = $_;
		my $b;
		[ gtkpack__(
		    gtknew('HBox'),
		    gtkset_markup(
			gtkset_selectable(gtknew('Label'), 1),
			qq($pkg:<span font_desc="monospace">$f</span>),
		    )
		),
		gtksignal_connect(
		    $b = gtknew('Button', text => N("Inspect...")),
		    clicked => sub {
			inspect($f);
			-r "$f.rpmnew" || -r "$f.rpmsave" or $b->set_sensitive(0);
		    },
		) ];
	    } @{$p2r{$pkg}};
	} keys %p2r ],
	[ gtknew('Button', text => N("Ok"), 
	    clicked => sub { Gtk2->main_quit }) ]
    );
    return 0;
}


sub do_merge_if_needed() {
    if ($rpmdragora_options{'merge-all-rpmnew'}) {
        my %pkg2rpmnew;
        my $wait = wait_msg(N("Please wait, searching..."));
        print "Searching .rpmnew and .rpmsave files...\n";
        # costly:
        open_rpm_db()->traverse(sub {
                          my $n = my_fullname($_[0]);
                          $pkg2rpmnew{$n} = [ grep { m|^/etc| && (-r "$_.rpmnew" || -r "$_.rpmsave") } map { chomp_($_) } $_[0]->conf_files ];
                      });
        print "done.\n";
        undef $wait;
        $typical_width = 330;
        dialog_rpmnew('', %pkg2rpmnew) and print "Nothing to do.\n";
        myexit(0);
    }
}

1;
