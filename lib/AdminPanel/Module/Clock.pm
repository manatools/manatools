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

Copyright (C) 2014, Angelo Naselli.

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
use strict;

use AdminPanel::Shared::GUI;
use AdminPanel::Shared::Locales;
use AdminPanel::Shared::TimeZone;
use AdminPanel::Shared::Services;# qw (services);

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
## returns 'info', a HASH references containing:
##    time_zone  => time zone hash reference to be restored
##    ntp_server => ntp server address
##    date       => date string
##    time       => time string
#
sub _restoreValues {
    my ($self) = @_;

    my $info;
    $info->{time_zone}  = $self->sh_tz->readConfiguration();
    $info->{ntp_server} = $self->sh_tz->ntpCurrentServer();
    #- strip digits from \d+.foo.pool.ntp.org
    $info->{ntp_server} =~ s/^\d+\.// if $info->{ntp_server};
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

    # Start Dialog layout:
    my $layout    = $factory->createVBox( $dialog );
    my $align;

    my $hbox = $factory->createHBox($layout);

    my $dateField = $optFactory->createDateField($hbox, "");
    $factory->createHSpacing($hbox, 1.0);
    my $timeField = $optFactory->createTimeField($hbox, "");

    $hbox = $factory->createHBox($layout);
    my $ntpFrame = $factory->createCheckBoxFrame($hbox, $self->loc->N("Enable Network Time Protocol"), 0);
#     $ntpFrame->setWeight($yui::YD_HORIZ, 1);

    my $vbox = $factory->createVBox( $ntpFrame );
    my $hbox1 = $factory->createHBox($factory->createLeft($vbox));
    $factory->createLabel($hbox1,$self->loc->N("Server:"));
    my $ntpLabel = $factory->createLabel($hbox1, $self->loc->N("not defined"));
#     $ntpLabel->setWeight($yui::YD_HORIZ, 1);

    $hbox1 = $factory->createLeft($vbox);
    my $changeNTPButton = $factory->createPushButton($hbox1, $self->loc->N("Change NTP server"));

    $factory->createHSpacing($hbox, 1.0);
    my $frame   = $factory->createFrame ($hbox, $self->loc->N("TimeZone"));
    $vbox = $factory->createVBox( $frame );
    my $timeZoneLbl = $factory->createLabel($vbox, $self->loc->N("not defined"));
#     $timeZoneLbl->setWeight($yui::YD_HORIZ, 1);

    my $changeTZButton = $factory->createPushButton($vbox, $self->loc->N("Change Time Zone"));


    # buttons on the last line 
    $align = $factory->createLeft($layout);
    $hbox = $factory->createHBox($align);
    my $aboutButton = $factory->createPushButton($hbox, $self->loc->N("About") );
    my $resetButton = $factory->createPushButton($hbox, $self->loc->N("Reset") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));
    my $okButton = $factory->createPushButton($hbox, $self->loc->N("Ok"));

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
        $ntpLabel->setLabel($info->{ntp_server});
    }

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
                ### TODO manage OK pressed ###
                last;
            }
            elsif ($widget == $changeNTPButton) {
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
            }
            elsif ($widget == $changeTZButton) {
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
                            $utc = lc$info->{time_zone}->{UTC};
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
            }
            elsif ($widget == $resetButton) {
                $info = $self->_restoreValues();

                $dateField->setValue($info->{date});
                $timeField->setValue($info->{time});
                if (exists $info->{time_zone} && $info->{time_zone}->{ZONE}) {
                    $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
                }
                else {
                    $timeZoneLbl->setValue($self->loc->N("not defined"));
                }
                if ($info->{ntp_server}) {
                    $ntpLabel->setLabel($info->{ntp_server});
                }
                else {
                    $ntpLabel->setLabel($self->loc->N("not defined"));
                }
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


