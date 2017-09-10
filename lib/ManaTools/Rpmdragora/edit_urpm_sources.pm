# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::edit_urpm_sources;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2002-2007 Mandriva Linux
#  Copyright (c) 2014-2017 Angelo Naselli <anaselli@linux.it>
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
# $Id: edit_urpm_sources.pm 266598 2010-03-03 12:00:58Z tv $


use strict;
use File::ShareDir ':ALL';
use File::HomeDir qw(home);

use MDK::Common::Func qw(if_ each_index);
use MDK::Common::Math qw(max);
use MDK::Common::File qw(cat_ output);
use MDK::Common::DataStructure qw(member put_in_hash uniq);
use MDK::Common::Various qw(to_bool);

use ManaTools::Shared;
use ManaTools::Shared::Locales;
use ManaTools::rpmdragora;
use ManaTools::Rpmdragora::init;
use ManaTools::Rpmdragora::open_db;
use ManaTools::Rpmdragora::formatting;
use ManaTools::Shared::GUI;
use URPM::Signature;
use urpm::media;
use urpm::download;
use urpm::lock;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(run);


my $urpm;
my ($mainw, $list_tv, $something_changed);

my %col = (
    mainw => {
        is_enabled => 0,
        is_update  => 1,
        type       => 2,
        name       => 3,
        activatable => 4
    },
);

my $loc = ManaTools::rpmdragora::locale();

sub get_medium_type {
    my ($medium) = @_;
    my %medium_type = (
        cdrom     => $loc->N("CD-ROM"),
        ftp       => $loc->N("FTP"),
        file      => $loc->N("Local"),
        http      => $loc->N("HTTP"),
        https     => $loc->N("HTTPS"),
        nfs       => $loc->N("NFS"),
        removable => $loc->N("Removable"),
        rsync     => $loc->N("rsync"),
        ssh       => $loc->N("NFS"),
    );
    return $loc->N("Mirror list") if $medium->{mirrorlist};
    return $medium_type{$1} if $medium->{url} =~ m!^([^:]*)://!;
    return $loc->N("Local");
}

sub selrow {
    my ($o_list_tv) = @_;
    defined $o_list_tv or $o_list_tv = $list_tv;
    my ($model, $iter) = $o_list_tv->get_selection->get_selected;
    $model && $iter or return -1;
    my $path = $model->get_path($iter);
    my $row = $path->to_string;
    return $row;
}

sub selected_rows {
    my ($o_list_tv) = @_;
    defined $o_list_tv or $o_list_tv = $list_tv;
    my (@rows) = $o_list_tv->get_selection->get_selected_rows;
    return -1 if @rows == 0;
    map { $_->to_string } @rows;
}

sub remove_row {
    my ($model, $path_str) = @_;
    my $iter = $model->get_iter_from_string($path_str);
    $iter or return;
    $model->remove($iter);
}

sub remove_from_list {
    my ($list, $list_ref, $model) = @_;
    my $row = selrow($list);
    if ($row != -1) {
        splice @$list_ref, $row, 1;
        remove_row($model, $row);
    }

}

sub _want_base_distro() {
    $::expert && distro_type(0) eq 'updates' ? interactive_msg(
        $loc->N("Choose media type"),
        $loc->N("In order to keep your system secure and stable, you must at a minimum set up
sources for official security and stability updates. You can also choose to set
up a fuller set of sources which includes the complete official Mageia
repositories, giving you access to more software than can fit on the Mageia
discs. Please choose whether to configure update sources only, or the full set
of sources."
        ),
        transient => $::main_window,
        yesno => 1, text => { yes => $loc->N("Full set of sources"), no => $loc->N("Update sources only") },
    ) : 1;
}

sub easy_add_callback_with_mirror() {
    # when called on early init by rpmdragora
    $urpm ||= fast_open_urpmi_db();

    #- cooker and community don't have update sources
    my $want_base_distro = _want_base_distro();
    defined $want_base_distro or return 0;
    my $distro = $ManaTools::rpmdragora::mageia_release;
    my ($mirror) = choose_mirror($urpm, message =>
        $loc->N("This will attempt to install all official sources corresponding to your
distribution (%s).\n
I need to contact the Mageia website to get the mirror list.
Please check that your network is currently running.\n
Is it ok to continue?", $distro),
        transient => $::main_window,
    ) or return 0;
    ref $mirror or return 0;
    my $wait = wait_msg($loc->N("Please wait, adding media..."));
    add_distrib_update_media($urpm, $mirror, if_(!$want_base_distro, only_updates => 1));
    $offered_to_add_sources->[0] = 1;
    remove_wait_msg($wait);
    return 1;
}

sub easy_add_callback() {
    # when called on early init by rpmdragora
    $urpm ||= fast_open_urpmi_db();

    #- cooker and community don't have update sources
    my $want_base_distro = _want_base_distro();
    defined $want_base_distro or return 0;
    warn_for_network_need(undef, transient => $::main_window) or return 0;
    my $wait = wait_msg($loc->N("Please wait, adding media..."));
    add_distrib_update_media($urpm, undef, if_(!$want_base_distro, only_updates => 1));
    $offered_to_add_sources->[0] = 1;
    remove_wait_msg($wait);
    return 1;
}

## Internal routine that builds input fields needed to manage
## the selected media type to be added
## return HASH reference with the added widgets
sub _build_add_dialog  {
    my $options = shift;

    die "replace point is needed" if !defined ($options->{replace_pnt});
    die "dialog is needed" if !defined ($options->{dialog});
    die "selected item is needed" if !defined ($options->{selected});
    die "media info is needed" if !defined ($options->{info});

    my %widgets;
    my $factory  = yui::YUI::widgetFactory;

    $options->{dialog}->startMultipleChanges();
    $options->{replace_pnt}->deleteChildren();

    # replace widgets
    my $vbox    = $factory->createVBox( $options->{replace_pnt} );
    my $hbox           = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label          = $factory->createLabel($hbox,
        $options->{info}->{$options->{selected}}->{url}
    );

    $factory->createHSpacing($hbox, 3.0);
    $widgets{url}   = $factory->createInputField($hbox, "", 0);
    $widgets{url}->setWeight($yui::YD_HORIZ, 2);
    if (defined($options->{info}->{$options->{selected}}->{dirsel})) {
        $widgets{dirsel} = $factory->createPushButton($hbox, $loc->N("Browse..."));
    }
    elsif (defined($options->{info}->{$options->{selected}}->{loginpass})) {
        $hbox           = $factory->createHBox($vbox);
        $factory->createHSpacing($hbox, 1.0);
        $label          = $factory->createLabel($hbox, $loc->N("Login:") );
        $factory->createHSpacing($hbox, 1.0);
        $widgets{login} = $factory->createInputField($hbox, "", 0);
        $label->setWeight($yui::YD_HORIZ, 1);
        $widgets{login}->setWeight($yui::YD_HORIZ, 3);
        $hbox           = $factory->createHBox($vbox);
        $factory->createHSpacing($hbox, 1.0);
        $label          = $factory->createLabel($hbox, $loc->N("Password:") );
        $factory->createHSpacing($hbox, 1.0);
        $widgets{pass}  = $factory->createInputField($hbox, "", 1);
        $label->setWeight($yui::YD_HORIZ, 1);
        $widgets{pass}->setWeight($yui::YD_HORIZ, 3);

    }
    # recalc layout
    $options->{replace_pnt}->showChild();
    $options->{dialog}->recalcLayout();
    $options->{dialog}->doneMultipleChanges();

    return \%widgets;
}

sub add_callback() {

    my $retVal = 0;

    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Add a medium"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 60, 5 );
    my $vbox    = $factory->createVBox( $minSize );

    $factory->createVSpacing($vbox, 0.5);

    my $hbox    = $factory->createHBox( $factory->createLeft($vbox) );
    $factory->createHeading($hbox, $loc->N("Adding a medium:"));
    $factory->createVSpacing($vbox, 0.5);

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label         = $factory->createLabel($hbox, $loc->N("Type of medium:") );
    my $media_type = $factory->createComboBox($hbox, "", 0);
    $media_type->setWeight($yui::YD_HORIZ, 2);

    my %radios_infos = (
            local => { name => $loc->N("Local files"),  url => $loc->N("Medium path:"), dirsel => 1 },
            ftp   => { name => $loc->N("FTP server"),   url => $loc->N("URL:"), loginpass => 1 },
            rsync => { name => $loc->N("RSYNC server"), url => $loc->N("URL:") },
            http  => { name => $loc->N("HTTP server"),  url => $loc->N("URL:") },
        removable => { name => $loc->N("Removable device (CD-ROM, DVD, ...)"),
                       url  => $loc->N("Path or mount point:"), dirsel => 1 },
    );
    my @radios_names_ordered = qw(local ftp rsync http removable);

    my $itemColl = new yui::YItemCollection;
    foreach my $elem (@radios_names_ordered) {
        my $it = new yui::YItem($radios_infos{$elem}->{'name'}, 0);
        if ($elem eq $radios_names_ordered[0])  {
            $it->setSelected(1);
        }
        $itemColl->push($it);
        $it->DISOWN();
    }
    $media_type->addItems($itemColl);
    $media_type->setNotify(1);

    $hbox           = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    $label          = $factory->createLabel($hbox, $loc->N("Medium name:") );
    $factory->createHSpacing($hbox, 1.0);
    my $media_name = $factory->createInputField($hbox, "", 0);
    $media_name->setWeight($yui::YD_HORIZ, 2);

    # per function layout (replace point)
    my $align       = $factory->createLeft($vbox);
    my $replace_pnt = $factory->createReplacePoint($align);

    my $add_widgets = _build_add_dialog({replace_pnt => $replace_pnt, dialog => $dialog,
                                     info => \%radios_infos, selected => $radios_names_ordered[0]}
    );
    # check-boxes
    $hbox    = $factory->createHBox($factory->createLeft($vbox));
    $factory->createHSpacing($hbox, 1.3);
    my $dist_media   = $factory->createCheckBox($hbox, $loc->N("Create media for a whole distribution"), 0);
    $hbox    = $factory->createHBox($factory->createLeft($vbox));
    $factory->createHSpacing($hbox, 1.3);
    my $update_media = $factory->createCheckBox($hbox, $loc->N("Tag this medium as an update medium"),   0);
    $dist_media->setNotify(1);

    # Last line buttons
    $factory->createVSpacing($vbox, 0.5);
    $hbox            = $factory->createHBox($vbox);
    my $cancelButton = $factory->createPushButton($hbox,  $loc->N("&Cancel"));
    $factory->createHSpacing($hbox, 3.0);
    my $okButton   = $factory->createPushButton($hbox,  $loc->N("&Ok"));

    $cancelButton->setDefaultButton(1);

    # dialog event loop
    while(1) {
        my $event     = $dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### widget
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $media_type) {
                my $item = $media_type->selectedItem();
                my $sel = $item ? $item->index() : 0 ;
                $add_widgets = _build_add_dialog({replace_pnt => $replace_pnt, dialog => $dialog,
                                     info => \%radios_infos, selected => $radios_names_ordered[$sel]}
                );
            }
            elsif ($widget == $dist_media) {
                $update_media->setEnabled(!$dist_media->value());
            }
            elsif ($widget == $okButton) {
                my $item = $media_type->selectedItem();
                my $sel = $item ? $item->index() : 0 ;
                my $info = $radios_infos{$radios_names_ordered[$sel]};
                my $name = $media_name->value();
                my $url  = $add_widgets->{url}->value();
                $name eq '' || $url eq '' and interactive_msg('rpmdragora', $loc->N("You need to fill up at least the two first entries.")), next;
                if (member($name, map { $_->{name} } @{$urpm->{media}})) {
                    interactive_msg('rpmdragora',
                                    $loc->N("There is already a medium called <%s>,\ndo you really want to replace it?", $name),
                                    yesno => 1) or next;
                }

                my %i = (
                    name    => $name,
                    url     => $url,
                    distrib => $dist_media->value()   ? 1 : 0,
                    update  => $update_media->value() ? 1 : undef,
                );
                my %make_url = (
                    local => "file:/$i{url}",
                    http => $i{url},
                    rsync => $i{url},
                    removable => "removable:/$i{url}",
                );
                $i{url} =~ s|^ftp://||;
                $make_url{ftp} = sprintf "ftp://%s%s",
                        defined($add_widgets->{login})
                        ?
                            $add_widgets->{login}->value() . ':' . ( $add_widgets->{pass}->value() ?
                                                                     $add_widgets->{pass}->value() :
                                                                     '')
                        :
                            '',
                        $i{url};

                if ($i{distrib}) {
                    add_medium_and_check(
                        $urpm,
                        { nolock => 1, distrib => 1 },
                        $i{name}, $make_url{$radios_names_ordered[$sel]}, probe_with => 'synthesis', update => $i{update},
                    );
                } else {
                    if (member($i{name}, map { $_->{name} } @{$urpm->{media}})) {
                        urpm::media::select_media($urpm, $i{name});
                        urpm::media::remove_selected_media($urpm);
                    }
                    add_medium_and_check(
                        $urpm,
                        { nolock => 1 },
                        $i{name}, $make_url{$radios_names_ordered[$sel]}, $i{hdlist}, update => $i{update},
                    );
                }

                $retVal = 1;
                last;
            }
            else {
                my $item = $media_type->selectedItem();
                my $sel = $item ? $item->index() : 0 ;
                if (defined($radios_infos{$radios_names_ordered[$sel]}->{dirsel}) &&
                    defined($add_widgets->{dirsel}) ) {
                    if ($widget == $add_widgets->{dirsel}) {
                        my $dir = yui::YUI::app()->askForExistingDirectory(home(),
                                          $radios_infos{$radios_names_ordered[$sel]}->{url}
                        );
                        $add_widgets->{url}->setValue($dir) if ($dir);
                    }
                }
            }
        }
    }
