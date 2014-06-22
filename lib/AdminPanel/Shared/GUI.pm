# vim: set et ts=4 sw=4:
package AdminPanel::Shared::GUI;
#============================================================= -*-perl-*-

=head1 NAME

Shared::GUI - Shared graphic routines

=head1 SYNOPSIS

    my $gui = AdminPanel::Shared::GUI->new();
    my $yesPressed = $gui->ask_YesOrNo($title, $text);

=head1 DESCRIPTION

    This module contains a collection of dialogs or widgets that can be used in more
    graphics modules.

=head1 EXPORT

exported

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc Shared::GUI


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

=head1 METHODS

=cut


use strict;
use warnings;
use diagnostics;
use yui;

use AdminPanel::Shared qw(pathList2hash);

use AdminPanel::Shared::Locales;

use Moose;


has 'loc' => (
        is => 'rw',
        init_arg => undef,
        builder => '_localeInitialize'
);

sub _localeInitialize {
    my $self = shift();

    # TODO fix domain binding for translation
    $self->loc(AdminPanel::Shared::Locales->new(domain_name => 'libDrakX-standalone') );
    # TODO if we want to give the opportunity to test locally add dir_name => 'path'
}


#=============================================================

=head2 warningMsgBox

=head3 INPUT

    $info: HASH, information to be passed to the dialog.
            title     =>     dialog title
            text      =>     string to be swhon into the dialog
            reachtext =>     1 if using reach text

=head3 DESCRIPTION

This function creates an Warning dialog and show the message
passed as input.

=cut

#=============================================================
sub warningMsgBox {
    my ($self, $info) = @_;

    return 0 if ( ! $info );

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);
    my $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_ONE,
                                        $yui::YMGAMessageBox::D_WARNING);

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{reachtext})  ? $info->{reachtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});

    $dlg->setButtonLabel($self->loc->N("Ok"), $yui::YMGAMessageBox::B_ONE );
#     $dlg->setMinSize(50, 5);

    $retVal = $dlg->show();

    $dlg = undef;

    return 1;
}

#=============================================================

=head2 infoMsgBox

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title     =>     dialog title
            text      =>     string to be swhon into the dialog
            reachtext =>     1 if using reach text

=head3 DESCRIPTION

This function creates an Info dialog and show the message
passed as input.

=cut

#=============================================================

sub infoMsgBox {
    my ($self, $info) = @_;

    return 0 if ( ! $info );

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);
    my $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_ONE,
                                        $yui::YMGAMessageBox::D_INFO);

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{reachtext})  ? $info->{reachtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});

    $dlg->setButtonLabel($self->loc->N("Ok"), $yui::YMGAMessageBox::B_ONE );
#     $dlg->setMinSize(50, 5);

    $retVal = $dlg->show();

    $dlg = undef;

    return 1;
}

#=============================================================

=head2 msgBox

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title     =>     dialog title
            text      =>     string to be swhon into the dialog
            reachtext =>     1 if using reach text

=head3 DESCRIPTION

This function creates a dialog and show the message passed as input.

=cut

#=============================================================

sub msgBox {
    my ($self, $info) = @_;

    return 0 if ( ! $info );

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);
    my $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_ONE);

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{reachtext})  ? $info->{reachtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});

    $dlg->setButtonLabel($self->loc->N("Ok"), $yui::YMGAMessageBox::B_ONE );
#     $dlg->setMinSize(50, 5);

    $retVal = $dlg->show();

    $dlg = undef;

    return 1;
}

#=============================================================

=head2 ask_OkCancel

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title     =>     dialog title
            text      =>     string to be swhon into the dialog
            reachtext =>     1 if using reach text

=head3 OUTPUT

    0: Cancel button has been pressed
    1: Ok button has been pressed

=head3 DESCRIPTION

This function create an OK-Cancel dialog with a 'title' and a
'text' passed as parameters.

=cut

#=============================================================

