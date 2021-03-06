# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::pkg;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
#  Copyright (c) 2012-2017 Matteo Pasotti <matteo.pasotti@gmail.com>
#  Copyright (c) 2014-2017 Angelo Naselli <anaselli@linux.it>
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
# $Id: pkg.pm 270160 2010-06-22 19:55:40Z jvictor $

use strict;
use Sys::Syslog;
use File::ShareDir ':ALL';

use MDK::Common::Func;  #qw(before_leaving any);
use MDK::Common::DataStructure; # qw (uniq difference2 member add2hash put_in_hash);
use MDK::Common::System qw(arch);
use MDK::Common::File; # qw(cat_);
use MDK::Common::Various qw(chomp_);

use POSIX qw(_exit ceil);
use URPM;
use utf8;
use ManaTools::rpmdragora;
use ManaTools::Rpmdragora::open_db;
use ManaTools::Rpmdragora::gurpm;
use ManaTools::Rpmdragora::formatting;
use ManaTools::Rpmdragora::rpmnew;
use ManaTools::Shared;
use ManaTools::Shared::RunProgram qw(run get_stdout);
use ManaTools::rpmdragora;
use urpm;
use urpm::lock;
use urpm::install;
use urpm::signature;
use urpm::get_pkgs;
use urpm::select;
use urpm::main_loop;
use urpm::args qw();
use urpm::util;
use Carp;

my $loc = ManaTools::rpmdragora::locale();

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                    $priority_up_alread_warned
                    download_callback
                    extract_header
                    find_installed_version
                    get_pkgs
                    perform_installation
                    perform_removal
                    run_rpm
                    sort_packages
                    );

our $priority_up_alread_warned;

sub sort_packages_biarch {
    sort {
        my ($na, $aa) = $a =~ /^(.*-[^-]+-[^-]+)\.([^.-]+)$/;
        my ($nb, $ab) = $b =~ /^(.*-[^-]+-[^-]+)\.([^.-]+)$/;
        !defined($na) ?
            (!defined($nb) ? 0 : 1) :
            (!defined($nb) ? -1 : $na cmp $nb || ($ab =~ /64$/) <=> ($aa =~ /64$/));
    } @_;
}

sub sort_packages_monoarch {
    sort { uc($a) cmp uc($b) } @_;
}

*sort_packages = MDK::Common::System::arch() =~ /x86_64/ ? \&sort_packages_biarch : \&sort_packages_monoarch;

sub run_rpm {
    foreach (qw(LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION LC_ALL)) {
        local $ENV{$_} = $ENV{$_} . '.UTF-8' if $ENV{$_} && $ENV{$_} !~ /UTF-8/;
    }
    my @l = map { ensure_utf8($_); $_ } ManaTools::Shared::RunProgram::get_stdout(@_);
    wantarray() ? @l : join('', @l);
}


sub extract_header {
    my ($pkg, $urpm, $xml_info, $o_installed_version) = @_;
    my %fields = (
        info      => 'description',
        files     => 'files',
        changelog => 'changelog',
    );
    # already extracted:
    return if $pkg->{$fields{$xml_info}};

    my $p = $pkg->{pkg};

    if (!$p) {
        warn ">> ghost package '$pkg' has no URPM object!!!\n";
        return;
    }

    my $name = $p->fullname;
    # fix extracting info for SRPMS and RPM GPG keys:
    $name =~ s!\.src!!;

    if ($p->flag_installed && !$p->flag_upgrade) {
        my @files = map { MDK::Common::Various::chomp_($_) } run_rpm("rpm -ql $name");
        MDK::Common::DataStructure::add2hash($pkg, { files => [ @files ? @files : $loc->N("(none)") ],
            description => rpm_description(scalar(run_rpm("rpm -q --qf '%{description}' $name"))),
                 changelog => format_changelog_string($o_installed_version, scalar(run_rpm("rpm -q --changelog $name"))) });
    } else {
        my $medium = pkg2medium($p, $urpm);
        my ($local_source, %xml_info_pkgs, $bar_id);
        my $_statusbar_clean_guard = MDK::Common::Func::before_leaving { $bar_id and statusbar_msg_remove($bar_id) };
        my $dir = urpm::file_from_local_url($medium->{url});

        print "p->filename: ". $p->filename."\n";
        $local_source = "$dir/" . $p->filename if $dir;
        print "local_source: " . ($local_source ? $local_source : "") . "\n";

        if ($local_source && -e $local_source) {
            $bar_id = statusbar_msg($loc->N("Getting information from %s...", $dir), 0);
            $urpm->{log}("getting information from rpms from $dir");
        } else {
            my $gurpm;
            $bar_id = statusbar_msg($loc->N("Getting '%s' from XML meta-data...", $xml_info), 0);
            my $_gurpm_clean_guard = MDK::Common::Func::before_leaving { undef $gurpm };
            if (my $xml_info_file = eval { urpm::media::any_xml_info($urpm, $medium, $xml_info, undef, sub {
                $gurpm ||= ManaTools::Rpmdragora::gurpm->new(
                    text => $loc->N("Please wait"),
                );
                download_callback($gurpm, @_)
                or goto header_non_available;
            }) }) {
                require urpm::xml_info;
                require urpm::xml_info_pkg;
                $urpm->{log}("getting information from $xml_info_file");
                my %nodes = eval { urpm::xml_info::get_nodes($xml_info, $xml_info_file, [ $name ]) };
                goto header_non_available if $@;
                MDK::Common::DataStructure::put_in_hash($xml_info_pkgs{$name} ||= {}, $nodes{$name});
            } else {
                if ($xml_info eq 'info') {
                    $urpm->{info}($loc->N("No xml info for medium \"%s\", only partial result for package %s", $medium->{name}, $name));
                } else {
                    $urpm->{error}($loc->N("No xml info for medium \"%s\", unable to return any result for package %s", $medium->{name}, $name));
                }
            }
        }

        #- even if non-root, search for a header in the global cachedir
        if ($local_source && -s $local_source) {
            $p->update_header($local_source) or do {
                warn "Warning, could not extract header for $name from $medium!";
                goto header_non_available;
            };
            my @files = $p->files;
            @files = $loc->N("(none)") if !@files;
            MDK::Common::DataStructure::add2hash($pkg, { description => rpm_description($p->description),
                files => \@files,
                url => $p->url,
                changelog => format_changelog_changelogs($o_installed_version, $p->changelogs) });
            $p->pack_header; # needed in order to call methods on objects outside ->traverse
        } elsif ($xml_info_pkgs{$name}) {
            if ($xml_info eq 'info') {
                MDK::Common::DataStructure::add2hash($pkg, { description => rpm_description($xml_info_pkgs{$name}{description}),
                         url => $xml_info_pkgs{$name}{url}
                });
            } elsif ($xml_info eq 'files') {
                my @files = map { MDK::Common::Various::chomp_($loc->to_utf8($_)) } split("\n", $xml_info_pkgs{$name}{files});
                MDK::Common::DataStructure::add2hash($pkg, { files => scalar(@files) ? \@files : [ $loc->N("(none)") ] });
            } elsif ($xml_info eq 'changelog') {
                MDK::Common::DataStructure::add2hash($pkg, {
                    changelog => format_changelog_changelogs($o_installed_version,
                                                             @{$xml_info_pkgs{$name}{changelogs}})
                });
            }
        } else {
            goto header_non_available;
        }
        return;
        header_non_available:
        MDK::Common::DataStructure::add2hash($pkg, { summary => $p->summary || $loc->N("(Not available)"), description => undef });
    }
}

