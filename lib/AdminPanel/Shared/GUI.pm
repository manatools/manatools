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


use Moose;

use diagnostics;
use yui;

use AdminPanel::Shared qw(pathList2hash);

use AdminPanel::Shared::Locales;

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
            richtext =>     1 if using rich text

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
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
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
                richtext =>     1 if using rich text

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
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
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
                richtext =>     1 if using rich text

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
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
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
                richtext =>     1 if using rich text

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
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
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
                richtext =>     1 if using rich text
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
    my $rt = (exists $info->{richtext})  ? $info->{richtext} : 0;
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

=head2 arrayListToYItemCollection

=head3 INPUT

    $listInfo: HASH reference containing
            default_item => Selected item (if any)
            item_list    => ARRAY reference containing the item list

=head3 OUTPUT

    $itemList: YItemCollection containing the item list passed

=head3 DESCRIPTION

    This method returns a YItemCollection containing the item list passed with default item
    the "default_item"

=cut

#=============================================================

sub arrayListToYItemCollection {
    my ($self, $listInfo) = @_;

    die "Item list is mandatory" if !($listInfo->{item_list});
    # TODO check type
    die "Not empty item list is mandatory" if (scalar @{$listInfo->{item_list}} < 1);


    my $itemColl = new yui::YItemCollection;
    foreach (@{$listInfo->{item_list}}) {
        my $item = new yui::YItem ($_, 0);
        $itemColl->push($item);
        $item->DISOWN();
        if ($listInfo->{default_item} && $listInfo->{default_item} eq $item->label()) {
            $item->setSelected(1);
        }
    }

    return $itemColl;
}


#=============================================================

=head2 ask_fromList

=head3 INPUT

    $info: HASH, information to be passed to the dialog.
                title          =>     dialog title
                header         =>     combobox header
                default_item   =>     selected item if any
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

    my $listInfo;
    $listInfo->{default_item} = $info->{default_item} if $info->{default_item};
    $listInfo->{item_list} = $info->{list};
    my $itemColl = $self->arrayListToYItemCollection($listInfo);
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
  default_item_separator ==> If default item is passed and is a path like string
                             the separator is needed to match the selected item, using
                             the full pathname instead leaf (e.g. root/subroot/leaf).
                             Default separator is also needed if '$treeInfo->{icons} entry is passed
                             to match the right icon to set (e.g. using the full pathname).
            hash_tree    ==> HASH reference containing the path tree representation
            icons        ==> HASH reference containing item icons e.g.
                             {
                                 root         => 'root_icon_pathname',
                                 root/subroot => 'root_subroot_icon_pathname',
                                 ....
                             }
                             Do not add it if no icons are wanted.
            default_icon ==> icon pathname to a default icon for all the items that are
                             not into $treeInfo->{icons} or if $treeInfo->{icons} is not
                             defined. Leave undef if no default icon is wanted

