# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005, 2007 Mandriva SA
#  Copyright (c) 2013-2016 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package ManaTools::rpmdragora;
use warnings::register;

use urpm;
use urpm::cfg;
use urpm::mirrors;
use urpm::download ();
use urpm::prompt;
use urpm::media;

# quick fix for mirror.pm
use lib qw(/usr/lib/libDrakX);

use MDK::Common;
use MDK::Common::System;
use MDK::Common::String;
use MDK::Common::Func;
use MDK::Common::File qw(basename cat_ output);
use URPM;
use URPM::Resolve;
use strict;
use POSIX qw(_exit);

use feature 'state';

use ManaTools::Shared;
use ManaTools::Shared::Locales;
use ManaTools::Shared::GUI;

use Carp;

our @ISA = qw(Exporter);
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
    locale
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

our $mageia_release = MDK::Common::File::cat_(
    -e '/etc/mageia-release' ? '/etc/mageia-release' : '/etc/release'
) || '';
chomp $mageia_release;
our ($distro_version) = $mageia_release =~ /(\d+\.\d+)/;
our ($branded, %distrib);
$branded = -f '/etc/sysconfig/oem'
    and %distrib = MDK::Common::System::distrib();

@rpmdragora::prompt::ISA = 'urpm::prompt';

# Locale::gettext::bind_textdomain_codeset('rpmdragora', 'UTF8');
my $loc;

sub locale() {
    my $lc;

    if (defined($loc)) {
        $lc = $loc;
    }
    else {
        my $cmdline    = new yui::YCommandLine;
        my $locale_dir = undef;
        my $pos        = $cmdline->find("--locales-dir");
        if ($pos > 0)
        {
            $locale_dir = $cmdline->arg($pos+1);
        }
        $lc = ManaTools::Shared::Locales->new(
                domain_name => 'manatools',
                dir_name    => $locale_dir,
        );
   }

   return $lc;
}

# Locale::gettext::bind_textdomain_codeset('rpmdragora', 'UTF8');
$loc = ManaTools::rpmdragora::locale();
our $myname_update = $branded ? $loc->N_("Software Update") : $loc->N_("Mageia Update");


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
	    gtksignal_connect(Gtk2::Button->new($loc->N("Ok")), clicked => sub { Gtk2->main_quit }),
	),
    );
    $d->main;
    map { $_->get_text } @answers;
}

$urpm::download::PROMPT_PROXY = new rpmdragora::prompt(
    $loc->N_("Please enter your credentials for accessing proxy\n"),
    [ $loc->N_("User name:"), $loc->N_("Password:") ],
    undef,
    [ 0, 1 ],
);

sub myexit {
    writeconf();
    destroy $::main_window if $::main_window;
    exit @_;
}

my ($root) = grep { $_->[2] == 0 } list_passwd();
$ENV{HOME} = $> == 0 ? $root->[7] : $ENV{HOME} || '/root';
$ENV{HOME} = $::env if $::env = $ManaTools::Rpmdragora::init::rpmdragora_options{env}[0];

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
        my ($key, @values) =  split ' ', $l;
        ${$config{$key}{var}} = \@values if scalar @values;
    }
    # special cases:
    $::rpmdragora_options{'no-confirmation'} = $no_confirmation->[0] if !defined $::rpmdragora_options{'no-confirmation'};
    $ManaTools::Rpmdragora::init::default_list_mode = $tree_mode->[0] if ref $tree_mode && !$ManaTools::Rpmdragora::init::overriding_config;
}

sub writeconf() {
    return if $::env;
    unlink $configfile;

    # special case:
    $no_confirmation->[0] = $::rpmdragora_options{'no-confirmation'};
    my @config_content = map { "$_ " . (ref ${$config{$_}{var}} ? join(' ', @${$config{$_}{var}}) : '') . "\n" } sort keys %config;
    MDK::Common::File::output($configfile, @config_content);
    print "writeconf done!\n";
}

