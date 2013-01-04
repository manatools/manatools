#! /usr/bin/perl
# vim: set et ts=4 sw=4:
#    Copyright 2012 Angelo Naselli <anaselli@linux.it>
#
#    This file is part of LogViever
#
#    LogViever is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    LogViever is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with LogViever.  If not, see <http://www.gnu.org/licenses/>.

package LogViewer;

use strict;
use POSIX qw/strftime floor/;
use Date::Simple ();
use File::HomeDir qw(home);
# use FindBin::Bin;
# use lib "$FindBin::RealBin";
use lib qw(/usr/lib/libDrakX);
use standalone;     #- warning, standalone must be loaded very first, for 'explanations'
use c;
use common;
#use AdminPanel::Privileges;
use yui;

### TODO icon 
my $wm_icon = "/usr/share/mcc/themes/default/logdrake-mdk.png";

#ask_for_authentication() if(require_root_capability());

my ($isExplain, $Explain, $isFile, $File, $isWord, $Word);

#- parse arguments list.
foreach (@ARGV) {
    /^--explain=(.*)$/ and do { $isExplain = ($Explain) = $1; $isFile = 1; $File = "/var/log/explanations"; next };
    /^--file=(.*)$/ and do { $isFile = ($File) = $1; next };
    /^--word=(.*)$/ and do { $isWord = ($Word) = $1; next };
    /^--alert$/ and do { alert_config(); quit() };
}

my $isTail = $isFile;
$| = 1 if $isTail;
my $h = chomp_(`hostname -s`);

