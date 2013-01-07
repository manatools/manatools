package AdminPanel::Rpmdragora::gurpm;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
#  Copyright (c) 2013 Matteo Pasotti <matteo.pasotti@gmail.com>
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
# $Id: gurpm.pm 255450 2009-04-03 16:00:16Z tv $

package AdminPanel::Rpmdragora::gurpm;

use strict;
use lib qw(/usr/lib/libDrakX);
use yui;
use Time::HiRes;
use feature 'state';

sub new {
    my ($class, $title, $initializing, %options) = @_;
    my $self = {
		my $label = 0,
		my $factory = 0,
		my $mainw = 0,
		my $vbox = 0,
		my $progressbar = 0,
		my $cancel = 0
	};
    bless $self, 'AdminPanel::Rpmdragora::gurpm';
    #my $mainw = bless(ugtk2->new($title, %options, default_width => 600, width => 600), $self);
    $self->{factory} = yui::YUI::widgetFactory;
    $self->{mainw} = $self->{factory}->createPopupDialog();
    $::main_window = $self->{mainw};
    $self->{vbox} = $self->{factory}->createVBox($self->{mainw});
    #OLD $mainw->{label} = gtknew('Label', text => $initializing, alignment => [ 0.5, 0 ]);
    $self->{label} = $self->{factory}->createLabel($self->{vbox}, $initializing);
    # size label's heigh to 2 lines in order to prevent dummy vertical resizing:
    #my $context = $mainw->{label}->get_layout->get_context;
    #my $metrics = $context->get_metrics($mainw->{label}->style->font_desc, $context->get_language);
    #$mainw->{label}->set_size_request(-1, 2 * Gtk2::Pango->PANGO_PIXELS($metrics->get_ascent + $metrics->get_descent));

    #OLD $mainw->{progressbar} = gtknew('ProgressBar');
    $self->{progressbar} = $self->{factory}->createProgressBar($self->{vbox}, "");
    #gtkadd($mainw->{window}, $mainw->{vbox} = gtknew('VBox', spacing => 5, border_width => 6, children_tight => [
    #    $mainw->{label},
    #    $mainw->{progressbar}
    #]));
    #$mainw->{rwindow}->set_position('center-on-parent');
    #$mainw->{real_window}->show_all;
    #select(undef, undef, undef, 0.1);  #- hackish :-(
    #$mainw->SUPER::sync;
    $self->{mainw}->recalcLayout();
    $self->{mainw}->doneMultipleChanges();
    $self;
}

sub label {
    my ($self, $label) = @_;
    $self->{label} = $self->{factory}->createLabel($self->{vbox},$label);
    #select(undef, undef, undef, 0.1);  #- hackish :-(
    #$self->flush;
}

sub progress {
    my ($self, $value) = @_;
    state $time;
    $value = 0 if $value < 0;
    $value = 100 if 1 < $value;
    $self->{progressbar}->setValue($value);
    return if Time::HiRes::clock_gettime() - $time < 0.333;
    $time = Time::HiRes::clock_gettime();
    #$self->flush;
}

sub DESTROY {
    my ($self) = @_;
    #mygtk2::may_destroy($self);
    $self and $self->{mainw}->destroy;
    #$self = undef;
    $self->{cancel} = undef;  #- in case we'll do another one later
}

sub validate_cancel {
    my ($self, $cancel_msg, $cancel_cb) = @_;
    if (!$self->{cancel}) {
		$self->{cancel} = $self->{factory}->createIconButton($self->{vbox},"",$cancel_msg);
        #gtkpack__(
	    #$self->{vbox},
	    #$self->{hbox_cancel} = gtkpack__(
		#gtknew('HButtonBox'),
		#$self->{cancel} = gtknew('Button', text => $cancel_msg, clicked => \&$cancel_cb),
	    #),
	#);
    }
    #$self->{cancel}->set_sensitive(1);
    #$self->{cancel}->show;
    $self->{mainw}->recalcLayout();
    $self->{mainw}->doneMultipleChanges();
}

sub invalidate_cancel {
    my ($self) = @_;
    $self->{cancel} and $self->{cancel}->setEnabled(0);
}

sub invalidate_cancel_forever {
    my ($self) = @_;
    #$self->{hbox_cancel} or return;
    #$self->{hbox_cancel}->destroy;
    # FIXME: temporary workaround that prevents
    # Gtk2::Label::set_text() set_text_internal() -> queue_resize() ->
    # size_allocate() call chain to mess up when ->shrink_topwindow()
    # has been called (#32613):
    #$self->shrink_topwindow;
}

1;