sub getbanner() {
    $::MODE or return undef;
    if (0) {
	+{
	remove  => $loc->N("Software Packages Removal"),
	update  => $loc->N("Software Packages Update"),
	install => $loc->N("Software Packages Installation"),
	};
    }
#    Gtk2::Banner->new($ugtk2::wm_icon, $::MODE eq 'update' ? $loc->N("Software Packages Update") : $loc->N("Software Management"));
}


#=============================================================

=head2 interactive_msg

=head3 INPUT

    $title:    dialog title
    $contents: dialog text
    %options:  optional HASH containing {
        scroll         => Rich Text with scroll bar used
        yesno          => dialog with "yes" and "no" buttons (deafult yes)
        dont_ask_again => add a checkbox with "dont ask again text"
        main_dialog    => create a main dialog instead of a popup one
        min_size       => {columns => X, lines => Y} for minimum dialog size,
    }

=head3 OUTPUT

    retval: if dont_ask_again HASH reference containig {
        value          => 1 yes (or ok) pressed, 0 no pressed
        dont_ask_again => 1 if checked
    }
    or if dont_ask_again is not passed:
        1 yes (or ok) pressed, 0 no pressed

=head3 DESCRIPTION

    This function shows a dialog with contents text and return the button
    pressed (1 ok or yes), optionally returns the checkbox value if dont_ask_again is
    passed.
    If min_size is passed a minimum dialog size is set (default is 75x6) see libyui
    createMinSize documenatation for explanation.

=cut

#=============================================================
sub interactive_msg {
    my ($title, $contents, %options) = @_;

    my $retVal = 0;

    my $info;

    if ($options{scroll}) {
        ## richtext needs <br> instead of '\n'
        $contents =~ s/\n/<br>/g;
    }

    my $oldTitle = yui::YUI::app()->applicationTitle();
    yui::YUI::app()->setApplicationTitle($title);

    my $factory = yui::YUI::widgetFactory;
    my $dlg     = $options{main_dialog} ?
        $factory->createMainDialog() :
        $factory->createPopupDialog();
    my $columns = $options{min_size}->{columns} || 75;
    my $lines   = $options{min_size}->{lines} || 6;
    my $minSize = $factory->createMinSize( $dlg, $columns, $lines);
    my $vbox    = $factory->createVBox( $minSize );
    my $midhbox = $factory->createHBox($vbox);
    ## app description
    my $toprightvbox = $factory->createVBox($midhbox);
    $toprightvbox->setWeight($yui::YD_HORIZ, 5);
    $factory->createSpacing($toprightvbox,$yui::YD_HORIZ, 0, 5.0);
    $factory->createRichText($toprightvbox, $contents, !$options{scroll});
    $factory->createSpacing($toprightvbox, $yui::YD_HORIZ, 0, 5.0);

    if ($options{dont_ask_again}){
        my $hbox  = $factory->createHBox($vbox);
        my $align = $factory->createRight($hbox);
        $info->{checkbox} = $factory->createCheckBox($align, $loc->N("Do not ask me next time"));
    }

    my $bottomhbox = $factory->createHBox($vbox);
    if ($options{yesno}) {
        my $alignRight = $factory->createRight($bottomhbox);
        my $buttonBox  = $factory->createHBox($alignRight);

        $info->{B1} = $factory->createPushButton($buttonBox, $options{text}{yes} || $loc->N("&Yes"));
        $info->{B2} = $factory->createPushButton($buttonBox, $options{text}{no}  || $loc->N("&No"));
    }
    else {
        $info->{B1} = $factory->createPushButton($bottomhbox, $loc->N("&Ok"));
    }

    $dlg->setDefaultButton($info->{B1});

    while (1) {
        my $event = $dlg->waitForEvent();
        my $eventType = $event->eventType();
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            $retVal = 1; ##default value
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();

            if ($info->{B1} && $widget == $info->{B1}) {
                $retVal = 1;
                last;
            }
            elsif ($info->{B2} && $widget == $info->{B2}) {
                last;
            }
        }
    }

    if ($info->{checkbox}) {
        my $value = $retVal;
        $retVal = undef;
        $retVal->{value} = $value;
        $retVal->{dont_ask_again} = $info->{checkbox}->isChecked();
    }

    $dlg->destroy();
    yui::YUI::app()->setApplicationTitle($oldTitle);

    return $retVal;
}