sub find_installed_version {
    my ($p) = @_;

    my $version = $loc->N("(none)");
    open_rpm_db()->traverse_tag_find('name', $p->name, sub { $version = $_[0]->EVR; return ($version ? 1 : 0) }) if $p;
    return $version;
}

my $canceled;
sub download_callback {
    my ($gurpm, $mode, $file, $percent, $total, $eta, $speed) = @_;
    $canceled = 0;

    if ($mode eq 'start') {
        $gurpm->label($loc->N("Downloading package `%s'...", urpm::util::basename($file)));
#         $gurpm->validate_cancel(but($loc->N("Cancel")), sub { $canceled = 1 });
    } elsif ($mode eq 'progress') {
        $gurpm->label(
            join("\n",
                 $loc->N("Downloading package `%s'...", urpm::util::basename($file)),
                 (defined $total && defined $eta ?
                    $loc->N("        %s%% of %s completed, ETA = %s, speed = %s", $percent, $total, $eta, $speed)
                      : $loc->N("        %s%% completed, speed = %s", $percent, $speed)
                  ) =~ /^\s*(.*)/
              ),
        );
	#$gurpm->progress($percenti/100);
        $gurpm->progress(ceil($percent));
    } elsif ($mode eq 'end') {
        $gurpm->progress(100);
#         $gurpm->invalidate_cancel;
    }
    !$canceled;
}


# -=-=-=---=-=-=---=-=-=-- install packages -=-=-=---=-=-=---=-=-=-

my (@update_medias, $is_update_media_already_asked);

