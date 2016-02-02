# vim: set et ts=4 sw=4:
package ManaTools::Module::Clock;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::Module::Clock - This module aims to configure system clock and time

=head1 SYNOPSIS

    my $clockSettings = ManaTools::Module::Clock->new();
    $clockSettings->start();

=head1 DESCRIPTION

Long_description

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc ManaTools::Module::Clock

=head1 SEE ALSO

SEE_ALSO

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2014-2016, Angelo Naselli.

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
extends qw( ManaTools::Module );

use diagnostics;

use File::ShareDir ':ALL';
use ManaTools::Shared::Locales;
use ManaTools::Shared::TimeZone;
use ManaTools::Shared::GUI;
use ManaTools::Shared::GUI::Dialog;


use Time::Piece;

use yui;


has '+icon' => (
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/manaclock.png'),
);

has 'sh_gui' => (
        is => 'rw',
        lazy => 1,
        init_arg => undef,
        builder => '_SharedGUIInitialize'
);

sub _SharedGUIInitialize {
    my $self = shift;

    $self->sh_gui(ManaTools::Shared::GUI->new() );
}

has 'sh_tz' => (
        is => 'rw',
        lazy => 1,
        builder => '_SharedTimeZoneInitialize'
);

sub _SharedTimeZoneInitialize {
    my $self = shift;

    $self->sh_tz(ManaTools::Shared::TimeZone->new(loc => $self->loc) );
}