### End ###

    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $retVal;

}

sub options_callback() {

    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Global options for package installation"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 50, 5 );
    my $vbox    = $factory->createVBox( $minSize );

    my $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label        = $factory->createLabel($hbox, $loc->N("Verify RPMs to be installed:") );
    $factory->createHSpacing($hbox, 3.5);
    my $verify_rpm   = $factory->createComboBox($hbox, "", 0);
    $verify_rpm->setWeight($yui::YD_HORIZ, 2);
    my @verif = ($loc->N("never"), $loc->N("always"));
    my $verify_rpm_value = $urpm->{global_config}{'verify-rpm'} || 0;

    my $itemColl = new yui::YItemCollection;
    my $cnt = 0;
    foreach my $elem (@verif) {
        my $it = new yui::YItem($elem, 0);
        if ($cnt == $verify_rpm_value) {
            $it->setSelected(1);
        }
        $itemColl->push($it);
        $it->DISOWN();
        $cnt++;
    }
    $verify_rpm->addItems($itemColl);

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    $label        = $factory->createLabel($hbox, $loc->N("Download program to use:") );
    $factory->createHSpacing($hbox, 4.0);
    my $downloader_entry   = $factory->createComboBox($hbox, "", 0);
    $downloader_entry->setWeight($yui::YD_HORIZ, 2);

    my @comboList =  urpm::download::available_ftp_http_downloaders() ;
    my $downloader = $urpm->{global_config}{downloader} || $comboList[0];

    if (scalar(@comboList) > 0) {
        $itemColl = new yui::YItemCollection;
        foreach my $elem (@comboList) {
            my $it = new yui::YItem($elem, 0);
            if ($elem eq $downloader) {
                $it->setSelected(1);
            }
            $itemColl->push($it);
            $it->DISOWN();
        }
        $downloader_entry->addItems($itemColl);
    }

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    $label        = $factory->createLabel($hbox, $loc->N("XML meta-data download policy:") );
    my $xml_info_policy   = $factory->createComboBox($hbox, "", 0);
    $xml_info_policy->setWeight($yui::YD_HORIZ, 2);

    my @xml_info_policies   = ('',   'never',    'on-demand',    'update-only',    'always');
    my @xml_info_policiesL  = ('', $loc->N("Never"), $loc->N("On-demand"), $loc->N("Update-only"), $loc->N("Always"));
    my $xml_info_policy_value = $urpm->{global_config}{'xml-info'};

    $itemColl = new yui::YItemCollection;
    $cnt = 0;
    foreach my $elem (@xml_info_policiesL) {
        my $it = new yui::YItem($elem, 0);
        if ($xml_info_policy_value && $xml_info_policy_value eq $xml_info_policies[$cnt]) {
            $it->setSelected(1);
        }
        $itemColl->push($it);
        $it->DISOWN();
        $cnt++;
    }
    $xml_info_policy->addItems($itemColl);

    ### TODO tips ###
    #tip =>
    #join("\n",
    #$loc->N("For remote media, specify when XML meta-data (file lists, changelogs & information) are downloaded."),
    #'',
    #$loc->N("Never"),
    #$loc->N("For remote media, XML meta-data are never downloaded."),
    #'',
    #$loc->N("On-demand"),
    #$loc->N("(This is the default)"),
    #$loc->N("The specific XML info file is downloaded when clicking on package."),
    #'',
    #$loc->N("Update-only"),
    #$loc->N("Updating media implies updating XML info files already required at least once."),
    #'',
    #$loc->N("Always"),
    #$loc->N("All XML info files are downloaded when adding or updating media."),

    $factory->createVSpacing($vbox, 0.5);


    ### last line buttons
    $factory->createVSpacing($vbox, 0.5);
    $hbox            = $factory->createHBox($vbox);
    my $cancelButton = $factory->createPushButton($hbox,  $loc->N("&Cancel"));
    $factory->createHSpacing($hbox, 3.0);
    my $okButton   = $factory->createPushButton($hbox,  $loc->N("&Ok"));

    $cancelButton->setDefaultButton(1);

    # dialog event loop
    while(1) {
        my $event     = $dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### widget
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $okButton) {
                my $changed = 0;
                my $item = $verify_rpm->selectedItem();
                if ($item->index() != $verify_rpm_value) {
                    $changed = 1;
                    $urpm->{global_config}{'verify-rpm'} = $item->index();
                }
                $item = $downloader_entry->selectedItem();
                if ($item->label() ne $downloader) {
                    $changed = 1;
                    $urpm->{global_config}{downloader} = $item->label();
                }
                $item = $xml_info_policy->selectedItem();
                if ($xml_info_policies[$item->index()] ne $xml_info_policy_value) {
                    $changed = 1;
                    $urpm->{global_config}{'xml-info'} = $xml_info_policies[$item->index()];
                }
                if ($changed) {
                    urpm::media::write_config($urpm);
                    $urpm = fast_open_urpmi_db();
                }

                last;
            }
        }
    }

    ### End ###

    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

}

#=============================================================

=head2 remove_callback

=head3 INPUT

$selection: YItemCollection (selected items)


=head3 DESCRIPTION

Remove the selected medias

=cut

#=============================================================

sub remove_callback {
    my $selection = shift;

    my @rows;
    for (my $it = 0; $it < $selection->size(); $it++) {
        my $item = $selection->get($it);
        push @rows, $item->index();
    }
    @rows == 0 and return 0;
    interactive_msg(
        $loc->N("Source Removal"),
        @rows == 1 ?
            $loc->N("Are you sure you want to remove source \"%s\"?", $urpm->{media}[$rows[0]]{name}) :
            $loc->N("Are you sure you want to remove the following sources?") . "\n\n" .
                format_list(map { $urpm->{media}[$_]{name} } @rows),
        yesno => 1, scroll => 1,
    ) or return 0;

    my $wait = wait_msg($loc->N("Please wait, removing medium..."));
    foreach my $row (reverse(@rows)) {
        $something_changed = 1;
        urpm::media::remove_media($urpm, [ $urpm->{media}[$row] ]);
    }
    urpm::media::write_urpmi_cfg($urpm);
    remove_wait_msg($wait);

    return 1;
}