sub warn_about_media {
    my ($w, %options) = @_;

    return 0 if $::MODE ne 'update';
    return 0 if $::rpmdragora_options{'no-media-update'};

    # we use our own instance of the urpmi db in order not to mess up with skip-list managment (#31092):
    # and no need to fully configure urpmi since we may have to do it again anyway because of new media:
    my $urpm = fast_open_urpmi_db();

    my $_lock = urpm::lock::urpmi_db($urpm, undef, wait => $urpm->{options}{wait_lock});

    # build media list:
    @update_medias = get_update_medias($urpm);

    # do not update again media after installing/removing some packages:
    $::rpmdragora_options{'no-media-update'} ||= 1;

    if (@update_medias > 0) {
        if (!$options{skip_updating_mu} && !$is_update_media_already_asked) {
            $is_update_media_already_asked = 1;
            if (!$::rpmdragora_options{'no-confirmation'}) {
                my $choice = interactive_msg($loc->N("Confirmation"),
                                $loc->N("I need to contact the mirror to get latest update packages.
Please check that your network is currently running.

Is it ok to continue?"
                                ), yesno => 1, dont_ask_again => 1,
# TODO                   widget =>  gtknew('CheckButton', text => $loc->N("Do not ask me next time"),
#                                      active_ref => \$::rpmdragora_options{'no-confirmation'}
#                                  )
               );
               $::rpmdragora_options{'no-confirmation'} = $choice->{dont_ask_again};
               return(-1) if !$choice->{value};
            }
            writeconf();
            urpm::media::select_media($urpm, map { $_->{name} } @update_medias);
            update_sources($urpm, noclean => 1, medialist => [ map { $_->{name} } @update_medias ]);
        }
    } else {
        if (MDK::Common::Func::any { $_->{update} } @{$urpm->{media}}) {
            interactive_msg($loc->N("Already existing update media"),
$loc->N("You already have at least one update medium configured, but
all of them are currently disabled. You should run the Software
Media Manager to enable at least one (check it in the \"%s\"
column).

Then, restart \"%s\".", $loc->N("Enabled"), $ManaTools::rpmdragora::myname_update));
            return (-1);
        }
        my ($mirror) = choose_mirror($urpm, transient => $w->{real_window} || $::main_window,
                                       message => join("\n\n",
                                                       $loc->N("You have no configured update media. MageiaUpdate cannot operate without any update media."),
                                                       $loc->N("I need to contact the Mageia website to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?"),
                                                         ),
                                   );
        my $m = ref($mirror) ? $mirror->{url} : '';
        $m or interactive_msg($loc->N("How to choose manually your mirror"),
$loc->N("You may also choose your desired mirror manually: to do so,
launch the Software Media Manager, and then add a `Security
updates' medium.

Then, restart %s.", $ManaTools::rpmdragora::myname_update)), return (-1);
        add_distrib_update_media($urpm, $mirror, only_updates => 0);
    }
    return 0;
}


sub get_parallel_group() {
    $::rpmdragora_options{parallel} ? $::rpmdragora_options{parallel}[0] : undef;
}

my ($count, $level, $limit, $new_stage, $prev_stage, $total);

sub init_progress_bar {
    my ($urpm) = @_;
    undef $_ foreach $count, $prev_stage, $new_stage, $limit;
    $level = 5;
    $total = @{$urpm->{depslist}};
}

sub reset_pbar_count {
    undef $prev_stage;
    $count = 0;
    $limit = $_[0];
}

sub update_pbar {
    my ($gurpm) = @_;
    return if !$total;          # don't die if there's no source
    $count++;
    $new_stage = $level+($limit-$level)*$count/$total;
    $prev_stage = 0 if(!defined($prev_stage));
    if ($prev_stage + 1 < $new_stage) {
        $prev_stage = $new_stage;
        $gurpm->progress(ceil($new_stage));
    }
}


sub get_installed_packages {
    my ($urpm, $db, $all_pkgs, $gurpm) = @_;

    $urpm->{global_config}{'prohibit-remove'} = '' if(!defined($urpm->{global_config}{'prohibit-remove'}));
    my @base = ("basesystem", split /,\s*/, $urpm->{global_config}{'prohibit-remove'});
    my (%base, %basepackages, @installed_pkgs, @processed_base);
    reset_pbar_count(33);
    while (defined(local $_ = shift @base)) {
	exists $basepackages{$_} and next;
	$db->traverse_tag(m|^/| ? 'path' : 'whatprovides', [ $_ ], sub {
			      update_pbar($gurpm);
			      my $name = $_[0]->fullname;
			      # workaround looping in URPM:
			      return if MDK::Common::DataStructure::member($name, @processed_base);
			      push @processed_base, $name;
			      push @{$basepackages{$_}}, $name;
			      push @base, $_[0]->requires_nosense;
			  });
    }
    foreach (values %basepackages) {
	my $n = @$_;            #- count number of times it's provided
	foreach (@$_) {
	    $base{$_} = \$n;
	}
    }
    # costly:
    $db->traverse(sub {
                      my ($pkg) = @_;
                      update_pbar($gurpm);
                      my $fullname = urpm_name($pkg);
                      return if $fullname =~ /@/;
                      $all_pkgs->{$fullname} = {
                          pkg => $pkg, urpm_name => $fullname,
                      } if !($all_pkgs->{$fullname} && $all_pkgs->{$fullname}{description});
                      if (my $name = $base{$fullname}) {
                          $all_pkgs->{$fullname}{base} = \$name;
                          $pkg->set_flag_base(1) if $$name == 1;
                      }
                      push @installed_pkgs, $fullname;
                      $pkg->set_flag_installed;
                      $pkg->pack_header; # needed in order to call methods on objects outside ->traverse
                  });
    @installed_pkgs;
}

urpm::select::add_packages_to_priority_upgrade_list('rpmdragora', 'perl-Glib', 'perl-Gtk2');

my ($priority_state, $priority_requested);
our $need_restart;

our $probe_only_for_updates;

sub get_updates_list {
    my ($urpm, $db, $state, $requested, $requested_list, $requested_strict, $all_pkgs, %limit_preselect) = @_;

    $urpm->request_packages_to_upgrade(
	$db,
	$state,
	$requested,
	%limit_preselect
    );

    my %common_opts = (
        callback_choices => \&ManaTools::Rpmdragora::gui::callback_choices,
        priority_upgrade => $urpm->{options}{'priority-upgrade'} || '',
    );

    if ($urpm->{options}{'priority-upgrade'}) {
        $need_restart =
          urpm::select::resolve_priority_upgrades_after_auto_select($urpm, $db, $state,
                                                                    $requested, %common_opts);
    }

    # list of updates (including those matching /etc/urpmi/skip.list):
    @$requested_list = sort map {
	my $name = urpm_name($_);
        $all_pkgs->{$name} = { pkg => $_ };
	$name;
    } @{$urpm->{depslist}}[keys %$requested];

    # list of pure updates (w/o those matching /etc/urpmi/skip.list but with their deps):
    if ($probe_only_for_updates && !$need_restart) {
        @$requested_strict = sort map {
            urpm_name($_);
        } $urpm->resolve_requested($db, $state, $requested, callback_choices => \&ManaTools::Rpmdragora::gui::callback_choices);

        if (my @l = grep { $state->{selected}{$_->id} }
              urpm::select::_priority_upgrade_pkgs($urpm, $urpm->{options}{'priority-upgrade'})) {
            if (!$need_restart) {
                $need_restart =
                  urpm::select::_resolve_priority_upgrades($urpm, $db, $state, $state->{selected},
                                                           \@l, %common_opts);
            }
        }
    }

    if ($need_restart) {
        $requested_strict = [ map { scalar $_->fullname } @{$urpm->{depslist}}[keys %{$state->{selected}}] ];
        # drop non priority updates:
        @$requested_list = ();
    }

    # list updates including skiped ones + their deps in MageiaUpdate:
    @$requested_list = MDK::Common::DataStructure::uniq(@$requested_list, @$requested_strict);

    # do not pre select updates in rpmdragora:
    @$requested_strict = () if !$probe_only_for_updates;
}

sub get_pkgs {
    my (%options) = @_;
    my $w = $::main_window;

    myexit (-1) if (warn_about_media($w, %options) == -1);

    my $gurpm = ManaTools::Rpmdragora::gurpm->new(
        text => $loc->N("Please wait"),
    );
    my $_gurpm_clean_guard = MDK::Common::Func::before_leaving { undef $gurpm };

    my $urpm = open_urpmi_db(update => $probe_only_for_updates && !is_it_a_devel_distro());

    my $_drop_lock = MDK::Common::Func::before_leaving { undef $urpm->{lock} };

    $priority_up_alread_warned = 0;

    # update media list in case warn_about_media() added some:
    @update_medias = get_update_medias($urpm);

    $gurpm->label($loc->N("Reading updates description"));
	#- parse the description file
    my $update_descr = urpm::get_updates_description($urpm, @update_medias);
    $gurpm->progress(100);

    my $_unused = $loc->N("Please wait, finding available packages...");

#     # find out installed packages:

    init_progress_bar($urpm);

    $gurpm->label($loc->N("Please wait, listing base packages..."));
    $gurpm->progress(ceil($level));

    my $db = eval { open_rpm_db() };
    if (my $err = $@) {
	interactive_msg($loc->N("Error"), $loc->N("A fatal error occurred: %s.", $err));
        return;
    }

    my $sig_handler = sub { undef $db; exit 3 };
    local $SIG{INT} = $sig_handler;
    local $SIG{QUIT} = $sig_handler;

    $gurpm->label($loc->N("Please wait, finding installed packages..."));
    $level = 33;
    $gurpm->progress(ceil($level));
    reset_pbar_count(66);
    my (@installed_pkgs, %all_pkgs);
    if (!$probe_only_for_updates) {
        @installed_pkgs = get_installed_packages($urpm, $db, \%all_pkgs, $gurpm);
    }

    if (my $group = get_parallel_group()) {
        urpm::media::configure($urpm, parallel => $group);
    }

    # find out availlable packages:

    $urpm->{state} = {};

    $gurpm->label($loc->N("Please wait, finding available packages..."));
    $level = 66;
    $gurpm->progress(ceil($level));

    check_update_media_version($urpm, @update_medias);

    my $requested = {};
    my $state = {};
    my (@requested, @requested_strict);

    if ($compute_updates->[0] || $::MODE eq 'update') {
        my %filter;
        if ($options{pure_updates}) {
            # limit to packages from update-media (dependencies can still come from other media)
            %filter = (idlist => [ map { $_->{start} .. $_->{end} } @update_medias ]);
        }
        get_updates_list($urpm, $db, $state, $requested, \@requested, \@requested_strict, \%all_pkgs, %filter);
    }

    if ($need_restart) {
        $priority_state = $state;
        $priority_requested = $requested;
    } else {
        ($priority_state, $priority_requested) = ();
    }

    if (!$probe_only_for_updates) {
        $urpm->compute_installed_flags($db); # TODO/FIXME: not for updates
        $urpm->{depslist}[$_]->set_flag_installed foreach keys %$requested; #- pretend it's installed
    }
    $urpm->{rpmdragora_state} = $state; #- Don't forget it
    $level = 70;
    $gurpm->progress(ceil($level));

    my %l;
    reset_pbar_count(100);
    foreach my $pkg (@{$urpm->{depslist}}) {
        update_pbar($gurpm);
        $pkg->flag_upgrade or next;
        my $key = $pkg->name . $pkg->arch;
        $l{$key} = $pkg if !$l{$key} || $l{$key}->compare_pkg($pkg);
    }
    my @installable_pkgs = map { my $n = $_->fullname; $all_pkgs{$n} = { pkg => $_ }; $n } values %l;
    undef %l;

    my @inactive_backports;
    my @active_backports;
    my @backport_medias = get_backport_media($urpm);

    foreach my $medium (@backport_medias) {
        update_pbar($gurpm);

        # The 'searchmedia' flag differentiates inactive backport medias
        # (because that option was passed to urpm::media::configure to
        # temporarily enable them)

        my $backports =
            $medium->{searchmedia} ? \@inactive_backports : \@active_backports;
        if (defined($medium->{start}) || defined($medium->{end})) {
            foreach my $pkg_id ($medium->{start} .. $medium->{end}) {
                next if !$pkg_id;
                my $pkg = $urpm->{depslist}[$pkg_id];
                $pkg->flag_upgrade or next;
                my $name = $pkg->fullname;
                push @$backports, $name;
                $all_pkgs{$name} = { pkg => $pkg, is_backport => 1 };
            }
        }
    }
    my @updates = @requested;
    # selecting updates by default but skipped ones (MageiaUpdate only):
    foreach (@requested_strict) {
        $all_pkgs{$_}{selected} = 1;
    }

    # urpmi only care about the first medium where it found the package,
    # so there's no need to list the same package several time:
    @installable_pkgs = MDK::Common::DataStructure::uniq(MDK::Common::DataStructure::difference2(\@installable_pkgs, \@updates));

    my @meta_pkgs = grep { /^task-|^basesystem/ } keys %all_pkgs;

    my $pkg_list = File::ShareDir::dist_file(ManaTools::Shared::distName(), 'modules/rpmdragora/gui.lst');

    my @gui_pkgs = map { chomp; $_ } MDK::Common::File::cat_($pkg_list);

    # add meta packages to GUI packages list (which expect basic names not fullnames):
    push @gui_pkgs, map { (split_fullname($_))[0] } @meta_pkgs;

    +{ urpm => $urpm,
       all_pkgs => \%all_pkgs,
       installed => \@installed_pkgs,
       installable => \@installable_pkgs,
       updates => \@updates,
       meta_pkgs => \@meta_pkgs,
       gui_pkgs => [ grep { my $p = $all_pkgs{$_}{pkg}; $p && MDK::Common::DataStructure::member(($p->fullname)[0], @gui_pkgs) } keys %all_pkgs ],
       update_descr => $update_descr,
       backports => [ @inactive_backports, @active_backports ],
       inactive_backports => \@inactive_backports
   };
}

sub _display_READMEs_if_needed {
    my $urpm = shift;
    return if !$urpm->{readmes};

    my %Readmes = %{$urpm->{readmes}};
    return if ! scalar keys %Readmes;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Upgrade information"));
    my $factory      = yui::YUI::widgetFactory;

    ## | [msg-label]                      |
    ## |                                  |
    ## | pkg-list                         |
    ## |                                  |
    ## | info on selected pkg             |(1)
    ## |                                  |
    ## |             [ok]                 |
    ####
    # (1) info on pkg list:
    #  selected package readmi.urpmi

    my $dialog       = $factory->createPopupDialog;
    my $vbox         = $factory->createVBox( $dialog );
    my $msgBox       = $factory->createLabel($vbox, $loc->N("These packages come with upgrade information"), 1);
    my $tree         = $factory->createTree($vbox, $loc->N("Select a package"));
                       $factory->createVSpacing($vbox, 1);
    my $infoBox      = $factory->createRichText($vbox, "", 0);
                       $tree->setWeight($yui::YD_HORIZ, 2);
                       $infoBox->setWeight($yui::YD_HORIZ, 4);
                       $tree->setWeight($yui::YD_VERT,  10);
                       $infoBox->setWeight($yui::YD_VERT,  10);
                       $factory->createVSpacing($vbox, 1);
    my $hbox         = $factory->createHBox( $vbox );
    my $align        = $factory->createHCenter($hbox);
    my $okButton     = $factory->createPushButton($align,  $loc->N("&Ok"));
                       $okButton->setDefaultButton(1);

    # adding packages to the list
    my $itemColl = new yui::YItemCollection;
    foreach my $f (sort keys %Readmes) {
        my $item  = new yui::YTreeItem ("$Readmes{$f}");
        my $child = new yui::YTreeItem ($item, "$f");
        $child->DISOWN();
        $itemColl->push($item);
        $item->DISOWN();
    }
    $tree->addItems($itemColl);
    $tree->setImmediateMode(1);

    while(1) {
        my $event     = $dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### widget
            my $widget = $event->widget();
            if ($widget == $tree) {
                my $content = "";
                my $item = $tree->selectedItem();
                if ($item && !$item->hasChildren()) {
                    my $filename = $tree->currentItem()->label();
                    $content = scalar MDK::Common::File::cat_($filename);
                    $content = $loc->N("(none)") if !$content; # should not happen
                    ensure_utf8($content);
                    $content =~ s/\n/<br>/g;
                }
                $infoBox->setValue($content);
            }
            elsif ($widget == $okButton) {
                last;
            }
        }
    }

    destroy $dialog;

    # restore original title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return;
}

sub perform_parallel_install {
    my ($urpm, $group, $w, $statusbar_msg_id) = @_;
    my @pkgs = map { MDK::Common::Func::if_($_->flag_requested, urpm_name($_)) } @{$urpm->{depslist}};

    my @error_msgs;
    my $res = !ManaTools::Shared::RunProgram::run('urpmi', '2>', \@error_msgs, '-v', '--X', '--parallel', $group, @pkgs);

    if ($res) {
        $$statusbar_msg_id = statusbar_msg(
            #$loc->N("Everything installed successfully"),
            $loc->N("All requested packages were installed successfully."),
        );
    } else {
        interactive_msg(
            $loc->N("Problem during installation"),
            $loc->N("There was a problem during the installation:\n\n%s", join("\n", @error_msgs)),
            scroll => 1,
        );
    }
    open_rpm_db('force_sync');
    $w->set_sensitive(1);
    return 0;
}

sub perform_installation {  #- (partially) duplicated from /usr/sbin/urpmi :-(
    my ($urpm, $pkgs) = @_;

    my @error_msgs;
    my $statusbar_msg_id;
    my $gurpm;
    local $urpm->{fatal} = sub {
        my $fatal_msg = $_[1];
        printf STDERR "Fatal: %s\n", $fatal_msg;
        undef $gurpm;
        interactive_msg($loc->N("Installation failed"),
                        $loc->N("There was a problem during the installation:\n\n%s", $fatal_msg));
        goto return_with_exit_code;
    };
    local $urpm->{error} = sub { printf STDERR "Error: %s\n", $_[0]; push @error_msgs, $_[0] };

    my $w = $::main_window;
    #$w->set_sensitive(0);
    #my $_restore_sensitive = MDK::Common::Func::before_leaving { $w->set_sensitive(1) };

    # my $_flush_guard = Gtk2::GUI_Update_Guard->new;

    if (my $group = get_parallel_group()) {
        return perform_parallel_install($urpm, $group, $w, \$statusbar_msg_id);
    }

    my ($lock, $rpm_lock);
    if (!$::env) {
        $lock = urpm::lock::urpmi_db($urpm, undef, wait => $urpm->{options}{wait_lock});
        $rpm_lock = urpm::lock::rpm_db($urpm, 'exclusive');
    }
    my $state = $priority_state || $probe_only_for_updates ? { } : $urpm->{rpmdragora_state};

    my $bar_id = statusbar_msg($loc->N("Checking validity of requested packages..."), 0);

    # FIXME: THIS SET flag_requested on all packages!!!!
    # select packages to install / enssure selected pkg set is consistant:
    my %saved_flags;
    my $requested = { map {
        $saved_flags{$_->id} = $_->flag_requested;
        $_->id => undef;
    } grep { $_->flag_selected } @{$urpm->{depslist}} };

    # NOTE: original code did not manage priority_upgrade anyway
    #       _priority_upgrade_pkgs needs a string and split gives a warning for an undef value.
    urpm::select::resolve_dependencies(
        $urpm, $state, $requested,
        rpmdb => $::env && "$::env/rpmdb.cz",
        callback_choices => \&ManaTools::Rpmdragora::gui::callback_choices,
        priority_upgrade => '',
    );
    statusbar_msg_remove($bar_id);

    my ($local_sources, $blist) = urpm::get_pkgs::selected2local_and_blists($urpm, $state->{selected});
    if (!$local_sources && (!$blist || !@$blist)) {
        interactive_msg(
	    $loc->N("Unable to get source packages."),
	    $loc->N("Unable to get source packages, sorry. %s",
		@error_msgs ? $loc->N("\n\nError(s) reported:\n%s", join("\n", @error_msgs)) : ''),
	    scroll => 1,
	);
        goto return_with_exit_code;
    }

    my @to_install = @{$urpm->{depslist}}[keys %{$state->{selected}}];
    my @pkgs = map { scalar($_->fullname) } sort(grep { $_->flag_selected } @to_install);

    @{$urpm->{ask_remove}} = sort(urpm::select::removed_packages($urpm->{state}));
    my @to_remove = map { MDK::Common::Func::if_($pkgs->{$_}{selected} && !$pkgs->{$_}{pkg}->flag_upgrade, $pkgs->{$_}{urpm_name}) } keys %$pkgs;

    my $r = format_list(map { scalar(urpm::select::translate_why_removed_one($urpm, $urpm->{state}, $_)) } @to_remove);

    my ($size, $filesize) = $urpm->selected_size_filesize($state);
    my $install_count = int(@pkgs);
    my $to_install = $install_count == 0 ? '' :
      ($priority_state ? '<b>' . $loc->N("Rpmdragora or one of its priority dependencies needs to be updated first. Rpmdragora will then restart.") . '</b>' . "\n\n" : '') .
      ($loc->P("The following package is going to be installed:", "The following %d packages are going to be installed:", $install_count, $install_count)
      . "\n\n" . format_list(map { s!.*/!!; $_ } @pkgs));
    my $remove_count =  scalar(@to_remove);
    interactive_msg(($to_install ? $loc->N("Confirmation") : $loc->N("Some packages need to be removed")),
                    join("\n\n",
                     ($r ?
                        (!$to_install ? ($loc->P("Remove one package?", "Remove %d packages?", $remove_count, $remove_count), $r) :
 (($remove_count == 1 ?
 $loc->N("The following package has to be removed for others to be upgraded:")
   : $loc->N("The following packages have to be removed for others to be upgraded:")), $r), MDK::Common::Func::if_($to_install, $to_install))
                          : $to_install),
                         format_size($size),
                         format_filesize($filesize),
                         $loc->N("Is it ok to continue?")),
                     scroll => 1,
                     yesno => 1, min_size => {lines => 18},) or return 1;

    my $_umount_guard = MDK::Common::Func::before_leaving { urpm::removable::try_umounting_removables($urpm) };

    # select packages to uninstall for !update mode:
    perform_removal($urpm, { map { $_ => $pkgs->{$_} } @to_remove }) if !$probe_only_for_updates;

    $gurpm = ManaTools::Rpmdragora::gurpm->new(
        text => $loc->N("Please wait"),
        title => $loc->N("Initializing..."),
    );
    # my $_gurpm_clean_guard = MDK::Common::Func::before_leaving { undef $gurpm };
    my $something_installed;

    if (@to_install && $::rpmdragora_options{auto_orphans}) {
        urpm::orphans::compute_future_unrequested_orphans($urpm, $state);
        if (my @orphans = map { scalar $_->fullname } @{$state->{orphans_to_remove}}) {
            interactive_msg($loc->N("Orphan packages"), $loc->P("The following orphan package will be removed.",
                    "The following orphan packages will be removed.", scalar(@orphans))
              . "\n" . urpm::orphans::add_leading_spaces(join("\n", @orphans) . "\n"), scroll => 1);
        }
    }

    urpm::orphans::mark_as_requested($urpm, $state, 0);

    my ($progress, $total, @rpms_upgrade);
    my $transaction;
    my ($progress_nb, $transaction_progress_nb, $remaining, $done) = (0, 0, 0 ,0);
    my $callback_inst = sub {
        my ($urpm, $type, $id, $subtype, $amount, $total) = @_;
        my $pkg = defined $id ? $urpm->{depslist}[$id] : undef;
        if ($subtype eq 'start') {
            if ($type eq 'trans') {
                print($loc->N("Preparing package installation...") . "\n");
                $gurpm->label($loc->N("Preparing package installation..."));
                } elsif (defined $pkg) {
                    $something_installed = 1;
                    $gurpm->label($loc->N("Installing package `%s' (%d/%d)...", $pkg->name, ++$transaction_progress_nb, scalar(@{$transaction->{upgrade}}))
                                        . "\n" . $loc->N("Total: %d/%d", ++$progress_nb, $install_count));
                    print($loc->N("Installing package `%s' (%d/%d)...", $pkg->name, $transaction_progress_nb, scalar(@{$transaction->{upgrade}})) .
                          "\n" . $loc->N("Total: %d/%d", $progress_nb, $install_count) . "\n");
                }
        } elsif ($subtype eq 'progress') {
            $gurpm->progress($total ? ceil(($amount/$total)*100) : 100);
          #  print("Progress: ".($total ? ($amount/$total)*100 : 100)."\n");
        }
    };

    # FIXME: sometimes state is lost:
    my @ask_unselect = urpm::select::unselected_packages($state);

    # fix flags for orphan computing:
    foreach (keys %{$state->{selected}}) {
        my $pkg = $urpm->{depslist}[$_];
        $pkg->set_flag_requested($saved_flags{$pkg->id});
    }
    my $exit_code =
      urpm::main_loop::run($urpm, $state, 1, \@ask_unselect,
                         {
                             completed => sub {
                                 # explicitly destroy the progress window when it's over; we may
                                 # have sg to display before returning (errors, rpmnew/rpmsave, ...):
                                 undef $gurpm;

                                 undef $lock;
                                 undef $rpm_lock;
                             },
                             inst => $callback_inst,
                             trans => $callback_inst,
                             ask_yes_or_no => sub {
                                 # handle 'allow-force' and 'allow-nodeps' options:
                                 my ($title, $msg) = @_;
                                 local $::main_window = $gurpm->{real_window};
                                 interactive_msg($title, $msg, yesno => 1, scroll => 1,
                                 );
                             },
                             message => sub {
                                 my ($title, $message) = @_;
                                 interactive_msg($title, $message, scroll => 1);
                             },
                             # cancel installation when 'cancel' button is pressed:
                             trans_log => sub { download_callback($gurpm, @_) or goto return_with_exit_code },
                             post_extract => sub {
                                 my ($set, $transaction_sources, $transaction_sources_install) = @_;
                                 $transaction = $set;
                                 $transaction_progress_nb = 0;
                                 $done += grep { !/\.src\.rpm$/ } values %$transaction_sources;         #updates
                                 $total = keys(%$transaction_sources_install) + keys %$transaction_sources;
                                 push @rpms_upgrade, keys %$transaction_sources;
                                 $done += grep { !/\.src\.rpm$/ } values %$transaction_sources_install; # installs
                             },
                             pre_removable => sub {
                                 # Gtk2::GUI_Update_Guard->new use of alarm() kill us when
                                 # running system(), thus making DVD being ejected and printing
                                 # wrong error messages (#30463)

                                 local $SIG{ALRM} = sub { die "ALARM" };
                                 $remaining = alarm(0);
                             },

                             post_removable => sub { alarm $remaining },
                             copy_removable => sub {
                                 my ($medium) = @_;
                                 interactive_msg(
                                     $loc->N("Change medium"),
                                     $loc->N("Please insert the medium named \"%s\"", $medium),
                                     yesno => 1, text => { no => $loc->N("&Cancel"), yes => $loc->N("&Ok") },
                                 );
                             },
                             pre_check_sig => sub { $gurpm->label($loc->N("Verifying package signatures...")) },
                             check_sig => sub { $gurpm->progress(ceil(++$progress/$total)*100) },
                             bad_signature => sub {
                                 my ($msg, $msg2) = @_;
                                 local $::main_window = $gurpm->{real_window};
                                 $msg =~ s/:$/\n\n/m; # FIXME: to be fixed in urpmi after 2008.0
                                 interactive_msg(
                                     $loc->N("Warning"), "$msg\n\n$msg2", yesno => 1, MDK::Common::Func::if_(10 < ($msg =~ tr/\n/\n/), scroll => 1),
                                 );
                             },
                             post_download => sub {
                                 $canceled and goto return_with_exit_code;
#                                  $gurpm->invalidate_cancel_forever;
                             },
                             need_restart => sub {
                                 my ($need_restart_formatted) = @_;
                                 # FIXME: offer to restart the system
                                 interactive_msg($loc->N("Warning"), join("\n", values %$need_restart_formatted), scroll => 1);
                             },
                             trans_error_summary => sub {
                                 my ($nok, $errors) = @_;
                                 interactive_msg(
                                     $loc->N("Problem during installation"),
                                     MDK::Common::Func::if_($nok, $loc->N("%d installation transactions failed", $nok) . "\n\n") .
                                       $loc->N("There was a problem during the installation:\n\n%s",
                                         join("\n\n", @$errors, @error_msgs)),
                                     scroll => 1,
                                 );
                             },
                             need_restart => sub {
                                 my ($need_restart_formatted) = @_;
                                 interactive_msg($loc->N("Warning"),
                                                 join("\n\n", values %$need_restart_formatted));
                             },
                             success_summary => sub {
                                 if (!($done || @to_remove)) {
                                     interactive_msg($loc->N("Error"),
                                                     $loc->N("Unrecoverable error: no package found for installation, sorry."));
                                     return;
                                 }
                                 my $id = statusbar_msg($loc->N("Inspecting configuration files..."), 0);
                                 my %pkg2rpmnew;
                                 foreach my $id (@rpms_upgrade) {
                                    my $pkg = $urpm->{depslist}[$id];
                                    next if $pkg->arch eq 'src';
                                    $pkg2rpmnew{$pkg->fullname} = [ grep { (-r "$_.rpmnew" || -r "$_.rpmsave") && !ignore_rpmnew($_) } $pkg->conf_files ];
                                 }
                                 statusbar_msg_remove($id);
                                 rpmnew_dialog($loc->N("The installation is finished; everything was installed correctly.

Some configuration files were created as `.rpmnew' or `.rpmsave',
you may now inspect some in order to take actions:"),
                                               %pkg2rpmnew)
                                   and statusbar_msg($loc->N("All requested packages were installed successfully."), 1);
                                 statusbar_msg($loc->N("Looking for \"README\" files..."), 1);
                                 _display_READMEs_if_needed($urpm);
                             },
                             already_installed_or_not_installable => sub {
                                 my ($msg1, $msg2) = @_;
                                 my $msg = join("\n", @$msg1, @$msg2);
                                 return if !$msg; # workaround missing state
                                 interactive_msg($loc->N("Error"), $msg);
                             },
                         },
                     );

    #- restart rpmdragora if needed, keep command line for that.
    if ($need_restart && !$exit_code) {
        Sys::Syslog::syslog('info|local1', "restarting rpmdragora");
        #- it seems to work correctly with exec instead of system, provided we stop timers
        #- added --previous-priority-upgrade to allow checking if yet if
        #-   priority-upgrade list has changed. and make sure we don't uselessly restart
        my @argv = ('--previous-priority-upgrade=' . $urpm->{options}{'priority-upgrade'},
                grep { !/^--no-priority-upgrade$|--previous-priority-upgrade=/ } @ManaTools::Rpmdragora::init::ARGV_copy);
        # remove "--emmbedded <id>" from argv:
        my $i = 0;
        foreach (@argv) {
            splice @argv, $i, 2 if /^--embedded$/;
            $i++;
        }
        alarm(0);
        # reMDK::Common::DataStructure::member not to ask again questions and the like:
        writeconf();

        my $err = yui::YUI::app()->runInTerminal(join(" ", $0, @argv, " --ncurses"));
        if ($err == -1) {
            exec($0, @argv);
        }
        destroy $::main_window if $::main_window;
        exit(0);
    }

    my $_s1 = $loc->N("RPM transaction %d/%d", 0, 0);
    my $_s2 = $loc->N("Unselect all");
    my $_s3 = $loc->N("Details");

    statusbar_msg_remove($statusbar_msg_id); #- XXX maybe remove this

    if ($exit_code == 0 && !$::rpmdragora_options{auto_orphans}) {
        if (urpm::orphans::check_unrequested_orphans_after_auto_select($urpm)) {
            if (my $msg = urpm::orphans::get_now_orphans_gui_msg($urpm)) {
                interactive_msg($loc->N("Orphan packages"), $msg, scroll => 1);
            }
        }
    }

  return_with_exit_code:
    return !($something_installed || scalar(@to_remove));
}


