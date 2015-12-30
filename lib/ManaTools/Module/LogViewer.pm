# vim: set et ts=4 sw=4:
package ManaTools::Module::LogViewer;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Module::LogViewer - Log viewer

=head1 SYNOPSIS

my $logViewer = ManaTools::Module::LogViewer->new();
$logViewer->start();

=head1 DESCRIPTION

Log viewer is a backend to journalctl, it can also load a custom
file.


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Module::::LogViewer

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2015, Angelo Naselli.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License version 2, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA

=head1 FUNCTIONS

=cut

use Moose;

use diagnostics;
use open OUT => ':utf8';
use File::ShareDir ':ALL';

use ManaTools::Shared::GUI;
use ManaTools::Shared::Locales;
use ManaTools::Shared::Services;
use ManaTools::Shared::JournalCtl;


use POSIX qw/strftime floor/;
use English;
use Date::Simple ();
use File::HomeDir qw(home);

use yui;

extends qw( ManaTools::Module );

has '+icon' => (
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/manalog.png'),
);

has '+name' => (
    lazy     => 1,
    builder => '_nameInitializer',
);

sub _nameInitializer {
    my $self = shift;

    return ($self->loc->N("Log viewer"));
}

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _SharedUGUIInitialize {
    my $self = shift;

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

my %prior = ('emerg'   => 0,
            'alert'   => 1,
            'crit'    => 2,
            'err'     => 3,
            'warning' => 4,
            'notice'  => 5,
            'info'    => 6,
            'debug'   => 7);


#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start the log viewer

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_logViewerPanel();
};





