# vim: set et ts=4 sw=4:
package AdminPanel::Module::Clock;
#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::Module::Clock - This module aims to configure system clock and time

=head1 SYNOPSIS

    my $clockSettings = AdminPanel::Module::Clock->new();
    $clockSettings->start();

=head1 DESCRIPTION

Long_description

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::Module::Clock

=head1 SEE ALSO

SEE_ALSO

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

use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Locales;
use AdminPanel::Shared::TimeZone;

use Time::Piece;
 
use yui;

extends qw( AdminPanel::Module );

### TODO icon 
has '+icon' => (
    default => "/usr/share/mcc/themes/default/time-mdk.png",
);

has 'loc' => (
        is => 'rw',
        init_arg => undef,
        builder => '_localeInitialize'
);

sub _localeInitialize {
    my $self = shift;

    # TODO fix domain binding for translation
    $self->loc(AdminPanel::Shared::Locales->new(domain_name => 'libDrakX-standalone') );
    # TODO if we want to give the opportunity to test locally add dir_name => 'path'
}

has 'sh_gui' => (
        is => 'rw',
        lazy => 1,
        init_arg => undef,
        builder => '_SharedGUIInitialize'
);

sub _SharedGUIInitialize {
    my $self = shift;

    $self->sh_gui(AdminPanel::Shared::GUI->new() );
}

has 'sh_tz' => (
        is => 'rw',
        lazy => 1,
        builder => '_SharedTimeZoneInitialize'
);

sub _SharedTimeZoneInitialize {
    my $self = shift;

    $self->sh_tz(AdminPanel::Shared::TimeZone->new() );
}


=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    in this methods Services loads all the service information.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    if (! $self->name) {
        $self->name ($self->loc->N("Date, Clock & Time Zone Settings"));
    }
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start admin clock

=cut

#=============================================================
sub start {
    my $self = shift;

    $self->_adminClockPanel();
};

### _get_NTPservers
## returns ntp servers in the format
##  Zone|Nation: server
#
sub _get_NTPservers {
    my $self = shift;

    my $servs = $self->sh_tz->ntpServers();
    [ map { "$servs->{$_}|$_" } sort { $servs->{$a} cmp $servs->{$b} || $a cmp $b } keys %$servs ];
}

### _restoreValues
## restore NTP server and Time Zone from configuration files
#
## input '$datetime_only' restore date and time only
#
## returns 'info', a HASH references containing:
##    time_zone   => time zone hash reference to be restored
##    ntp_server  => ntp server address
##    date        => date string
##    time        => time string
##    ntp_running => is NTP running?
#
sub _restoreValues {
    my ($self, $datetime_only) = @_;

    my $info;
    if (!$datetime_only) {
        $info->{time_zone}  = $self->sh_tz->readConfiguration();
        $info->{ntp_server} = $self->sh_tz->ntpCurrentServer();
        #- strip digits from \d+.foo.pool.ntp.org
        $info->{ntp_server} =~ s/^\d+\.// if $info->{ntp_server};
        $info->{ntp_running} = $self->sh_tz->isNTPRunning();
    }
    my $t = localtime;
    my $day = $t->strftime("%F");
    my $time = $t->strftime("%H:%M:%S");
    $info->{date} = $day;
    $info->{time} = $time;

    return $info;
}

sub _adminClockPanel {
    my $self = shift;

    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);

    my $factory    = yui::YUI::widgetFactory;
    my $optFactory = yui::YUI::optionalWidgetFactory;
    die "calendar widgets missing" if (!$optFactory->hasDateField() || !$optFactory->hasTimeField());  

    # Create Dialog
    my $dialog  = $factory->createMainDialog;
