# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::edit_urpm_sources;
#*****************************************************************************
# 
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2002-2007 Mandriva Linux
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

use lib qw(/usr/lib/libDrakX);
use common;
use AdminPanel::rpmdragora;
use AdminPanel::Rpmdragora::init;
use AdminPanel::Rpmdragora::open_db;
use AdminPanel::Rpmdragora::formatting;
use AdminPanel::Shared::GUI;
use URPM::Signature;
use MDK::Common::Math qw(max);
use MDK::Common::File;
use MDK::Common::DataStructure qw(member);
use urpm::media;
use urpm::download;
use urpm::lock;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(run);

#use mygtk2 qw(gtknew gtkset);
#use ugtk2 qw(:all);

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


sub get_medium_type {
    my ($medium) = @_;
    my %medium_type = (
        cdrom     => N("CD-ROM"),
        ftp       => N("FTP"),
        file      => N("Local"),
        http      => N("HTTP"),
        https     => N("HTTPS"),
        nfs       => N("NFS"),
        removable => N("Removable"),
        rsync     => N("rsync"),
        ssh       => N("NFS"),
    );
    return N("Mirror list") if $medium->{mirrorlist};
    return $medium_type{$1} if $medium->{url} =~ m!^([^:]*)://!;
    return N("Local");
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
    distro_type(0) eq 'updates' ? interactive_msg(
	N("Choose media type"),
N("In order to keep your system secure and stable, you must at a minimum set up
sources for official security and stability updates. You can also choose to set
up a fuller set of sources which includes the complete official Mageia
repositories, giving you access to more software than can fit on the Mageia
discs. Please choose whether to configure update sources only, or the full set
of sources."),
	 transient => $::main_window,
	yesno => 1, text => { yes => N("Full set of sources"), no => N("Update sources only") },
    ) : 1;
}

sub easy_add_callback_with_mirror() {
    # when called on early init by rpmdragora
    $urpm ||= fast_open_urpmi_db();

    #- cooker and community don't have update sources
    my $want_base_distro = _want_base_distro();
    defined $want_base_distro or return;
    my $distro = $rpmdragora::mandrake_release;
    my ($mirror) = choose_mirror($urpm, message =>
N("This will attempt to install all official sources corresponding to your
distribution (%s).

I need to contact the Mageia website to get the mirror list.
Please check that your network is currently running.

Is it ok to continue?", $distro),
     transient => $::main_window,
    ) or return 0;
    ref $mirror or return;
    my $wait = wait_msg(N("Please wait, adding media..."));
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
    defined $want_base_distro or return;
    warn_for_network_need(undef, transient => $::main_window) or return;
    my $wait = wait_msg(N("Please wait, adding media..."));
    add_distrib_update_media($urpm, undef, if_(!$want_base_distro, only_updates => 1));
    $offered_to_add_sources->[0] = 1;
    remove_wait_msg($wait);
    return 1;
}

sub add_callback() {
    my $w = ugtk2->new(N("Add a medium"), grab => 1, center => 1,  transient => $::main_window);
    my $prev_main_window = $::main_window;
    local $::main_window = $w->{real_window};
    my %radios_infos = (
	local => { name => N("Local files"), url => N("Medium path:"), dirsel => 1 },
	ftp => { name => N("FTP server"), url => N("URL:"), loginpass => 1 },
	rsync => { name => N("RSYNC server"), url => N("URL:") },
	http => { name => N("HTTP server"), url => N("URL:") },
	removable => { name => N("Removable device (CD-ROM, DVD, ...)"), url => N("Path or mount point:"), dirsel => 1 },
    );
    my @radios_names_ordered = qw(local ftp rsync http removable);
    # TODO: replace NoteBook by sensitive widgets and Label->set()
    my $notebook = gtknew('Notebook');
    $notebook->set_show_tabs(0); $notebook->set_show_border(0);
    my ($count_nbs, %pages);
    my $size_group = Gtk2::SizeGroup->new('horizontal');
    my ($cb1, $cb2);
    foreach (@radios_names_ordered) {
	my $info = $radios_infos{$_};
	my $url_entry = sub {
	    gtkpack_(
		gtknew('HBox'),
		1, $info->{url_entry} = gtkentry(),
		if_(
		    $info->{dirsel},
		    0, gtksignal_connect(
			gtknew('Button', text => but(N("Browse..."))),
			clicked => sub { $info->{url_entry}->set_text(ask_dir()) },
		    )
		),
	    );
	};
        my $checkbut_entry = sub {
            my ($name, $label, $visibility, $callback, $tip) = @_;
            my $w = [ gtksignal_connect(
		    $info->{$name . '_check'} = gtkset(gtknew('CheckButton', text => $label), tip => $tip),
		    clicked => sub {
			$info->{$name . '_entry'}->set_sensitive($_[0]->get_active);
			$callback and $callback->(@_);
		    },
	    ),
	    gtkset_visibility(gtkset_sensitive($info->{$name . '_entry'} = gtkentry(), 0), $visibility) ];
	    $size_group->add_widget($info->{$name . '_check'});
	    $w;
        };
	my $loginpass_entries = sub {
	    map {
		$checkbut_entry->(
		    @$_, sub {
			$info->{pass_check}->set_active($_[0]->get_active);
			$info->{login_check}->set_active($_[0]->get_active);
		    }
		);
	    } ([ 'login', N("Login:"), 1 ], [ 'pass', N("Password:"), 0 ]);
	};
	$pages{$info->{name}} = $count_nbs++;
	$notebook->append_page(
	    gtkshow(create_packtable(
		{ xpadding => 0, ypadding => 0 },
		[ gtkset_alignment(gtknew('Label', text => N("Medium name:")), 0, 0.5),
		    $info->{name_entry} = gtkentry('') ],
		[ gtkset_alignment(gtknew('Label', text => $info->{url}), 0, 0.5),
		    $url_entry->() ],
		if_($info->{loginpass}, $loginpass_entries->()),
		sub {
		    [ $info->{distrib_check} = $cb1 = gtknew('CheckButton', text => N("Create media for a whole distribution"),
                                                         toggled => sub {
                                                             return if !$cb2;
                                                             my ($w) = @_;
                                                             $info->{update_check}->set_sensitive(!$w->get_active);
                                                         })
		    ];
		}->(),
		sub {
		    [ $info->{update_check} = $cb2 = gtknew('CheckButton', text => N("Tag this medium as an update medium")) ];
		}->(),
	    ))
	);
    }
    $size_group->add_widget($_) foreach $cb1, $cb2;

    my $checkok = sub {
	my $info = $radios_infos{$radios_names_ordered[$notebook->get_current_page]};
	my ($name, $url) = map { $info->{$_ . '_entry'}->get_text } qw(name url);
	$name eq '' || $url eq '' and interactive_msg('rpmdragora', N("You need to fill up at least the two first entries.")), return 0;
	if (member($name, map { $_->{name} } @{$urpm->{media}})) {
	    $info->{name_entry}->select_region(0, -1);
	    interactive_msg('rpmdragora',
N("There is already a medium by that name, do you
really want to replace it?"), yesno => 1) or return 0;
	}
	1;
    };

    my $type = 'local';
    my (%i, %make_url);
    gtkadd(
	$w->{window},
	gtkpack(
	    gtknew('VBox', spacing => 5),
	    gtknew('Title2', label => N("Adding a medium:")),
	    gtknew('HBox', children_tight => [
                      Gtk2::Label->new(but(N("Type of medium:"))),
                      gtknew('ComboBox', text_ref => \$type, 
                             list => \@radios_names_ordered,
                             format => sub { $radios_infos{$_[0]}{name} },
                             changed => sub { $notebook->set_current_page($pages{$_[0]->get_text}) })
                     ]),
	    $notebook,
	    gtknew('HSeparator'),
	    gtkpack(
		gtknew('HButtonBox'),
		gtknew('Button', text => N("Cancel"), clicked => sub { $w->{retval} = 0; Gtk2->main_quit }),
		gtksignal_connect(
		    gtknew('Button', text => N("Ok")), clicked => sub {
			if ($checkok->()) {
			    $w->{retval} = { nb => $notebook->get_current_page };
			    my $info = $radios_infos{$type};
			    %i = (
				name => $info->{name_entry}->get_text,
				url => $info->{url_entry}->get_text,
				distrib => $info->{distrib_check} ? $info->{distrib_check}->get_active : 0,
				update => $info->{update_check}->get_active ? 1 : undef,
			    );
			    %make_url = (
				local => "file:/$i{url}",
				http => $i{url},
				rsync => $i{url},
				removable => "removable:/$i{url}",
			    );
			    $i{url} =~ s|^ftp://||;
			    $make_url{ftp} = sprintf "ftp://%s%s",
				$info->{login_check}->get_active
				    ? ($info->{login_entry}->get_text . ':' . $info->{pass_entry}->get_text . '@')
				    : '',
				$i{url};
			    Gtk2->main_quit;
			}
		    },
		),
	    ),
	),
    );

    if ($w->main) {
	$::main_window = $prev_main_window;
	if ($i{distrib}) {
	    add_medium_and_check(
		$urpm,
		{ nolock => 1, distrib => 1 },
		$i{name}, $make_url{$type}, probe_with => 'synthesis', update => $i{update},
	    );
	} else {
	    if (member($i{name}, map { $_->{name} } @{$urpm->{media}})) {
		urpm::media::select_media($urpm, $i{name});
		urpm::media::remove_selected_media($urpm);
	    }
	    add_medium_and_check(
		$urpm,
		{ nolock => 1 },
		$i{name}, $make_url{$type}, $i{hdlist}, update => $i{update},
	    );
	}
	return 1;
    }
    return 0;
}

sub options_callback() {
    my $w = ugtk2->new(N("Global options for package installation"), grab => 1, center => 1,  transient => $::main_window);
    local $::main_window = $w->{real_window};
    my %verif = (0 => N("never"), 1 => N("always"));
    my $verify_rpm = $urpm->{global_config}{'verify-rpm'};
    my @avail_downloaders = urpm::download::available_ftp_http_downloaders();
    my $downloader = $urpm->{global_config}{downloader} || $avail_downloaders[0];
    my %xml_info_policies = (
        'never'       => N("Never"), 
        'on-demand'   => N("On-demand"), 
        'update-only' => N("Update-only"), 
        'always'      => N("Always"), 
    );
    my $xml_info_policy = $urpm->{global_config}{'xml-info'};

    gtkadd(
	$w->{window},
	gtkpack(
	    gtknew('VBox', spacing => 5),
	    gtknew('HBox', children_loose => [ gtknew('Label', text => N("Verify RPMs to be installed:")),
                                               gtknew('ComboBox', list => [ keys %verif ], text_ref => \$verify_rpm,
                                                      format => sub { $verif{$_[0]} || $_[0] },
                                                  )
                                           ]),
	    gtknew('HBox', children_loose => [ gtknew('Label', text => N("Download program to use:")),
                                               gtknew('ComboBox', list => \@avail_downloaders, text_ref => \$downloader,
                                                      format => sub { $verif{$_[0]} || $_[0] },
                                                  )
                                           ]),
	    gtknew('HBox',
                   children_loose =>
                     [ gtknew('Label', text => N("XML meta-data download policy:")),
                       gtknew('ComboBox',
                              list => [ keys %xml_info_policies ], text_ref => \$xml_info_policy,

                              format => sub { $xml_info_policies{$_[0]} || $_[0] },
                              tip => 
                                join("\n",
                                     N("For remote media, specify when XML meta-data (file lists, changelogs & information) are downloaded."),
                                     '',
                                     N("Never"),
                                     N("For remote media, XML meta-data are never downloaded."),
                                     '',
                                     N("On-demand"),
                                     N("(This is the default)"),
                                     N("The specific XML info file is downloaded when clicking on package."),
                                     '',
                                     N("Update-only"), 
                                     N("Updating media implies updating XML info files already required at least once."),
                                     '',
                                     N("Always"),
                                     N("All XML info files are downloaded when adding or updating media."),
                                 ),
                          ),
                   ]),

	    gtkpack(
		gtknew('HButtonBox'),
		gtknew('Button', text => N("Cancel"), clicked => sub { Gtk2->main_quit }),
		gtksignal_connect(
		    gtknew('Button', text => N("Ok")), clicked => sub {
                        $urpm->{global_config}{'verify-rpm'} = $verify_rpm;
                        $urpm->{global_config}{downloader} = $downloader;
                        $urpm->{global_config}{'xml-info'} = $xml_info_policy;
                        $something_changed = 1;
			urpm::media::write_config($urpm);
			$urpm = fast_open_urpmi_db();
			Gtk2->main_quit;
		    },
		),
	    ),
	),
    );
    $w->main;
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
    @rows == 0 and return;
    interactive_msg(
        N("Source Removal"),
        @rows == 1 ?
            N("Are you sure you want to remove source \"%s\"?", $urpm->{media}[$rows[0]]{name}) :
            N("Are you sure you want to remove the following sources?") . "\n\n" .
                format_list(map { $urpm->{media}[$_]{name} } @rows),
        yesno => 1, scroll => 1,
    ) or return;

    # TODO dialog waiting if needed
    #     my $wait = wait_msg(N("Please wait, removing medium..."));
    foreach my $row (reverse(@rows)) {
        $something_changed = 1;
        urpm::media::remove_media($urpm, [ $urpm->{media}[$row] ]);
        urpm::media::write_urpmi_cfg($urpm);
        #         undef $wait
        # 	remove_wait_msg($wait);
    }
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

#- returns the name of the media for which edition failed, or undef on success
sub edit_callback {
    my $table = shift;

    ## get the first
    my $item = $table->selectedItem();
    !$item and return 0;
    my $row = $item->index();

    my $medium = $urpm->{media}[$row];
    my $config = urpm::cfg::load_config_raw($urpm->{config}, 1);
    my ($verbatim_medium) = grep { $medium->{name} eq $_->{name} } @$config;

    my $appTitle = yui::YUI::app()->applicationTitle();
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Edit a medium"));

    my $factory      = yui::YUI::widgetFactory;

    my $dialog  = $factory->createPopupDialog();
    my $minSize = $factory->createMinSize( $dialog, 80, 5 );
    my $vbox    = $factory->createVBox( $minSize );

    my $hbox    = $factory->createHBox( $factory->createLeft($vbox) );
    $factory->createHeading($hbox, N("Editing medium \"%s\":", $medium->{name}));
    $factory->createVSpacing($vbox, 1.0);

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    my $label     = $factory->createLabel($hbox, N("URL:"));
    my $url_entry = $factory->createInputField($hbox, "", 0);
#     $label->setWeight($yui::YD_HORIZ, 1);
    $url_entry->setWeight($yui::YD_HORIZ, 2);
    $url_entry->setValue($verbatim_medium->{url} || $verbatim_medium->{mirrorlist});

    $hbox    = $factory->createHBox($vbox);
    $factory->createHSpacing($hbox, 1.0);
    $label        = $factory->createLabel($hbox, N("Downloader:") );
    my $downloader_entry   = $factory->createComboBox($hbox, $verbatim_medium->{downloader} || "", 0);
#     $label->setWeight($yui::YD_HORIZ, 1);
    $downloader_entry->setWeight($yui::YD_HORIZ, 2);

    my @comboList =  urpm::download::available_ftp_http_downloaders() ;
    if (scalar(@comboList) > 0) {
        my $itemColl = new yui::YItemCollection;
        foreach my $elem (@comboList) {
            my $it = new yui::YItem($elem, 0);
            $itemColl->push($it);
            $it->DISOWN();
        }
        $downloader_entry->addItems($itemColl);
    }
    $factory->createVSpacing($vbox, 0.5);

    $hbox    = $factory->createHBox($factory->createLeft($vbox));
    $factory->createHSpacing($hbox, 1.0);
    ### TODO cell to get info
    my $tableItem = yui::toYTableItem($item);
    # enabled cell 0, updates cell 1
    my $cell = $tableItem->cell(0);
    my $enabled = $factory->createCheckBox($hbox, N("Enabled"), $cell->label? 1:0);
    $cell = $tableItem->cell(1);
    my $update  = $factory->createCheckBox($hbox, N("Updates"), $cell->label? 1:0);
    $update->setDisabled() if (!$::expert);

    $factory->createVSpacing($vbox, 0.5);
    $hbox            = $factory->createHBox($vbox);
    my $cancelButton = $factory->createPushButton($hbox,  N("Cancel"));
    $factory->createHSpacing($hbox, 3.0);
    my $saveButton   = $factory->createPushButton($hbox,  N("Save changes"));
    $factory->createHSpacing($hbox, 3.0);
    my $proxyButton  = $factory->createPushButton($hbox,  N("Proxy..."));

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
        }
    }
### End ###
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

##############################################


sub tobe_removed {
    my ($row) = selected_rows();
    $row == -1 and return;
    my $medium = $urpm->{media}[$row];
    my $config = urpm::cfg::load_config_raw($urpm->{config}, 1);
    my ($verbatim_medium) = grep { $medium->{name} eq $_->{name} } @$config;

    my $old_main_window = $::main_window;
    my $w = ugtk2->new(N("Edit a medium"), grab => 1, center => 1,  transient => $::main_window);
    local $::main_window = $w->{real_window};
    my ($url_entry, $downloader_entry, $url, $downloader);
    gtkadd(
	$w->{window},
	gtkpack_(
	    gtknew('VBox', spacing => 5),
	    0, gtknew('Title2', label => N("Editing medium \"%s\":", $medium->{name})),

	    0, create_packtable(
		{},
		[ gtknew('Label_Left', text => N("URL:")), $url_entry = gtkentry($verbatim_medium->{url} || $verbatim_medium->{mirrorlist}) ],
		[ gtknew('Label_Left', text => N("Downloader:")),
            my $download_combo = Gtk2::ComboBox->new_with_strings([ urpm::download::available_ftp_http_downloaders() ],
                                                                  $verbatim_medium->{downloader} || '') ],
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtksignal_connect(
		    gtknew('Button', text => N("Cancel")),
		    clicked => sub { $w->{retval} = 0; Gtk2->main_quit },
		),
		gtksignal_connect(
		    gtknew('Button', text => N("Save changes")),
		    clicked => sub {
			$w->{retval} = 1;
			$url = $url_entry->get_text;
			$downloader = $downloader_entry->get_text;
			Gtk2->main_quit;
		    },
		),
		gtksignal_connect(
		    gtknew('Button', text => N("Proxy...")),
		    clicked => sub { proxy_callback($medium) },
		),
	    )
	)
    );
    $downloader_entry = $download_combo->entry;
    $w->{rwindow}->set_size_request(600, -1);
    if ($w->main) {
	my ($name, $update) = map { $medium->{$_} } qw(name update);
	$url =~ m|^removable://| and (
	    interactive_msg(
		N("You need to insert the medium to continue"),
		N("In order to save the changes, you need to insert the medium in the drive."),
		yesno => 1, text => { yes => N("Ok"), no => N("Cancel") }
	    ) or return 0
	);
	my $saved_proxy = urpm::download::get_proxy($name);
	undef $saved_proxy if !defined $saved_proxy->{http_proxy} && !defined $saved_proxy->{ftp_proxy};
	urpm::media::select_media($urpm, $name);
     if (my ($media) = grep { $_->{name} eq $name } @{$urpm->{media}}) {
         put_in_hash($media, {
             ($verbatim_medium->{mirrorlist} ? 'mirrorlist' : 'url') => $url,
             name => $name,
             if_($update ne $media->{update} || $update, update => $update),
             if_($saved_proxy ne $media->{proxy} || $saved_proxy, proxy => $saved_proxy),
             if_($downloader ne $media->{downloader} || $downloader, downloader => $downloader),
             modified => 1,
         });
         urpm::media::write_config($urpm);
         local $::main_window = $old_main_window;
         update_sources_noninteractive($urpm, [ $name ], transient => $::main_window, nolock => 1);
     } else {
         urpm::media::remove_selected_media($urpm);
         add_medium_and_check($urpm, { nolock => 1, proxy => $saved_proxy }, $name, $url, undef, update => $update, if_($downloader, downloader => $downloader));
     }
	return $name;
    }
}

    return undef;
}

sub update_callback() {
    update_sources_interactive($urpm,  transient => $::main_window, nolock => 1);
}

sub proxy_callback {
    my ($medium) = @_;
    my $medium_name = $medium ? $medium->{name} : '';
    my $w = ugtk2->new(N("Configure proxies"), grab => 1, center => 1,  transient => $::main_window);
    local $::main_window = $w->{real_window};
    require curl_download;
    my ($proxy, $proxy_user) = curl_download::readproxy($medium_name);
    my ($user, $pass) = $proxy_user =~ /^([^:]*):(.*)$/;
    my ($proxybutton, $proxyentry, $proxyuserbutton, $proxyuserentry, $proxypasswordentry);
    my $sg = Gtk2::SizeGroup->new('horizontal');
    gtkadd(
	$w->{window},
	gtkpack__(
	    gtknew('VBox', spacing => 5),
	    gtknew('Title2', label =>
		$medium_name
		    ? N("Proxy settings for media \"%s\"", $medium_name)
		    : N("Global proxy settings")
	    ),
	    gtknew('Label_Left', text => N("If you need a proxy, enter the hostname and an optional port (syntax: <proxyhost[:port]>):")),
	    gtkpack_(
		gtknew('HBox', spacing => 10),
		1, gtkset_active($proxybutton = gtknew('CheckButton', text => N("Proxy hostname:")), to_bool($proxy)),
		0, gtkadd_widget($sg, gtkset_sensitive($proxyentry = gtkentry($proxy), to_bool($proxy))),
	    ),
         gtkset_active($proxyuserbutton = gtknew('CheckButton', text => N("You may specify a username/password for the proxy authentication:")), to_bool($proxy_user)),
	    gtkpack_(
		my $hb_user = gtknew('HBox', spacing => 10, sensitive => to_bool($proxy_user)),
		1, gtknew('Label_Left', text => N("User:")),
		0, gtkadd_widget($sg, $proxyuserentry = gtkentry($user)),
      ),
	    gtkpack_(
		my $hb_pswd = gtknew('HBox', spacing => 10, sensitive => to_bool($proxy_user)),
		1, gtknew('Label_Left', text => N("Password:")),
		0, gtkadd_widget($sg, gtkset_visibility($proxypasswordentry = gtkentry($pass), 0)),
	    ),
	    gtknew('HSeparator'),
	    gtkpack(
		gtknew('HButtonBox'),
		gtksignal_connect(
		    gtknew('Button', text => N("Ok")),
		    clicked => sub {
			$w->{retval} = 1;
			$proxy = $proxybutton->get_active ? $proxyentry->get_text : '';
			$proxy_user = $proxyuserbutton->get_active
			    ? ($proxyuserentry->get_text . ':' . $proxypasswordentry->get_text) : '';
			Gtk2->main_quit;
		    },
		),
		gtksignal_connect(
		    gtknew('Button', text => N("Cancel")),
		    clicked => sub { $w->{retval} = 0; Gtk2->main_quit },
		)
	    )
	)
    );
    $sg->add_widget($_) foreach $proxyentry, $proxyuserentry, $proxypasswordentry;
    $proxybutton->signal_connect(
	clicked => sub {
	    $proxyentry->set_sensitive($_[0]->get_active);
	    $_[0]->get_active and return;
	    $proxyuserbutton->set_active(0);
	    $hb_user->set_sensitive(0);
	    $hb_pswd->set_sensitive(0);
	}
    );
    $proxyuserbutton->signal_connect(clicked => sub { $_->set_sensitive($_[0]->get_active) foreach $hb_user, $hb_pswd;
    $proxypasswordentry->set_sensitive($_[0]->get_active) });

    $w->main and do {
        $something_changed = 1;
        curl_download::writeproxy($proxy, $proxy_user, $medium_name);
    };
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
                gtknew('Button', text => N("Ok"), clicked => sub { $w->{retval} = 1; $get_value->(); Gtk2->main_quit }),
                gtknew('Button', text => N("Cancel"), clicked => sub { $w->{retval} = 0; Gtk2->main_quit })
            )
        )
    );
    $check->() if $w->main;
}

