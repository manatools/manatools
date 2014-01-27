#!/usr/bin/perl
# vim: set et ts=4 sw=4:
#    Copyright 2012-2013 Angelo Naselli <anaselli@linux.it>
#
#    This file is part of AdminPanel
#
#    AdminPanel is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    AdminPanel is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.

package AdminPanel::Shared;

=head1 NAME

AdminPanel::Shared - AdminPanel::Shared contains all the shared routines 
                     needed by AdminPanel and modules

=head1 SYNOPSIS

    

=head1 DESCRIPTION

This module collects all the routines shared between AdminPanel and its modules.

=head1 EXPORT

    warningMsgBox
    msgBox
    infoMsgBox
    ask_YesOrNo
    ask_OkCancel
    AboutDialog
    trim


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc AdminPanel::Shared

=head1 AUTHOR

Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

Copyright (C) 2013, Angelo Naselli.

This file is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This file is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this file.  If not, see <http://www.gnu.org/licenses/>.

=head1 FUNCTIONS

=cut

use strict;
use warnings;
use diagnostics;

use lib qw(/usr/lib/libDrakX);
use common qw(N 
              N_);
use yui;
use base qw(Exporter);

# TODO move GUI dialogs to Shared::GUI
our @EXPORT = qw(
                warningMsgBox
                msgBox
                infoMsgBox
                ask_YesOrNo
                ask_OkCancel
                ask_fromList
                AboutDialog
                trim 
                member
);


=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

our $License = N_("This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
");


#=============================================================

=head2 warningMsgBox

=head3 INPUT

    $st: string to be swhon into the dialog

=head3 DESCRIPTION

This function creates an Warning dialog and show the message 
passed as input.

=cut

#=============================================================

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

#=============================================================

=head2 infoMsgBox

=head3 INPUT

    $st: string to be swhon into the dialog

=head3 DESCRIPTION

This function creates an Info dialog and show the message 
passed as input.

=cut

#=============================================================

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

#=============================================================

=head2 msgBox

=head3 INPUT

    $st: string to be swhon into the dialog

=head3 DESCRIPTION

This function creates a dialog and show the message passed as input.

=cut

#=============================================================

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

#=============================================================

=head2 ask_OkCancel

=head3 INPUT

    $title: Title shown as heading
    $text:  text to be shown into the dialog

=head3 OUTPUT

    0: Cancel button has been pressed
    1: Ok button has been pressed

=head3 DESCRIPTION

This function create an OK-Cancel dialog with a 'title' and a 
'text' passed as parameters.

=cut

#=============================================================

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

#=============================================================

=head2 ask_YesOrNo

=head3 INPUT

    $title: Title shown as heading
    $text:  question text to be shown into the dialog

=head3 OUTPUT

    0: "No" button has been pressed
    1: "Yes" button has been pressed

=head3 DESCRIPTION

This function create a Yes-No dialog with a 'title' and a 
question 'text' passed as parameters.

=cut

#=============================================================

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


#=============================================================

=head2 ask_fromList

=head3 INPUT

    $title: dialog title
    $text:  combobox heading
    $list:  item list 

=head3 OUTPUT

    undef:          if Cancel button has been pressed
    selected item:  if Ok button has been pressed

=head3 DESCRIPTION

This function create a dialog with a combobox in which to 
choose an item from a given list.

=cut

#=============================================================

sub ask_fromList {
    my ($title, $text, $list) = @_;
    
    die "Title is mandatory"   if (! $title);
    die "Heading is mandatory" if (! $text);
    die "List is mandatory"   if (! $list );
    die "At least one element is mandatory into list"   if (scalar(@$list) < 1);

    my $choice  = undef;
    my $factory = yui::YUI::widgetFactory;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($title);

    my $dlg = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($dlg);

    my $combo   = $factory->createComboBox($layout, $text, 0);
    my $itemColl = new yui::YItemCollection;
    foreach (@$list) {
            my $item = new yui::YItem ($_, 0);
            $itemColl->push($item);
            $item->DISOWN();
    }
    $combo->addItems($itemColl);

    my $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    my $okButton = $factory->createPushButton($hbox, N("Ok"));
    my $cancelButton = $factory->createPushButton($hbox, N("Cancel"));

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
                my $item = $combo->selectedItem();
                $choice = $item->label() if ($item);
                last;
            }
        }
    }

    destroy $dlg;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
    
    return $choice;
}


#=============================================================

=head2 AboutDialog

=head3 INPUT

    $opts: optional options needed to get info for dialog.
           name          => Application Name,
           version       => Application Version,
           copyright     => Copyright ususally like "Copyright (C) copyright-holder Year",
           license       => License text, 
           comments      => A comment related to application to be shown,
           website       => Web site URL,
           website_label => Label to hide previous link,
           authors       => Application authors,
           translator_credits => Application translators 
           documenters   => Application documenters 
           artists       => Graphic applicaton designers
           logo          => picture path to be shown as application logo

=head3 OUTPUT

    Output_Parameter: out_par_description

=head3 DESCRIPTION

About dialog implementation, this dialog can be used by
modules, to show authors, license, credits, etc.

=cut

#=============================================================

sub AboutDialog {
    my ($opts) = @_;
    
    # Credits dialog
    sub Credits {
        my ($opts) = @_;
        
        my $factory  = yui::YUI::widgetFactory;
        my $optional = yui::YUI::optionalWidgetFactory;
        
        my $creditsdlg = $factory->createPopupDialog();
        my $layout = $factory->createVBox($creditsdlg);
        
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
            my $label = $factory->createLabel( $align, "***", 0);
            $factory->createVSpacing($vbox, 1.0);
       
            # start value for first Item
            $label->setValue($opts->{authors}) if exists $opts->{authors};
        
            # Close button
            $align = $factory->createRight($layout);
            my $closeButton = $factory->createPushButton($align, N("Close"));
            
            # manage Credits dialog events
            while(1) {
                my $event     = $creditsdlg->waitForEvent();
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
        destroy $creditsdlg;
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
        $factory->createLabel( $align, $license);
            
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

#=============================================================

=head2 trim

=head3 INPUT

    $st: String to be trimmed

=head3 OUTPUT

    $st: trimmed string

=head3 DESCRIPTION

This function trim the given string.

=cut

#=============================================================

sub trim {
    my ($st) = shift;
    $st =~s /^\s+//g;
    $st =~s /\s+$//g;
    return $st;
}

#=============================================================

=head2 member

=head3 INPUT

    $e: Array element to be found into array
    @_: any array

=head3 OUTPUT

    1 or 0: if $e is a member of the given array

=head3 DESCRIPTION

This function look for an element into an array

=cut

#=============================================================
sub member { 
    my $e = shift; 
    foreach (@_) { 
        $e eq $_ and return 1;
    } 
    0; 
}

1; # End of AdminPanel::Shared