sub interactive_list {
    my ($title, $contents, $list, $callback, %options) = @_;

    my $factory = yui::YUI::widgetFactory;
    my $mainw = $factory->createPopupDialog();
    my $vbox = $factory->createVBox($mainw);
    my $lbltitle = $factory->createLabel($vbox, $loc->N("Dependencies"));
    my $left = $factory->createLeft($factory->createHBox($vbox));
    my $radiobuttongroup = $factory->createRadioButtonGroup($left);
    my $rbbox = $factory->createVBox($radiobuttongroup);
    foreach my $item (@$list) {
        my $radiobutton = $factory->createRadioButton($rbbox,$item);
        if ($item eq $list->[0]) {
            # select first by default
            $radiobutton->setValue(1);
        }
        $radiobutton->setNotify(0);
        $radiobuttongroup->addRadioButton($radiobutton);
    }
    my $submitButton = $factory->createIconButton($vbox,"", $loc->N("OK"));
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
                # NOTE if for any reason radio button is not checked let's take the first package
                $choice = $radiobuttongroup->currentButton() ? $radiobuttongroup->currentButton()->label() : $list->[0];
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
    my $msg = shift;

    my $label = $msg ? $msg : $loc->N("Please wait");

    my $factory = yui::YUI::widgetFactory;
    my $mainw = $factory->createPopupDialog();
    my $vbox = $factory->createVBox($mainw);
    my $title = $factory->createLabel($vbox, $label);
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

#=============================================================

=head2 slow_func

=head3 INPUT

    $func: function to be executed with a busy cursor or waiting
           dialog
    $msg:  message to be shown in ncurses waiting dialog (if any)

=head3 DESCRIPTION

    This function executes a given function with a busy cursor set
    in graphical environment, or with a waiting dialog if in ncurses
    text mode

=cut

#=============================================================
sub slow_func (&) {
    my ($func, $msg) = @_;

    my $retval = 1;
    # NOTE busy cursor is not implemented in yui-ncurses
    #      but we can avoid a waiting dialog in Gtk and QT
    if (yui::YUI::app()->isTextMode()) {
        my $w = wait_msg($msg);
        $retval = $func->();
        remove_wait_msg($w)
    }
    else {
        yui::YUI::app()->busyCursor();
        $retval = $func->();
        yui::YUI::app()->normalCursor();
    }
    return $retval;
}

sub statusbar_msg {
    my ($msg, $o_timeout) = @_;

    unless ($::statusbar) { #- fallback if no status bar
        return wait_msg($msg);
    }

    $::statusbar->setLabel($msg);
    #- always use the same context description for now
    #my $cx = $::statusbar->get_context_id("foo");
    #$::w and $::w->{rwindow} and gtkset_mousecursor_wait($::w->{rwindow}->window);
    #- returns a msg_id to be passed optionnally to statusbar_msg_remove
    #my $id = $::statusbar->push($cx, $msg);
    #gtkflush();
    #Glib::Timeout->add(5000, sub { statusbar_msg_remove($id); 0 }) if $o_timeout;
    $::statusbar->setTimeout ( 5000 );
    Glib::Timeout->add(5000, sub { statusbar_msg_remove(); 0 }) if $o_timeout;
    #$id;
    return 1;
}

sub statusbar_msg_remove {
    if (!$::statusbar) { #- fallback if no status bar
        my $id = shift;
	    return remove_wait_msg($id);;
    }
    my ($msg_id) = @_;
    #my $cx = $::statusbar->get_context_id("foo");
    #if (defined $msg_id) {
	#$::statusbar->remove($cx, $msg_id);
    #} else {
	#$::statusbar->pop($cx);
    #}
    #$::w and $::w->{rwindow} and gtkset_mousecursor_normal($::w->{rwindow}->window);
    $::statusbar->setLabel("");
}

sub slow_func_statusbar ($$&) {
    my ($msg, $w, $func) = @_;
    yui::YUI::app()->busyCursor();

    my $msg_id = statusbar_msg($msg);
    $func->();
    statusbar_msg_remove($msg_id);

    yui::YUI::app()->normalCursor();
}

my %u2l = (
       ar => $loc->N_("Argentina"),
       at => $loc->N_("Austria"),
       au => $loc->N_("Australia"),
       by => $loc->N_("Belarus"),
       be => $loc->N_("Belgium"),
       br => $loc->N_("Brazil"),
       gb => $loc->N_("Britain"),
       ca => $loc->N_("Canada"),
       ch => $loc->N_("Switzerland"),
       cr => $loc->N_("Costa Rica"),
       cz => $loc->N_("Czech Republic"),
       de => $loc->N_("Germany"),
       dk => $loc->N_("Danmark"),
       ec => $loc->N_("Ecuador"),
       el => $loc->N_("Greece"),
       es => $loc->N_("Spain"),
       fi => $loc->N_("Finland"),
       fr => $loc->N_("France"),
       gr => $loc->N_("Greece"),
       hu => $loc->N_("Hungary"),
       id => $loc->N_("Indonesia"),
       il => $loc->N_("Israel"),
       it => $loc->N_("Italy"),
       jp => $loc->N_("Japan"),
       ko => $loc->N_("Korea"),
       nl => $loc->N_("Netherlands"),
       no => $loc->N_("Norway"),
       pl => $loc->N_("Poland"),
       pt => $loc->N_("Portugal"),
       ru => $loc->N_("Russia"),
       se => $loc->N_("Sweden"),
       sg => $loc->N_("Singapore"),
       sk => $loc->N_("Slovakia"),
       za => $loc->N_("South Africa"),
       tw => $loc->N_("Taiwan"),
       th => $loc->N_("Thailand"),
       tr => $loc->N_("Turkey"),
       uk => $loc->N_("United Kingdom"),
       cn => $loc->N_("China"),
       us => $loc->N_("United States"),
       com => $loc->N_("United States"),
       org => $loc->N_("United States"),
       net => $loc->N_("United States"),
       edu => $loc->N_("United States"),
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
            $loc->N("Error"),
            $loc->N("Unable to add medium, errors reported:\n\n%s",
            join("\n", map { MDK::Common::String::formatAlaTeX($_) } @error_msgs)) . "\n\n" . $loc->N("Medium: ") . "$_[0] ($_[1])",
            scroll => 1,
        );
        return 0;
    }

    foreach my $name (@newnames) {
        urpm::download::set_proxy_config($_, $options->{proxy}{$_}, $name) foreach keys %{$options->{proxy} || {}};
    }

    if (update_sources_check($urpm, $options, $loc->N_("Unable to add medium, errors reported:\n\n%s"), @newnames)) {
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
        interactive_msg($loc->N("Error"), $loc->N("Unable to create medium."));
        return 0;
    }

  fatal_error:
    interactive_msg($loc->N("Failure when adding medium"),
                    $loc->N("There was a problem adding medium:\n\n%s", $fatal_msg));
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
        interactive_msg($loc->N("Error"), $loc->N($error_msg, join("\n", map { formatAlaTeX($_) } @error_msgs)), scroll => 1);
        return 0;
    }
    return 1;
}