sub edit_parallel {
    my ($num, $conf) = @_;
    my $edited = $num == -1 ? {} : $conf->[$num];
    my $w = ugtk2->new($num == -1 ? N("Add a parallel group") : N("Edit a parallel group"), grab => 1, center => 1,  transient => $::main_window);
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
        add_callback_(N("Add a medium limit"), N("Choose a medium to add to the media limit:"),
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
        add_callback_(N("Add a host"), N("Type in the hostname or IP address of the host to add:"),
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
		0, gtknew('Label', text => N("Editing parallel group \"%s\":", $edited->{name}))
	    ),
	    1, create_packtable(
		{},
		[ N("Group name:"), $name_entry = gtkentry($edited->{name}) ],
		[ N("Protocol:"), gtknew('HBox', children_tight => [
		    @protocols = gtkradio($edited->{protocol}, @protocols_names) ]) ],
		[ N("Media limit:"),
		gtknew('HBox', spacing => 5, children => [
		    1, gtknew('Frame', shadow_type => 'in', child => 
			gtknew('ScrolledWindow', h_policy => 'never', child => $medias)),
		    0, gtknew('VBox', children_tight => [
			gtksignal_connect(Gtk2::Button->new(but(N("Add"))),    clicked => sub { $add_media->() }),
			gtksignal_connect(Gtk2::Button->new(but(N("Remove"))), clicked => sub {
                                              remove_from_list($medias, $edited->{medias}, $medias_ls);
                                          }) ]) ]) ],
		[ N("Hosts:"),
		gtknew('HBox', spacing => 5, children => [
		    1, gtknew('Frame', shadow_type => 'in', child => 
			gtknew('ScrolledWindow', h_policy => 'never', child => $hosts)),
		    0, gtknew('VBox', children_tight => [
			gtksignal_connect(Gtk2::Button->new(but(N("Add"))),    clicked => sub { $add_host->() }),
			gtksignal_connect(Gtk2::Button->new(but(N("Remove"))), clicked => sub {
                                              remove_from_list($hosts, $hosts_list, $hosts_ls);
                                          }) ]) ]) ]
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtksignal_connect(
		    gtknew('Button', text => N("Ok")), clicked => sub {
			$w->{retval} = 1;
			$edited->{name} = $name_entry->get_text;
			mapn { $_[0]->get_active and $edited->{protocol} = $_[1] } \@protocols, \@protocols_names;
			Gtk2->main_quit;
		    }
		),
		gtknew('Button', text => N("Cancel"), clicked => sub { $w->{retval} = 0; Gtk2->main_quit }))
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
    my $w = ugtk2->new(N("Configure parallel urpmi (distributed execution of urpmi)"), grab => 1, center => 1,  transient => $mainw->{real_window});
    local $::main_window = $w->{real_window};
    my $list_ls = Gtk2::ListStore->new("Glib::String", "Glib::String", "Glib::String", "Glib::String");
    my $list = Gtk2::TreeView->new_with_model($list_ls);
    each_index { $list->append_column(Gtk2::TreeViewColumn->new_with_attributes($_, Gtk2::CellRendererText->new, 'text' => $::i)) } N("Group"), N("Protocol"), N("Media limit");
    $list->append_column(my $commandcol = Gtk2::TreeViewColumn->new_with_attributes(N("Command"), Gtk2::CellRendererText->new, 'text' => 3));
    $commandcol->set_max_width(200);

    my $conf;
    my $reread = sub {
	$list_ls->clear;
        $conf = parallel_read_sysconf();
	foreach (@$conf) {
            $list_ls->append_set([ 0 => $_->{name},
                                   1 => $_->{protocol},
                                   2 => @{$_->{medias}} ? join(', ', @{$_->{medias}}) : N("(none)"),
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
			Gtk2::Button->new(but(N("Remove"))),
			clicked => sub { remove_parallel(selrow($list), $conf); $reread->() },
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but(N("Edit..."))),
			clicked => sub {
			    my $row = selrow($list);
			    $row != -1 and edit_parallel($row, $conf);
			    $reread->();
			},
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but(N("Add..."))),
			clicked => sub { edit_parallel(-1, $conf) and $reread->() },
		    )
		)
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtknew('Button', text => N("Ok"), clicked => sub { Gtk2->main_quit })
	    )
	)
    );
    $w->main;
}