=head3 DESCRIPTION

    This function add to the given $treeInfo->{collection} new tree items from
    the the given $treeInfo->{hash_tree}

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

        # building full path name
        my $label = $key;
        if (exists $treeInfo->{default_item_separator}) {
            my $parent = $item;
            while($parent = $parent->parent()) {
                $label = $parent->label() . $treeInfo->{default_item_separator} . $label ;
            }
        }
        my $icon = undef;
        $icon = $treeInfo->{default_icon} if defined($treeInfo->{default_icon});
        $icon = $treeInfo->{icons}->{$label} if defined($treeInfo->{icons}) && defined($treeInfo->{icons}->{$label});

        $item->setIconName($icon) if $icon;

        ### select item
        if ($treeInfo->{default_item}) {
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
            $tf{icons} =  $treeInfo->{icons};
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
    if ($treeInfo->{default_item} && $info->{item_separator}) {
        if (index($treeInfo->{default_item}, $info->{item_separator}) != -1) {
            $treeInfo->{default_item_separator} = $info->{item_separator};
        }
    }
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
                my $getChoice = 1;
                if (!exists $info->{any_item_selection} || $info->{any_item_selection} != 0) {
                    if ($item) {
                        $getChoice = (!$item->hasChildren());
                    }
                }
                if ($info->{skip_path} && $info->{skip_path} != 0) {
                    $choice = $item->label() if ($item && $getChoice);
                }
                else {
                    if ($getChoice) {
                        my $separator = exists $info->{item_separator} ? $info->{item_separator} : '/';
                        if ($item) {
                            $choice = $item->label();
                            my $parent = $item;
                            while($parent = $parent->parent()) {
                                $choice = $parent->label() . $separator . $choice ;
                            }
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


#=============================================================

=head2 select_fromList

=head3 INPUT

    $info: HASH, information to be passed to the dialog.
                title  => dialog title
                info_label => optional info text
                header => column header hash reference{
                    text_column  => text column header
                    check_column =>
                }
                list   => item list hash reference
                          containing {
                    text     => item text
                    selected => 0 ur undefined means unchecked
                }

=head3 OUTPUT

    selection:  list of selected items

=head3 DESCRIPTION

    This function create a dialog cotaining a table with a list of
    items to be checked. The list of the checked items is returned.

=cut

#=============================================================

sub select_fromList {
    my ($self, $info) = @_;

    die "Missing dialog information" if (!$info);
    die "Title is mandatory"   if (! exists $info->{title});
    die "Header is mandatory" if (! exists $info->{header});
    die "Header text column is mandatory" if (! $info->{header}->{text_column});
    die "List is mandatory"   if (! exists $info->{list} );
    my $list = $info->{list};
    die "At least one element is mandatory into list"   if (scalar(@$list) < 1);

    my $selection  = [];

    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);

    ## push application title
    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($info->{title});

    my $dlg = $factory->createPopupDialog($yui::YDialogNormalColor);
    my $layout = $factory->createVBox($dlg);

    if ($info->{info_label}) {
        $factory->createLabel($layout, $info->{info_label});
    }

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($info->{header}->{text_column}, $yui::YAlignBegin);
    $yTableHeader->addColumn($info->{header}->{check_column} || '', $yui::YAlignBegin);

    ## service list (serviceBox)
    my $selectionTable = $mgaFactory->createCBTable(
        $layout,
        $yTableHeader,
        $yui::YCBTableCheckBoxOnLastColumn
    );
    $selectionTable->setImmediateMode(1);
    $selectionTable->setWeight($yui::YD_HORIZ, 75);

    $selectionTable->startMultipleChanges();
    $selectionTable->deleteAllItems();
    my $itemCollection = new yui::YItemCollection;
    ## NOTE do not sort to preserve item indexes
    foreach (@{$list}) {
        my $text = $_->{text} || die "item text is mandatory";

        my $item = new yui::YCBTableItem($text);
        $item->check( $_->{checked} );
        $itemCollection->push($item);
        $item->DISOWN();
    }
    $selectionTable->addItems($itemCollection);
    $selectionTable->doneMultipleChanges();

    my $align = $factory->createRight($layout);
    my $hbox = $factory->createHBox($align);
    $factory->createVSpacing($hbox, 1.0);
    my $okButton = $factory->createPushButton($hbox, $self->loc->N("Ok"));
    $dlg->setDefaultButton($okButton);
    $dlg->recalcLayout();

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

            if ($widget == $okButton) {
                last;
            }
            elsif ($widget == $selectionTable) {
                my $wEvent = yui::toYWidgetEvent($event);
                if ($wEvent->reason() == $yui::YEvent::ValueChanged) {
                    my $item = $selectionTable->changedItem();
                    if ($item) {
                        my $index = $item->index();
                        $list->[$index]->{checked} = $item->checked();
                    }
                }
            }
        }
    }

    destroy $dlg;

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);

    foreach (@{$list}) {
        push @{$selection}, $_->{text} if $_->{checked};
    }

    return $selection;
}

no Moose;
__PACKAGE__->meta->make_immutable;


1;

