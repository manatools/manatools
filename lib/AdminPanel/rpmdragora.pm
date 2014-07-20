# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005, 2007 Mandriva SA
#  Copyright (c) 2013 Matteo Pasotti <matteo.pasotti@gmail.com>
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
# $Id: rpmdragora.pm 267936 2010-04-26 16:40:21Z jvictor $

package AdminPanel::rpmdragora;

use lib qw(/usr/lib/libDrakX);
use urpm::download ();
use urpm::prompt;
use urpm::media;

use MDK::Common;
use MDK::Common::System;
use MDK::Common::String;
use MDK::Common::File;
use urpm;
use urpm::cfg;
use URPM;
use URPM::Resolve;
use strict;
use c;
use POSIX qw(_exit);
use common;
use Locale::gettext;
use feature 'state';

use AdminPanel::Shared;
use AdminPanel::Shared::GUI;

our @ISA = qw(Exporter);
our $VERSION = '2.27';
our @EXPORT = qw(
    $changelog_first_config
    $compute_updates
    $filter
    $dont_show_selections
    $ignore_debug_media
    $mandrakeupdate_wanted_categories
    $mandrivaupdate_height
    $mandrivaupdate_width
    $max_info_in_descr
    $mode
    $NVR_searches
    $offered_to_add_sources
    $rpmdragora_height
    $rpmdragora_width
    $tree_flat
    $tree_mode
    $use_regexp
    $typical_width
    $clean_cache
    $auto_select
    add_distrib_update_media
    add_medium_and_check
    but
    but_
    check_update_media_version
    choose_mirror
    distro_type
    fatal_msg
    getbanner
    get_icon
    interactive_list
    interactive_list_
    interactive_msg
    interactive_packtable
    myexit
    readconf
    remove_wait_msg
    run_drakbug
    show_urpm_progress
    slow_func
    slow_func_statusbar
    statusbar_msg
    statusbar_msg_remove
    strip_first_underscore
    update_sources
    update_sources_check
    update_sources_interactive
    update_sources_noninteractive
    wait_msg
    warn_for_network_need
    writeconf
);
our $typical_width = 280;

our $dont_show_selections;

# i18n: IMPORTANT: to get correct namespace (rpmdragora instead of libDrakX)
BEGIN { unshift @::textdomains, qw(rpmdragora urpmi rpm-summary-main rpm-summary-contrib rpm-summary-devel rpm-summary-non-free) }

use yui;
use Glib;
#ugtk2::add_icon_path('/usr/share/rpmdragora/icons');

Locale::gettext::bind_textdomain_codeset('rpmdragora', 'UTF8');

our $mageia_release = MDK::Common::File::cat_(
    -e '/etc/mageia-release' ? '/etc/mageia-release' : '/etc/release'
) || '';
chomp $mageia_release;
our ($distro_version) = $mageia_release =~ /(\d+\.\d+)/;
our ($branded, %distrib);
$branded = -f '/etc/sysconfig/oem'
    and %distrib = MDK::Common::System::distrib();
our $myname_update = $branded ? N_("Software Update") : N_("Mageia Update");

@rpmdragora::prompt::ISA = 'urpm::prompt';

