#!/usr/bin/perl
# vim: set et ts=4 sw=4:
#    Copyright 2012-2013 Angelo Naselli <anaselli@linux.it>
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

package AdminPanel::Shared;

use strict;
use warnings;
use diagnostics;
use lib qw(/usr/lib/libDrakX);
use common;
use yui;
use base qw(Exporter);

our @EXPORT = qw(warningMsgBox
         msgBox
         infoMsgBox
         ask_YesOrNo
         ask_OkCancel
         AboutDialog
         trim);

sub warningMsgBox {
    my ($st) = @_;
    my $factory = yui::YUI::widgetFactory;
    my $msg_box = $factory->createPopupDialog($yui::YDialogWarnColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub infoMsgBox {
    my ($st) = @_;
    my $factory = yui::YUI::widgetFactory;
    my $msg_box = $factory->createPopupDialog($yui::YDialogInfoColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub msgBox {
    my ($st) = @_;
    my $factory = yui::YUI::widgetFactory;
    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);
    my $align = $factory->createAlignment($layout, 3, 0);
    $factory->createLabel( $align, $st, 1, 0);
    $align = $factory->createAlignment($layout, 3, 0);
    $factory->createPushButton($align, N("Ok"));
    $msg_box->waitForEvent();

    destroy $msg_box;
}

sub ask_OkCancel {
    my ($title, $text) = @_;
    my $retVal = 0;
    my $factory = yui::YUI::widgetFactory;

    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);

    my $align = $factory->createAlignment($layout, 3, 0);
    ## title with headings true
    $factory->createLabel( $align, $title, 1, 0);
    $align = $factory->createLeft($layout);
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
        $retVal = ($widget == $okButton) ? 1 : 0;
    }

    destroy $msg_box;

    return $retVal;
}

sub ask_YesOrNo {
    my ($title, $text) = @_;
    my $retVal = 0;
    my $factory = yui::YUI::widgetFactory;

    my $msg_box = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($msg_box);

    my $align = $factory->createAlignment($layout, 3, 0);
    ## title with headings true
    $factory->createLabel( $align, $title, 1, 0);
    $align = $factory->createLeft($layout);
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
        $retVal = ($widget == $yesButton) ? 1 : 0;
    }

    destroy $msg_box;

    return $retVal;
}