#=============================================================

=head2 upwards_callback

=head3 INPUT

$table: Mirror table (YTable)

=head3 DESCRIPTION

Move selected item to high priority level

=cut

#=============================================================
sub upwards_callback {
    my $table = shift;

    ## get the first
    my $item = $table->selectedItem();
    !$item and return 0;
    return 0 if ($item->index() == 0);
    my $row = $item->index();
    my @media = ( $urpm->{media}[$row-1], $urpm->{media}[$row]);
    $urpm->{media}[$row] = $media[0];
    $urpm->{media}[$row-1] = $media[1];

    urpm::media::write_config($urpm);
    $urpm = fast_open_urpmi_db();
    return $row - 1;
}

#=============================================================

=head2 downwards_callback

=head3 INPUT

$table: Mirror table (YTable)

=head3 DESCRIPTION

Move selected item to low priority level

=cut

#=============================================================
sub downwards_callback {
    my $table = shift;

    ## get the first
    my $item = $table->selectedItem();
    !$item and return 0;
    my $row = $item->index();
    return $row if ($row >= $table->itemsCount()-1);

    my @media = ( $urpm->{media}[$row], $urpm->{media}[$row+1]);
    $urpm->{media}[$row+1] = $media[0];
    $urpm->{media}[$row]   = $media[1];

    urpm::media::write_config($urpm);
    $urpm = fast_open_urpmi_db();
    return $row + 1;
}

#- returns 1 if something changed to force readMedia()
sub edit_callback {
    my $table = shift;

    my $changed = 0;
    ## get the first
    my $item = $table->selectedItem();
    !$item and return 0;
    my $row = $item->index();

    my $medium = $urpm->{media}[$row];
    my $config = urpm::cfg::load_config_raw($urpm->{config}, 1);
    my ($verbatim_medium) = grep { $medium->{name} eq $_->{name} } @$config;

    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Edit a medium"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 80, 5 );
    my $vbox    = $factory->createVBox( $minSize );

    my $hbox    = $factory->createHBox( $factory->createLeft($vbox) );
    $factory->createHeading($hbox, $loc->N("Editing medium \"%s\":", $medium->{name}));
    $factory->createVSpacing($vbox, 1.0);

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label     = $factory->createLabel($hbox, $loc->N("URL:"));
    my $url_entry = $factory->createInputField($hbox, "", 0);
    $url_entry->setWeight($yui::YD_HORIZ, 2);
    $url_entry->setValue($verbatim_medium->{url} || $verbatim_medium->{mirrorlist});

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    $label        = $factory->createLabel($hbox, $loc->N("Downloader:") );
    my $downloader_entry   = $factory->createComboBox($hbox, "", 0);
    $downloader_entry->setWeight($yui::YD_HORIZ, 2);

    my @comboList =  urpm::download::available_ftp_http_downloaders() ;
    my $downloader = $verbatim_medium->{downloader} || $urpm->{global_config}{downloader} || $comboList[0];

    if (scalar(@comboList) > 0) {
        my $itemColl = new yui::YItemCollection;
        foreach my $elem (@comboList) {
            my $it = new yui::YItem($elem, 0);
            if ($elem eq $downloader) {
                $it->setSelected(1);
            }
            $itemColl->push($it);
            $it->DISOWN();
        }
        $downloader_entry->addItems($itemColl);
    }
    $factory->createVSpacing($vbox, 0.5);

    my $url = $url_entry->value();

    $hbox    = $factory->createHBox($factory->createLeft($vbox));
    $factory->createHSpacing($hbox, 1.0);

    my $tableItem = yui::toYTableItem($item);
    # enabled cell 0, updates cell 1
    my $cellEnabled = $tableItem->cell(0)->label() ? 1 : 0;
    my $enabled = $factory->createCheckBox($hbox, $loc->N("Enabled"), $cellEnabled);
    my $cellUpdates = $tableItem->cell(1)->label() ? 1 : 0;
    my $update  = $factory->createCheckBox($hbox, $loc->N("Updates"), $cellUpdates);
    $update->setDisabled() if (!$::expert);

    $factory->createVSpacing($vbox, 0.5);
    $hbox            = $factory->createHBox($vbox);
    my $cancelButton = $factory->createPushButton($hbox,  $loc->N("&Cancel"));
    $factory->createHSpacing($hbox, 3.0);
    my $saveButton   = $factory->createPushButton($hbox,  $loc->N("&OK"));
    $factory->createHSpacing($hbox, 3.0);
    my $proxyButton  = $factory->createPushButton($hbox,  $loc->N("&Proxy..."));

    $cancelButton->setDefaultButton(1);

    # dialog event loop
    while(1) {
        my $event     = $dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### widget
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $saveButton) {
                if ($cellEnabled != $enabled->value()) {
                    $urpm->{media}[$row]{ignore} = !$urpm->{media}[$row]{ignore} || undef;
                    $changed = 1;
                }
                if ($cellUpdates != $update->value()) {
                    $urpm->{media}[$row]{update} = !$urpm->{media}[$row]{update} || undef;
                    $changed = 1;
                }
                if ( $changed ) {
                    urpm::media::write_config($urpm);
                }

                my ($m_name, $m_update) = map { $medium->{$_} } qw(name update);
                # TODO check if really changed first
                $url = $url_entry->value();
                $downloader = $downloader_entry->value();
                $url =~ m|^removable://| and (
                    interactive_msg(
                        $loc->N("You need to insert the medium to continue"),
                                    $loc->N("In order to save the changes, you need to insert the medium in the drive."),
                                    yesno => 1, text => { yes => $loc->N("&Ok"), no => $loc->N("&Cancel") }
                    ) or return 0
                );
                my $saved_proxy = urpm::download::get_proxy($m_name);
                undef $saved_proxy if !defined $saved_proxy->{http_proxy} && !defined $saved_proxy->{ftp_proxy};
                urpm::media::select_media($urpm, $m_name);
                if (my ($media) = grep { $_->{name} eq $m_name } @{$urpm->{media}}) {
                    MDK::Common::DataStructure::put_in_hash($media, {
                        ($verbatim_medium->{mirrorlist} ? 'mirrorlist' : 'url') => $url,
                        name => $m_name,
                        if_($m_update && $m_update ne $media->{update} || $m_update, update => $m_update),
                        if_($saved_proxy && $saved_proxy ne $media->{proxy} || $saved_proxy, proxy => $saved_proxy),
                        if_($downloader ne $media->{downloader} || $downloader, downloader => $downloader),
                        modified => 1,
                    });
                    urpm::media::write_config($urpm);
                    update_sources_noninteractive($urpm, [ $m_name ]);
                } else {
                    urpm::media::remove_selected_media($urpm);
                    add_medium_and_check($urpm, { nolock => 1, proxy => $saved_proxy }, $m_name, $url, undef, update => $m_update, if_($downloader, downloader => $downloader));
                }
                last;
            }
            elsif ($widget == $proxyButton) {
                proxy_callback($medium);
            }
        }
    }
### End ###

    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $changed;
}

sub update_callback() {
    update_sources_interactive($urpm,  transient => $::main_window, nolock => 1);
}

#=============================================================

=head2 proxy_callback

=head3 INPUT

$medium: the medium which proxy is going to be modified

=head3 DESCRIPTION

Set or change the proxy settings for the given media.
Note that Ok button saves the changes.

=cut

#=============================================================
sub proxy_callback {
    my ($medium) = @_;
    my $medium_name = $medium ? $medium->{name} : '';

    my ($proxy, $proxy_user) = readproxy($medium_name);
    my ($user, $pass) = $proxy_user =~ /^([^:]*):(.*)$/;

    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Configure proxies"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 80, 5 );
    my $vbox    = $factory->createVBox( $minSize );

    my $hbox    = $factory->createHBox( $factory->createLeft($vbox) );
    $factory->createHeading($hbox,
                            $medium_name
                            ? $loc->N("Proxy settings for media \"%s\"", $medium_name)
                            : $loc->N("Global proxy settings"));
    $factory->createVSpacing($vbox, 0.5);

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label     = $factory->createLabel($hbox, $loc->N("If you need a proxy, enter the hostname and an optional port (syntax: <proxyhost[:port]>):"));
    $factory->createVSpacing($vbox, 0.5);

    my ($proxybutton, $proxyentry, $proxyuserbutton, $proxyuserentry, $proxypasswordentry);

    $hbox    = $factory->createHBox($factory->createLeft($vbox));
    $proxybutton = $factory->createCheckBoxFrame($hbox, $loc->N("Enable proxy"), 1);
    my $frm_vbox    = $factory->createVBox( $proxybutton );
    my $align       = $factory->createRight($frm_vbox);
    $hbox           = $factory->createHBox($align);
    $label          = $factory->createLabel($hbox, $loc->N("Proxy hostname:") );
    $proxyentry = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $proxyentry->setWeight($yui::YD_HORIZ, 2);
    $proxyuserbutton = $factory->createCheckBoxFrame($factory->createLeft($frm_vbox),
                                                     $loc->N("You may specify a username/password for the proxy authentication:"), 1);
    $proxyentry->setValue($proxy) if $proxy;

    $frm_vbox    = $factory->createVBox( $proxyuserbutton );

    ## proxy user name
    $align       = $factory->createRight($frm_vbox);
    $hbox           = $factory->createHBox($align);
    $label          = $factory->createLabel($hbox, $loc->N("User:") );
    $proxyuserentry = $factory->createInputField($hbox, "", 0);
    $label->setWeight($yui::YD_HORIZ, 1);
    $proxyuserentry->setWeight($yui::YD_HORIZ, 2);
    $proxyuserentry->setValue($user) if $user;

    ## proxy user password
    $align           = $factory->createRight($frm_vbox);
    $hbox            = $factory->createHBox($align);
    $label           = $factory->createLabel($hbox, $loc->N("Password:") );
    $proxypasswordentry = $factory->createInputField($hbox, "", 1);
    $label->setWeight($yui::YD_HORIZ, 1);
    $proxypasswordentry->setWeight($yui::YD_HORIZ, 2);
    $proxypasswordentry->setValue($pass) if $pass;

    $proxyuserbutton->setValue ($proxy_user ? 1 : 0);
    $proxybutton->setValue ($proxy ? 1 : 0);

    # dialog low level buttons
    $factory->createVSpacing($vbox, 0.5);
    $hbox            = $factory->createHBox($vbox);
    my $okButton   = $factory->createPushButton($hbox,   $loc->N("&Ok"));
    $factory->createHSpacing($hbox, 3.0);
    my $cancelButton = $factory->createPushButton($hbox, $loc->N("&Cancel"));

    $cancelButton->setDefaultButton(1);

    # dialog event loop
    while(1) {
        my $event     = $dialog->waitForEvent();
        my $eventType = $event->eventType();

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            ### widget
            my $widget = $event->widget();
            if ($widget == $cancelButton) {
                last;
            }
            elsif ($widget == $okButton) {
                $proxy = $proxybutton->value() ? $proxyentry->value() : '';
                $proxy_user = $proxyuserbutton->value()
                            ? ($proxyuserentry->value() . ':' . $proxypasswordentry->value()) : '';

                writeproxy($proxy, $proxy_user, $medium_name);
                last;
            }
        }
    }