sub rpmdragora::prompt::prompt {
    my ($self) = @_;
    my @answers;
    my $d = ugtk2->new("", grab => 1, if_($::main_window, transient => $::main_window));
    $d->{rwindow}->set_position('center_on_parent');
    gtkadd(
	$d->{window},
	gtkpack(
	    Gtk2::VBox->new(0, 5),
	    Gtk2::WrappedLabel->new($self->{title}),
	    (map { gtkpack(
		Gtk2::HBox->new(0, 5),
		Gtk2::Label->new($self->{prompts}[$_]),
		$answers[$_] = gtkset_visibility(gtkentry(), !$self->{hidden}[$_]),
	    ) } 0 .. $#{$self->{prompts}}),
	    gtksignal_connect(Gtk2::Button->new(N("Ok")), clicked => sub { Gtk2->main_quit }),
	),
    );
    $d->main;
    map { $_->get_text } @answers;
}

$urpm::download::PROMPT_PROXY = new rpmdragora::prompt(
    N_("Please enter your credentials for accessing proxy\n"),
    [ N_("User name:"), N_("Password:") ],
    undef,
    [ 0, 1 ],
);

sub myexit {
    writeconf();
    #ugtk2::exit(undef, @_);
}

my ($root) = grep { $_->[2] == 0 } list_passwd();
$ENV{HOME} = $> == 0 ? $root->[7] : $ENV{HOME} || '/root';
$ENV{HOME} = $::env if $::env = $AdminPanel::Rpmdragora::init::rpmdragora_options{env}[0];

our $configfile = "$ENV{HOME}/.rpmdragora";

#
# Configuration File Options
#

# clear download cache after successfull installation of packages
our $clean_cache;

# automatic select dependencies without user intervention
our $auto_select;

our ($changelog_first_config, $compute_updates, $filter, $max_info_in_descr, $mode, $NVR_searches, $tree_flat, $tree_mode, $use_regexp);
our ($mandrakeupdate_wanted_categories, $ignore_debug_media, $offered_to_add_sources, $no_confirmation);
our ($rpmdragora_height, $rpmdragora_width, $mandrivaupdate_height, $mandrivaupdate_width);

our %config = (
    clean_cache => { 
	var => \$clean_cache, 
	default => [ 0 ] 
    },
    auto_select => { 
	var => \$auto_select, 
	default => [ 0 ] 
    },
    changelog_first_config => { var => \$changelog_first_config, default => [ 0 ] },
    compute_updates => { var => \$compute_updates, default => [ 1 ] },
    dont_show_selections => { var => \$dont_show_selections, default => [ $> ? 1 : 0 ] },
    filter => { var => \$filter, default => [ 'all' ] },
    ignore_debug_media => { var => \$ignore_debug_media, default => [ 0 ] },
    mandrakeupdate_wanted_categories => { var => \$mandrakeupdate_wanted_categories, default => [ qw(security) ] },
    mandrivaupdate_height => { var => \$mandrivaupdate_height, default => [ 0 ] },
    mandrivaupdate_width => { var => \$mandrivaupdate_width, default => [ 0 ] },
    max_info_in_descr => { var => \$max_info_in_descr, default => [] },
    mode => { var => \$mode, default => [ 'by_group' ] },
    NVR_searches => { var => \$NVR_searches, default => [ 0 ] },
    'no-confirmation' => { var => \$no_confirmation, default => [ 0 ] },
    offered_to_add_sources => { var => \$offered_to_add_sources, default => [ 0 ] },
    rpmdragora_height => { var => \$rpmdragora_height, default => [ 0 ] },
    rpmdragora_width => { var => \$rpmdragora_width, default => [ 0 ] },
    tree_flat => { var => \$tree_flat, default => [ 0 ] },
    tree_mode => { var => \$tree_mode, default => [ qw(gui_pkgs) ] },
    use_regexp => { var => \$use_regexp, default => [ 0 ] },
);

sub readconf() {
    ${$config{$_}{var}} = $config{$_}{default} foreach keys %config;
    foreach my $l (MDK::Common::File::cat_($configfile)) {
	foreach (keys %config) {
	    ${$config{$_}{var}} = [ split ' ', $1 ] if $l =~ /^\Q$_\E(.*)/;
	}
    }
    # special cases:
    $::rpmdragora_options{'no-confirmation'} = $no_confirmation->[0] if !defined $::rpmdragora_options{'no-confirmation'};
    $AdminPanel::Rpmdragora::init::default_list_mode = $tree_mode->[0] if ref $tree_mode && !$AdminPanel::Rpmdragora::init::overriding_config;
}

sub writeconf() {
    return if $::env;
    unlink $configfile;

    # special case:
    $no_confirmation->[0] = $::rpmdragora_options{'no-confirmation'};

    MDK::Common::File::output($configfile, map { "$_ " . (ref ${$config{$_}{var}} ? join(' ', @${$config{$_}{var}}) : undef) . "\n" } keys %config);
}

sub getbanner() {
    $::MODE or return undef;
    if (0) {
	+{
	remove  => N("Software Packages Removal"),
	update  => N("Software Packages Update"),
	install => N("Software Packages Installation"),
	};
    }
#    Gtk2::Banner->new($ugtk2::wm_icon, $::MODE eq 'update' ? N("Software Packages Update") : N("Software Management"));
}

# return value:
# - undef if if closed (aka really canceled)
# - 0 if if No/Cancel
# - 1 if if Yes/Ok
sub interactive_msg {
    my ($title, $contents, %options) = @_;
    my $sh_gui = AdminPanel::Shared::GUI->new();

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);

    my $info;
    $info->{title} = $title;

    if ($options{scroll}) {
        $info->{richtext} = 1;
        ## richtext needs <br> instead of '\n'
        $contents =~ s/\n/<br>/g;
    }

    $info->{text} = $contents;

    my $dlg;

    if ($options{yesno}) {
        $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_TWO);
        $dlg->setButtonLabel($options{text}{yes} || N("Yes"), $yui::YMGAMessageBox::B_ONE);
        $dlg->setButtonLabel($options{text}{no}  || N("No"),  $yui::YMGAMessageBox::B_TWO);
    }
    else {
        $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_ONE);
        $dlg->setButtonLabel(N("Ok"), $yui::YMGAMessageBox::B_ONE );
    }

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});
    $dlg->setDefaultButton($yui::YMGAMessageBox::B_ONE);

    $dlg->setMinSize(75, 6);

    $retVal = $dlg->show() == $yui::YMGAMessageBox::B_ONE ? 1 : 0;

    $dlg = undef;

    return $retVal;