sub ask_OkCancel {
    my ($self, $info) = @_;

    return 0 if ( ! $info );

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);
    my $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_TWO);

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{reachtext})  ? $info->{reachtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});

    $dlg->setButtonLabel($self->loc->N("Ok"), $yui::YMGAMessageBox::B_ONE );
    $dlg->setButtonLabel($self->loc->N("Cancel"), $yui::YMGAMessageBox::B_TWO);
    $dlg->setDefaultButton($yui::YMGAMessageBox::B_ONE);
    $dlg->setMinSize(50, 5);

    $retVal = $dlg->show() == $yui::YMGAMessageBox::B_ONE ? 1 : 0;

    $dlg = undef;

    return $retVal;
}

#=============================================================

=head2 ask_YesOrNo

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title     =>     dialog title
            text      =>     string to be swhon into the dialog
            reachtext =>     1 if using reach text
            default_button => (optional) 1: "Yes" (any other values "No")

=head3 OUTPUT

    0: "No" button has been pressed
    1: "Yes" button has been pressed

=head3 DESCRIPTION

This function create a Yes-No dialog with a 'title' and a
question 'text' passed as parameters.

=cut

#=============================================================

sub ask_YesOrNo {
    my ($self, $info) = @_;

    return 0 if ( ! $info );

    my $retVal = 0;
    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);
    my $dlg = $factory->createDialogBox($yui::YMGAMessageBox::B_TWO);

    $dlg->setTitle($info->{title}) if (exists $info->{title});
    my $rt = (exists $info->{reachtext})  ? $info->{reachtext} : 0;
    $dlg->setText($info->{text}, $rt) if (exists $info->{text});

    $dlg->setButtonLabel($self->loc->N("Yes"), $yui::YMGAMessageBox::B_ONE );
    $dlg->setButtonLabel($self->loc->N("No"), $yui::YMGAMessageBox::B_TWO);
    if (exists $info->{default_button} && $info->{default_button} == 1) {
        $dlg->setDefaultButton($yui::YMGAMessageBox::B_ONE);
    }
    else {
        $dlg->setDefaultButton($yui::YMGAMessageBox::B_TWO);
    }
    $dlg->setMinSize(50, 5);

    $retVal = $dlg->show() == $yui::YMGAMessageBox::B_ONE ? 1 : 0;

    $dlg = undef;

    return $retVal;
}



#=============================================================

=head2 ask_fromList

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title          =>     dialog title
            header         =>     combobox header
            list           =>     item list
            default_button =>     (optional) 1: Select (any other values Cancel)

=head3 OUTPUT

    undef:          if Cancel button has been pressed
    selected item:  if Select button has been pressed

=head3 DESCRIPTION

This function create a dialog with a combobox in which to
choose an item from a given list.

=cut

#=============================================================

