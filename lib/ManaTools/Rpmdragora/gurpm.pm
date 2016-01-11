# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::gurpm;

#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::Rpmdragora::gurpm - Module that shows the urpmi
                                    progress status

=head1 SYNOPSIS

    my %option = (title => "Urpmi action ivoked", text => "Please wait", );
    my $gurpmi = ManaTools::Rpmdragora::gurpm->new(%option);
    $gurpmi->progress(45);

    #add to an existing dialog
    %option = (title => "Urpmi action ivoked", text => "Please wait", main_dialog => $dialog, parent => $parent_container);
    $gurpmi = ManaTools::Rpmdragora::gurpm->new(%option);
    $gurpmi->progress(20);

=head1 DESCRIPTION

    This class is used to show the progress of an urpmi operation on
    its progress bar. It can be istantiated as a popup dialog or used
    to add label and progress bar into a YLayoutBox container.

=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::Rpmdragora::gurpm

=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

    Matteo Pasotti <matteo.pasotti@gmail.com>

=head1 COPYRIGHT and LICENSE

    Copyright (c) 2002 Guillaume Cottenceau
    Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
    Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
    Copyright (c) 2005-2007 Mandriva SA
    Copyright (c) 2013-2016 Matteo Pasotti <matteo.pasotti@gmail.com>
    Copyright (C) 2015, Angelo Naselli <anaselli@linux.it>

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

=cut


use Moose;
use Carp;
use Time::HiRes;

use yui;
use feature 'state';


has 'title' => (
    is => 'rw',
    isa => 'Str',
);

has 'text' => (
    is => 'rw',
    isa => 'Str',
);

has 'main_dialog' => (
    is => 'rw',
    isa => 'yui::YDialog',
);

has 'parent' => (
    is => 'rw',
    isa => 'yui::YReplacePoint',
);

has 'label_widget' => (
    is => 'rw',
    isa => 'yui::YLabel',
    init_arg  => undef,
);

has 'progressbar' => (
    is => 'rw',
    isa => 'yui::YProgressBar',
    init_arg  => undef,
);

#=============================================================

=head2 BUILD

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    in this methods Services loads all the service information.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    my $factory = yui::YUI::widgetFactory;
    my $vbox;

    if (! $self->main_dialog) {
        if ($self->parent) {
            carp "WARNING: parent parameter is skipped without main_dialog set\n" ;
            $self->parent(undef);
        }
        $self->main_dialog($factory->createPopupDialog());
        $vbox =  $factory->createVBox($self->main_dialog);
    }
    else {
        die "parent parameter is mandatory with main_dialog" if !$self->parent;
        $self->main_dialog->startMultipleChanges();
        $self->parent->deleteChildren();
        $vbox = $factory->createVBox($self->parent);
        $factory->createVSpacing($vbox, 0.5);
    }

    $self->label_widget( $factory->createLabel($vbox, $self->text) );
    $self->label_widget->setStretchable( $yui::YD_HORIZ, 1 );
    $self->progressbar( $factory->createProgressBar($vbox, "") );

    if ($self->parent) {
        $factory->createVSpacing($vbox, 0.5);
        $self->parent->showChild();
        $self->main_dialog->recalcLayout();
        $self->main_dialog->doneMultipleChanges();
    }

    $self->main_dialog->pollEvent();
    $self->flush();
}


#=============================================================

=head2 flush

=head3 DESCRIPTION

    Polls a dialog event to refresh the dialog

=cut

#=============================================================
sub flush {
    my ($self) = @_;

    $self->main_dialog->startMultipleChanges();
    $self->main_dialog->recalcLayout();
    $self->main_dialog->doneMultipleChanges();

    if ($self->main_dialog->isTopmostDialog()) {
        $self->main_dialog->waitForEvent(10);
        $self->main_dialog->pollEvent();
    }
    else {
        carp "This dialog is not a top most dialog\n";
    }
    yui::YUI::app()->redrawScreen();
}

#=============================================================

=head2 label

=head3 INPUT

    $text: text to be shown on label

=head3 DESCRIPTION

    Sets the label text

=cut

#=============================================================
sub label {
    my ($self, $text) = @_;

    $self->main_dialog->startMultipleChanges();
    $self->label_widget->setValue($text) if $text;
    $self->main_dialog->doneMultipleChanges();

    $self->flush();
}

#=============================================================

=head2 progress

=head3 INPUT

    $value: integer value in the range 0..100

=head3 DESCRIPTION

    Sets the progress bar percentage value

=cut

#=============================================================
sub progress {
    my ($self, $value) = @_;
    state $time = 0;

    $value = 0 if !defined($value) || $value < 0;
    $value = 100 if 100 < $value;

    $self->progressbar->setValue($value);
    return if Time::HiRes::clock_gettime() - $time < 0.333;
    $time = Time::HiRes::clock_gettime();

    $self->flush();
}

#=============================================================

=head2 DEMOLISH

=head3 INPUT

    $val: boolean value indicating whether or not this method
        was called as part of the global destruction process
        (when the Perl interpreter exits)

=head3 DESCRIPTION

    Moose provides a hook for object destruction with the
    DEMOLISH method as it does for construtor with BUILD

=cut

#=============================================================
sub DEMOLISH {
    my ($self, $val) = @_;

    $self->main_dialog->destroy if !$self->parent;
}

# TODO cancel button cannot be easily managed in libyui polling events
# removed atm
#
# sub validate_cancel {
#     my ($self, $cancel_msg, $cancel_cb) = @_;
#     $self->{main_dialog}->startMultipleChanges();
#     if (!$self->{cancel}) {
# 		$self->{cancel} = $self->{factory}->createIconButton($self->{vbox},"",$cancel_msg);
#         #gtkpack__(
# 	    #$self->{vbox},
# 	    #$self->{hbox_cancel} = gtkpack__(
# 		#gtknew('HButtonBox'),
# 		#$self->{cancel} = gtknew('Button', text => $cancel_msg, clicked => \&$cancel_cb),
# 	    #),
# 	#);
#     }
#     #$self->{cancel}->set_sensitive(1);
#     #$self->{cancel}->show;
#     $self->flush();
# }
#
# sub invalidate_cancel {
#     my ($self) = @_;
#     $self->{cancel} and $self->{cancel}->setEnabled(0);
# }
#
# sub invalidate_cancel_forever {
#     my ($self) = @_;
#     #$self->{hbox_cancel} or return;
#     #$self->{hbox_cancel}->destroy;
#     # FIXME: temporary workaround that prevents
#     # Gtk2::Label::set_text() set_text_internal() -> queue_resize() ->
#     # size_allocate() call chain to mess up when ->shrink_topwindow()
#     # has been called (#32613):
#     #$self->shrink_topwindow;
# }

1;