### End ###
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

}

sub parallel_read_sysconf() {
    my @conf;
    foreach (MDK::Common::File::cat_('/etc/urpmi/parallel.cfg')) {
        my ($name, $protocol, $command) = /([^:]+):([^:]+):(.*)/ or print STDERR "Warning, unrecognized line in /etc/urpmi/parallel.cfg:\n$_";
        my $medias = $protocol =~ s/\(([^\)]+)\)$// ? [ split /,/, $1 ] : [];
        push @conf, { name => $name, protocol => $protocol, medias => $medias, command => $command };
    }
    \@conf;
}

sub parallel_write_sysconf {
    my ($conf) = @_;
    output '/etc/urpmi/parallel.cfg',
           map { my $m = @{$_->{medias}} ? '(' . join(',', @{$_->{medias}}) . ')' : '';
                 "$_->{name}:$_->{protocol}$m:$_->{command}\n" } @$conf;
}

sub remove_parallel {
    my ($num, $conf) = @_;
    if ($num != -1) {
        splice @$conf, $num, 1;
        parallel_write_sysconf($conf);
    }
}

sub add_callback_ {
    my ($title, $label, $mainw, $widget, $get_value, $check) = @_;
    my $w = ugtk2->new($title, grab => 1,  transient => $mainw->{real_window});
    local $::main_window = $w->{real_window};
    gtkadd(
        $w->{window},
        gtkpack__(
            gtknew('VBox', spacing => 5),
            gtknew('Label', text => $label),
            $widget,
            gtknew('HSeparator'),
            gtkpack(
                gtknew('HButtonBox'),
                gtknew('Button', text => $loc->N("Ok"), clicked => sub { $w->{retval} = 1; $get_value->(); Gtk2->main_quit }),
                gtknew('Button', text => $loc->N("Cancel"), clicked => sub { $w->{retval} = 0; Gtk2->main_quit })
            )
        )
    );
    $check->() if $w->main;
}

sub edit_parallel {
    my ($num, $conf) = @_;
    my $edited = $num == -1 ? {} : $conf->[$num];
    my $w = ugtk2->new($num == -1 ? $loc->N("Add a parallel group") : $loc->N("Edit a parallel group"), grab => 1, center => 1,  transient => $::main_window);
    local $::main_window = $w->{real_window};
    my $name_entry;

    my ($medias_ls, $hosts_ls) = (Gtk2::ListStore->new("Glib::String"), Gtk2::ListStore->new("Glib::String"));

    my ($medias, $hosts) = map {
        my $list = Gtk2::TreeView->new_with_model($_);
        $list->append_column(Gtk2::TreeViewColumn->new_with_attributes(undef, Gtk2::CellRendererText->new, 'text' => 0));
        $list->set_headers_visible(0);
        $list->get_selection->set_mode('browse');
        $list;
    } $medias_ls, $hosts_ls;

    $medias_ls->append_set([ 0 => $_ ]) foreach @{$edited->{medias}};

    my $add_media = sub {
        my $medias_list_ls = Gtk2::ListStore->new("Glib::String");
        my $medias_list = Gtk2::TreeView->new_with_model($medias_list_ls);
        $medias_list->append_column(Gtk2::TreeViewColumn->new_with_attributes(undef, Gtk2::CellRendererText->new, 'text' => 0));
        $medias_list->set_headers_visible(0);
        $medias_list->get_selection->set_mode('browse');
        $medias_list_ls->append_set([ 0 => $_->{name} ]) foreach @{$urpm->{media}};
        my $sel;
        add_callback_($loc->N("Add a medium limit"), $loc->N("Choose a medium to add to the media limit:"),
                      $w, $medias_list, sub { $sel = selrow($medias_list) },
                      sub {
                          return if $sel == -1;
                          my $media = ${$urpm->{media}}[$sel]{name};
                          $medias_ls->append_set([ 0 => $media ]);
                          push @{$edited->{medias}}, $media;
                      }
                  );
    };

    my $hosts_list;
    if    ($edited->{protocol} eq 'ssh')    { $hosts_list = [ split /:/, $edited->{command} ] }
    elsif ($edited->{protocol} eq 'ka-run') { push @$hosts_list, $1 while $edited->{command} =~ /-m (\S+)/g }
    $hosts_ls->append_set([ 0 => $_ ]) foreach @$hosts_list;
    my $add_host = sub {
        my ($entry, $value);
        add_callback_($loc->N("Add a host"), $loc->N("Type in the hostname or IP address of the host to add:"),
                      $mainw, $entry = gtkentry(), sub { $value = $entry->get_text },
                      sub { $hosts_ls->append_set([ 0 => $value ]); push @$hosts_list, $value }
                  );
    };

    my @protocols_names = qw(ka-run ssh);
    my @protocols;
    gtkadd(
	$w->{window},
	gtkpack_(
	    gtknew('VBox', spacing => 5),
	    if_(
		$num != -1,
		0, gtknew('Label', text => $loc->N("Editing parallel group \"%s\":", $edited->{name}))
	    ),
	    1, create_packtable(
		{},
		[ $loc->N("Group name:"), $name_entry = gtkentry($edited->{name}) ],
		[ $loc->N("Protocol:"), gtknew('HBox', children_tight => [
		    @protocols = gtkradio($edited->{protocol}, @protocols_names) ]) ],
		[ $loc->N("Media limit:"),
		gtknew('HBox', spacing => 5, children => [
		    1, gtknew('Frame', shadow_type => 'in', child =>
			gtknew('ScrolledWindow', h_policy => 'never', child => $medias)),
		    0, gtknew('VBox', children_tight => [
			gtksignal_connect(Gtk2::Button->new(but($loc->N("Add"))),    clicked => sub { $add_media->() }),
			gtksignal_connect(Gtk2::Button->new(but($loc->N("Remove"))), clicked => sub {
                                              remove_from_list($medias, $edited->{medias}, $medias_ls);
                                          }) ]) ]) ],
		[ $loc->N("Hosts:"),
		gtknew('HBox', spacing => 5, children => [
		    1, gtknew('Frame', shadow_type => 'in', child =>
			gtknew('ScrolledWindow', h_policy => 'never', child => $hosts)),
		    0, gtknew('VBox', children_tight => [
			gtksignal_connect(Gtk2::Button->new(but($loc->N("Add"))),    clicked => sub { $add_host->() }),
			gtksignal_connect(Gtk2::Button->new(but($loc->N("Remove"))), clicked => sub {
                                              remove_from_list($hosts, $hosts_list, $hosts_ls);
                                          }) ]) ]) ]
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtksignal_connect(
		    gtknew('Button', text => $loc->N("Ok")), clicked => sub {
			$w->{retval} = 1;
			$edited->{name} = $name_entry->get_text;
			mapn { $_[0]->get_active and $edited->{protocol} = $_[1] } \@protocols, \@protocols_names;
			Gtk2->main_quit;
		    }
		),
		gtknew('Button', text => $loc->N("Cancel"), clicked => sub { $w->{retval} = 0; Gtk2->main_quit }))
	)
    );
    $w->{rwindow}->set_size_request(600, -1);
    if ($w->main) {
        $num == -1 and push @$conf, $edited;
        if ($edited->{protocol} eq 'ssh')    { $edited->{command} = join(':', @$hosts_list) }
        if ($edited->{protocol} eq 'ka-run') { $edited->{command} = "-c ssh " . join(' ', map { "-m $_" } @$hosts_list) }
        parallel_write_sysconf($conf);
	return 1;
    }
    return 0;
}