sub ask_fromList {
    my ($self, $info) = @_;

    die "Missing dialog information" if (!$info);
    die "Title is mandatory"   if (! exists $info->{title});
    die "Header is mandatory" if (! exists $info->{header});
    die "List is mandatory"   if (! exists $info->{list} );
    my $list = $info->{list};
    die "At least one element is mandatory into list"   if (scalar(@$list) < 1);

    my $choice  = undef;
    my $factory = yui::YUI::widgetFactory;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($info->{title});

    my $dlg = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($dlg);

    my $combo   = $factory->createComboBox($layout, $info->{header}, 0);
    my $itemColl = new yui::YItemCollection;
    foreach (@$list) {
            my $item = new yui::YItem ($_, 0);
            $itemColl->push($item);
            $item->DISOWN();
    }
    $combo->addItems($itemColl);

    my $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    my $selectButton = $factory->createPushButton($hbox, $self->loc->N("Select"));
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));

    if (exists $info->{default_button} ) {
        my $dflBtn = ($info->{default_button} == 1) ? $selectButton : $cancelButton;
        $dlg->setDefaultButton($selectButton);
    }

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
            elsif ($widget == $selectButton) {
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

    $info: HASH containing optional information needed to get info for dialog.
            name        => the application name
            version     =>  the application version
            license     =>  the application license, the short length one (e.g. GPLv2, GPLv3, LGPLv2+, etc)
            authors     =>  the string providing the list of authors; it could be html-formatted
            description =>  the string providing a brief description of the application
            logo        => the string providing the file path for the application logo (high-res image)
            icon        => the string providing the file path for the application icon (low-res image)
            credits     => the application credits, they can be html-formatted
            information => other extra informations, they can be html-formatted
            dialog_mode => 1: classic style dialog, any other as tabbed style dialog

=head3 DESCRIPTION

    About dialog implementation, this dialog can be used by
    modules, to show authors, license, credits, etc.

=cut

#=============================================================

sub AboutDialog {
    my ($self, $info) = @_;

    die "Missing dialog information" if (!$info);


    yui::YUI::widgetFactory;
    my $factory = yui::YExternalWidgets::externalWidgetFactory("mga");
    $factory = yui::YMGAWidgetFactory::getYMGAWidgetFactory($factory);

    my $name        = (exists $info->{name}) ? $info->{name} : "";
    my $version     = (exists $info->{version}) ? $info->{version} : "";
    my $license     = (exists $info->{license}) ? $info->{license} : "";
    my $authors     = (exists $info->{authors}) ? $info->{authors} : "";
    my $description = (exists $info->{description}) ? $info->{description} : "";
    my $logo        = (exists $info->{logo}) ? $info->{logo} : "";
    my $icon        = (exists $info->{icon}) ? $info->{icon} : "";
    my $credits     = (exists $info->{credits}) ? $info->{credits} : "";
    my $information = (exists $info->{information}) ? $info->{information} : "";
    my $dialog_mode = $yui::YMGAAboutDialog::TABBED;
    if (exists $info->{dialog_mode}) {
        $dialog_mode = $yui::YMGAAboutDialog::CLASSIC if ($info->{dialog_mode} == 1);
    }

    my $dlg = $factory->createAboutDialog($name, $version, $license,
                                        $authors, $description, $logo,
                                        $icon, $credits, $information
    );

    $dlg->show($dialog_mode);

    $dlg = undef;

    return 1;
}

#=============================================================

=head2 hashTreeToYItemCollection

=head3 INPUT

    $treeInfo: HASH reference containing
            parent       ==> YItem parent (if not root object)
            collection   ==> YItemCollection (mandatory)
            default_item ==> Selected item (if any)
  default_item_separator ==> If default item is a path like string for tree representation
                             the separator is needed to match the selected item e.g. using all
                             the path instead of the just item itself
            hash_tree    ==> HASH reference containing the path tree representation

=head3 OUTPUT

    $treeItem: YtreeItem to be added to YItemCollection

=head3 DESCRIPTION

Function desctription

=cut

#=============================================================

sub hashTreeToYItemCollection {
    my ($self, $treeInfo) = @_;

    die "Collection is mandatory" if !($treeInfo->{collection});
    die "Hash tree is mandatory" if !($treeInfo->{hash_tree});

    my $treeLine = $treeInfo->{parent};
    my $item;
    foreach my $key (sort keys %{$treeInfo->{hash_tree}}) {
        if ($treeInfo->{parent}) {
            $item = new yui::YTreeItem ($treeLine, $key);
            $item->DISOWN();
        }
        else {
            if ($treeLine) {
                if ( $treeLine->label() eq $key) {
                    $item = $treeLine;
                }
                else {
                    $treeInfo->{collection}->push($treeLine);
                    $item = $treeLine = new yui::YTreeItem ($key);
                    $item->DISOWN();
                }
            }
            else {
                $item = $treeLine = new yui::YTreeItem ($key);
                $item->DISOWN();
            }
        }

        ### select item
        if ($treeInfo->{default_item}) {
            my $label = $key;
            if (exists $treeInfo->{default_item_separator}) {
                my $parent = $item;
                while($parent = $parent->parent()) {
                    $label = $parent->label() . $treeInfo->{default_item_separator} . $label ;
                }
            }
            if ($treeInfo->{default_item} eq $label) {
                $item->setSelected(1) ;
                $item->setOpen(1);
                my $parent = $item;
                while($parent = $parent->parent()) {
                    $parent->setOpen(1);
                }
            }
        }

        if ($treeInfo->{hash_tree}->{$key} && keys %{$treeInfo->{hash_tree}->{$key}}) {
            my %tf;
            $tf{collection} = $treeInfo->{collection};
            $tf{parent} = $item;
            $tf{default_item} = $treeInfo->{default_item} if $treeInfo->{default_item};
            $tf{default_item_separator} = $treeInfo->{default_item_separator} if $treeInfo->{default_item_separator};
            $tf{hash_tree} = $treeInfo->{hash_tree}->{$key};
            $self->hashTreeToYItemCollection(\%tf);
        }
        else {
            if (! $treeInfo->{parent}) {
                $treeInfo->{collection}->push($treeLine);
                $treeLine = undef;
            }
        }
    }
    if (! $treeInfo->{parent}) {
        $treeInfo->{collection}->push($treeLine) if $treeLine;
    }
}


#=============================================================

=head2 ask_fromTreeList

=head3 INPUT

$info: HASH, information to be passed to the dialog.
            title          =>     dialog title
            header         =>     TreeView header
            list           =>     path item list
            min_size       =>     minimum dialog size in the libYUI meaning
                                  HASH {width => w, height => h} 
            default_item   =>     selected item if any
            item_separator =>     item separator default "/"
            skip_path      =>     if set item is returned without its original path,
                                  just as a leaf (default use full path)
            any_item_selection => allow to select any item, not just leaves (default just leaves)
            default_button =>     (optional) 1: Select (any other values Cancel)

=head3 OUTPUT

    undef:          if Cancel button has been pressed
    selected item:  if Select button has been pressed

=head3 DESCRIPTION

This function create a dialog with a combobox in which to
choose an item from a given list.

=cut

#=============================================================

sub ask_fromTreeList {
    my ($self, $info) = @_;

    die "Missing dialog information" if (!$info);
    die "Title is mandatory"   if (! exists $info->{title});
    die "Header is mandatory" if (! exists $info->{header});
    die "List is mandatory"   if (! exists $info->{list} );
    my $list = $info->{list};
    die "At least one element is mandatory into list"   if (scalar(@$list) < 1);

    my $choice  = undef;
    my $factory = yui::YUI::widgetFactory;

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($info->{title});
    my $minWidth  = 80;
    my $minHeight = 25;
    
    if (exists $info->{min_size}) {
        $minWidth  = $info->{min_size}->{width} if $info->{min_size}->{width};
        $minHeight = $info->{min_size}->{height} if $info->{min_size}->{height};
    }

    my $dlg     = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $minSize = $factory->createMinSize( $dlg, $minWidth, $minHeight );
    my $layout  = $factory->createVBox($minSize);

    my $treeWidget = $factory->createTree($layout, $info->{header});

    my $treeInfo;
    $treeInfo->{collection}   = new yui::YItemCollection;
    $treeInfo->{default_item} = $info->{default_item} if $info->{default_item};
    $treeInfo->{default_item_separator} = $info->{item_separator} if $info->{item_separator};
    my $list2Convert;
    $list2Convert->{paths} = $info->{list};
    $list2Convert->{separator} = $info->{item_separator} if $info->{item_separator};
    $treeInfo->{hash_tree}    = AdminPanel::Shared::pathList2hash($list2Convert);

    $self->hashTreeToYItemCollection($treeInfo);
    $treeWidget->addItems($treeInfo->{collection});

    my $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    my $selectButton = $factory->createPushButton($hbox, $self->loc->N("Select"));
    my $cancelButton = $factory->createPushButton($hbox, $self->loc->N("Cancel"));

    if (exists $info->{default_button} ) {
        my $dflBtn = ($info->{default_button} == 1) ? $selectButton : $cancelButton;
        $dlg->setDefaultButton($selectButton);
    }

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
            elsif ($widget == $selectButton) {
                my $item = $treeWidget->selectedItem();
                if ($info->{skip_path} && $info->{skip_path} != 0) {
                    $choice = $item->label() if ($item);
                }
                else {
                    my $separator = exists $info->{item_separator} ? $info->{item_separator} : '/';
                    if ($item) {
                        $choice = $item->label();
                        my $parent = $item;
                        while($parent = $parent->parent()) {
                            $choice = $parent->label() . $separator . $choice ;
                        }
                    }
                }

                last;
            }
        }
    }

    destroy $dlg;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

    return $choice;
}


no Moose;
__PACKAGE__->meta->make_immutable;


1;