sub _logViewerPanel {
    my $self = shift;

    if(!$self->_warn_about_user_mode()) {
        return 0;
    }

    my $appTitle = yui::YUI::app()->applicationTitle();

    my $factory    = yui::YUI::widgetFactory;
    my $optFactory = yui::YUI::optionalWidgetFactory;

    # Create Dialog
    my $dialog  = $factory->createMainDialog;

    # Start Dialog layout:
    my $layout    = $factory->createVBox( $dialog );
    my $align = $factory->createAlignment($layout, $yui::YAlignCenter, $yui::YAlignUnchanged);
    $factory->createLabel( $align, $self->loc->N("A tool to monitor your logs"), 1, 0 );

    #### matching
    my $hbox = $factory->createHBox($layout);
    my $matchingInputField = $factory->createInputField($hbox, $self->loc->N("Matching"));
    $factory->createHSpacing($hbox, 1);

    #### not matching
    my $notMatchingInputField = $factory->createInputField($hbox, $self->loc->N("but not matching"));
    $matchingInputField->setWeight($yui::YD_HORIZ, 2);
    $notMatchingInputField->setWeight($yui::YD_HORIZ, 2);

    my $frame = $factory->createFrame($layout, $self->loc->N("Options"));

    #### lastBoot
    my $vbox = $factory->createVBox( $frame );
    $align = $factory->createLeft($vbox);
    my $lastBoot = $factory->createCheckBox($align, $self->loc->N("Last boot"), 1);
    $factory->createVSpacing($vbox, 0.5);
    $lastBoot->setNotify(1);

    my $row1 = $factory->createHBox($vbox);
    $factory->createVSpacing($vbox, 0.5);
    my $row2 = $factory->createHBox($vbox);
    $factory->createVSpacing($vbox, 0.5);
    my $row3 = $factory->createHBox($vbox);

    #### since and until
    my $sinceDate;
    my $sinceTime;
    my $sinceFrame = $factory->createCheckBoxFrame($row1, $self->loc->N("Since"), 1);
    $sinceFrame->setNotify(1);

    my $untilDate;
    my $untilTime;
    my $untilFrame = $factory->createCheckBoxFrame($row2, $self->loc->N("Until"), 1);
    $untilFrame->setNotify(1);
    if ($optFactory->hasDateField()) {
        my $hbox1 = $factory->createHBox($sinceFrame);

        $sinceDate = $optFactory->createDateField($hbox1, "");
        $factory->createHSpacing($hbox1, 1.0);
        $sinceTime = $optFactory->createTimeField($hbox1, "");
        my $day = strftime "%F", localtime;
        $sinceDate->setValue($day);
        $sinceTime->setValue("00:00:00");

        $hbox1 = $factory->createHBox($untilFrame);
        $untilDate = $optFactory->createDateField($hbox1, "");
        $factory->createHSpacing($hbox1, 1.0);
        $untilTime = $optFactory->createTimeField($hbox1, "");
        $untilDate->setValue($day);
        $untilTime->setValue("23:59:59");
    }
    else {
        $sinceFrame->enable(0);
        $untilFrame->enable(0);
    }

    #### units
    my $spacing = $factory->createHSpacing($row1, 2.0);

    my $unitsFrame = $factory->createCheckBoxFrame($row1, $self->loc->N("Select a unit"), 1);
    $unitsFrame->setNotify(1);
    $align = $factory->createLeft($unitsFrame);
    my $units = $factory->createComboBox  ( $align, "" );
    my $itemCollection = new yui::YItemCollection;

    yui::YUI::app()->busyCursor();
    my $serv = ManaTools::Shared::Services->new();
    my ($l, $active_services) = $serv->services();

    foreach (@{$active_services}) {
        my $serviceName = $_;
        my $item = new yui::YItem($serviceName);
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $units->addItems($itemCollection);
    yui::YUI::app()->normalCursor();

    #### priority
    # From
    $factory->createHSpacing($row2, 2.0);
    my $priorityFromFrame = $factory->createCheckBoxFrame($row2, $self->loc->N("From priority"), 1);
    $priorityFromFrame->setNotify(1);
    $priorityFromFrame->setWeight($yui::YD_HORIZ, 1);
    my $priorityFrom = $factory->createComboBox  ( $priorityFromFrame, "" );
    $itemCollection->clear();

    my @pr = ('emerg', 'alert', 'crit', 'err',
            'warning', 'notice', 'info', 'debug');
    foreach (@pr) {
        my $item = new yui::YItem($_);
        if ( $_ eq 'emerg' ) {
            $item->setSelected(1);
        }
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $priorityFrom->addItems($itemCollection);

    $factory->createHSpacing( $row2, 2.0 );
    # To
    my $priorityToFrame = $factory->createCheckBoxFrame($row2, $self->loc->N("To priority"), 1);
    $priorityToFrame->setNotify(1);
    $priorityToFrame->setWeight($yui::YD_HORIZ, 1);
    my $priorityTo = $factory->createComboBox  ( $priorityToFrame, "" );
    $itemCollection->clear();

    foreach (@pr) {
        my $item = new yui::YItem($_);
        if ( $_ eq 'debug' ) {
            $item->setSelected(1);
        }
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $priorityTo->addItems($itemCollection);

    #### search
    $align = $factory->createRight($row3);
    my $searchButton = $factory->createPushButton($align, $self->loc->N("&Find"));

    #### create log view object
    my $logView = $factory->createLogView($layout, $self->loc->N("Log content"), 10, 0);


    ### NOTE CheckBoxFrame doesn't honoured his costructor checked value for his children
    $unitsFrame->setValue(0);
    $sinceFrame->setValue(0);
    $untilFrame->setValue(0);
    $priorityFromFrame->setValue(0);
    $priorityToFrame->setValue(0);

    # buttons on the last line
    $align = $factory->createRight($layout);
    $hbox = $factory->createHBox($align);
    my $aboutButton = $factory->createPushButton($hbox, $self->loc->N("&About") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);
    my $saveButton = $factory->createPushButton($hbox, $self->loc->N("&Save"));
    my $quitButton = $factory->createPushButton($hbox, $self->loc->N("&Quit"));

    # End Dialof layout

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
            if ($widget == $quitButton) {
                last;
            }
            elsif($widget == $aboutButton) {
                my $translators = $self->loc->N("_: Translator(s) name(s) & email(s)\n");
                $translators =~ s/\</\&lt\;/g;
                $translators =~ s/\>/\&gt\;/g;
                $self->sh_gui->AboutDialog({ name    => $self->name,
                                            version => $self->Version(),
                            credits => $self->loc->N("Copyright (C) %s Mageia community", '2014'),
                            license => $self->loc->N("GPLv2"),
                            description => $self->loc->N("Log viewer is a systemd journal viewer"),
                            authors => $self->loc->N("<h3>Developers</h3>
                                                    <ul><li>%s</li>
                                                        <li>%s</li>
                                                    </ul>
                                                    <h3>Translators</h3>
                                                    <ul><li>%s</li></ul>",
                                                    "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                                    "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;",
                                                    $translators
                                                    ),
                            }
                );
            }
            elsif($widget == $saveButton) {
                if ($logView->lines()) {
                    $self->_save($logView);
                }
                else {
                    $self->sh_gui->warningMsgBox({text => $self->loc->N("Empty log found")});
                }
            }
            elsif ($widget == $searchButton) {
                yui::YUI::app()->busyCursor();
                $dialog->startMultipleChanges();
                $logView->clearText();
                my %log_opts;
                if ($lastBoot->value()) {
                    $log_opts{this_boot} = 1;
                }
                if ($unitsFrame->value()) {
                    $log_opts{unit} = $units->value();
                }
                if ($sinceFrame->value()) {
                    $log_opts{since} = $sinceDate->value() . " " . $sinceTime->value();
                }
                if ($untilFrame->value()) {
                    $log_opts{until} = $untilDate->value() . " " . $untilTime->value();
# TODO check date until > date since
                }
                if ($priorityFromFrame->value() || $priorityToFrame->value()) {
                    my $prio = $priorityFrom->value();
                    $prio .= "..".$priorityTo->value() if ($priorityToFrame->value());
                    $log_opts{priority} = $prio;
# TODO enabling right using checkBoxes
                }
                my $log = $self->_search(\%log_opts);
print " log lines: ". scalar (@{$log}) ."\n";
# TODO check on log line number what to do if too big? and adding a progress bar?
                $self->_parse_content({'matching'   => $matchingInputField->value(),
                                    'noMatching' => $notMatchingInputField->value(),
                                    'log'        => $log,
                                    'logView'    => $logView,
                                    }
                );
                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::app()->normalCursor();
            }
            elsif ($widget == $lastBoot) {
                yui::YUI::ui()->blockEvents();
                if ($lastBoot->value()) {
                    #last boot overrrides until and since
                    $sinceFrame->setValue(0);
                    $untilFrame->setValue(0);
                }
                yui::YUI::ui()->unblockEvents();
            }
            elsif ($widget == $sinceFrame) {
                yui::YUI::ui()->blockEvents();
                if ($sinceFrame->value()) {
                    #disabling last boot that overrrides until and since
                    $lastBoot->setValue(0);
                }
                yui::YUI::ui()->unblockEvents();
            }
            elsif ($widget == $untilFrame) {
                yui::YUI::ui()->blockEvents();
                if ($untilFrame->value()) {
                    #disabling last boot that overrrides until and since
                    $lastBoot->setValue(0);
                }
                yui::YUI::ui()->unblockEvents();
            }
            elsif ($widget == $priorityFromFrame) {
                if ($priorityToFrame->value() && !$priorityFromFrame->value()) {
                    yui::YUI::ui()->blockEvents();
                    $priorityToFrame->setValue(0) ;
                    yui::YUI::ui()->unblockEvents();
                }
            }
            elsif ($widget == $priorityToFrame) {
                if ($priorityToFrame->value() && !$priorityFromFrame->value()) {
                    yui::YUI::ui()->blockEvents();
                    $priorityFromFrame->setValue(1) ;
                    yui::YUI::ui()->unblockEvents();
                }
            }

        }
    }
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;
}



sub _warn_about_user_mode {
    my $self = shift;

    my $title = $self->loc->N("manalog - running in user mode");
    my $msg   = $self->loc->N("You are launching this program as a normal user.\n".
                            "You will not be able to read system logs which you do not have rights to,\n".
                            "but you may still browse all the others.");

    if(($EUID != 0) and (!$self->sh_gui->ask_OkCancel({title => $title, text => $msg}))) {
        return 0;
    }

    return 1;
}


## Save as
#
# $logView: log Widget
#
##
sub _save {
    my ($self, $logView) = @_;

    yui::YUI::app()->busyCursor();

    my $outFile = yui::YUI::app()->askForSaveFileName(home(), "*", $self->loc->N("Save as.."));
    if ($outFile) {
        open(OF, ">".$outFile);
        print OF $logView->logText();
        close OF;
    }

    yui::YUI::app()->normalCursor();
}

## Search call back
sub _search {
    my ($self, $log_opts) = @_;

    my $log = ManaTools::Shared::JournalCtl->new(%{$log_opts});
    my $all = $log->getLog();

    return $all;
}

## _parse_content
#
#  $info : HASH cotaining
#
#  matching:    string to match
#  notMatching: string to skip
#  log:         ARRAY REF to log content
#  logViewer:   logViewer Widget
#
##
sub _parse_content {
    my ($self, $info) = @_;

    my $ey = "";
    my $en = "";

    if( exists($info->{'matching'} ) ){
        $ey = $info->{'matching'};
    }
    if( exists($info->{'noMatching'} ) ){
        $en = $info->{'noMatching'};
    }

    $ey =~ s/ OR /|/ if ($ey);
    $ey =~ s/^\*$//  if ($ey);
    $en =~ s/^\*$/.*/ if ($en);

    my $test;

    if ($en && !$ey) {
        $test = sub { $_[0] !~ /$en/ };
    }
    elsif ($ey && !$en) {
        $test = sub { $_[0] =~ /$ey/ };
    }
    elsif ($ey && $en) {
        $test = sub { $_[0] =~ /$ey/ && $_[0] !~ /$en/ };
    }
    else {
        $test = sub { $_[0] };
    }

    foreach (@{$info->{log}}) {
        $info->{logView}->appendLines($_) if $test->($_);
    }

}


1