my @months = qw(Err Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

my $explain_title = N("%s Tools Logs", N("Mageia"));

yui::YUI::app()->setApplicationTitle($isExplain ? $explain_title : N("Log viewer"));
yui::YUI::app()->setApplicationIcon($wm_icon);

my $factory = yui::YUI::widgetFactory;
my $optFactory = yui::YUI::optionalWidgetFactory;

### MAIN DIALOG ###
my $my_win = $factory->createMainDialog;


my %files = (
    "auth" => { file => "/var/log/auth.log", desc => N("_:this is the auth.log log file\nAuthentication") },
    "user" => { file => "/var/log/user.log", desc => N("_:this is the user.log log file\nUser") },
    "messages" => { file => "/var/log/messages", desc => N("_:this is the /var/log/messages log file\nMessages") },
    "syslog" => { file => "/var/log/syslog", desc => N("_:this is the /var/log/syslog log file\nSyslog") },
    "explanations" => { file => "/var/log/explanations", desc => $explain_title }
);

my %toggle;
my $searchButton  = 0;
my $matchingInputField = 0;
my $notMatchingInputField = 0;
my $progressBarPosition = 0;
my $fileChooserFrame = 0;
my $calendarFrame = 0;
my $journalctlFrame = 0;
my $calendar = 0;
my $journalAll = 0;
my $journalFree = 0;
my $journalFreeInputField = 0;

my $mainLayout = $factory->createVBox($my_win);

my $align = $factory->createAlignment($mainLayout, 3, 0);
$factory->createLabel( $align, N("A tool to monitor your logs"), 1, 0);

if (!$isFile) {
    my $vbox = $factory->createVBox($mainLayout);
    $align = $factory->createAlignment($vbox, 1, 0);
    $factory->createLabel($align, N("Settings") );

    my $hbox = $factory->createHBox($vbox);
    #input field aligned to left
    $align = $factory->createLeft($hbox);
    $matchingInputField = $factory->createInputField($align, N("Matching"));

    $factory->createHSpacing($hbox, 5);

    #input field aligned to left
    $align = $factory->createLeft($hbox);
    $notMatchingInputField = $factory->createInputField($align, N("but not matching"));

    $hbox = $factory->createHBox($vbox);

    $fileChooserFrame = $factory->createCheckBoxFrame($hbox, N("Choose file"), 1);
    $fileChooserFrame->setNotify(1);
    $journalctlFrame = $factory->createCheckBoxFrame($hbox, N("Get from the journal"), 1);
    $journalctlFrame->setNotify(1);
    $calendarFrame = $factory->createCheckBoxFrame($hbox, N("Calendar"), 1);

    $fileChooserFrame->setWeight(0, 40);
    $journalctlFrame->setWeight(0, 40);
    $calendarFrame->setWeight(0, 20);

    $searchButton = $factory->createPushButton($vbox, N("search"));
    $searchButton->setStretchable(0, 1);
    #  here we change the widget (add and remove progress bar)
    $progressBarPosition = $factory->createReplacePoint($vbox);
    $factory->createLabel($progressBarPosition, "");

    # file chooser 
    $vbox = $factory->createVBox($fileChooserFrame);
    for my $cb (keys %files) {
        $align = $factory->createAlignment($vbox, 1, 0);
        $toggle{$cb} = $factory->createCheckBox($align, $files{$cb}{desc}, 0);
    }

    # journalctl    
    my $rg = $factory->createRadioButtonGroup($journalctlFrame);
    $vbox = $factory->createVBox($rg);
    $align = $factory->createAlignment($vbox, 1, 0);
    $journalAll = $factory->createRadioButton($align, N("Whole journal"), 1);
    if ($journalAll->buttonGroup()) {
        $journalAll->buttonGroup()->addRadioButton($journalAll);
    }
    $align = $factory->createAlignment($vbox, 1, 0);
    $hbox = $factory->createHBox($align);
    $journalFree = $factory->createRadioButton($hbox, N("Free journalctl parameters"), 0);
    if ($journalFree->buttonGroup()) {
        $journalFree->buttonGroup()->addRadioButton($journalFree);
    }
    $journalFreeInputField = $factory->createInputField($hbox, N("journalctl parameters"));

    # calendar
    $vbox = $factory->createVBox($calendarFrame);
    $align = $factory->createAlignment($vbox, 3, 3);

    if ($optFactory->hasDateField()) {
        $calendar = $optFactory->createDateField($align, "");
        my $day = strftime "%F", localtime;
        $calendar->setValue($day);
    }

    ### NOTE CheckBoxFrame doesn't honoured his costructor checked value for his children
    $calendarFrame->setValue(0);
    $journalctlFrame->setValue(0);
}
# create log view object
my $logView = $factory->createLogView($mainLayout, N("Content of the file"), 10, 0);

# buttons are on the ritght
$align = $factory->createRight($mainLayout);
my $hbox = $factory->createHBox($align);
my $mailALertButton = $factory->createPushButton($hbox, N("Mail alert"));
my $SaveButton = $factory->createPushButton($hbox, N("Save"));
my $QuitButton = $factory->createPushButton($hbox, N("Quit"));


search() if $isFile;

######## main loop ####################
while(1) {
    my $event = $my_win->waitForEvent();

    my $eventType = $event->eventType();

    #event type checking
    if ($eventType == $yui::YEvent::CancelEvent) {
        quit();
        last;
    }
    elsif ($eventType == $yui::YEvent::WidgetEvent) {
        # widget selected
        my $widget      = $event->widget();

        if($widget == $SaveButton) {
            save();
        }
        elsif ($widget == $QuitButton) {
            quit();
            last;
        }
        elsif ($searchButton && $widget == $searchButton) {
            $logView->clearText();
            search();
        }
        elsif ($fileChooserFrame && $widget == $fileChooserFrame) {
            # block journalctl frame notification
            $journalctlFrame->setNotify(0);
            if ($fileChooserFrame->value()) {
                # unchecK $journalctlFrame
                $journalctlFrame->setValue(0);
            }
            else {
                # checK $journalctlFrame
                $journalctlFrame->setValue(1);
            }
            # unblock journalctl frame notification
            $journalctlFrame->setNotify(1);
        }
        elsif ($journalctlFrame && $widget == $journalctlFrame) {
            # block file chooser frame notification
            $fileChooserFrame->setNotify(0);
            if ($journalctlFrame->value()) {
                # unchecK $fileChooserFrame
                $fileChooserFrame->setValue(0);
            }
            else {
                # checK $fileChooserFrame
                $fileChooserFrame->setValue(1);
            }
            # unblock file chooser frame notification
            $fileChooserFrame->setNotify(1);
        }
       elsif ($widget == $mailALertButton) {
           alert_config();
       }
        else {
            warningMsgBox(N("Unmanaged WidgetEvent"));
        }
    }
}

######### fuctions  #################

## Search call back
sub search() {
    if ($isFile) {
        parse_file($File, $File);
    } else {
        if ($fileChooserFrame && $fileChooserFrame->value()) {
            foreach (keys %files) {
                parse_file($files{$_}{file}, $files{$_}{desc}) if $toggle{$_}->isChecked();
            }
        }
        elsif ($journalctlFrame && $journalctlFrame->value()) {
            my @all;
            # using journal log
            # there is not any perl binding at the moment
            if ($journalAll->value()) {
                if ($calendarFrame && $calendarFrame->value() == 1 && $calendar) {
                    my $date  = Date::Simple->new($calendar->value());
                    @all = `journalctl --all --no-pager --since=$date`;
                }
                else {
                    @all = `journalctl --all --no-pager`;
                }
            }
            elsif ($journalFree->value()) {
                if ($calendarFrame && $calendarFrame->value() == 1 && $calendar) {
                    my $date  = Date::Simple->new($calendar->value());
                    my $param = $journalFreeInputField->value();
                    @all = `journalctl --no-pager --since=$date $param`;
                }
                else {
                    my $param = $journalFreeInputField->value();
                    @all = `journalctl --all --no-pager $param`;
                }
            }
            parse_content(@all, N("from journalctl"));
        }
    }
}

sub parse_content {
    my (@all, $descr) = @_;

    my $pbar = 0;
    my $ey = "";
    my $en = "";

    if ($progressBarPosition) {
        $my_win->startMultipleChanges();
        $progressBarPosition->deleteChildren();
        $pbar = $factory->createProgressBar($progressBarPosition, N("please wait, parsing file: %s", $descr), 100);
        $progressBarPosition->showChild();
        $my_win->recalcLayout();
        $my_win->doneMultipleChanges();
    }

    ## TODO if no input maybe we could load all instead of nothing
    if ($matchingInputField) {
        $ey = $matchingInputField->value();
    }
    if ($notMatchingInputField) {
        $en = $notMatchingInputField->value();
    }
    $ey =~ s/ OR /|/;
    $ey =~ s/^\*$//;
    $en =~ s/^\*$/.*/;
    $ey = $ey . $Word if $isWord;

    #### calendar
    if ($journalAll && !$journalAll->value() && $journalFree && !$journalFree->value()) {
        if ($calendarFrame && $calendarFrame->value() == 1 && $calendar) {
            my $date  = Date::Simple->new($calendar->value());
            my $month = $date->month;
            my $day   = $date->day;
            $ey = $months[$month] . "\\s{1,2}$day\\s.*$ey.*\n";
        }
    }


    if ($isExplain) {
        my (@t, $t);
        while (@all) {
            $t = pop @all;
            next if $t =~ /logdrake/;
            last if $t !~ /$Explain/;
            push @t, $t;
        }
        @all = reverse @t;
    }

    my $taille = @all;
    my $i = 0;
    my $test;

    if ($en && !$ey) {
        $test = sub { $_[0] !~ /$en/ };
    } elsif ($ey && !$en) {
        $test = sub { $_[0] =~ /$ey/ };
    } else {
        $test = sub { $_[0] =~ /$ey/ && $_[0] !~ /$en/ };
    }

    foreach (@all) {
        $i++;
        if ($pbar && $i % 10) {
            $pbar->setValue(floor(100*$i/$taille));
        }
        if ($journalFree && $journalFree->value()) {
            $logView->appendLines($_);
        }
        else {
            $logView->appendLines($_) if $test->($_);
        }
    }

    if ($progressBarPosition) {
        $my_win->startMultipleChanges();
        $progressBarPosition->deleteChildren();
        $factory->createLabel($progressBarPosition, "");
        $progressBarPosition->showChild();
        $my_win->recalcLayout();
        $my_win->doneMultipleChanges();
        $pbar = 0;
    }

}

sub parse_file {
    my ($file, $descr) = @_;

    $file =~ s/\.gz$//;

    logText("****************************************");
    logText($file . " - " . $descr);

    my @all = -e $file ? catMaybeCompressed($file) : N("Sorry, log file isn't available!");

    parse_content(@all, $descr);

    if ($isTail && ! $isWord) {
        my $F;
        unless (open ($F, "<", $file)) {
            my $error = $!;
            my $string = N("Error while opening \"%s\" log file: %s", $file, $error);
            logText($string);
            return;
        }
        while ( ! eof($F) ) {
            my $buffer = readline( $F );
            $logView->appendLines($buffer) if $buffer;
        } 
        close $F if $F;
    }
}

## Append a custom string to log view adding date
sub logText {
    my ($st) = @_;

    my $string = strftime('%Y %b %d %T', localtime) . " " . $st . "\n";
    # convert to utf8:
    c::set_tagged_utf8($string);

    # log given text
    $logView->appendLines($string);
}

## Save as
sub save() {
    my $outFile = yui::YUI::app()->askForSaveFileName(home(), "*", N("Save as.."));
    if ($outFile) {
        output($outFile, $logView->logText());
    }
}

## Quit 
sub quit() {
    $my_win->destroy();
}

## alert config call back
sub alert_config() {
## TODO
    infoMsgBox(N("To be implemented yet"));
    return;
}


### Begin interactive functions ###
# NOTE next routines (from BEGIN to END) have to be moved to a package and
#      factory got by using yui::YUI::widgetFactory

sub warningMsgBox() {
    my ($st) = @_;
    my $msg_box = $factory->createPopupDialog($yui::YDialogWarnColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub infoMsgBox() {
    my ($st) = @_;
    my $msg_box = $factory->createPopupDialog($yui::YDialogInfoColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub msgBox() {
    my ($st) = @_;
    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub ask_OkCancel() {
    my ($title, $text) = @_;
    my $retVal = 0;

    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);

    my $align = $factory->createAlignment($layout, 3, 0);
    ## title with headings true
    $factory->createLabel( $align, $title, 1, 0);
    my $align = $factory->createLeft($layout);
    $factory->createLabel( $align, $text, 0, 0);

    $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    my $okButton = $factory->createPushButton($hbox, N("Ok"));
    my $cancelButton = $factory->createPushButton($hbox, N("Cancel"));

    my $event = $msg_box->waitForEvent();

    my $eventType = $event->eventType();

    if ($eventType == $yui::YEvent::WidgetEvent) {
        # widget selected
        my $widget      = $event->widget();
        $retVal = ($widget == $okButton);
    }

    destroy $msg_box;

    return $retVal;
}

sub ask_YesOrNo() {
    my ($title, $text) = @_;
    my $retVal = "No";

    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);

    my $align = $factory->createAlignment($layout, 3, 0);
    ## title with headings true
    $factory->createLabel( $align, $title, 1, 0);
    my $align = $factory->createLeft($layout);
    $factory->createLabel( $align, $text, 0, 0);

    $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    my $yesButton = $factory->createPushButton($hbox, N("Yes"));
    my $noButton  = $factory->createPushButton($hbox, N("No"));

    my $event = $msg_box->waitForEvent();

    my $eventType = $event->eventType();

    if ($eventType == $yui::YEvent::WidgetEvent) {
        # widget selected
        my $widget      = $event->widget();
        $retVal = ($widget == $yesButton) ? "Yes" : "No";
    }

    destroy $msg_box;

    return $retVal;
}

### END interactive functions ###

### NOTE next code has to be removed after getting mail alert functionality
=comment

#-------------------------------------------------------------
# mail/sms alert
#-------------------------------------------------------------

sub alert_config() {
    local $::isEmbedded = 0;
    undef $::WizardTable;
    undef $::WizardWindow;
    my $conffile = "/etc/sysconfig/mail_alert";
    my %options = getVarsFromSh($conffile);
    $options{LOAD} ||= 3;
    $options{MAIL} ||= "root";
    $options{SMTP} ||= "localhost";
    
    my $service = {
        httpd => N("Apache World Wide Web Server"),
        bind => N("Domain Name Resolver"),
        ftp => N("Ftp Server"),
        postfix => N("Postfix Mail Server"),
        samba => N("Samba Server"),
        sshd => N("SSH Server"),
        webmin => N("Webmin Service"),
        xinetd => N("Xinetd Service")
    };
    my @installed_d = grep { -e "/etc/init.d/$_" } sort keys %$service;
    my %services_to_check = map { $_ => 1 } split(':', $options{SERVICES});

    $::isWizard = 1;
    my $mode;
    my $cron_file = "/etc/cron.hourly/logdrake_service";
    my %modes = (
                   configure => N("Configure the mail alert system"),
                   disable =>  N("Stop the mail alert system"),
                  );
    require wizards;
    my $wiz = wizards->new({
               defaultimage => "logdrake.png",
               name => N("Mail alert"),
               pages => {
                         welcome => {
                                     name => N("Mail alert configuration") . "\n\n" .
                                     N("Welcome to the mail configuration utility.\n\nHere, you'll be able to set up the alert system.\n"),
                                     no_back => 1,
                                     data => [
                                              { val => \$mode, label => N("What do you want to do?"),
                                                list => [ keys %modes ], format => sub { $modes{$_[0]} },  },
                                              ],

                                     post => sub { $mode eq 'configure' ? 'services' : 'stop' },
                                    },
                         services => {
                                      name => N("Services settings") . "\n\n" .
                                      N("You will receive an alert if one of the selected services is no longer running"),
                                      data => [ map { { label => $_, val => \$services_to_check{$_}, 
                                                          type => "bool", text => $service->{$_} } } @installed_d ],
                                      next => "load",
                                     },
                         load => {
                                  #PO- Here "load" is a noun; that is load refers to the system/CPU) load
                                  name => N("Load setting") . "\n\n" .
                                  N("You will receive an alert if the load is higher than this value"),
                                  data => [ { label => N("_: load here is a noun, the load of the system\nLoad"), 
                                              val => \$options{LOAD}, type => 'range', min => 1, max => 50 } ],
                                  next => "email",
                                 },
                         email => {
                                   name => N("Alert configuration") . "\n\n" .
                                   N("Please enter your email address below ") . "\n" .
                                   N("and enter the name (or the IP) of the SMTP server you wish to use"),
                                   data => [
                                            { label => "Email address", val => \$options{MAIL} },
                                            { label => "Email server", val => \$options{SMTP} },
                                           ],
                                   complete => sub {
                                       if ($options{MAIL} !~ /[\w.-]*\@[\w.-]/ && !member($options{MAIL}, map { $_->[0] } list_passwd())) {
                                           err_dialog(N("Error"), N("\"%s\" neither is a valid email nor is an existing local user!",
                                                                          $options{MAIL}));
                                           return 1;
                                       }
                                       if (member($options{MAIL}, map { $_->[0] } list_passwd()) && $options{SMP} !~ /localhost/) {
                                           err_dialog(N("Error"), N("\"%s\" is a local user, but you did not select a local smtp, so you must use a complete email address!", $options{MAIL}));
                                           return 1;
                                       }
                                   },
                                   next => "end",
                                  },
                         end => {
                                 name => N("Congratulations") . "\n\n" . N("The wizard successfully configured the mail alert."), 
                                 end => 1,
                                 no_back => 1,
                                },
                         stop => {
                                  pre => sub { eval { rm_rf($cron_file) } },
                                  name => N("Congratulations") . "\n\n" . N("The wizard successfully disabled the mail alert."), 
                                  end => 1,
                                  no_back => 1,
                                },
                        },
              });
    $wiz->process($in);
    return if $mode eq 'disable';
    
    $options{SERVICES} = join ':', grep { $services_to_check{$_} } sort keys %services_to_check;

    use Data::Dumper;
    output_with_perm $cron_file, 0755, q(#!/usr/bin/perl
# generated by logdrake
use MDK::Common;
my $r;
my %options = getVarsFromSh("/etc/sysconfig/mail_alert");

#- check services
my ) . Data::Dumper->Dump([ $service ], [qw(*services)]) . q(
foreach (split(':', $options{SERVICES})) {
    next unless $services{$_};
    $r .= "Service $_ ($services{$_} is not running)\\n" unless -e "/var/lock/subsys/$_";
}

#- load
my ($load) = split ' ', first(cat_("/proc/loadavg"));
$r .= "Load is huge: $load\n" if $load > $options{LOAD};

#- report it
if ($r) {
    use Mail::Mailer;
    my $mailer = Mail::Mailer->new('smtp', Server => $options{SMTP});
    $mailer->open({ From    => 'root@localhost',
                    To      => $options{MAIL},
                    Subject => "DrakLog Mail Alert",
                  })
      or die "Cannot open: $!\n";
    print $mailer $r;
    $mailer->close;
}

# EOF);
    setVarsInSh($conffile, \%options);
        
    if (defined $::WizardWindow) {
	$::WizardWindow->destroy;
	undef $::WizardWindow;
    }
}

=cut


1
