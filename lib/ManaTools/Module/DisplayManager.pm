# vim: set et ts=4 sw=4:
#*****************************************************************************
#
#  Copyright (c) 2013-2015 Matteo Pasotti <matteo.pasotti@gmail.com>
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

package ManaTools::Module::DisplayManager;

use Modern::Perl '2011';
use autodie;
use Moose;
use POSIX qw(ceil);
use English;
use utf8;
use File::ShareDir ':ALL';

use yui;
use ManaTools::Shared qw(trim apcat devel_mode);
use ManaTools::Shared::GUI;
# use ManaTools::Shared::DisplayManager;

# TODROP but provides network::network
use lib qw(/usr/lib/libDrakX);
use network::network;
use MDK::Common::System qw(getVarsFromSh addVarsInSh);
use MDK::Common::Func qw(find);

extends qw( ManaTools::Module );


has '+icon' => (
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/manadm.png'),
);

has '+name' => (
    default => "DisplayManager",
);

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

has 'dialog' => (
    is => 'rw',
    init_arg => undef
);

has 'conffile' => (
    is      => 'rw',
    isa     => 'Str',
    default => '/etc/sysconfig/desktop',
);

has 'dmlist' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    builder => '_build_dmlist',
);

has 'desc_for_i18n' => (
    is      => 'rw',
    isa     => 'ArrayRef',
);

has 'sh_gui' => (
        is => 'rw',
        init_arg => undef,
        builder => '_SharedUGUIInitialize'
);

sub _build_desc_for_i18n {
    my $self = shift();

    my @_DESCRIPTIONS_for_i18n = (
        $self->loc->N("LightDM (The Light Display Manager)"),
        $self->loc->N("GDM (GNOME Display Manager)"),
        $self->loc->N("KDM (KDE Display Manager)"),
        $self->loc->N("XDM (X Display Manager)"),
    );

    $self->desc_for_i18n(\@_DESCRIPTIONS_for_i18n);

    return 1;
}

sub _build_dmlist {
    my $self = shift();

    my @list = map {
        my %l = map { /(\S+)=(.*)/ } apcat($_);
        \%l;
    } sort(glob("/usr/share/X11/dm.d/*.conf"));
    return \@list;
}

sub _SharedUGUIInitialize {
    my $self = shift();

    $self->sh_gui( ManaTools::Shared::GUI->new() );
}

#=============================================================

=head2 start

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method extends Module::start and is invoked to
    start proxy manager

=cut

#=============================================================
sub start {
    my $self = shift;

    if (!ManaTools::Shared::devel_mode() && $EUID != 0) {
        $self->sh_gui->warningMsgBox({
                                title => $self->name,
                                text  => $self->loc->N("root privileges required"),
                                });
        return;
    }

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);

    # initialize dm descriptions for i18n
    $self->_build_desc_for_i18n();

    $self->_manageProxyDialog();
};

#=============================================================

=head2 ask_for_X_restart

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    This method shows a message box warning the user
    that a X server restart is required

=cut

#=============================================================

sub ask_for_X_restart {
    my $self = shift;

    $self->sh_gui->warningMsgBox({title=>$self->loc->N("X Restart Required"),text=>$self->loc->N("You need to log out and back in again for changes to take effect"),richtext=>1});
}

sub _manageProxyDialog {
    my $self = shift;

    ## TODO fix for manatools
    my $appTitle = yui::YUI::app()->applicationTitle();
    my $appIcon = yui::YUI::app()->applicationIcon();
    ## set new title to get it in dialog
    my $newTitle = $self->loc->N("Display Manager");
    yui::YUI::app()->setApplicationTitle($newTitle);

    my $factory  = yui::YUI::widgetFactory;
    my $optional = yui::YUI::optionalWidgetFactory;

    my $label_width = 25;
    my $inputfield_width = 45;

    my ($dm_NAME) = apcat($self->conffile) =~ /^DISPLAYMANAGER=(.*)/m;
    my $dm = (MDK::Common::Func::find { uc($_->{NAME}) eq uc($dm_NAME) } @{$self->dmlist});

    $self->dialog($factory->createMainDialog());
    my $layout    = $factory->createVBox($self->dialog);

    my $hbox_header = $factory->createHBox($layout);
    my $headLeft = $factory->createHBox($factory->createLeft($hbox_header));
    my $headRight = $factory->createHBox($factory->createRight($hbox_header));

    my $logoImage = $factory->createImage($headLeft, $appIcon);
    my $labelAppDescription = $factory->createLabel($headRight,$newTitle);
    $logoImage->setWeight($yui::YD_HORIZ,0);
    $labelAppDescription->setWeight($yui::YD_HORIZ,3);

    # app description
    my $hbox_content = $factory->createHBox($layout);
    $factory->createLabel($hbox_content, $self->loc->N("Choosing a display manager"));

    $hbox_content = $factory->createHBox($layout);

    my $vbox_spacer = $factory->createVBox($hbox_content);
    $factory->createHSpacing($vbox_spacer,2);
    my $vbox_labels_flags = $factory->createVBox($hbox_content);
    my $vbox_inputfields = $factory->createVBox($hbox_content);

    # list of desktop managers
    my $rb_group = $factory->createRadioButtonGroup($vbox_labels_flags);
    my $rbbox = $factory->createVBox($rb_group);
    foreach my $d (@{$self->dmlist()})
    {
        my $rowentry = $factory->createHBox($factory->createLeft($rbbox));
        my $rb = $factory->createRadioButton($rowentry, $d->{NAME});
        $rb->setWeight($yui::YD_HORIZ, 1);
        my $desc = $factory->createLabel($rowentry, $self->loc->N($d->{DESCRIPTION}));
        $desc->setWeight($yui::YD_HORIZ, 2);
        if($d->{PACKAGE} eq lc($dm_NAME))
        {
            $rb->setValue(1);
        }
        $rb_group->addRadioButton($rb);
        $rb->DISOWN();
    }
    my $hbox_filler = $factory->createHBox($layout);
    $factory->createSpacing($hbox_filler,$yui::YD_VERT,2);

    my $hbox_foot = $factory->createHBox($layout);
    my $vbox_foot_left = $factory->createVBox($factory->createLeft($hbox_foot));
    my $vbox_foot_right = $factory->createVBox($factory->createRight($hbox_foot));
    my $aboutButton = $factory->createPushButton($vbox_foot_left,$self->loc->N("&About"));
    my $cancelButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&Cancel"));
    my $okButton = $factory->createPushButton($vbox_foot_right,$self->loc->N("&OK"));

    # main loop
    while(1) {
        my $event     = $self->dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
### Buttons and widgets ###
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }elsif ($widget == $aboutButton) {
                $self->sh_gui->AboutDialog({
                    name => $appTitle,
                    version => $VERSION,
                    credits => "Copyright (c) 2013-2015 by Matteo Pasotti",
                    license => "GPLv2",
                    description => $self->loc->N("Graphical configurator for system Display Manager"),
                    authors => "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;"
                    }
                );
            }elsif ($widget == $okButton) {
                my $current_choice = ManaTools::Shared::trim($rb_group->currentButton()->label());
                $current_choice =~s/\&//g;
                addVarsInSh($self->conffile, { DISPLAYMANAGER => lc($current_choice) } );
                $self->ask_for_X_restart();
                last;
            }
        }
    }

    $self->dialog->destroy() ;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

1;