#     my $minSize = $factory->createMinSize($dialog, 40, 15);

    # Start Dialog layout:
    my $layout = $factory->createVBox($dialog);
    my $align  = $factory->createLeft($layout);

    my $frame   = $factory->createFrame($align, $self->loc->N("Setting date and time"));
    my $hbox = $factory->createHBox($frame);

    my $dateField = $optFactory->createDateField($hbox, "");
    $factory->createHSpacing($hbox, 3.0);
    my $timeField = $optFactory->createTimeField($hbox, "");
    $factory->createHSpacing($hbox, 1.0);
    $factory->createVSpacing($hbox, 1.0);
    $factory->createVSpacing($layout, 1.0);

    $align  = $factory->createLeft($layout);
    $hbox = $factory->createHBox($align);
    my $ntpFrame = $factory->createCheckBoxFrame($hbox, $self->loc->N("Enable Network Time Protocol"), 0);

    my $hbox1 = $factory->createHBox($ntpFrame);
    my $changeNTPButton = $factory->createPushButton($hbox1, $self->loc->N("Change NTP server"));
    $factory->createHSpacing($hbox1, 1.0);
    $factory->createLabel($hbox1,$self->loc->N("Current:"));
    $factory->createHSpacing($hbox1, 1.0);
    my $ntpLabel = $factory->createLabel($hbox1, $self->loc->N("not defined"));
    $factory->createHSpacing($hbox1, 1.0);
    $ntpLabel->setWeight($yui::YD_HORIZ, 2);
    $changeNTPButton->setWeight($yui::YD_HORIZ, 1);
    $factory->createHSpacing($hbox, 1.0);

    $factory->createVSpacing($layout, 1.0);
    $align  = $factory->createLeft($layout);
    $hbox = $factory->createHBox($align);
    $frame   = $factory->createFrame ($hbox, $self->loc->N("TimeZone"));
    $hbox1 = $factory->createHBox( $frame );
    my $changeTZButton = $factory->createPushButton($hbox1, $self->loc->N("Change Time Zone"));
    $factory->createHSpacing($hbox1, 1.0);
    $factory->createLabel($hbox1,$self->loc->N("Current:"));
    $factory->createHSpacing($hbox1, 1.0);
    my $timeZoneLbl = $factory->createLabel($hbox1, $self->loc->N("not defined"));
    $factory->createHSpacing($hbox1, 1.0);
    $timeZoneLbl->setWeight($yui::YD_HORIZ, 2);
    $changeTZButton->setWeight($yui::YD_HORIZ, 1);

    $factory->createHSpacing($hbox, 1.0);

    # buttons on the last line
    $factory->createVSpacing($layout, 1.0);
    $hbox = $factory->createHBox($layout);

    $align = $factory->createLeft($hbox);
    $hbox = $factory->createHBox($align);
    my $aboutButton = $factory->createPushButton($hbox, $self->loc->N("About") );
    my $resetButton = $factory->createPushButton($hbox, $self->loc->N("Reset") );

    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));
    my $okButton = $factory->createPushButton($hbox, $self->loc->N("Ok"));
    $factory->createHSpacing($hbox, 1.0);

    ## no changes by default
    $dialog->setDefaultButton($cancelButton);

    # End Dialof layout 

    ## default value
    my $info = $self->_restoreValues();

    $dateField->setValue($info->{date});
    $timeField->setValue($info->{time});

    if (exists $info->{time_zone} && $info->{time_zone}->{ZONE}) {
        $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
    }

    if ($info->{ntp_server}) {
        $ntpLabel->setValue($info->{ntp_server});
    }
    $ntpFrame->setValue($info->{ntp_running});


    # get only once
    my $NTPservers = $self->_get_NTPservers();

    while(1) {
        my $event       = $dialog->waitForEvent(1000);
        my $eventType   = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::TimeoutEvent) {
            my $t = Time::Piece->strptime($timeField->value(), "%H:%M:%S") + 1;
            $timeField->setValue($t->strftime("%H:%M:%S"));
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $okButton) {
                yui::YUI::app()->busyCursor();
                my $finished = 1;
                # (1) write new TZ settings
                # (2) write new NTP settigs if checked
                # (3) use date time fields if NTP is not checked

                if ($info->{time_zone}->{UTC}) {
                    # (1)
                    $self->sh_tz->writeConfiguration($info->{time_zone});
                }
                if ($ntpFrame->value()) {
                    # (2)
                    if ($info->{ntp_server}) {

                        $self->sh_tz->setNTPServer($info->{ntp_server});

                    }
                    else {
                        $self->sh_gui->warningMsgBox({text => $self->loc->N("Please enter a valid NTP server address.")});
                        $finished = 0;
                    }
                }
                else {
                    $self->sh_tz->disableAndStopNTP();
                    # (3)
                    my $t = Time::Piece->strptime($timeField->value(), "%H:%M:%S");
                    my $d = Time::Piece->strptime($dateField->value(), "%Y-%m-%d");
                    my $ts = sprintf("%02d%02d%02d%02d%04d.%02d",
                                     $d->mon, $d->mday, $t->hour,
                                     $t->min, $d->year,$t->sec);
                    $ENV{PATH} = "/usr/bin:/usr/sbin";
                    system("/usr/bin/date " . $ts);
                    -e '/usr/sbin/hwclock' and system('/usr/sbin/hwclock', '--systohc');
                }
                yui::YUI::app()->normalCursor();

                last if ($finished);
            }
            elsif ($widget == $changeNTPButton) {
                # get time to calculate elapsed
                my $t0 = localtime;
                my $item = $self->sh_gui->ask_fromTreeList({title => $self->loc->N("NTP server - DrakClock"),
                                                            header => $self->loc->N("Choose your NTP server"),
                                                            default_button => 1,
                                                            item_separator => '|',
                                                            default_item => $info->{ntp_server},
                                                            skip_path => 1,
                                                            list  => $NTPservers});
                if ($item) {
                    $ntpLabel->setValue($item);
                    $info->{ntp_server} = $item;
                }
                # fixing elapsed time (dialog is modal)
                my $t1 = localtime;
                my $elapsed = $t1->epoch - $t0->epoch;

                my $t = Time::Piece->strptime($dateField->value() . "T" . $timeField->value(),
                                              '%Y-%m-%dT%H:%M:%S') + $elapsed;
                $timeField->setValue($t->strftime("%H:%M:%S"));
                $dateField->setValue($t->strftime("%F"));
            }
            elsif ($widget == $changeTZButton) {
                # get time to calculate elapsed
                my $t0 = localtime;
                my $timezones = $self->sh_tz->getTimeZones();
                if (!$timezones || scalar (@{$timezones}) == 0) {
                    $self->sh_gui->warningMsgBox({title => $self->loc->N("Timezone - DrakClock"),
                                                  text  => $self->loc->N("Failed to retrieve timezone list"),
                    });
                    $changeTZButton->setDisabled();
                }
                else {
                    my $item = $self->sh_gui->ask_fromTreeList({title => $self->loc->N("Timezone - DrakClock"),
                                                                header => $self->loc->N("Which is your timezone?"),
                                                                default_button => 1,
                                                                item_separator => '/',
                                                                default_item => $info->{time_zone}->{ZONE},
                                                                list  => $timezones});
                    if ($item) {
                        my $utc = 0;
                        if ($info->{time_zone}->{UTC} ) {
                            $utc = lc $info->{time_zone}->{UTC};
                            $utc = ($utc eq "false" || $utc eq "0") ? 0 : 1;
                        }
                        $utc = $self->sh_gui->ask_YesOrNo({
                                                    title  => $self->loc->N("GMT - DrakClock"),
                                                    text   => $self->loc->N("Is your hardware clock set to GMT?"),
                                            default_button => $utc,
                                                });
                        $info->{time_zone}->{UTC}  = $utc == 1 ? 'true' : 'false';
                        $info->{time_zone}->{ZONE} = $item;
                        $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
                    }
                }
                # fixing elapsed time (dialog is modal)
                my $t1 = localtime;
                my $elapsed = $t1->epoch - $t0->epoch;

                my $t = Time::Piece->strptime($dateField->value() . "T" . $timeField->value(),
                                              '%Y-%m-%dT%H:%M:%S') + $elapsed;
                $timeField->setValue($t->strftime("%H:%M:%S"));
                $dateField->setValue($t->strftime("%F"));
            }
            elsif ($widget == $resetButton) {
                my $datetime_only = $self->sh_gui->ask_YesOrNo({
                                                    title  => $self->loc->N("Restore data"),
                                                    text   => $self->loc->N("Restore date and time only?"),
                                            default_button => 1, #Yes
                                                });
                my $newInfo = $self->_restoreValues($datetime_only);
                if ($datetime_only) {
                    $info->{date} = $newInfo->{date};
                    $info->{time} = $newInfo->{time};
                }
                else{
                    $info = $newInfo;
                }

                $dateField->setValue($info->{date});
                $timeField->setValue($info->{time});
                if (exists $info->{time_zone} && $info->{time_zone}->{ZONE}) {
                    $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
                }
                else {
                    $timeZoneLbl->setValue($self->loc->N("not defined"));
                }
                if ($info->{ntp_server}) {
                    $ntpLabel->setValue($info->{ntp_server});
                }
                else {
                    $ntpLabel->setValue($self->loc->N("not defined"));
                }
                $ntpFrame->setValue($info->{ntp_running});
            }
            elsif($widget == $aboutButton) {
                my $translators = $self->loc->N("_: Translator(s) name(s) & email(s)\n");
                $translators =~ s/\</\&lt\;/g;
                $translators =~ s/\>/\&gt\;/g;
                $self->sh_gui->AboutDialog({ name    => $self->name,
                                            version => $self->VERSION,
                            credits => $self->loc->N("Copyright (C) %s Mageia community", '2014'),
                            license => $self->loc->N("GPLv2"),
                            description => $self->loc->N("Date, Clock & Time Zone Settings allows to setup time zone and adjust date and time"),
                            authors => $self->loc->N("<h3>Developers</h3>
                                                    <ul><li>%s</li>
                                                        <li>%s</li>
                                                    </ul>
                                                    <h3>Translators</h3>
                                                    <ul><li>%s</li></ul>",
                                                    "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                                    $translators
                                                    ),
                            }
                );
            }
        }
    }
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;
}