sub parallel_callback() {
    my $w = ugtk2->new($loc->N("Configure parallel urpmi (distributed execution of urpmi)"), grab => 1, center => 1,  transient => $mainw->{real_window});
    local $::main_window = $w->{real_window};
    my $list_ls = Gtk2::ListStore->new("Glib::String", "Glib::String", "Glib::String", "Glib::String");
    my $list = Gtk2::TreeView->new_with_model($list_ls);
    each_index { $list->append_column(Gtk2::TreeViewColumn->new_with_attributes($_, Gtk2::CellRendererText->new, 'text' => $::i)) } $loc->N("Group"), $loc->N("Protocol"), $loc->N("Media limit");
    $list->append_column(my $commandcol = Gtk2::TreeViewColumn->new_with_attributes($loc->N("Command"), Gtk2::CellRendererText->new, 'text' => 3));
    $commandcol->set_max_width(200);

    my $conf;
    my $reread = sub {
	$list_ls->clear;
        $conf = parallel_read_sysconf();
	foreach (@$conf) {
            $list_ls->append_set([ 0 => $_->{name},
                                   1 => $_->{protocol},
                                   2 => @{$_->{medias}} ? join(', ', @{$_->{medias}}) : $loc->N("(none)"),
                                   3 => $_->{command} ]);
	}
    };
    $reread->();

    gtkadd(
	$w->{window},
	gtkpack_(
	    gtknew('VBox', spacing => 5),
	    1, gtkpack_(
		gtknew('HBox', spacing => 10),
		1, $list,
		0, gtkpack__(
		    gtknew('VBox', spacing => 5),
		    gtksignal_connect(
			Gtk2::Button->new(but($loc->N("Remove"))),
			clicked => sub { remove_parallel(selrow($list), $conf); $reread->() },
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but($loc->N("Edit..."))),
			clicked => sub {
			    my $row = selrow($list);
			    $row != -1 and edit_parallel($row, $conf);
			    $reread->();
			},
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but($loc->N("Add..."))),
			clicked => sub { edit_parallel(-1, $conf) and $reread->() },
		    )
		)
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtknew('Button', text => $loc->N("Ok"), clicked => sub { Gtk2->main_quit })
	    )
	)
    );
    $w->main;
}

sub keys_callback() {
    my $changed = 0;
    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Manage keys for digital signatures of packages"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 80, 20 );
    my $vbox    = $factory->createVBox( $minSize );

    my $hbox_headbar = $factory->createHBox($vbox);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headbar = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);


    my $hbox_content = $factory->createHBox($vbox);
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,3);

    my $frame   = $factory->createFrame ($leftContent, "");

    my $frmVbox = $factory->createVBox( $frame );
    my $hbox = $factory->createHBox( $frmVbox );

    ## media list
    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($loc->N("Medium"), $yui::YAlignBegin);
    my $multiselection = 0;
    my $mediaTbl = $factory->createTable($hbox, $yTableHeader, $multiselection);
    $mediaTbl->setKeepSorting(1);
    $mediaTbl->setImmediateMode(1);

    my $itemColl = new yui::YItemCollection;
    foreach (@{$urpm->{media}}) {
        my $name = $_->{name};

        my $item = new yui::YTableItem ($name);
        # NOTE row is $item->index()
        $item->setLabel( $name );
        $itemColl->push($item);
        $item->DISOWN();
    }
    $mediaTbl->addItems($itemColl);

    ## key list
    $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,3);
    $frame   = $factory->createFrame ($leftContent, "");
    $frmVbox = $factory->createVBox( $frame );
    $hbox = $factory->createHBox( $frmVbox );
    $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($loc->N("Keys"), $yui::YAlignBegin);
    $multiselection = 0;
    my $keyTbl = $factory->createTable($hbox, $yTableHeader, $multiselection);
    $keyTbl->setKeepSorting(1);

    my ($current_medium, $current_medium_nb, @keys);

    ### internal subroutines
    my $read_conf = sub {
        $urpm->parse_pubkeys(root => $urpm->{root});
        @keys = map { [ split /[,\s]+/, ($_->{'key-ids'} || '') ] } @{$urpm->{media}};
    };

    my $write = sub {
            $something_changed = 1;
            urpm::media::write_config($urpm);
            $urpm = fast_open_urpmi_db();
            $read_conf->();
        };

    $read_conf->();

    my $key_name = sub {
        exists $urpm->{keys}{$_[0]} ? $urpm->{keys}{$_[0]}{name}
                                    : $loc->N("no name found, key doesn't exist in rpm keyring!");
    };

    my $sel_changed = sub {
        my $item = $mediaTbl->selectedItem();
        if ($item) {
            $current_medium = $item->label();
            $current_medium_nb = $item->index();

            yui::YUI::app()->busyCursor();
            yui::YUI::ui()->blockEvents();
            $dialog->startMultipleChanges();

            $keyTbl->deleteAllItems();
            my $itemColl = new yui::YItemCollection;
            foreach ( @{$keys[$current_medium_nb]} ) {
                my $it = new yui::YTableItem (sprintf("%s (%s)", $_, $key_name->($_)));
                # NOTE row is $item->index()
                $it->setLabel( $_ );
                $itemColl->push($it);
                $it->DISOWN();
            }
            $keyTbl->addItems($itemColl);

            $dialog->recalcLayout();
            $dialog->doneMultipleChanges();
            yui::YUI::ui()->unblockEvents();
            yui::YUI::app()->normalCursor();
        }
    };

    my $add_key = sub {
        my $sh_gui = ManaTools::Shared::GUI->new();
        my $item = $mediaTbl->selectedItem();
        if ($item) {
            $current_medium = $item->label();
            $current_medium_nb = $item->index();
            my @list;
            my %key;
            foreach (keys %{$urpm->{keys}}) {
                my $k = sprintf("%s (%s)", $_, $key_name->($_));
                $key{$k} = $_;
                push @list, $k;
            }

            my $choice = $sh_gui->ask_fromList({
                title   => $loc->N("Add a key"),
                header  => $loc->N("Choose a key to add to the medium %s", $current_medium),
                list    => \@list,
            });
            if ($choice) {
                my $k = $key{$choice};
                $urpm->{media}[$current_medium_nb]{'key-ids'} = join(',', sort(uniq(@{$keys[$current_medium_nb]}, $k)));
                $write->();
                return 1;
            }
        }
        return 0;
    };

    my $remove_key = sub {
        my $sh_gui = ManaTools::Shared::GUI->new();
        my $keyItem   = $keyTbl->selectedItem();
        my $mediaItem = $mediaTbl->selectedItem();
        if ($keyItem && $mediaItem) {
            $current_medium = $mediaItem->label();
            $current_medium_nb = $mediaItem->index();
            my $current_key    = $keyItem->label();
            my $current_keyVal = yui::toYTableItem($keyItem)->cell(0)->label();
            my $choice = $sh_gui->ask_YesOrNo({
                title   => $loc->N("Remove a key"),
                text    => $loc->N("Are you sure you want to remove the key <br>%s<br> from medium %s?<br>(name of the key: %s)",
                             $current_keyVal, $current_medium, $current_key
                           ),
                richtext => 1,
            });
            if ($choice) {
                $urpm->{media}[$current_medium_nb]{'key-ids'} = join(',',
                    difference2(\@{$keys[$current_medium_nb]}, [ $current_key ])
                );
                $write->();
                return 1;
            }
        }

        return 0;

    };


    #### end subroutines
    $sel_changed->();

    my $rightContent = $factory->createRight($hbox_content);
    $rightContent->setWeight($yui::YD_HORIZ,1);
    my $topContent = $factory->createTop($rightContent);
    my $vbox_commands = $factory->createVBox($topContent);
    $factory->createVSpacing($vbox_commands, 1.0);
    my $addButton = $factory->createPushButton($factory->createHBox($vbox_commands), $loc->N("Add"));
    my $remButton = $factory->createPushButton($factory->createHBox($vbox_commands), $loc->N("Remove"));

    # dialog buttons
    $factory->createVSpacing($vbox, 1.0);
    $hbox = $factory->createHBox( $vbox );

    ### Close button
    my $closeButton = $factory->createPushButton($hbox, $loc->N("&Quit") );

    ### dialog event loop
    while(1) {
        my $event       = $dialog->waitForEvent();
        my $eventType   = $event->eventType();
        my $changed = 0;
        my $selection_changed = 0;

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
         elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            my $wEvent = yui::toYWidgetEvent($event);

            if ($widget == $closeButton) {
                last;
            }
            elsif ($widget == $addButton) {
                $changed = $add_key->();
                $sel_changed->() if $changed;
            }
            elsif ($widget == $remButton) {
                $changed = $remove_key->();
                $sel_changed->() if $changed;
            }
            elsif ($widget == $mediaTbl) {
                $sel_changed->();
            }
        }
    }

    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $changed;
}

#=============================================================

=head2 readMedia

=head3 INPUT

$name: optional parameter, the media called name has to be
       updated

=head3 OUTPUT

$itemColl: yui::YItemCollection containing media data to
           be added to the YTable

=head3 DESCRIPTION

This method reads the configured media and add their info
to the collection

=cut

#=============================================================
sub readMedia {
    my ($name) = @_;
    if (defined $name) {
        urpm::media::select_media($urpm, $name);
        update_sources_check(
            $urpm,
            { nolock => 1 },
            $loc->N_("Unable to update medium, errors reported:\n\n%s"),
                             $name,
        );
    }
    # reread configuration after updating media else ignore bit will be restored
    # by urpm::media::check_existing_medium():
    $urpm = fast_open_urpmi_db();

    my $itemColl = new yui::YItemCollection;
    foreach (grep { ! $_->{external} } @{$urpm->{media}}) {
        my $name = $_->{name};

        my $item = new yui::YTableItem (($_->{ignore} ? ""  : "X"),
                                        ($_->{update} ? "X" : ""),
                                        get_medium_type($_),
                                        $name);
        ## NOTE anaselli: next lines add check icon to cells, but they are 8x8, a dimension should
        ##      be evaluated by font size, so disabled atm
#         my $cell = $item->cell(0); # Checked
#         my $checkedIcon = File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/Check_8x8.png');
#
#         $cell->setIconName($checkedIcon) if (!$_->{ignore});
#         $cell    = $item->cell(1); # Updates
#         $cell->setIconName($checkedIcon) if ($_->{update});
        ## end icons on cells

        # TODO manage to_bool($::expert)
        # row # is $item->index()
        $item->setLabel( $name );
        $itemColl->push($item);
        $item->DISOWN();
    }

    return $itemColl;
}