# -=-=-=---=-=-=---=-=-=-- remove packages -=-=-=---=-=-=---=-=-=-

sub perform_removal {
    my ($urpm, $pkgs) = @_;
    my @toremove = map { MDK::Common::Func::if_($pkgs->{$_}{selected}, $pkgs->{$_}{urpm_name}) } keys %$pkgs;
    return if !@toremove;
    my $gurpm = ManaTools::Rpmdragora::gurpm->new(
        text => $loc->N("Please wait")
    );
    my $_gurpm_clean_guard = MDK::Common::Func::before_leaving { undef $gurpm };

    my $may_be_orphans = 1;
    urpm::orphans::unrequested_orphans_after_remove($urpm, \@toremove)
	or $may_be_orphans = 0;

    my $progress = -1;
    local $urpm->{log} = sub {
        my $str = $_[0];
        print $str;
        $progress++;
        return if $progress <= 0; # skip first "creating transaction..." message
        $gurpm->label($str); # display "removing package %s"
        $gurpm->progress(ceil(min(99, scalar($progress/@toremove)*100)));
	#gtkflush();
    };

    my @results;
    slow_func_statusbar(
	$loc->N("Please wait, removing packages..."),
	$::main_window,
	sub {
	    @results = $::rpmdragora_options{parallel}
		? urpm::parallel::remove($urpm, \@toremove)
		: urpm::install::install($urpm, \@toremove, {}, {},
                                   callback_report_uninst => sub { $gurpm->label($_[0]) },
                               );
	    open_rpm_db('force_sync');
	},
    );
    if (@results) {
	interactive_msg(
	    $loc->N("Problem during removal"),
	    $loc->N("There was a problem during the removal of packages:\n\n%s", join("\n",  @results)),
	    MDK::Common::Func::if_(@results > 1, scroll => 1),
	);
	return 1;
    } else {
        if ($may_be_orphans && !$::rpmdragora_options{auto_orphans}) {
            if (my $msg = urpm::orphans::get_now_orphans_gui_msg($urpm)) {
                interactive_msg($loc->N("Information"), $msg, scroll => 1);
            }
        }
	return 0;
    }
}

1;