sub update_sources {
    my ($urpm, %options) = @_;
    my $cancel = 0;

    # NOTE urpm::media::_update_medium__parse_if_unmodified__local needs it as string
    $options{probe_with} = "" if !defined($options{probe_with});

    my $factory = yui::YUI::widgetFactory;

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("rpmdragora"));

    my $dlg = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dlg, 80, 5 );
    my $vbox = $factory->createVBox($minSize);
    my $hbox = $factory->createHBox($factory->createLeft($vbox));
    my $label = $factory->createRichText($hbox, $loc->N("Please wait, updating media..."), 1 );
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
                $urpm->{fatal}->($loc->N("Error retrieving packages"),
$loc->N("It's impossible to retrieve the list of new packages from the media
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
        $label->setValue($loc->N("Copying file for medium `%s'...", $file));
    } elsif ($mode eq 'parse') {
        $pb->setValue(0);
        $label->setValue($loc->N("Examining file of medium `%s'...", $file));
    } elsif ($mode eq 'retrieve') {
        $pb->setValue(0);
        $label->setValue($loc->N("Examining remote file of medium `%s'...", $file));
        $medium = $file;
    } elsif ($mode eq 'done') {
        $pb->setValue(100);
        $label->setValue($label->value() . $loc->N(" done."));
        $medium = undef;
    } elsif ($mode eq 'failed') {
        $pb->setValue(100);
        $label->setValue($label->value() . $loc->N(" failed!"));
        $medium = undef;
    } else {
        # FIXME: we're displaying misplaced quotes such as "downloading `foobar from 'medium Main Updates'´"
        $file = $medium && length($file) < 40 ? #-PO: We're downloading the said file from the said medium
                                                 $loc->N("%s from medium %s", basename($file), $medium)
                                               : basename($file);
        if ($mode eq 'start') {
            $pb->setValue(0);
            $label->setValue($loc->N("Starting download of `%s'...", $file));
        } elsif ($mode eq 'progress') {
            if (defined $total && defined $eta) {
                $pb->setValue($percent);
                $label->setValue($loc->N("Download of `%s'\ntime to go:%s, speed:%s", $file, $eta, $speed));
            } else {
                $pb->setValue($percent);
                $label->setValue($loc->N("Download of `%s'\nspeed:%s", $file, $speed));
            }
        }
    }
}