sub keys_callback() {
    my $w = ugtk2->new(N("Manage keys for digital signatures of packages"), grab => 1, center => 1,  transient => $mainw->{real_window});
    local $::main_window = $w->{real_window};
    $w->{real_window}->set_size_request(600, 300);

    my $media_list_ls = Gtk2::ListStore->new("Glib::String");
    my $media_list = Gtk2::TreeView->new_with_model($media_list_ls);
    $media_list->append_column(Gtk2::TreeViewColumn->new_with_attributes(N("Medium"), Gtk2::CellRendererText->new, 'text' => 0));
    $media_list->get_selection->set_mode('browse');

    my $key_col_size = 200;
    my $keys_list_ls = Gtk2::ListStore->new("Glib::String", "Glib::String");
    my $keys_list = Gtk2::TreeView->new_with_model($keys_list_ls);
    $keys_list->set_rules_hint(1);
    $keys_list->append_column(my $col = Gtk2::TreeViewColumn->new_with_attributes(N("_:cryptographic keys\nKeys"), my $renderer = Gtk2::CellRendererText->new, 'text' => 0));
    $col->set_sizing('fixed');
    $col->set_fixed_width($key_col_size);
    $renderer->set_property('width' => 1);
    $renderer->set_property('wrap-width', $key_col_size);
    $keys_list->get_selection->set_mode('browse');

    my ($current_medium, $current_medium_nb, @keys);

    my $read_conf = sub {
        $urpm->parse_pubkeys(root => $urpm->{root});
        @keys = map { [ split /[,\s]+/, $_->{'key-ids'} ] } @{$urpm->{media}};
    };
    my $write = sub {
        $something_changed = 1;
        urpm::media::write_config($urpm);
        $urpm = fast_open_urpmi_db();
        $read_conf->();
        $media_list->get_selection->signal_emit('changed');
    };
    $read_conf->();
    my $key_name = sub {
        exists $urpm->{keys}{$_[0]} ? $urpm->{keys}{$_[0]}{name}
                                    : N("no name found, key doesn't exist in rpm keyring!");
    };
    $media_list_ls->append_set([ 0 => $_->{name} ]) foreach @{$urpm->{media}};
    $media_list->get_selection->signal_connect(changed => sub {
        my ($model, $iter) = $_[0]->get_selected;
        $model && $iter or return;
        $current_medium = $model->get($iter, 0);
        $current_medium_nb = $model->get_path($iter)->to_string;
        $keys_list_ls->clear;
        $keys_list_ls->append_set([ 0 => sprintf("%s (%s)", $_, $key_name->($_)), 1 => $_ ]) foreach @{$keys[$current_medium_nb]};
    });

    my $add_key = sub {
        my $available_keyz_ls = Gtk2::ListStore->new("Glib::String", "Glib::String");
        my $available_keyz = Gtk2::TreeView->new_with_model($available_keyz_ls);
        $available_keyz->append_column(Gtk2::TreeViewColumn->new_with_attributes(undef, Gtk2::CellRendererText->new, 'text' => 0));
        $available_keyz->set_headers_visible(0);
        $available_keyz->get_selection->set_mode('browse');
        $available_keyz_ls->append_set([ 0 => sprintf("%s (%s)", $_, $key_name->($_)), 1 => $_ ]) foreach keys %{$urpm->{keys}};
        my $key;
        add_callback_(N("Add a key"), N("Choose a key to add to the medium %s", $current_medium), $w, $available_keyz,
                      sub {
                          my ($model, $iter) = $available_keyz->get_selection->get_selected;
                          $model && $iter and $key = $model->get($iter, 1);
                      },
                      sub {
                          return if !defined $key;
                          $urpm->{media}[$current_medium_nb]{'key-ids'} = join(',', sort(uniq(@{$keys[$current_medium_nb]}, $key)));
                          $write->();
                      }
                  );


    };

    my $remove_key = sub {
        my ($model, $iter) = $keys_list->get_selection->get_selected;
        $model && $iter or return;
        my $key = $model->get($iter, 1);
	interactive_msg(N("Remove a key"),
                        N("Are you sure you want to remove the key %s from medium %s?\n(name of the key: %s)",
                          $key, $current_medium, $key_name->($key)),
                        yesno => 1,  transient => $w->{real_window}) or return;
        $urpm->{media}[$current_medium_nb]{'key-ids'} = join(',', difference2(\@{$keys[$current_medium_nb]}, [ $key ]));
        $write->();
    };

    gtkadd(
	$w->{window},
	gtkpack_(
	    gtknew('VBox', spacing => 5),
	    1, gtkpack_(
		gtknew('HBox', spacing => 10),
		1, create_scrolled_window($media_list),
		1, create_scrolled_window($keys_list),
		0, gtkpack__(
		    gtknew('VBox', spacing => 5),
		    gtksignal_connect(
			Gtk2::Button->new(but(N("Add"))),
			clicked => \&$add_key,
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but(N("Remove"))),
			clicked => \&$remove_key,
		    )
		)
	    ),
	    0, gtknew('HSeparator'),
	    0, gtkpack(
		gtknew('HButtonBox'),
		gtknew('Button', text => N("Ok"), clicked => sub { Gtk2->main_quit })
	    ),
	),
    );
    $w->main;
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
            N_("Unable to update medium, errors reported:\n\n%s"),
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
#         my $checkedIcon = File::ShareDir::dist_file('AdminPanel', 'images/Check_8x8.png');
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