=comment
    return $sh_gui->ask_YesOrNo({ title => $title, text => $contents, richtext => 0});
=cut
}

sub interactive_packtable {
    my ($title, $parent_window, $top_label, $lines, $action_buttons) = @_;
    
    my $w = ugtk2->new($title, grab => 1, transient => $parent_window);
    local $::main_window = $w->{real_window};
    $w->{rwindow}->set_position($parent_window ? 'center_on_parent' : 'center');
    my $packtable = create_packtable({}, @$lines);

    gtkadd($w->{window},
	   gtkpack_(Gtk2::VBox->new(0, 5),
		    if_($top_label, 0, Gtk2::Label->new($top_label)),
		    1, create_scrolled_window($packtable),
		    0, gtkpack__(create_hbox(), @$action_buttons)));
    my $preq = $packtable->size_request;
    my ($xpreq, $ypreq) = ($preq->width, $preq->height);
    my $wreq = $w->{rwindow}->size_request;
    my ($xwreq, $ywreq) = ($wreq->width, $wreq->height);
    $w->{rwindow}->set_default_size(max($typical_width, min($typical_width*2.5, $xpreq+$xwreq)),
 				    max(200, min(450, $ypreq+$ywreq)));
    $w->main;
}

sub interactive_list {
    my ($title, $contents, $list, $callback, %options) = @_;

    my $factory = yui::YUI::widgetFactory;
    my $mainw = $factory->createPopupDialog();
    my $vbox = $factory->createVBox($mainw);
    my $lbltitle = $factory->createLabel($vbox, N("Dependencies"));
    my $radiobuttongroup = $factory->createRadioButtonGroup($vbox);
    my $rbbox = $factory->createVBox($radiobuttongroup);
    foreach my $item(@$list){
        my $radiobutton = $factory->createRadioButton($rbbox,$item);
        $radiobutton->setNotify(0);
        $radiobuttongroup->addRadioButton($radiobutton);
    }
    my $submitButton = $factory->createIconButton($vbox,"", N("OK"));
    my $choice;

    while(1) {
        my $event = $mainw->waitForEvent();
        my $eventType = $event->eventType();
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            $mainw->destroy();
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();

            if($widget == $submitButton) {
                $choice = $radiobuttongroup->currentButton->label();
                $choice =~s/\&//g;
                last;
            }
        }
    }
    $mainw->destroy();
    return $choice;
}

sub interactive_list_ { interactive_list(@_, if_($::main_window, transient => $::main_window)) }

sub fatal_msg {
    interactive_msg @_;
    myexit -1;
}

sub wait_msg {
    my ($msg, %options) = @_;
    #OLD my $mainw = ugtk2->new(N("Please wait"), grab => 1, if_(exists $options{transient}, transient => $options{transient}));
    #$mainw->{real_window}->set_position($options{transient} ? 'center_on_parent' : 'center_always');
    #my $label = $factory->createLabel($vbox, $msg);
    #OLD my $label = ref($msg) =~ /^Gtk/ ? $msg : Gtk2::WrappedLabel->new($msg);
    #gtkadd(
	#$mainw->{window},
	#gtkpack__(
	#    gtkset_border_width(Gtk2::VBox->new(0, 5), 6),
	#    $label,
	#    if_(exists $options{widgets}, @{$options{widgets}}),
	#)
    #);
    my $factory = yui::YUI::widgetFactory;
    my $mainw = $factory->createPopupDialog();
    my $vbox = $factory->createVBox($mainw);
    my $title = $factory->createLabel($vbox, N("Please wait"));
    #$mainw->recalcLayout();
    #$mainw->doneMultipleChanges();
    $mainw->waitForEvent(10);
    $mainw->pollEvent();
    #$mainw->recalcLayout();
    #$mainw->doneMultipleChanges();
    yui::YUI::app()->busyCursor();

    $mainw;
}

sub remove_wait_msg {
    my $w = shift;
    #gtkset_mousecursor_normal($w->{rwindow}->window);
    $w->destroy;
    yui::YUI::app()->normalCursor();
}

sub but { "    $_[0]    " }
sub but_ { "        $_[0]        " }

sub slow_func ($&) {
    my ($param, $func) = @_;
    if (ref($param) =~ /^Gtk/) {
	#gtkset_mousecursor_wait($param);
	#ugtk2::flush();
	#$func->();
	#gtkset_mousecursor_normal($param);
    } else {
		my $w = wait_msg($param);
		$func->();
		remove_wait_msg($w);
    }
}