#=============================================================

=head2 selectRow

=head3 INPUT

$itemCollection: YItem collection in which to find the item that
                 has to be selected
$row:            line to be selected

=head3 DESCRIPTION

Select item at row position
=cut

#=============================================================

sub selectRow {
    my ($itemCollection, $row) = @_;

    return if !$itemCollection;

    for (my $it = 0; $it < $itemCollection->size(); $it++) {
        my $item = $itemCollection->get($it);
        if ($it == $row) {
            $item->setSelected(1);
            return;
        }
    }
}

#=============================================================

=head2 _showMediaStatus

=head3 INPUT

$info: HASH reference containing
       item => selected item
       updates => updates checkbox widget
       enabled => enabled checkbox widget

=head3 DESCRIPTION

This internal function enables/disables checkboxes according to the
passed item value.

=cut

#=============================================================
sub _showMediaStatus {
    my $info = shift;

    die "Updates checkbox is mandatory" if !defined($info->{updates}) || !$info->{updates};
    die "Enabled checkbox is mandatory" if !defined($info->{enabled}) || !$info->{enabled};

    if (defined($info->{item})) {
        my $tableItem = yui::toYTableItem($info->{item});
        # enabled cell 0, updates cell 1
        my $cellEnabled = $tableItem && $tableItem->cell(0)->label() ? 1 : 0;
        my $cellUpdates = $tableItem && $tableItem->cell(1)->label() ? 1 : 0;
        $info->{enabled}->setValue($cellEnabled);
        $info->{updates}->setValue($cellUpdates);
    }
    else {
        $info->{enabled}->setDisabled();
        $info->{updates}->setDisabled();
    }
}

sub mainwindow() {

    my $something_changed = 0;
    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($loc->N("Configure media"));
    ## set icon if not already set by external launcher TODO
    yui::YUI::app()->setApplicationIcon("/usr/share/mcc/themes/default/rpmdrake-mdk.png");

    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createMainDialog;
    my $vbox    = $factory->createVBox( $dialog );

    my $hbox_headbar = $factory->createHBox($vbox);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headbar = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);

    my %fileMenu = (
            widget => $factory->createMenuButton($headbar,$loc->N("File")),
            update => new yui::YMenuItem($loc->N("Update")),
         add_media => new yui::YMenuItem($loc->N("Add a specific media mirror")),
            custom => new yui::YMenuItem($loc->N("Add a custom medium")),
            quit   => new yui::YMenuItem($loc->N("&Quit")),
    );

    my @ordered_menu_lines = qw(update add_media custom quit);
    foreach (@ordered_menu_lines) {
        $fileMenu{ widget }->addItem($fileMenu{ $_ });
    }
    $fileMenu{ widget }->rebuildMenuTree();

    my %optionsMenu = (
            widget => $factory->createMenuButton($headbar, $loc->N("&Options")),
            global => new yui::YMenuItem($loc->N("Global options")),
          man_keys => new yui::YMenuItem($loc->N("Manage keys")),
          parallel => new yui::YMenuItem($loc->N("Parallel")),
             proxy => new yui::YMenuItem($loc->N("Proxy")),
    );
    @ordered_menu_lines = qw(global man_keys parallel proxy);
    foreach (@ordered_menu_lines) {
        $optionsMenu{ widget }->addItem($optionsMenu{ $_ });
    }
    $optionsMenu{ widget }->rebuildMenuTree();

    my %helpMenu = (
            widget     => $factory->createMenuButton($headRight, $loc->N("&Help")),
            help       => new yui::YMenuItem($loc->N("Manual")),
            report_bug => new yui::YMenuItem($loc->N("Report Bug")),
            about      => new yui::YMenuItem($loc->N("&About")),
    );
    @ordered_menu_lines = qw(help report_bug about);
    foreach (@ordered_menu_lines) {
        $helpMenu{ widget }->addItem($helpMenu{ $_ });
    }
    $helpMenu{ widget }->rebuildMenuTree();