sub mainwindow() {

    my $something_changed = 0;
    my $appTitle = yui::YUI::app()->applicationTitle();

    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle(N("Configure media"));
    ## set icon if not already set by external launcher TODO
    yui::YUI::app()->setApplicationIcon("/usr/share/mcc/themes/default/rpmdrake-mdk.png");

    my $mageiaPlugin = "mga";
    my $factory      = yui::YUI::widgetFactory;
    my $mgaFactory   = yui::YExternalWidgets::externalWidgetFactory($mageiaPlugin);
    $mgaFactory      = yui::YMGAWidgetFactory::getYMGAWidgetFactory($mgaFactory);

    my $dialog  = $factory->createMainDialog;
    my $vbox    = $factory->createVBox( $dialog );

    my $hbox_headbar = $factory->createHBox($vbox);
    my $head_align_left = $factory->createLeft($hbox_headbar);
    my $head_align_right = $factory->createRight($hbox_headbar);
    my $headbar = $factory->createHBox($head_align_left);
    my $headRight = $factory->createHBox($head_align_right);

    my %fileMenu = (
            widget => $factory->createMenuButton($headbar,N("File")),
            update => new yui::YMenuItem(N("Update")),
         add_media => new yui::YMenuItem(N("Add a specific media mirror")),
            custom => new yui::YMenuItem(N("Add a custom medium")),
            quit   => new yui::YMenuItem(N("&Close")),
    );

    my @ordered_menu_lines = qw(update add_media custom quit);
    foreach (@ordered_menu_lines) {
        $fileMenu{ widget }->addItem($fileMenu{ $_ });
    }
    $fileMenu{ widget }->rebuildMenuTree();

    my %optionsMenu = (
            widget => $factory->createMenuButton($headbar, N("Options")),
            global => new yui::YMenuItem(N("Global options")),
          man_keys => new yui::YMenuItem(N("Manage keys")),
          parallel => new yui::YMenuItem(N("Parallel")),
             proxy => new yui::YMenuItem(N("Proxy")),
    );
    @ordered_menu_lines = qw(global man_keys parallel proxy);
    foreach (@ordered_menu_lines) {
        $optionsMenu{ widget }->addItem($optionsMenu{ $_ });
    }
    $optionsMenu{ widget }->rebuildMenuTree();

    my %helpMenu = (
            widget     => $factory->createMenuButton($headRight, N("&Help")),
            help       => new yui::YMenuItem(N("Manual")),
            report_bug => new yui::YMenuItem(N("Report Bug")),
            about      => new yui::YMenuItem(N("&About")),
    );
    @ordered_menu_lines = qw(help report_bug about);
    foreach (@ordered_menu_lines) {
        $helpMenu{ widget }->addItem($helpMenu{ $_ });
    }
    $helpMenu{ widget }->rebuildMenuTree();

    my $hbox_content = $factory->createHBox($vbox);
    my $leftContent = $factory->createLeft($hbox_content);
    $leftContent->setWeight($yui::YD_HORIZ,3);

    my $frame   = $factory->createFrame ($leftContent, "");

    my $frmVbox = $factory->createVBox( $frame );
    my $hbox = $factory->createHBox( $frmVbox );

    my $yTableHeader = new yui::YTableHeader();
    $yTableHeader->addColumn(N("Enabled"), $yui::YAlignCenter);
    $yTableHeader->addColumn(N("Updates"),  $yui::YAlignCenter);
    $yTableHeader->addColumn(N("Type"), $yui::YAlignBegin);
    $yTableHeader->addColumn(N("Medium"), $yui::YAlignBegin);

    ## mirror list
    # NOTE let's use YTable and not YCBTable atm
#     my $mirrorTbl = $mgaFactory->createCBTable($hbox, $yTableHeader, $yui::YCBTableCheckBoxOnFirstColumn);
#     $mirrorTbl->setKeepSorting(1);
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
    my $remButton = $factory->createPushButton($factory->createHBox($vbox_commands), N("Remove"));
    my $edtButton = $factory->createPushButton($factory->createHBox($vbox_commands), N("Edit"));
    my $addButton = $factory->createPushButton($factory->createHBox($vbox_commands), N("Add"));
    $hbox = $factory->createHBox( $vbox_commands );
    ## TODO icon and label for ncurses
    my $upIcon     = File::ShareDir::dist_file('AdminPanel', 'images/Up_16x16.png');
    my $downIcon   = File::ShareDir::dist_file('AdminPanel', 'images/Down_16x16.png');
    my $upButton   = $factory->createPushButton($factory->createHBox($hbox), N("Up"));
    my $downButton = $factory->createPushButton($factory->createHBox($hbox), N("Down"));
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


    my $helpButton = $factory->createPushButton($hbox, N("Help") );
    $align = $factory->createRight($hbox);
    $hbox     = $factory->createHBox($align);

    ### Service Refresh button ($refreshButton)
    my $closeButton = $factory->createPushButton($hbox, N("Ok") );
    while(1) {
        my $event       = $dialog->waitForEvent();
        my $eventType   = $event->eventType();

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
                my $translators = N("_: Translator(s) name(s) & email(s)\n");
                $translators =~ s/\</\&lt\;/g;
                $translators =~ s/\>/\&gt\;/g;
                my $sh_gui = AdminPanel::Shared::GUI->new();
                $sh_gui->AboutDialog({ name => "Rpmdragora",
                                             version => "TODO",
                         credits => N("Copyright (C) %s Mageia community", '2013-2014'),
                         license => N("GPLv2"),
                         description => N("Rpmdragora is the Mageia package management tool."),
                         authors => N("<h3>Developers</h3>
                                                    <ul><li>%s</li>
                                                           <li>%s</li>
                                                       </ul>
                                                       <h3>Translators</h3>
                                                       <ul><li>%s</li></ul>",
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
                $dialog->startMultipleChanges();

                my $row = upwards_callback($mirrorTbl);

                $mirrorTbl->deleteAllItems();
                my $itemCollection = readMedia();
                selectRow($itemCollection, $row);
                $mirrorTbl->addItems($itemCollection);

                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::app()->normalCursor();
            }
            elsif ($widget == $downButton) {
                yui::YUI::app()->busyCursor();
                $dialog->startMultipleChanges();

                my $row = downwards_callback($mirrorTbl);

                $mirrorTbl->deleteAllItems();
                my $itemCollection = readMedia();
                selectRow($itemCollection, $row);
                $mirrorTbl->addItems($itemCollection);

                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::app()->normalCursor();
            }
            elsif ($widget == $edtButton) {
                edit_callback($mirrorTbl);
#                 my $sel = $mirrorTbl->selectedItem();
#                 print " ITEM #" . $sel->index() . " -> " .$sel->label() . "\n" if $sel;
            }
            elsif ($widget == $remButton) {
                yui::YUI::app()->busyCursor();
                $dialog->startMultipleChanges();

                my $sel = $mirrorTbl->selectedItems();
                remove_callback($sel);
                $mirrorTbl->deleteAllItems();
                my $itemCollection = readMedia();
                $mirrorTbl->addItems($itemCollection);

                $dialog->recalcLayout();
                $dialog->doneMultipleChanges();
                yui::YUI::app()->normalCursor();

            }
            elsif ($widget == $mirrorTbl) {
                my $sel = $mirrorTbl->selectedItems();
                if ($sel->size() > 1 ) {
                    $edtButton->setEnabled(0);
                    $upButton->setEnabled(0);
                    $downButton->setEnabled(0);
                }
                else {
                    $edtButton->setEnabled(1);
                    $upButton->setEnabled(1);
                    $downButton->setEnabled(1);
                }
            }
        }
    }
    $dialog->destroy();

    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle) if $appTitle;

    return $something_changed;
}