sub statusbar_msg {
    unless ($::statusbar) { #- fallback if no status bar
	if (defined &::wait_msg_) { goto &::wait_msg_ } else { goto &wait_msg }
    }
    my ($msg, $o_timeout) = @_;
    $::statusbar->setText($msg);
    #- always use the same context description for now
    #my $cx = $::statusbar->get_context_id("foo");
    #$::w and $::w->{rwindow} and gtkset_mousecursor_wait($::w->{rwindow}->window);
    #- returns a msg_id to be passed optionnally to statusbar_msg_remove
    #my $id = $::statusbar->push($cx, $msg);
    #gtkflush();
    #Glib::Timeout->add(5000, sub { statusbar_msg_remove($id); 0 }) if $o_timeout;
    Glib::Timeout->add(5000, sub { statusbar_msg_remove(); 0 }) if $o_timeout;
    #$id;
}

sub statusbar_msg_remove {
    #my ($msg_id) = @_;
    #if (!$::statusbar || ref $msg_id) { #- fallback if no status bar
	#goto &remove_wait_msg;
    #}
    #my $cx = $::statusbar->get_context_id("foo");
    #if (defined $msg_id) {
	#$::statusbar->remove($cx, $msg_id);
    #} else {
	#$::statusbar->pop($cx);
    #}
    #$::w and $::w->{rwindow} and gtkset_mousecursor_normal($::w->{rwindow}->window);
    $::statusbar->setValue("");
}

sub slow_func_statusbar ($$&) {
    my ($msg, $w, $func) = @_;
    gtkset_mousecursor_wait($w->window);
    my $msg_id = statusbar_msg($msg);
    gtkflush();
    $func->();
    statusbar_msg_remove($msg_id);
    gtkset_mousecursor_normal($w->window);
}

my %u2l = (
       ar => N_("Argentina"),
       at => N_("Austria"),
       au => N_("Australia"),
       by => N_("Belarus"),
       be => N_("Belgium"),
       br => N_("Brazil"),
       gb => N_("Britain"),
       ca => N_("Canada"),
       ch => N_("Switzerland"),
       cr => N_("Costa Rica"),
       cz => N_("Czech Republic"),
       de => N_("Germany"),
       dk => N_("Danmark"),
       ec => N_("Ecuador"),
       el => N_("Greece"),
       es => N_("Spain"),
       fi => N_("Finland"),
       fr => N_("France"),
       gr => N_("Greece"),
       hu => N_("Hungary"),
       il => N_("Israel"),
       it => N_("Italy"),
       jp => N_("Japan"),
       ko => N_("Korea"),
       nl => N_("Netherlands"),
       no => N_("Norway"),
       pl => N_("Poland"),
       pt => N_("Portugal"),
       ru => N_("Russia"),
       se => N_("Sweden"),
       sg => N_("Singapore"),
       sk => N_("Slovakia"),
       za => N_("South Africa"),
       tw => N_("Taiwan"),
       th => N_("Thailand"),
       tr => N_("Turkey"),
       uk => N_("United Kingdom"),
       cn => N_("China"),
       us => N_("United States"),
       com => N_("United States"),
       org => N_("United States"),
       net => N_("United States"),
       edu => N_("United States"),
);
my $us = [ qw(us com org net edu) ];
my %t2l = (
       'America/\w+' =>       $us,
       'Asia/Tel_Aviv' =>     [ qw(il ru it cz at de fr se) ],
       'Asia/Tokyo' =>        [ qw(jp ko tw), @$us ],
       'Asia/Seoul' =>        [ qw(ko jp tw), @$us ],
       'Asia/Taipei' =>       [ qw(tw jp), @$us ],
       'Asia/(Shanghai|Beijing)' => [ qw(cn tw sg), @$us ],
       'Asia/Singapore' =>    [ qw(cn sg), @$us ],
       'Atlantic/Reykjavik' => [ qw(gb uk no se fi dk), @$us, qw(nl de fr at cz it) ],
       'Australia/\w+' =>     [ qw(au jp ko tw), @$us ],
       'Brazil/\w+' =>        [ 'br', @$us ],
       'Canada/\w+' =>        [ 'ca', @$us ],
       'Europe/Amsterdam' =>  [ qw(nl be de at cz fr se dk it) ],
       'Europe/Athens' =>     [ qw(gr pl cz de it nl at fr) ],
       'Europe/Berlin' =>     [ qw(de be at nl cz it fr se) ],
       'Europe/Brussels' =>   [ qw(be de nl fr cz at it se) ],
       'Europe/Budapest' =>   [ qw(cz it at de fr nl se) ],
       'Europe/Copenhagen' => [ qw(dk nl de be se at cz it) ],
       'Europe/Dublin' =>     [ qw(gb uk fr be nl dk se cz it) ],
       'Europe/Helsinki' =>   [ qw(fi se no nl be de fr at it) ],
       'Europe/Istanbul' =>   [ qw(il ru it cz it at de fr nl se) ],
       'Europe/Lisbon' =>     [ qw(pt es fr it cz at de se) ],
       'Europe/London' =>     [ qw(gb uk fr be nl de at cz se it) ],
       'Europe/Madrid' =>     [ qw(es fr pt it cz at de se) ],
       'Europe/Moscow' =>     [ qw(ru de pl cz at se be fr it) ],
       'Europe/Oslo' =>       [ qw(no se fi dk de be at cz it) ],
       'Europe/Paris' =>      [ qw(fr be de at cz nl it se) ],
       'Europe/Prague' =>     [ qw(cz it at de fr nl se) ],
       'Europe/Rome' =>       [ qw(it fr cz de at nl se) ],
       'Europe/Stockholm' =>  [ qw(se no dk fi nl de at cz fr it) ],
       'Europe/Vienna' =>     [ qw(at de cz it fr nl se) ],
);