#     my %contextMenu = (
#         enable  => $loc->N("Enable/Disable"),
#         update  => $loc->N("Check as updates"),
#     );
#     @ordered_menu_lines = qw(enable update);
#     my $itemColl = new yui::YItemCollection;
#     foreach (@ordered_menu_lines) {
# #         last if (!$::expert && $_ eq "update");
#         my $item = new yui::YMenuItem($contextMenu{$_});
#         $item->DISOWN();
#         $itemColl->push($item);
#     }
#     yui::YUI::app()->openContextMenu($itemColl) or die "Cannot create contextMenu";

    my $hbox_content = $factory->createHBox($vbox);
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,3);

    my $frame   = $factory->createFrame ($leftContent, "");

    my $frmVbox = $factory->createVBox( $frame );
    my $hbox = $factory->createHBox( $frmVbox );

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn($loc->N("Enabled"), $yui::YAlignCenter);
    $yTableHeader->addColumn($loc->N("Updates"),  $yui::YAlignCenter);
    $yTableHeader->addColumn($loc->N("Type"), $yui::YAlignBegin);
    $yTableHeader->addColumn($loc->N("Medium"), $yui::YAlignBegin);

    ## mirror list
    my $multiselection = 1;
    my $mirrorTbl = $factory->createTable($hbox, $yTableHeader, $multiselection);
    $mirrorTbl->setKeepSorting(1);
    $mirrorTbl->setImmediateMode(1);

    my $itemCollection = readMedia();
    selectRow($itemCollection, 0); #default selection
    $mirrorTbl->addItems($itemCollection);

    my $rightContent = $factory->createRight($hbox_content);
    $rightContent->setWeight($yui::YD_HORIZ,1);
    my $topContent = $factory->createTop($rightContent);
    my $vbox_commands = $factory->createVBox($topContent);
    $factory->createVSpacing($vbox_commands, 1.0);
    my $remButton = $factory->createPushButton($factory->createHBox($vbox_commands), $loc->N("Remove"));
    my $edtButton = $factory->createPushButton($factory->createHBox($vbox_commands), $loc->N("Edit"));
    my $addButton = $factory->createPushButton($factory->createHBox($vbox_commands), $loc->N("Add"));

    $hbox = $factory->createHBox( $vbox_commands );
    my $item = $mirrorTbl->selectedItem();
    $factory->createHSpacing($hbox, 1.0);
    my $enabled = $factory->createCheckBox($factory->createLeft($hbox), $loc->N("Enabled"));
    my $update  = $factory->createCheckBox($factory->createLeft($hbox), $loc->N("Updates"));
    _showMediaStatus({item => $item, enabled => $enabled, updates => $update});
    $update->setNotify(1);
    $enabled->setNotify(1);
    $update->setDisabled() if (!$::expert);

    $hbox = $factory->createHBox( $vbox_commands );
    ## TODO icon and label for ncurses
    my $upIcon     = File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/Up_16x16.png');
    my $downIcon   = File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/Down_16x16.png');
    my $upButton   = $factory->createPushButton($factory->createHBox($hbox), $loc->N("Up"));
    my $downButton = $factory->createPushButton($factory->createHBox($hbox), $loc->N("Down"));
    $upButton->setIcon($upIcon);
    $downButton->setIcon($downIcon);

    $addButton->setWeight($yui::YD_HORIZ,1);
    $edtButton->setWeight($yui::YD_HORIZ,1);
    $remButton->setWeight($yui::YD_HORIZ,1);
    $upButton->setWeight($yui::YD_HORIZ,1);
    $downButton->setWeight($yui::YD_HORIZ,1);


    # dialog buttons
    $factory->createVSpacing($vbox, 1.0);
    ## Window push buttons
    $hbox = $factory->createHBox( $vbox );
    my $align = $factory->createLeft($hbox);
    $hbox     = $factory->createHBox($align);

    my $helpButton = $factory->createPushButton($hbox, $loc->N("Help") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);

    ### Close button
    my $closeButton = $factory->createPushButton($hbox, $loc->N("&Quit") );

    ### dialog event loop
    while(1) {
        my $event       = $dialog->waitForEvent();
        my $eventType   = $event->eventType();
        my $changed = 0;
        my $selection_changed = 0;

        #event type checking
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::MenuEvent) {
            ### MENU ###
            my $item = $event->item();
            my $menuLabel = $item->label();
            if ($menuLabel eq $fileMenu{ quit }->label()) {
                last;
            }
            elsif ($menuLabel eq $helpMenu{ about }->label()) {
                my $translators = ManaTools::Shared::i18NTranslators($loc->N("_: Translator(s) name(s) & email(s)\n"));

                my $sh_gui = ManaTools::Shared::GUI->new();
                $sh_gui->AboutDialog({ name => "Rpmdragora",
                                             version => $VERSION,
                         credits => $loc->N("Copyright (C) %s Mageia community", '2013-2017'),
                         license => $loc->N("GPLv2"),
                         description => $loc->N("Rpmdragora is the Mageia package management tool."),
                         authors => $loc->N("<h3>Developers</h3>
                                                    <ul><li>%s</li>
                                                           <li>%s</li>
                                                       </ul>
                                                       <h3>Translators</h3>
                                                       <ul>%s</ul>",
                                                      "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                                      "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;",
                                                      $translators
                                                     ),
                            }
                );
            }
            elsif ($menuLabel eq $fileMenu{ update }->label()) {
                update_callback();
            }
            elsif ($menuLabel eq $fileMenu{ add_media }->label()) {
                $changed = easy_add_callback_with_mirror();
            }
            elsif ($menuLabel eq $fileMenu{ custom }->label()) {
                $changed = add_callback();
            }
            elsif ($menuLabel eq $optionsMenu{ proxy }->label()) {
                proxy_callback();
            }
            elsif ($menuLabel eq $optionsMenu{ global }->label()) {
                options_callback();
            }
            elsif ($menuLabel eq $optionsMenu{ man_keys }->label()) {
                $changed = keys_callback();
            }
            elsif ($menuLabel eq $optionsMenu{ parallel }->label()) {
#                 parallel_callback();
            }
        }
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            # widget selected
            my $widget = $event->widget();
            my $wEvent = yui::toYWidgetEvent($event);

            if ($widget == $closeButton) {
                last;
            }
            elsif ($widget == $helpButton) {
            }
            elsif ($widget == $upButton) {
                yui::YUI::app()->busyCursor();
                yui::YUI::ui()->blockEvents();
                $dialog->startMultipleChanges();

                my $row = upwards_callback($mirrorTbl);

                $mirrorTbl->deleteAllItems();
                my $itemCollection = readMedia();
                selectRow($itemCollection, $row);
                $mirrorTbl->addItems($itemCollection);

                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::ui()->unblockEvents();
                yui::YUI::app()->normalCursor();
            }
            elsif ($widget == $downButton) {
                yui::YUI::app()->busyCursor();
                yui::YUI::ui()->blockEvents();
                $dialog->startMultipleChanges();

                my $row = downwards_callback($mirrorTbl);

                $mirrorTbl->deleteAllItems();
                my $itemCollection = readMedia();
                selectRow($itemCollection, $row);
                $mirrorTbl->addItems($itemCollection);

                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::ui()->unblockEvents();
                yui::YUI::app()->normalCursor();
            }
            elsif ($widget == $edtButton) {
                my $item = $mirrorTbl->selectedItem();
                if ($item && edit_callback($mirrorTbl) ) {
                    my $row = $item->index();
                    yui::YUI::app()->busyCursor();
                    yui::YUI::ui()->blockEvents();

                    $dialog->startMultipleChanges();

                    my $ignored = $urpm->{media}[$row]{ignore};
                    my $itemCollection = readMedia();
                    if (!$ignored && $urpm->{media}[$row]{ignore}) {
                        # reread media failed to un-ignore an ignored medium
                        # probably because urpm::media::check_existing_medium() complains
                        # about missing synthesis when the medium never was enabled before;
                        # thus it restored the ignore bit
                        $urpm->{media}[$row]{ignore} = !$urpm->{media}[$row]{ignore} || undef;
                        urpm::media::write_config($urpm);
                        #- Enabling this media failed, force update
                        interactive_msg('rpmdragora',
                                        $loc->N("This medium needs to be updated to be usable. Update it now?"),
                                        yesno => 1,
                        ) and $itemCollection = readMedia($urpm->{media}[$row]{name});
                    }
                    $mirrorTbl->deleteAllItems();
                    selectRow($itemCollection, $row);
                    $mirrorTbl->addItems($itemCollection);

                    $dialog->recalcLayout();
                    $dialog->doneMultipleChanges();
                    yui::YUI::ui()->unblockEvents();
                    yui::YUI::app()->normalCursor();
                    $selection_changed = 1; # to align $enabled and $update status
                }
            }
            elsif ($widget == $remButton) {
                my $sel = $mirrorTbl->selectedItems();
                $changed = remove_callback($sel);
            }
            elsif ($widget == $addButton) {
                $changed = easy_add_callback();
            }
            elsif ($widget == $update) {
                my $item = $mirrorTbl->selectedItem();
                if ($item) {
                    yui::YUI::app()->busyCursor();
                    my $row = $item->index();
                    $urpm->{media}[$row]{update} = !$urpm->{media}[$row]{update} || undef;
                    urpm::media::write_config($urpm);
                    yui::YUI::ui()->blockEvents();
                    $dialog->startMultipleChanges();
                    $mirrorTbl->deleteAllItems();
                    my $itemCollection = readMedia();
                    selectRow($itemCollection, $row);
                    $mirrorTbl->addItems($itemCollection);
                    $dialog->recalcLayout();
                    $dialog->doneMultipleChanges();
                    yui::YUI::ui()->unblockEvents();
                    yui::YUI::app()->normalCursor();
                }
            }
            elsif ($widget == $enabled) {
                ## TODO same as $edtButton after edit_callback
                my $item = $mirrorTbl->selectedItem();
                if ($item) {
                    my $row = $item->index();
                    yui::YUI::app()->busyCursor();
                    yui::YUI::ui()->blockEvents();

                    $dialog->startMultipleChanges();

                    $urpm->{media}[$row]{ignore} = !$urpm->{media}[$row]{ignore} || undef;
                    urpm::media::write_config($urpm);
                    my $ignored = $urpm->{media}[$row]{ignore};
                    my $itemCollection = readMedia();
                    if (!$ignored && $urpm->{media}[$row]{ignore}) {
                        # reread media failed to un-ignore an ignored medium
                        # probably because urpm::media::check_existing_medium() complains
                        # about missing synthesis when the medium never was enabled before;
                        # thus it restored the ignore bit
                        $urpm->{media}[$row]{ignore} = !$urpm->{media}[$row]{ignore} || undef;
                        urpm::media::write_config($urpm);
                        #- Enabling this media failed, force update
                        interactive_msg('rpmdragora',
                                        $loc->N("This medium needs to be updated to be usable. Update it now?"),
                                        yesno => 1,
                        ) and $itemCollection = readMedia($urpm->{media}[$row]{name});
                    }
                    $mirrorTbl->deleteAllItems();
                    selectRow($itemCollection, $row);
                    $mirrorTbl->addItems($itemCollection);

                    $dialog->recalcLayout();
                    $dialog->doneMultipleChanges();
                    yui::YUI::ui()->unblockEvents();
                    yui::YUI::app()->normalCursor();
                }
            }
            elsif ($widget == $mirrorTbl) {
                $selection_changed = 1;
            }
        }
        if ($changed) {
            yui::YUI::app()->busyCursor();
            yui::YUI::ui()->blockEvents();

            $dialog->startMultipleChanges();

            $mirrorTbl->deleteAllItems();
            my $itemCollection = readMedia();
            selectRow($itemCollection, 0); #default selection
            $mirrorTbl->addItems($itemCollection);

            $dialog->recalcLayout();
            $dialog->doneMultipleChanges();
            yui::YUI::app()->normalCursor();
            $selection_changed = 1;
        }
        if ($selection_changed) {
            yui::YUI::ui()->blockEvents();
            my $item = $mirrorTbl->selectedItem();
            _showMediaStatus({item => $item, enabled => $enabled, updates => $update});

            my $sel = $mirrorTbl->selectedItems();
            if ($sel->size() == 0 || $sel->size() > 1 ) {
                $remButton->setEnabled(($sel->size() == 0) ? 0 : 1);
                $edtButton->setEnabled(0);
                $upButton->setEnabled(0);
                $downButton->setEnabled(0);
                $enabled->setEnabled(0);
                $update->setEnabled(0);
            }
            else {
                $remButton->setEnabled(1);
                $edtButton->setEnabled(1);
                $upButton->setEnabled(1);
                $downButton->setEnabled(1);
                $enabled->setEnabled(1);
                $update->setEnabled(1) if $::expert;
            }

            yui::YUI::ui()->unblockEvents();
        }
    }
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $something_changed;
}