sub OLD_mainwindow() {
    undef $something_changed;
    $mainw = ugtk2->new(N("Configure media"), center => 1, transient => $::main_window, modal => 1);
    local $::main_window = $mainw->{real_window};

    my $reread_media;

    my ($menu, $_factory) = create_factory_menu(
	$mainw->{real_window},
	[ N("/_File"), undef, undef, undef, '<Branch>' ],
	[ N("/_File") . N("/_Update"), N("<control>U"), sub { update_callback() and $reread_media->() }, undef, '<Item>', ],
        [ N("/_File") . N("/Add a specific _media mirror"), N("<control>M"), sub { easy_add_callback_with_mirror() and $reread_media->() }, undef, '<Item>' ],
        [ N("/_File") . N("/_Add a custom medium"), N("<control>A"), sub { add_callback() and $reread_media->() }, undef, '<Item>' ],
	[ N("/_File") . N("/Close"), N("<control>W"), sub { Gtk2->main_quit }, undef, '<Item>', ],
     [ N("/_Options"), undef, undef, undef, '<Branch>' ],
     [ N("/_Options") . N("/_Global options"), N("<control>G"), \&options_callback, undef, '<Item>' ],
     [ N("/_Options") . N("/Manage _keys"), N("<control>K"), \&keys_callback, undef, '<Item>' ],
     [ N("/_Options") . N("/_Parallel"), N("<control>P"), \&parallel_callback, undef, '<Item>' ],
     [ N("/_Options") . N("/P_roxy"), N("<control>R"), \&proxy_callback, undef, '<Item>' ],
     if_($0 =~ /edit-urpm-sources/,
         [ N("/_Help"), undef, undef, undef, '<Branch>' ],
         [ N("/_Help") . N("/_Report Bug"), undef, sub { run_drakbug('edit-urpm-sources.pl') }, undef, '<Item>' ],
         [ N("/_Help") . N("/_Help"), undef, sub { rpmdragora::open_help('sources') }, undef, '<Item>' ],
         [ N("/_Help") . N("/_About..."), undef, sub {
               my $license = formatAlaTeX(translate($::license));
               $license =~ s/\n/\n\n/sg; # nicer formatting
               my $w = gtknew('AboutDialog', name => N("Rpmdragora"),
                              version => $rpmdragora::distro_version,
                              copyright => N("Copyright (C) %s by Mandriva", '2002-2008'),
                              license => $license, wrap_license => 1,
                              comments => N("Rpmdragora is the Mageia package management tool."),
                              website => 'http://www.mageia.org/',
                              website_label => N("Mageia"),
                              authors => 'Thierry Vignaud <vignaud@mandriva.com>',
                              artists => 'Hélène Durosini <ln@mandriva.com>',
                              translator_credits =>
                                #-PO: put here name(s) and email(s) of translator(s) (eg: "John Smith <jsmith@nowhere.com>")
                                N("_: Translator(s) name(s) & email(s)\n"),
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

    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes(N("Enabled"),
                                                                      my $tr = Gtk2::CellRendererToggle->new,
                                                                      'active' => $col{mainw}{is_enabled}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes(N("Updates"),
                                                                      my $cu = Gtk2::CellRendererToggle->new,
                                                                      'active' => $col{mainw}{is_update},
                                                                      activatable => $col{mainw}{activatable}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes(N("Type"),
                                                                      Gtk2::CellRendererText->new,
                                                                      'text' => $col{mainw}{type}));
    $list_tv->append_column(Gtk2::TreeViewColumn->new_with_attributes(N("Medium"),
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
		    N("This medium needs to be updated to be usable. Update it now?"),
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
		N_("Unable to update medium, errors reported:\n\n%s"),
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
	    ($0 =~ /rpm-edit-media|edit-urpm-sources/ ? (0, Gtk2::Banner->new($ugtk2::wm_icon, N("Configure media"))) : ()),
	    1, gtkpack_(
		gtknew('HBox', spacing => 10),
		1, gtknew('ScrolledWindow', child => $list_tv),
		0, gtkpack__(
		    gtknew('VBox', spacing => 5),
		    gtksignal_connect(
			$remove_button = Gtk2::Button->new(but(N("Remove"))),
			clicked => sub { remove_callback() and $reread_media->() },
		    ),
		    gtksignal_connect(
			$edit_button = Gtk2::Button->new(but(N("Edit"))),
			clicked => sub {
			    my $name = edit_callback(); defined $name and $reread_media->($name);
			}
		    ),
		    gtksignal_connect(
			Gtk2::Button->new(but(N("Add"))),
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
		gtksignal_connect(Gtk2::Button->new(but(N("Help"))), clicked => sub { rpmdragora::open_help('sources') }),
		gtksignal_connect(Gtk2::Button->new(but(N("Ok"))), clicked => sub { Gtk2->main_quit })
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
                            N("The Package Database is locked. Please close other applications
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


1;