#- get distrib release number (2006.0, etc)
sub etc_version() {
    (my $v) = split / /, MDK::Common::File::cat_('/etc/version');
    return $v;
}

#- returns the keyword describing the type of the distribution.
#- the parameter indicates whether we want base or update sources
sub distro_type {
    my ($want_base_distro) = @_;
    return 'cauldron' if $mageia_release =~ /cauldron/i;
    #- we can't use updates for community while official is not out (release ends in ".0")
    if ($want_base_distro || $mageia_release =~ /community/i && etc_version() =~ /\.0$/) {
	return 'official' if $mageia_release =~ /official|limited/i;
	return 'community' if $mageia_release =~ /community/i;
	#- unknown: fallback to updates
    }
    return 'updates';
}

sub compat_arch_for_updates($) {
    # FIXME: We prefer 64-bit packages to update on biarch platforms,
    # since the system is populated with 64-bit packages anyway.
    my ($arch) = @_;
    return $arch =~ /x86_64|amd64/ if arch() eq 'x86_64';
    MDK::Common::System::compat_arch($arch);
}

sub add_medium_and_check {
    my ($urpm, $options) = splice @_, 0, 2;
    my @newnames = ($_[0]); #- names of added media
    my $fatal_msg;
    my @error_msgs;
    local $urpm->{fatal} = sub { printf STDERR "Fatal: %s\n", $_[1]; $fatal_msg = $_[1]; goto fatal_error };
    local $urpm->{error} = sub { printf STDERR "Error: %s\n", $_[0]; push @error_msgs, $_[0] };
    if ($options->{distrib}) {
        @newnames = urpm::media::add_distrib_media($urpm, @_);
    } else {
        urpm::media::add_medium($urpm, @_);
    }
    if (@error_msgs) {
        interactive_msg(
            N("Error"),
            N("Unable to add medium, errors reported:\n\n%s",
            join("\n", map { MDK::Common::String::formatAlaTeX($_) } @error_msgs)) . "\n\n" . N("Medium: ") . "$_[0] ($_[1])",
            scroll => 1,
        );
        return 0;
    }

    foreach my $name (@newnames) {
        urpm::download::set_proxy_config($_, $options->{proxy}{$_}, $name) foreach keys %{$options->{proxy} || {}};
    }

    if (update_sources_check($urpm, $options, N_("Unable to add medium, errors reported:\n\n%s"), @newnames)) {
        urpm::media::write_config($urpm);
        $options->{proxy} and urpm::download::dump_proxy_config();
    } else {
        urpm::media::read_config($urpm, 0);
        return 0;
    }

    my %newnames; @newnames{@newnames} = ();
    if (any { exists $newnames{$_->{name}} } @{$urpm->{media}}) {
        return 1;
    } else {
        interactive_msg(N("Error"), N("Unable to create medium."));
        return 0;
    }

  fatal_error:
    interactive_msg(N("Failure when adding medium"),
                    N("There was a problem adding medium:\n\n%s", $fatal_msg));
    return 0;
}

sub update_sources_check {
    my ($urpm, $options, $error_msg, @media) = @_;
    my @error_msgs;
    local $urpm->{fatal} = sub { push @error_msgs, $_[1]; goto fatal_error };
    local $urpm->{error} = sub { push @error_msgs, $_[0] };
    update_sources($urpm, %$options, noclean => 1, medialist => \@media);
  fatal_error:
    if (@error_msgs) {
        interactive_msg(N("Error"), translate($error_msg, join("\n", map { formatAlaTeX($_) } @error_msgs)), scroll => 1);
        return 0;
    }
    return 1;
}