has 'NTPServers' => (
        is => 'ro',
        lazy => 1,
        init_arg => undef,
        builder => '_get_NTPservers'
);


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
}

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
##    ntp_servers  => ntp server address
##    pool_server  => ntp pool server address
##    date        => date string
##    time        => time string
##    ntp_running => is NTP running?
#
sub _restoreValues {
    my ($self, $datetime_only) = @_;

    my $info;
    if (!$datetime_only) {
        $info->{time_zone}  = $self->sh_tz->readConfiguration();
        $DB::single = 1;
        $info->{ntp_servers} = [ $self->sh_tz->ntpCurrentServers() ];
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

    my $dialog = ManaTools::Shared::GUI::Dialog->new(
        module => $self,
        dialogType => ManaTools::Shared::GUI::Dialog::mainDialog,
        title => $self->name(),
        icon => $self->icon(),
        buttons => {
            ManaTools::Shared::GUI::Dialog::aboutButton => sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $self = $event->parentDialog()->module(); #this object

                my $translators = $self->loc->N("_: Translator(s) name(s) & email(s)\n");
                $translators =~ s/\</\&lt\;/g;
                $translators =~ s/\>/\&gt\;/g;
                $self->sh_gui->AboutDialog({
                    name    => $self->name,
                    version => $self->Version(),
                    credits => $self->loc->N("Copyright (C) %s Mageia community", '2014-2016'),
                    license => $self->loc->N("GPLv2"),
                    description => $self->loc->N("Date, Clock & Time Zone Settings allows to setup time zone and adjust date and time"),
                    authors => $self->loc->N("<h3>Developers</h3>
                                              <ul><li>%s</li></ul>
                                              <h3>Translators</h3>
                                              <ul><li>%s</li></ul>",
                                              "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                              $translators
                    ),
                });
                return 1;
            },
            ManaTools::Shared::GUI::Dialog::resetButton => sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $dialog = $event->parentDialog();
                my $self = $dialog->module(); #this object

                my $datetime_only = $self->sh_gui->ask_YesOrNo({
                    title  => $self->loc->N("Restore data"),
                    text   => $self->loc->N("Restore date and time only?"),
                    default_button => 1, #Yes
                });
                my $info = $dialog->info();
                my $newInfo = $self->_restoreValues($datetime_only);
                if ($datetime_only) {
                    $info->{date} = $newInfo->{date};
                    $info->{time} = $newInfo->{time};
                }
                else{
                    $info = $newInfo;
                }

                $dialog->widget('dateField')->setValue($info->{date});

                $dialog->widget('timeField')->setValue($info->{time});
                if (exists $info->{time_zone} && $info->{time_zone}->{ZONE}) {
                    $dialog->widget('timeZoneLbl')->setValue($info->{time_zone}->{ZONE});
                }
                else {
                    $dialog->widget('timeZoneLbl')->setValue($self->loc->N("not defined"));
                }
                if (scalar @{$info->{ntp_servers}}) {
                    $dialog->widget('ntpLabel')->setValue(join (',', @{$info->{ntp_servers}}));
                }
                else {
                    $dialog->widget('ntpLabel')->setValue($self->loc->N("not defined"));
                }
                $dialog->widget('ntpFrame')->setValue($info->{ntp_running});

                return 1;
            },
            ManaTools::Shared::GUI::Dialog::cancelButton => sub {return 0;},
            ManaTools::Shared::GUI::Dialog::okButton => sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $dialog = $event->parentDialog();
                my $self = $dialog->module(); #this object
                my $ydialog = $dialog->dialog();

                yui::YUI::app()->busyCursor();
                my $info = $dialog->info();
                my $finished = 1;

                # (1) write new TZ settings
                # (2) write new NTP settigs if checked
                # (3) use date time fields if NTP is not checked
                my $old_conf = $self->sh_tz->readConfiguration();
                if ($info->{time_zone}->{UTC} != $old_conf->{UTC}) {
                    my $localRTC = $info->{time_zone}->{UTC} ? 0 : 1;
                    eval { $self->sh_tz->setLocalRTC($localRTC) };
                    my $errors = $@;
                    if ($errors) {
                        $finished = 0;
                        $self->sh_gui->warningMsgBox({
                            title =>  $self->loc->N("Set local RTC failed"),
                            text  => "$errors",
                            richtext => 1,
                        });
                    }
                    # NOTE refresh to clean closed dialogs it happens in user mode
                    #      after polkit password dialog or warning dialog
                    $ydialog->pollEvent();
                }
                if ($info->{time_zone}->{ZONE} ne $old_conf->{ZONE}) {
                    eval { $self->sh_tz->setTimeZone($info->{time_zone}->{ZONE}) };
                    my $errors = $@;
                    if ($errors) {
                        $finished = 0;
                        $self->sh_gui->warningMsgBox({
                            title =>  $self->loc->N("Set time zone failed"),
                            text  => "$errors",
                            richtext => 1,
                        });
                    }
                    # NOTE refresh to clean closed dialogs it happens in user mode
                    #      after polkit password dialog or warning dialog
                    $ydialog->pollEvent();
                }
                my $ntpFrame = $dialog->widget('ntpFrame');
                if ($ntpFrame->value()) {
                    # (2)
                    my @currentServers   = $self->sh_tz->ntpCurrentServers();
                    my $currentServer = join(',', @currentServers) if scalar @currentServers;
                    my $isRunning       = $self->sh_tz->isNTPRunning();
                    my $currentService  = $self->sh_tz->ntp_program();
                    my $ntpService      = $dialog->widget('ntpService');
                    my $selectedService = $ntpService->selectedItem();
                    my $newServers = join(',', sort @{$info->{ntp_servers}}) if scalar @{$info->{ntp_servers}};

                    my $sameService = ($currentService && $currentService eq $selectedService->label());
                    my $sameConfig  = $sameService && ((!$currentServer && !$newServers) ||
                        ($currentServer && $newServers && $currentServer eq $newServers)
                    );

                    my $nothingToDo = ($isRunning && $sameConfig);
                    if (!$nothingToDo) {
                        # we stop the service anyway
                        if ($isRunning) {
                            eval { $self->sh_tz->disableAndStopNTP() };
                            $ydialog->pollEvent();
                        }
                        # (a) different service or same service - different configuration
                        if (!$sameService) {
                            $self->sh_tz->ntp_program($selectedService->label());
                        }
                        if (!$sameConfig) {
                            eval { $self->sh_tz->setNTPConfiguration($info->{ntp_servers}) };
                            my $errors = $@;
                            if ($errors) {
                                $self->sh_gui->warningMsgBox({
                                    title =>  $self->loc->N("Set NTP Configuration failed"),
                                    text  => "$errors",
                                    richtext => 1,
                                });
                            }
                            $ydialog->pollEvent();
                        }
                        # and finally enabling the service
                        eval {
                            my $ntp_server = $info->{ntp_servers}->[0];
                            $self->sh_tz->enableAndStartNTP($ntp_server);
                        };
                        my $errors = $@;
                        if ($errors) {
                            $finished = 0;
                            $self->sh_gui->warningMsgBox({
                                title =>  $self->loc->N("Set NTP failed"),
                                text  => "$errors",
                                richtext => 1,
                            });
                        }
                        $ydialog->pollEvent();
                    }
                }
                else {
                    my $timeField = $dialog->widget('timeField');
                    my $dateField = $dialog->widget('dateField');
                    my $t =  Time::Piece->strptime($dateField->value()."T".$timeField->value(),
                                                    "%Y-%m-%dT%H:%M:%S"
                    );
                    eval {
                        $self->sh_tz->disableAndStopNTP();
                        # (3)
                        $self->sh_tz->setTime($t->epoch());
                    };
                    my $errors = $@;
                    if ($errors) {
                        $finished = 0;
                        $self->sh_gui->warningMsgBox({
                            title =>  $self->loc->N("Set system time failed"),
                            text  => "$errors",
                            richtext => 1,
                        });
                    }
                }
                yui::YUI::app()->normalCursor();

                return 0 if ($finished);

                return 1;


            },
        },
        event_timeout => 1000,
        layout => sub {
            my $self = shift; #ManaTools::Shared::GUI::Dialog
            my $layoutstart = shift;

            my $ydialog = $self->dialog();
            my $module  = $self->module();
            my $info    = $self->info();
            my $factory = $self->factory();
            my $optFactory = $self->optFactory();

            $layoutstart = $factory->createVBox($layoutstart);
            my $hbox = $factory->createHBox($layoutstart);
            my $align  = $factory->createLeft($hbox);

            ### first line Setting Date and Time
            my $dateTimeFrame = $factory->createFrame($align, $self->loc->N("Setting date and time"));
            $self->addWidget("dateTimeFrame", $dateTimeFrame, sub {return 1;});
            $hbox = $factory->createHBox($dateTimeFrame);

            my $dateField = $optFactory->createDateField($hbox, "");
            $self->addWidget("dateField", $dateField, sub {return 1;});
            $factory->createHSpacing($hbox, 3.0);
            my $timeField = $optFactory->createTimeField($hbox, "");
            $self->addWidget("timeField", $timeField, sub {return 1;});
            $factory->createHSpacing($hbox, 1.0);
            $factory->createVSpacing($hbox, 1.0);
            $factory->createVSpacing($layoutstart, 1.0);
            $dateField->setValue($info->{date});
            $timeField->setValue($info->{time});

            ### second line setting NTP
            $hbox = $factory->createHBox($layoutstart);
            $align  = $factory->createLeft($hbox);
            my $ntpFrame = $factory->createCheckBoxFrame($align, $self->loc->N("Enable Network Time Protocol"), 0);
            $self->addWidget(
                "ntpFrame",
                $ntpFrame, sub {
                    my $event = shift; #ManaTools::Shared::GUI::Event
                    my $dialog = $event->parentDialog();
                    my $self = $dialog->module(); #this object
                    my $ntpFrame = $dialog->widget('ntpFrame');
                    my $dateTimeFrame = $dialog->widget('dateTimeFrame');

                    if (scalar @{$self->sh_tz->ntpServiceList()} == 0) {
                        $self->sh_gui->warningMsgBox({
                            title => $self->loc->N("manaclock: NTP service missed"),
                            text  => $self->loc->N("Please install a NTP service such as chrony or ntp to manage"),
                            richtext => 1,
                        });
                        $ntpFrame->setValue(0);
                        $dateTimeFrame->setEnabled(1);
                    }
                    else {
                        $dateTimeFrame->setEnabled(!$ntpFrame->value());
                    }

                    return 1;
                },
            );

            my $hbox1 = $factory->createHBox($ntpFrame);
            my $vbx = $factory->createVBox($hbox1);
            my $chooseNTPButton = $factory->createPushButton($vbx, $self->loc->N("Choose &NTP server"));
            $self->addWidget(
                "chooseNTPButton",
                $chooseNTPButton, sub {
                    my $event = shift; #ManaTools::Shared::GUI::Event
                    my $dialog = $event->parentDialog();
                    my $self = $dialog->module(); #this object
                    my $info = $dialog->info();

                    # get time to calculate elapsed
                    my $t0 = localtime;
                    # let's guess it's a pool for selecting item
                    my $pool_server = $info->{ntp_servers}->[0] if scalar @{$info->{ntp_servers}};
                    #- strip digits from \d+.foo.pool.ntp.org
                    $pool_server =~ s/^\d+\.// if $pool_server;

                    my $item = $self->sh_gui->ask_fromTreeList({title => $self->loc->N("NTP server - DrakClock"),
                                                                header => $self->loc->N("Choose your NTP server"),
                                                                default_button => 1,
                                                                item_separator => '|',
                                                                default_item => $pool_server,
                                                                skip_path => 1,
                                                                list  => $self->NTPServers});
                    if ($item) {
                        my $ntpLabel = $dialog->widget('ntpLabel');
                        my $pool_match = qr/\.pool\.ntp\.org$/;
                        my $server = $item;
                        $info->{ntp_servers} = [  $server =~ $pool_match  ? (map { "$_.$server" } 0 .. 2) : $server ];
                        $ntpLabel->setValue(join (',', @{$info->{ntp_servers}}));
                    }
                    # fixing elapsed time (dialog is modal)
                    my $t1 = localtime;
                    my $elapsed = $t1->epoch - $t0->epoch;

                    my $timeField = $dialog->widget('timeField');
                    my $dateField = $dialog->widget('dateField');

                    my $t = Time::Piece->strptime($dateField->value() . "T" . $timeField->value(),
                                                '%Y-%m-%dT%H:%M:%S') + $elapsed;
                    $timeField->setValue($t->strftime("%H:%M:%S"));
                    $dateField->setValue($t->strftime("%F"));

                    return 1;
                },
            );
            $chooseNTPButton->setStretchable(0,1);

            my $localNTPButton = $factory->createPushButton($vbx, $self->loc->N("&Local NTP server"));
            $self->addWidget(
                "localNTPButton",
                $localNTPButton, sub {
                    my $event = shift; #ManaTools::Shared::GUI::Event
                    my $dialog = $event->parentDialog();
                    my $self = $dialog->module(); #this object
                    my $info = $dialog->info();

                    my $factory = $dialog->factory();
                    ## push application title
                    my $appTitle = yui::YUI::app()->applicationTitle();
                    ## set new title to get it in dialog
                    yui::YUI::app()->setApplicationTitle($self->loc->N("Set local NTP server"));

                    my $dlg = $factory->createPopupDialog($yui::YDialogNormalColor);
                    my $layout = $factory->createVBox($dlg);
                    my $input = $factory->createInputField($layout, $self->loc->N("Please set your local NTP server"));
                    $input->setStretchable(0,1);
                    my $hbox = $factory->createHBox($layout);

                    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("&Cancel"));
                    my $okButton = $factory->createPushButton($hbox, $self->loc->N("&Ok"));
                    $dlg->setDefaultButton($okButton);

                    while (1) {
                        my $event = $dlg->waitForEvent();

                        my $eventType = $event->eventType();
                        #event type checking
                        if ($eventType == $yui::YEvent::CancelEvent) {
                            last;
                        }
                        elsif ($eventType == $yui::YEvent::WidgetEvent) {
                            # widget selected
                            my $widget = $event->widget();

                            if ($widget == $cancelButton) {
                                last;
                            }
                            elsif ($widget == $okButton) {
                                my $server = $input->value();
                                my $ntpLabel = $dialog->widget('ntpLabel');
                                $info->{ntp_servers} = [  $server ];
                                $ntpLabel->setValue(join (',', @{$info->{ntp_servers}}));
                                last;
                            }
                        }
                    }

                    $dlg->destroy();
                }
            );
            $localNTPButton->setStretchable(0,1);

            $factory->createHSpacing($hbox1, 1.0);
            my $ntpService = $factory->createComboBox($hbox1, "", );
             $self->addWidget(
                "ntpService",
                $ntpService, sub { return 1;}
            );
            my $itemColl = new yui::YItemCollection;
            my $sel_serv = $module->sh_tz->currentNTPService();
            foreach my $serv (@{$module->sh_tz->ntpServiceList()}) {
                my $item = new yui::YItem ($serv, 0);
                $item->setSelected(1) if ($sel_serv && $sel_serv eq $serv);
                $itemColl->push($item);
                $item->DISOWN();
            }
            $ntpService->addItems($itemColl);

            $factory->createLabel($hbox1,$self->loc->N("Current:"));
            $factory->createHSpacing($hbox1, 1.0);
            my $ntpLabel = $factory->createLabel($hbox1, $self->loc->N("not defined"));
            $self->addWidget(
                "ntpLabel",
                $ntpLabel, sub {
                    return 1;
                },
            );
            if ($info->{ntp_servers}) {
                $ntpLabel->setValue(join (',', @{$info->{ntp_servers}}));
            }
            $ntpFrame->setValue($info->{ntp_running});
            $dateTimeFrame->setEnabled(!$info->{ntp_running});
            $ntpFrame->setNotify(1);

            $factory->createHSpacing($hbox1, 1.0);
            $ntpLabel->setWeight($yui::YD_HORIZ, 2);
            $chooseNTPButton->setWeight($yui::YD_HORIZ, 1);
            $factory->createHSpacing($hbox, 1.0);
            $factory->createVSpacing($layoutstart, 1.0);

            ### third line setting TZ
            $hbox = $factory->createHBox($layoutstart);
            $align  = $factory->createLeft($hbox);
            my $frame   = $factory->createFrame ($align, $self->loc->N("TimeZone"));
            $hbox1 = $factory->createHBox( $frame );
            my $changeTZButton = $factory->createPushButton($hbox1, $self->loc->N("Change &Time Zone"));
            $self->addWidget(
                "changeTZButton",
                $changeTZButton, sub {
                    my $event = shift; #ManaTools::Shared::GUI::Event
                    my $dialog = $event->parentDialog();
                    my $self = $dialog->module(); #this object

                    # get time to calculate elapsed
                    my $changeTZButton = $dialog->widget('changeTZButton');
                    my $t0 = localtime;
                    my $timezones = $self->sh_tz->getTimeZones();
                    if (!$timezones || scalar (@{$timezones}) == 0) {
                        $self->sh_gui->warningMsgBox({title => $self->loc->N("Timezone - DrakClock"),
                                                    text  => $self->loc->N("Failed to retrieve timezone list"),
                        });
                        $changeTZButton->setDisabled();
                    }
                    else {
                        my $info    = $dialog->info();
                        my $item = $self->sh_gui->ask_fromTreeList({
                            title => $self->loc->N("Timezone - DrakClock"),
                            header => $self->loc->N("Which is your timezone?"),
                            default_button => 1,
                            item_separator => '/',
                            default_item => $info->{time_zone}->{ZONE},
                            list  => $timezones,
                        });
                        if ($item) {
                            my $utc = 0;
                            if ($info->{time_zone}->{UTC} ) {
                                $utc = $info->{time_zone}->{UTC};
                            }
                            $utc = $self->sh_gui->ask_YesOrNo({
                                title  => $self->loc->N("GMT - manaclock"),
                                text   => $self->loc->N("Is your hardware clock set to GMT?"),
                                default_button => 1,
                            });
                            $info->{time_zone}->{UTC}  = $utc;
                            $info->{time_zone}->{ZONE} = $item;
                            my $timeZoneLbl = $dialog->widget('timeZoneLbl');
                            $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
                        }
                    }
                    # fixing elapsed time (dialog is modal)
                    my $t1 = localtime;
                    my $elapsed = $t1->epoch - $t0->epoch;

                    my $timeField = $dialog->widget('timeField');
                    my $dateField = $dialog->widget('dateField');
                    my $t = Time::Piece->strptime($dateField->value() . "T" . $timeField->value(),
                                                '%Y-%m-%dT%H:%M:%S') + $elapsed;
                    $timeField->setValue($t->strftime("%H:%M:%S"));
                    $dateField->setValue($t->strftime("%F"));
                    return 1;
                },
            );
            $factory->createHSpacing($hbox1, 1.0);
            $factory->createLabel($hbox1,$self->loc->N("Current:"));
            $factory->createHSpacing($hbox1, 1.0);
            my $timeZoneLbl = $factory->createLabel($hbox1, $self->loc->N("not defined"));
            $self->addWidget(
                "timeZoneLbl",
                $timeZoneLbl, sub {
                    return 1;
                },
            );

            if (exists $info->{time_zone} && $info->{time_zone}->{ZONE}) {
                $timeZoneLbl->setValue($info->{time_zone}->{ZONE});
            }
            $factory->createHSpacing($hbox1, 1.0);
            $timeZoneLbl->setWeight($yui::YD_HORIZ, 2);
            $changeTZButton->setWeight($yui::YD_HORIZ, 1);
            $factory->createHSpacing($hbox, 1.0);

            return $self->widget('layout');
        },
        restoreValues => sub {
            my $self = shift;

            my $module  = $self->module();


            return $module->_restoreValues();
        },
    );

    ## Manage timeout event
    ManaTools::Shared::GUI::Event->new(
        name => 'timeoutEvent',
        eventHandler => $dialog,
        eventType => $yui::YEvent::TimeoutEvent,
        event => sub {
            my $event = shift;
            my $dialog = $event->parentDialog();
            my $self = $dialog->module(); #this object

            my $timeField = $dialog->widget('timeField');
            my $t = Time::Piece->strptime($timeField->value(), "%H:%M:%S") + 1;
            $timeField->setValue($t->strftime("%H:%M:%S"));

            return 1;
         },
    );

    return $dialog->call();
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