sub AboutDialog {
    my ($opts) = @_;
    
    # Credits dialog
    sub Credits {
        my ($opts) = @_;
        
        my $factory  = yui::YUI::widgetFactory;
        my $optional = yui::YUI::optionalWidgetFactory;
        
        my $licensedlg = $factory->createPopupDialog();
        my $layout = $factory->createVBox($licensedlg);
        
        # header
        $factory->createHBox($layout);
        my $hbox  = $factory->createHBox($layout);
        my $align = $factory->createHVCenter($hbox);
        $hbox     = $factory->createHBox($align);
        $factory->createHeading($hbox, N("Credits"));
        
        # Credits tab widget
        if ($optional->hasDumbTab()) {
            $hbox = $factory->createHBox($layout);
            $align = $factory->createAlignment($hbox, 3, 0);
            my $dumptab = $optional->createDumbTab($align);
            my $item = new yui::YItem(N("Written by"));
            $item->setSelected();
            $dumptab->addItem( $item );
            $item->DISOWN();
            if (exists $opts->{documenters}) {
                $item = new yui::YItem(N("Documented by"));
                $dumptab->addItem( $item );
                $item->DISOWN();
            }
            if (exists $opts->{translator_credits}) {
                $item = new yui::YItem(N("Translated by"));
                $dumptab->addItem( $item );
                $item->DISOWN();
            }
            if (exists $opts->{artists}) {
                $item = new yui::YItem(N("Artwork by"));
                $dumptab->addItem( $item );
                $item->DISOWN();
            }
            my $vbox = $factory->createVBox($dumptab);
            $align = $factory->createLeft($vbox);
            $factory->createVSpacing($vbox, 1.0);
            my $label = $factory->createRichText( $align, "***", 1);
            $factory->createVSpacing($vbox, 1.0);
       
            # start value for first Item
            $label->setValue($opts->{authors}) if exists $opts->{authors};
        
            # Close button
            $align = $factory->createRight($layout);
            my $closeButton = $factory->createPushButton($align, N("Close"));
            
            # manage Credits dialog events
            while(1) {
                my $event     = $licensedlg->waitForEvent();
                my $eventType = $event->eventType();
                
                #event type checking
                if ($eventType == $yui::YEvent::CancelEvent) {
                    last;
                }
                elsif ($eventType == $yui::YEvent::WidgetEvent) {
                    # widget selected
                    my $widget = $event->widget();

                    if ($widget == $closeButton) {
                        last;
                    }                  
                }
                elsif ($event->item() ) {
                    # $eventType MenuEvent!!!
                    my $itemLabel = $event->item()->label();
                    $itemLabel =~ s/&//; #remove shortcut from label
                    if ($itemLabel eq N("Written by")) {
                        $label->setValue($opts->{authors}) if exists $opts->{authors};
                    }
                    elsif ($itemLabel eq N("Documented by")) {
                        $label->setValue($opts->{documenters}) if exists $opts->{documenters};
                    }
                    elsif ($itemLabel eq N("Translated by")) {
                        $label->setValue($opts->{translator_credits}) if exists $opts->{translator_credits};
                    }
                    elsif ($itemLabel eq N("Artwork by")) {
                        $label->setValue($opts->{artists}) if exists $opts->{artists};
                    }  
                }
            }
        }
        else {
            print "No tab widgets available!\n";
        }
        destroy $licensedlg;
    }
    
    # License dialog
    sub License {
        my ($license) = @_;
        
        my $factory = yui::YUI::widgetFactory;
        my $licensedlg = $factory->createPopupDialog();
        my $layout = $factory->createVBox($licensedlg);
        
        # header
        $factory->createHBox($layout);
        my $hbox  = $factory->createHBox($layout);
        my $align = $factory->createHVCenter($hbox);
        $hbox     = $factory->createHBox($align);
        $factory->createHeading($hbox, N("License"));
        
        # license
        $hbox = $factory->createHBox($layout);
        $align = $factory->createAlignment($hbox, 3, 0);
        $factory->createRichText( $align, $license, 1);
            
        $align = $factory->createRight($layout);
        my $closeButton = $factory->createPushButton($align, N("Close"));
        
        $licensedlg->waitForEvent();
        
        destroy $licensedlg;
    }
    
    my $website = "http://www.mageia.org";
    my $website_label = "Mageia";
    my $factory = yui::YUI::widgetFactory;
    my $aboutdlg = $factory->createPopupDialog();
    my $layout = $factory->createVBox($aboutdlg);

    # header
    $factory->createHBox($layout);
    my $hbox_iconbar  = $factory->createHBox($layout);
    my $align  = $factory->createHVCenter($hbox_iconbar);
    $hbox_iconbar     = $factory->createHBox($align);
    $factory->createImage($hbox_iconbar, $opts->{logo}) if exists $opts->{logo};
    my $header = $opts->{name} . " " . $opts->{version};
    $factory->createHeading($hbox_iconbar, $header);

    # comments
    my $hbox = $factory->createHBox($layout);
    $align = $factory->createAlignment($hbox, 3, 0);
    $factory->createLabel( $align, $opts->{comments}, 0, 0) if exists $opts->{comments};
    
    # copyright
    $hbox = $factory->createHBox($layout);
    $align = $factory->createHVCenter($hbox);
    $factory->createLabel( $align, $opts->{copyright}, 0, 0) if exists $opts->{copyright};

    # website / website_label
    $hbox = $factory->createHBox($layout);
    $align = $factory->createHVCenter($hbox);
    $website = $opts->{website} if exists $opts->{website};
    $website_label = $opts->{website_label} if exists $opts->{website_label};
    my $webref = "<a href=\"". $website ."\">". $website_label ."</a>";
    $factory->createRichText( $align, $webref);
    
    # Credits, License and Close buttons
    $hbox = $factory->createHBox($layout);
    $align = $factory->createLeft($hbox);
    my $hbox1 = $factory->createHBox($align);
    my $creditsButton = $factory->createPushButton($hbox1, N("Credits"));
    my $licenseButton = $factory->createPushButton($hbox1, N("License"));
    $factory->createHSpacing($hbox, 2.0);
    $align = $factory->createRight($hbox);
    my $closeButton = $factory->createPushButton($align, N("Close"));
    
    # AboutDialog Events
    while(1) {
        my $event     = $aboutdlg->waitForEvent();
        my $eventType = $event->eventType();
        
        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();

            if($widget == $licenseButton) {
                License($opts->{license}) if exists $opts->{license};
            }
            elsif ($widget == $creditsButton) {
                Credits($opts);
            }
            elsif ($widget == $closeButton) {
                last;
            }
        }
        elsif ($eventType == $yui::YEvent::MenuEvent) {
            my  $menuEvent = yui::YMGAWidgetFactory::getYMenuEvent($event);
            #TODO check why is not working
            run_program::raw({ detach => 1 }, 'www-browser', $menuEvent->id());
        }
    }
    
    destroy $aboutdlg;
}

sub trim {
    my ($st) = shift;
    $st =~s /^\s+//g;
    $st =~s /\s+$//g;
    return $st;
}

1;

=head1 NAME

       Shared - shared module providing common routines

=head1 SYNOPSIS


=head1 METHODS

=head2 warningMsgBox

=head2 msgBox

       shows a simple message box

=head2 infoMsgBox

       shows a message box for informations

=head2 AboutDialog

       shows an About Dialog box 

=head2 ask_YesOrNo

       shows a dialog with two buttons (Yes/No)

=head3 return bool

=head2 ask_OkCancel

       shows a dialog with to buttons (Ok/Cancel)

=head3 return bool