sub update_sources {
    my ($urpm, %options) = @_;
    my $cancel = 0;


    my $factory = yui::YUI::widgetFactory;

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("rpmdragora"));

    my $dlg = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dlg, 80, 5 );
    my $vbox = $factory->createVBox($minSize);
    my $hbox = $factory->createHBox($factory->createLeft($vbox));
    my $label = $factory->createRichText($hbox, N("Please wait, updating media..."), 1 );
    $label->setWeight($yui::YD_HORIZ, 1);
    $label->setWeight($yui::YD_VERT, 1);

    my $pb = $factory->createProgressBar( $vbox, "");
    $pb->setValue(0);
    # NOTE urpm::media::update_those_media seems not to say anything
    #      when downloads and tests md5sum
    #      a fake event (timeout 10 msec) allow to draw the waiting
    #      dialog
    $dlg->waitForEvent(10);
    $dlg->pollEvent();

    my @media; @media = @{$options{medialist}} if ref $options{medialist};
    my $outerfatal = $urpm->{fatal};
    local $urpm->{fatal} = sub { $outerfatal->(@_) };
    urpm::media::update_those_media($urpm, [ urpm::media::select_media_by_name($urpm, \@media) ],
        %options, allow_failures => 1,
        callback => sub {
            $cancel and goto cancel_update;
            my ($type, $media) = @_;
            goto cancel_update if $type !~ /^(?:start|progress|end)$/ && @media && !member($media, @media);
            if ($type eq 'failed') {
                $urpm->{fatal}->(N("Error retrieving packages"),
N("It's impossible to retrieve the list of new packages from the media
`%s'. Either this update media is misconfigured, and in this case
you should use the Software Media Manager to remove it and re-add it in order
to reconfigure it, either it is currently unreachable and you should retry
later.",
    $media));
            } else {
                show_urpm_progress($label, $pb, @_);
                $dlg->pollEvent();
            }
        },
    );

    $pb->setValue(100);
    $dlg->waitForEvent(10);
    $dlg->pollEvent();

cancel_update:
    $dlg->destroy();
}

sub show_urpm_progress {
    my ($label, $pb, $mode, $file, $percent, $total, $eta, $speed) = @_;
    $file =~ s|([^:]*://[^/:\@]*:)[^/:\@]*(\@.*)|$1xxxx$2|; #- if needed...
    state $medium;

    if ($mode eq 'copy') {
        $pb->setValue(0);
        $label->setValue(N("Copying file for medium `%s'...", $file));
    } elsif ($mode eq 'parse') {
        $pb->setValue(0);
        $label->setValue(N("Examining file of medium `%s'...", $file));
    } elsif ($mode eq 'retrieve') {
        $pb->setValue(0);
        $label->setValue(N("Examining remote file of medium `%s'...", $file));
        $medium = $file;
    } elsif ($mode eq 'done') {
        $pb->setValue(100);
        $label->setValue($label->value() . N(" done."));
        $medium = undef;
    } elsif ($mode eq 'failed') {
        $pb->setValue(100);
        $label->setValue($label->value() . N(" failed!"));
        $medium = undef;
    } else {
        # FIXME: we're displaying misplaced quotes such as "downloading `foobar from 'medium Main Updates'´"
        $file = $medium && length($file) < 40 ? #-PO: We're downloading the said file from the said medium
                                                 N("%s from medium %s", basename($file), $medium)
                                               : basename($file);
        if ($mode eq 'start') {
            $pb->setValue(0);
            $label->setValue(N("Starting download of `%s'...", $file));
        } elsif ($mode eq 'progress') {
            if (defined $total && defined $eta) {
                $pb->setValue($percent);
                $label->setValue(N("Download of `%s'\ntime to go:%s, speed:%s", $file, $eta, $speed));
            } else {
                $pb->setValue($percent);
                $label->setValue(N("Download of `%s'\nspeed:%s", $file, $speed));
            }
        }
    }
}


sub update_sources_interactive {
    my ($urpm, %options) = @_;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Update media"));

    my $retVal  = 0;
    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);

    my $dialog = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 60, 15 );
    my $vbox = $factory->createVBox($minSize);

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn("", $yui::YAlignBegin);
    $yTableHeader->addColumn(N("Media"),  $yui::YAlignBegin);

    my $mediaTable = $mgaFactory->createCBTable($vbox, $yTableHeader, $yui::YCBTableCheckBoxOnFirstColumn);
    my @media = grep { ! $_->{ignore} } @{$urpm->{media}};
    unless (@media) {
        interactive_msg(N("Warning"), N("No active medium found. You must enable some media to be able to update them."));
        return 0;
    }

    my $itemCollection = new yui::YItemCollection;
    foreach (@media) {
        my $item = new yui::YCBTableItem($_->{name});
        $item->setLabel($_->{name});
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $mediaTable->addItems($itemCollection);

    # dialog buttons
    $factory->createVSpacing($vbox, 1.0);
    ## Window push buttons
    my $hbox = $factory->createHBox( $vbox );

    my $cancelButton = $factory->createPushButton($hbox, N("Cancel") );
    my $selectButton = $factory->createPushButton($hbox, N("Select all") );
    my $updateButton = $factory->createPushButton($hbox, N("Update") );

    while(1) {
        my $event       = $dialog->waitForEvent();
        my $eventType   = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            my $wEvent = yui::toYWidgetEvent($event);

            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $selectButton) {
                yui::YUI::app()->busyCursor();
                yui::YUI::ui()->blockEvents();
                $dialog->startMultipleChanges();
                for (my $it = $mediaTable->itemsBegin(); $it != $mediaTable->itemsEnd(); ) {
                    my $item  = $mediaTable->YItemIteratorToYItem($it);
                    if ($item) {
                        $mediaTable->checkItem($item, 1);
                        # NOTE for some reasons it is never == $mediaTable->itemsEnd()
                        if ($item->index() == $mediaTable->itemsCount()-1) {
                            last;
                        }
                    }
                    $it = $mediaTable->nextItem($it);
                }
                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::ui()->unblockEvents();
                yui::YUI::app()->normalCursor();

            }
            elsif ($widget == $updateButton) {
                yui::YUI::app()->busyCursor();
                my @checked_media;
                for (my $it = $mediaTable->itemsBegin(); $it != $mediaTable->itemsEnd(); ) {
                    my $item  = $mediaTable->YItemIteratorToYItem($it);
                    $item = $mediaTable->toCBYTableItem($item);
                    if ($item) {
                        if ($item->checked()) {
                            push @checked_media, $item->label();
                        }
                        # NOTE for some reasons it is never == $mediaTable->itemsEnd()
                        if ($item->index() == $mediaTable->itemsCount()-1) {
                            last;
                        }
                    }
                    $it = $mediaTable->nextItem($it);
                }

                $retVal = update_sources_noninteractive($urpm, \@checked_media, %options);
                yui::YUI::app()->normalCursor();
                last;
            }
        }
    }

    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $retVal;
}