sub OLD_mainwindow() {
    undef $something_changed;
    $mainw = ugtk2->new($loc->N("Configure media"), center => 1, transient => $::main_window, modal => 1);
    local $::main_window = $mainw->{real_window};

    my $reread_media;

    my ($menu, $_factory) = create_factory_menu(
	$mainw->{real_window},
	[ $loc->N("/_File"), undef, undef, undef, '<Branch>' ],
	[ $loc->N("/_File") . $loc->N("/_Update"), $loc->N("<control>U"), sub { update_callback() and $reread_media->() }, undef, '<Item>', ],
        [ $loc->N("/_File") . $loc->N("/Add a specific _media mirror"), $loc->N("<control>M"), sub { easy_add_callback_with_mirror() and $reread_media->() }, undef, '<Item>' ],
        [ $loc->N("/_File") . $loc->N("/_Add a custom medium"), $loc->N("<control>A"), sub { add_callback() and $reread_media->() }, undef, '<Item>' ],
	[ $loc->N("/_File") . $loc->N("/Close"), $loc->N("<control>W"), sub { Gtk2->main_quit }, undef, '<Item>', ],
     [ $loc->N("/_Options"), undef, undef, undef, '<Branch>' ],
     [ $loc->N("/_Options") . $loc->N("/_Global options"), $loc->N("<control>G"), \&options_callback, undef, '<Item>' ],
     [ $loc->N("/_Options") . $loc->N("/Manage _keys"), $loc->N("<control>K"), \&keys_callback, undef, '<Item>' ],
     [ $loc->N("/_Options") . $loc->N("/_Parallel"), $loc->N("<control>P"), \&parallel_callback, undef, '<Item>' ],
     [ $loc->N("/_Options") . $loc->N("/P_roxy"), $loc->N("<control>R"), \&proxy_callback, undef, '<Item>' ],
     if_($0 =~ /edit-urpm-sources/,
         [ $loc->N("/_Help"), undef, undef, undef, '<Branch>' ],
         [ $loc->N("/_Help") . $loc->N("/_Report Bug"), undef, sub { run_drakbug('edit-urpm-sources.pl') }, undef, '<Item>' ],
         [ $loc->N("/_Help") . $loc->N("/_Help"), undef, sub { rpmdragora::open_help('sources') }, undef, '<Item>' ],
         [ $loc->N("/_Help") . $loc->N("/_About..."), undef, sub {
               my $license = MDK::Common::String::formatAlaTeX(translate($::license));
               $license =~ s/\n/\n\n/sg; # nicer formatting
               my $w = gtknew('AboutDialog', name => $loc->N("Rpmdragora"),
                              version => $rpmdragora::distro_version,
                              copyright => $loc->N("Copyright (C) %s by Mandriva", '2002-2008'),
                              license => $license, wrap_license => 1,
                              comments => $loc->N("Rpmdragora is the Mageia package management tool."),
                              website => 'http://www.mageia.org/',
                              website_label => $loc->N("Mageia"),
                              authors => 'Thierry Vignaud <vignaud@mandriva.com>',
                              artists => 'Hélène Durosini <ln@mandriva.com>',
                              translator_credits =>
                                #-PO: put here name(s) and email(s) of translator(s) (eg: "John Smith <jsmith@nowhere.com>")
                                $loc->N("_: Translator(s) name(s) & email(s)\n"),
                              transient_for => $::main_window, modal => 1, position_policy => 'center-on-parent',
                          );
               $w->show_all;
               $w->run;
           }, undef, '<Item>'
       ]
     ),
    );

    my $list = Gtk2::ListStore->new("Glib::Boolean", "Glib::Boolean", "Glib::String", "Glib::String", "Glib::Boolean");
    $list_tv = Gtk2::TreeView->new_with_model($list);
    $list_tv->get_selection->set_mode('multiple');
    my ($dw_button, $edit_button, $remove_button, $up_button);
    $list_tv->get_selection->signal_connect(changed => sub {
        my ($selection) = @_;
        my @rows = $selection->get_selected_rows;
        my $model = $list;
        # we can delete several medium at a time:
        $remove_button and $remove_button->set_sensitive($#rows != -1);
        # we can only edit/move one item at a time:
        $_ and $_->set_sensitive(@rows == 1) foreach $up_button, $dw_button, $edit_button;

        # we can only up/down one item if not at begin/end:
        return if @rows != 1;

        my $curr_path = $rows[0];
        my $first_path = $model->get_path($model->get_iter_first);
        $up_button->set_sensitive($first_path && $first_path->compare($curr_path));

        $curr_path->next;
        my $next_item = $model->get_iter($curr_path);
        $dw_button->set_sensitive($next_item); # && !$model->get($next_item, 0)
    });

    $list_tv->set_rules_hint(1);
    $list_tv->set_reorderable(1);

    my $reorder_ok = 1;
    $list->signal_connect(
	row_deleted => sub {
	    $reorder_ok or return;
	    my ($model) = @_;
	    my @media;
	    $model->foreach(
		sub {
		    my (undef, undef, $iter) = @_;
		    my $name = $model->get($iter, $col{mainw}{name});
		    push @media, urpm::media::name2medium($urpm, $name);
		    0;
		}, undef);
	    @{$urpm->{media}} = @media;
	},
    );

    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes($loc->N("Enabled"),
                                                                      my $tr = Gtk2::CellRendererToggle->new,
                                                                      'active' => $col{mainw}{is_enabled}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes($loc->N("Updates"),
                                                                      my $cu = Gtk2::CellRendererToggle->new,
                                                                      'active' => $col{mainw}{is_update},
                                                                      activatable => $col{mainw}{activatable}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes($loc->N("Type"),
                                                                      Gtk2::CellRendererText->new,
                                                                      'text' => $col{mainw}{type}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes($loc->N("Medium"),
                                                                      Gtk2::CellRendererText->new,
                                                                      'text' => $col{mainw}{name}));
    my $id;
    $id = $tr->signal_connect(
	toggled => sub {
	    my (undef, $path) = @_;
	    $tr->signal_handler_block($id);
	    my $_guard = before_leaving { $tr->signal_handler_unblock($id) };
	    my $iter = $list->get_iter_from_string($path);
	    $urpm->{media}[$path]{ignore} = !$urpm->{media}[$path]{ignore} || undef;
	    $list->set($iter, $col{mainw}{is_enabled}, !$urpm->{media}[$path]{ignore});
	    urpm::media::write_config($urpm);
	    my $ignored = $urpm->{media}[$path]{ignore};
	    $reread_media->();
	    if (!$ignored && $urpm->{media}[$path]{ignore}) {
		# reread media failed to un-ignore an ignored medium
		# probably because urpm::media::check_existing_medium() complains
		# about missing synthesis when the medium never was enabled before;
		# thus it restored the ignore bit
		$urpm->{media}[$path]{ignore} = !$urpm->{media}[$path]{ignore} || undef;
		urpm::media::write_config($urpm);
		#- Enabling this media failed, force update
		interactive_msg('rpmdragora',
		    $loc->N("This medium needs to be updated to be usable. Update it now?"),
		    yesno => 1,
		) and $reread_media->($urpm->{media}[$path]{name});
	    }
	},
    );

    $cu->signal_connect(
	toggled => sub {
	    my (undef, $path) = @_;
	    my $iter = $list->get_iter_from_string($path);
	    $urpm->{media}[$path]{update} = !$urpm->{media}[$path]{update} || undef;
	    $list->set($iter, $col{mainw}{is_update}, ! !$urpm->{media}[$path]{update});
         $something_changed = 1;
	},
    );

    $reread_media = sub {
	my ($name) = @_;
        $reorder_ok = 0;
     $something_changed = 1;
	if (defined $name) {
	    urpm::media::select_media($urpm, $name);
	    update_sources_check(
		$urpm,
		{ nolock => 1 },
		$loc->N_("Unable to update medium, errors reported:\n\n%s"),
		$name,
	    );
	}
	# reread configuration after updating media else ignore bit will be restored
	# by urpm::media::check_existing_medium():
	$urpm = fast_open_urpmi_db();
	$list->clear;
     foreach (grep { ! $_->{external} } @{$urpm->{media}}) {
         my $name = $_->{name};
         $list->append_set($col{mainw}{is_enabled} => !$_->{ignore},
                           $col{mainw}{is_update} => ! !$_->{update},
                           $col{mainw}{type} => get_medium_type($_),
                           $col{mainw}{name} => $name,
                           $col{mainw}{activatable} => to_bool($::expert),
                       );
     }
        $reorder_ok = 1;
    };
    $reread_media->();
    $something_changed = 0;

    gtkadd(
	$mainw->{window},
	gtkpack_(
	    gtknew('VBox', spacing => 5),
	    0, $menu,
	    ($0 =~ /rpm-edit-media|edit-urpm-sources/ ? (0, Gtk2::Banner->new($ugtk2::wm_icon, $loc->N("Configure media"))) : ()),
	    1, gtkpack_(
		gtknew('HBox', spacing => 10),
		1, gtknew('ScrolledWindow', child => $list_tv),
		0, gtkpack__(
		    gtknew('VBox', spacing => 5),
		    gtksignal_connect(
			$remove_button = Gtk2::Button->new(but($loc->N("Remove"))),
			clicked => sub { remove_callback() and $reread_media->() },
		    ),
		    gtksignal_connect(
			$edit_button = Gtk2::Button->new(but($loc->N("Edit"))),
			clicked => sub {
			    my $name = edit_callback(); defined $name and $reread_media->($name);
			}
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but($loc->N("Add"))),
			clicked => sub { easy_add_callback() and $reread_media->() },
		    ),
		    gtkpack(
			gtknew('HBox'),
			gtksignal_connect(
                            $up_button = gtknew('Button',
                                                image => gtknew('Image', stock => 'gtk-go-up')),
                            clicked => \&upwards_callback),

			gtksignal_connect(
                            $dw_button = gtknew('Button',
                                                image => gtknew('Image', stock => 'gtk-go-down')),
                            clicked => \&downwards_callback),
		    ),
		)
	    ),
	    0, gtknew('HSeparator'),
	    0, gtknew('HButtonBox', layout => 'edge', children_loose => [
		gtksignal_connect(Gtk2::Button->new(but($loc->N("Help"))), clicked => sub { rpmdragora::open_help('sources') }),
		gtksignal_connect(Gtk2::Button->new(but($loc->N("Ok"))), clicked => sub { Gtk2->main_quit })
	    ])
	)
    );
    $_->set_sensitive(0) foreach $dw_button, $edit_button, $remove_button, $up_button;

    $mainw->{rwindow}->set_size_request(600, 400);
    $mainw->main;
    return $something_changed;
}


sub run() {
    # ignore rpmdragora's option regarding ignoring debug media:
    local $ignore_debug_media = [ 0 ];
#     local $ugtk2::wm_icon = get_icon('rpmdragora-mdk', 'title-media');
    my $lock;
    {
        $urpm = fast_open_urpmi_db();
        my $err_msg = "urpmdb locked\n";
        local $urpm->{fatal} = sub {
            interactive_msg('rpmdragora',
                            $loc->N("The Package Database is locked. Please close other applications
working with the Package Database. Do you have another media
manager on another desktop, or are you currently installing
packages as well?"));
            die $err_msg;
        };
        # lock urpmi DB
        eval { $lock = urpm::lock::urpmi_db($urpm, 'exclusive', wait => $urpm->{options}{wait_lock}) };
        if (my $err = $@) {
            return if $err eq $err_msg;
            die $err;
        }
    }

    my $res = mainwindow();
    urpm::media::write_config($urpm);

    writeconf();

    undef $lock;
    $res;
}

sub readproxy (;$) {
    my $proxy = get_proxy($_[0]);
    ($proxy->{http_proxy} || $proxy->{ftp_proxy} || '',
        defined $proxy->{user} ? "$proxy->{user}:$proxy->{pwd}" : '');
}

sub writeproxy {
    my ($proxy, $proxy_user, $o_media_name) = @_;
    my ($user, $pwd) = split /:/, $proxy_user;
    set_proxy_config(user => $user, $o_media_name);
    set_proxy_config(pwd => $pwd, $o_media_name);
    set_proxy_config(http_proxy => $proxy, $o_media_name);
    set_proxy_config(ftp_proxy => $proxy, $o_media_name);
    dump_proxy_config();
}

1;
