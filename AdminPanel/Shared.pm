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

=head2 ask_YesOrNo

       shows a dialog with two buttons (Yes/No)

=head3 return bool

=head2 ask_OkCancel

       shows a dialog with to buttons (Ok/Cancel)

=head3 return bool