sub update_sources_noninteractive {
    my ($urpm, $media, %options) = @_;

        urpm::media::select_media_by_name($urpm, $media);
        update_sources_check(
            $urpm,
            {},
            N_("Unable to update medium; it will be automatically disabled.\n\nErrors:\n%s"),
            @$media,
        );
        return 1;
}

sub add_distrib_update_media {
    my ($urpm, $mirror, %options) = @_;
    #- ensure a unique medium name
    my $medium_name = $AdminPanel::rpmdragora::mageia_release =~ /(\d+\.\d+) \((\w+)\)/ ? $2 . $1 . '-' : 'distrib';
    my $initial_number = 1 + max map { $_->{name} =~ /\(\Q$medium_name\E(\d+)\b/ ? $1 : 0 } @{$urpm->{media}};
    $DB::single = 1;
    add_medium_and_check(
        $urpm,
        { nolock => 1, distrib => 1 },
        $medium_name,
        ($mirror ? $mirror->{url} : (undef, mirrorlist => '$MIRRORLIST')),
        probe_with => 'synthesis', initial_number => $initial_number, %options,
        usedistrib => 1,
    );
}

sub warn_for_network_need {
    my ($message, %options) = @_;
    $message ||=
        $branded
        ? N("I need to access internet to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?")
        : N("I need to contact the Mageia website to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?");
    interactive_msg(N("Mirror choice"), $message, yesno => 1, %options) or return '';
}

sub choose_mirror {
    my ($urpm, %options) = @_;
    delete $options{message};
    my @transient_options = exists $options{transient} ? (transient => $options{transient}) : ();
    warn_for_network_need($options{message}, %options) or return;
    my @mirrors = eval { mirrors($urpm, $options{want_base_distro}) };
    my $error = $@;
    if ($error) {
        $error = "\n$error\n";
        interactive_msg(N("Error during download"),
                        ($branded
                        ? N("There was an error downloading the mirror list:\n%s\n
The network, or the website, may be unavailable.
Please try again later.", $error)
                        : N("There was an error downloading the mirror list:\n%s\n
The network, or the Mageia website, may be unavailable.
Please try again later.", $error)), %options
        );
        return '';
    }

    !@mirrors and interactive_msg(N("No mirror"),
                                  ($branded
                                  ? N("I can't find any suitable mirror.")
                                  : N("I can't find any suitable mirror.\n
There can be many reasons for this problem; the most frequent is
the case when the architecture of your processor is not supported
by Mageia Official Updates.")), %options
    ), return '';

    my @mirrorlist = map {$_->{country} . "|" . $_->{url}} @mirrors;

    my $sh_gui = AdminPanel::Shared::GUI->new();
    my $mirror = $sh_gui->ask_fromTreeList({title => N("Mirror choice"),
        header => N("Please choose the desired mirror."),
        default_button => 1,
        item_separator => "|",
        default_item => $mirrors[0]->{url},
        skip_path => 1,
        list  => \@mirrorlist }
    );

    return $mirror ? { url => $mirror} : undef;

}







#- Check whether the default update media (added by installation)
#- matches the current mdk version
sub check_update_media_version {
    my $urpm = shift;
    foreach (@_) {
        if ($_->{name} =~ /(\d+\.\d+).*\bftp\du\b/ && $1 ne $distro_version) {
            interactive_msg(
                N("Warning"),
                $branded
                ? N("Your medium `%s', used for updates, does not match the version of %s you're running (%s).
It will be disabled.",
                    $_->{name}, $distrib{system}, $distrib{product})
                : N("Your medium `%s', used for updates, does not match the version of Mageia you're running (%s).
It will be disabled.",
                    $_->{name}, $distro_version)
            );
            $_->{ignore} = 1;
            urpm::media::write_config($urpm) if -w $urpm->{config};
            return 0;
        }
    }
    1;
}



sub mirrors {
    my ($urpm, $want_base_distro) = @_;
    my $cachedir = $urpm->{cachedir} || '/root';
    require mirror;
    mirror::register_downloader(
        sub {
            my ($url) = @_;
            my $file = $url;
            $file =~ s!.*/!$cachedir/!;
            unlink $file;       # prevent "partial file" errors
            before_leaving(sub { unlink $file });

            my ($gurpm, $id, $canceled);
            # display a message in statusbar (if availlable):
            $::statusbar and $id = statusbar_msg(
                $branded
                  ? N("Please wait, downloading mirror addresses.")
                    : N("Please wait, downloading mirror addresses from the Mageia website."),
                0);
            my $_clean_guard = before_leaving {
                undef $gurpm;
                $id and statusbar_msg_remove($id);
            };

            require AdminPanel::Rpmdragora::gurpm;
            require AdminPanel::Rpmdragora::pkg;

            my $res = urpm::download::sync_url($urpm, $url,
                                           dir => $cachedir,
                                           callback => sub {
                                               $gurpm ||=
                                                 AdminPanel::Rpmdragora::gurpm->new(N("Please wait"),
                                                                      transient => $::main_window);
                                               $canceled ||=
                                                 !AdminPanel::Rpmdragora::pkg::download_callback($gurpm, @_);
                                               $gurpm->flush();
                                           },
                                       );
            $res or die N("retrieval of [%s] failed", $file) . "\n";
            return $canceled ? () : MDK::Common::File::cat_($file);
        });
    my @mirrors = @{ mirror::list(common::parse_LDAP_namespace_structure(MDK::Common::File::cat_('/etc/product.id')), 'distrib') || [] };

    require AdminPanel::Shared::TimeZone;
    my $tzo = AdminPanel::Shared::TimeZone->new();
    my $tz = $tzo->readConfiguration()->{ZONE};
    foreach my $mirror (@mirrors) {
        my $goodness = 0;
        my $pri_mirr = defined ($t2l{$tz}) ? $t2l{$tz} : $us;
        my $ind = 0;
        foreach (@{$pri_mirr}) {
            if ($_ eq lc($mirror->{country})) {
                $goodness = scalar(@{$pri_mirr}) - $ind;
            }
            $ind ++;
        }

        $mirror->{goodness} = $goodness + rand();
        $mirror->{country} = $u2l{lc($mirror->{country})} ? translate($u2l{lc($mirror->{country})}) : $mirror->{country};
    }
    unless (-x '/usr/bin/rsync') {
    @mirrors = grep { $_->{url} !~ /^rsync:/ } @mirrors;
    }
    return sort { $b->{goodness} <=> $a->{goodness} } @mirrors;
}





sub open_help {
    my ($mode) = @_;
    use run_program;
    run_program::raw({ detach => 1, as_user => 1 },  'drakhelp', '--id', $mode ?  "software-management-$mode" : 'software-management');
    my $_s = N("Help launched in background");
    statusbar_msg(N("The help window has been started, it should appear shortly on your desktop."), 1);
}

sub run_drakbug {
    my ($id) = @_;
    run_program::raw({ detach => 1, as_user => 1 }, 'drakbug', '--report', $id);
}

#mygtk2::add_icon_path('/usr/share/mcc/themes/default/');
sub get_icon {
    my ($mcc_icon, $fallback_icon) = @_;
    my $icon = eval { mygtk2::_find_imgfile($mcc_icon) };
    $icon ||= eval { mygtk2::_find_imgfile($fallback_icon) };
    $icon;
}

sub strip_first_underscore { join '', map { s/_//; $_ } @_ }

1;