sub update_sources_interactive {
    my ($urpm, %options) = @_;

    my @media = grep { ! $_->{ignore} } @{$urpm->{media}};
    unless (@media) {
        interactive_msg($loc->N("Warning"), $loc->N("No active medium found. You must enable some media to be able to update them."));
        return 0;
    }

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Update media"));

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
    $yTableHeader->addColumn($loc->N("Media"),  $yui::YAlignBegin);

    my $mediaTable = $mgaFactory->createCBTable($vbox, $yTableHeader, $yui::YCBTableCheckBoxOnFirstColumn);

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

    my $cancelButton = $factory->createPushButton($hbox, $loc->N("&Cancel") );
    my $selectButton = $factory->createPushButton($hbox, $loc->N("&Select all") );
    my $updateButton = $factory->createPushButton($hbox, $loc->N("&Update") );

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
            $loc->N_("Unable to update medium; it will be automatically disabled.\n\nErrors:\n%s"),
            @$media,
        );
        return 1;
}

sub add_distrib_update_media {
    my ($urpm, $mirror, %options) = @_;
    #- ensure a unique medium name
    my $medium_name = $ManaTools::rpmdragora::mageia_release =~ /(\d+\.\d+) \((\w+)\)/ ? $2 . $1 . '-' : 'distrib';
    my $initial_number = 1 + max map { $_->{name} =~ /\(\Q$medium_name\E(\d+)\b/ ? $1 : 0 } @{$urpm->{media}};
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
        ? $loc->N("I need to access internet to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?")
        : $loc->N("I need to contact the Mageia website to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?");
    interactive_msg($loc->N("Mirror choice"), $message, yesno => 1, %options) or return '';
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
        interactive_msg($loc->N("Error during download"),
                        ($branded
                        ? $loc->N("There was an error downloading the mirror list:\n%s\n
The network, or the website, may be unavailable.
Please try again later.", $error)
                        : $loc->N("There was an error downloading the mirror list:\n%s\n
The network, or the Mageia website, may be unavailable.
Please try again later.", $error)), %options
        );
        return '';
    }

    !@mirrors and interactive_msg($loc->N("No mirror"),
                                  ($branded
                                  ? $loc->N("I can't find any suitable mirror.")
                                  : $loc->N("I can't find any suitable mirror.\n
There can be many reasons for this problem; the most frequent is
the case when the architecture of your processor is not supported
by Mageia Official Updates.")), %options
    ), return '';

    my @mirrorlist = map {$_->{country} . "|" . $_->{url}} @mirrors;

    my $sh_gui = ManaTools::Shared::GUI->new();
    my $mirror = $sh_gui->ask_fromTreeList({title => $loc->N("Mirror choice"),
        header => $loc->N("Please choose the desired mirror."),
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
                $loc->N("Warning"),
                $branded
                ? $loc->N("Your medium `%s', used for updates, does not match the version of %s you're running (%s).
It will be disabled.",
                    $_->{name}, $distrib{system}, $distrib{product})
                : $loc->N("Your medium `%s', used for updates, does not match the version of Mageia you're running (%s).
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
            MDK::Common::Func::before_leaving(sub { unlink $file });

            my ($gurpm, $id, $canceled);
            # display a message in statusbar (if availlable):
            $::statusbar and $id = statusbar_msg(
                $branded
                  ? $loc->N("Please wait, downloading mirror addresses.")
                    : $loc->N("Please wait, downloading mirror addresses from the Mageia website."),
                0);
            my $_clean_guard = MDK::Common::Func::before_leaving {
                undef $gurpm;
                $id and statusbar_msg_remove($id);
            };

            require ManaTools::Rpmdragora::gurpm;
            require ManaTools::Rpmdragora::pkg;

            my $res = urpm::download::sync_url($urpm, $url,
                                           dir => $cachedir,
                                           callback => sub {
                                               $gurpm ||=
                                                 ManaTools::Rpmdragora::gurpm->new(
                                                     text => $loc->N("Please wait"),
                                                 );
                                               $canceled ||=
                                                 !ManaTools::Rpmdragora::pkg::download_callback($gurpm, @_);
                                               $gurpm->flush();
                                           },
                                       );
            $res or die $loc->N("retrieval of [%s] failed", $file) . "\n";
            return $canceled ? () : MDK::Common::File::cat_($file);
        });
    my @mirrors = @{ mirror::list(urpm::mirrors::parse_LDAP_namespace_structure(MDK::Common::File::cat_('/etc/product.id')), 'distrib') || [] };

    require ManaTools::Shared::TimeZone;
    my $tzo = ManaTools::Shared::TimeZone->new();
    my $tz = $tzo->readConfiguration()->{ZONE};
    foreach my $mirror (@mirrors) {
        my $goodness = 0;
        my $pri_mirr = defined ($t2l{$tz}) ? $t2l{$tz} : $us;
        my $ind = 0;
        foreach (@{$pri_mirr}) {
            if (($_ eq lc($mirror->{zone})) || ($_ eq lc($mirror->{country}))) {
                $goodness = scalar(@{$pri_mirr}) - $ind;
            }
            $ind ++;
        }

        $mirror->{goodness} = $goodness + rand();
        $mirror->{country} = $u2l{lc($mirror->{country})} ? $loc->N($u2l{lc($mirror->{country})}) : $mirror->{country};
    }
    unless (-x '/usr/bin/rsync') {
    @mirrors = grep { $_->{url} !~ /^rsync:/ } @mirrors;
    }
    return sort { $b->{goodness} <=> $a->{goodness} } @mirrors;
}





sub open_help {
    my ($mode) = @_;
    require ManaTools::Shared::RunProgram;
    ManaTools::Shared::RunProgram::raw({ detach => 1, as_user => 1 },  'drakhelp', '--id', $mode ?  "software-management-$mode" : 'software-management');
    my $_s = $loc->N("Help launched in background");
    statusbar_msg($loc->N("The help window has been started, it should appear shortly on your desktop."), 1);
}

sub run_drakbug {
    my ($id) = @_;
    require ManaTools::Shared::RunProgram;
    ManaTools::Shared::RunProgram::raw({ detach => 1, as_user => 1 }, 'drakbug', '--report', $id);
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
