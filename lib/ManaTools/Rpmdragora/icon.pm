# vim: set et ts=4 sw=4:
package ManaTools::Rpmdragora::icon;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
#  Copyright (c) 2013-2017 Matteo Pasotti <matteo.pasotti@gmail.com>
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
# $Id: icon.pm 237459 2008-02-26 14:20:47Z tv $

use strict;

use ManaTools::rpmdragora;
use ManaTools::Shared::Locales;

my $loc = ManaTools::rpmdragora::locale();

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_icon_path);
#- /usr/share/rpmlint/config (duplicates are normal, so that we are not too far away from .py)
my %group_icons = (
	$loc->N("All") => 'system_section',
	$loc->N("Accessibility") => 'accessibility_section',
	$loc->N("Archiving") => 'archiving_section',
	join('|', $loc->N("Archiving"), $loc->N("Backup")) => 'backup_section',
	join('|', $loc->N("Archiving"), $loc->N("Cd burning")) => 'cd_burning_section',
	join('|', $loc->N("Archiving"), $loc->N("Compression")) => 'compression_section',
	join('|', $loc->N("Archiving"), $loc->N("Other")) => 'other_archiving',
	$loc->N("Communications") => 'communications_section',
	join('|', $loc->N("Communications"), $loc->N("Bluetooth")) => 'communications_bluetooth_section',
	join('|', $loc->N("Communications"), $loc->N("Dial-Up")) => 'communications_dialup_section',
	join('|', $loc->N("Communications"), $loc->N("Fax")) => 'communications_fax_section',
	join('|', $loc->N("Communications"), $loc->N("Mobile")) => 'communications_mobile_section',
	join('|', $loc->N("Communications"), $loc->N("Radio")) => 'communications_radio_section',
	join('|', $loc->N("Communications"), $loc->N("Serial")) => 'communications_serial_section',
	join('|', $loc->N("Communications"), $loc->N("Telephony")) => 'communications_phone_section',
	$loc->N("Databases") => 'databases_section',
	$loc->N("Development") => 'development_section',
	join('|', $loc->N("Development"), $loc->N("Basic")) => '',
	join('|', $loc->N("Development"), $loc->N("C")) => '',
	join('|', $loc->N("Development"), $loc->N("C++")) => '',
	join('|', $loc->N("Development"), $loc->N("C#")) => '',
	join('|', $loc->N("Development"), $loc->N("Databases")) => 'databases_section',
	join('|', $loc->N("Development"), $loc->N("Debug")) => '',
	join('|', $loc->N("Development"), $loc->N("Erlang")) => '',
	join('|', $loc->N("Development"), $loc->N("GNOME and GTK+")) => 'gnome_section',
	join('|', $loc->N("Development"), $loc->N("Java")) => '',
	join('|', $loc->N("Development"), $loc->N("KDE and Qt")) => 'kde_section',
	join('|', $loc->N("Development"), $loc->N("Kernel")) => '',
	join('|', $loc->N("Development"), $loc->N("OCaml")) => '',
	join('|', $loc->N("Development"), $loc->N("Other")) => '',
	join('|', $loc->N("Development"), $loc->N("Perl")) => '',
	join('|', $loc->N("Development"), $loc->N("PHP")) => '',
	join('|', $loc->N("Development"), $loc->N("Python")) => '',
	join('|', $loc->N("Development"), $loc->N("Tools")) => 'development_tools_section',
	join('|', $loc->N("Development"), $loc->N("X11")) => '',
	$loc->N("Documentation") => 'documentation_section',
	$loc->N("Editors") => 'editors_section',
	$loc->N("Education") => 'education_section',
	$loc->N("Emulators") => 'emulators_section',
	$loc->N("File tools") => 'file_tools_section',
	$loc->N("Games") => 'amusement_section',
	join('|', $loc->N("Games"), $loc->N("Adventure")) => 'adventure_section',
	join('|', $loc->N("Games"), $loc->N("Arcade")) => 'arcade_section',
	join('|', $loc->N("Games"), $loc->N("Boards")) => 'boards_section',
	join('|', $loc->N("Games"), $loc->N("Cards")) => 'cards_section',
	join('|', $loc->N("Games"), $loc->N("Other")) => 'other_amusement',
	join('|', $loc->N("Games"), $loc->N("Puzzles")) => 'puzzle_section',
	join('|', $loc->N("Games"), $loc->N("Shooter")) => 'shooter_section',
	join('|', $loc->N("Games"), $loc->N("Simulation")) => 'simulation_section',
	join('|', $loc->N("Games"), $loc->N("Sports")) => 'sport_section',
	join('|', $loc->N("Games"), $loc->N("Strategy")) => 'strategy_section',
	$loc->N("Geography") => 'geography_section',
	$loc->N("Graphical desktop") => 'graphical_desktop_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("Enlightenment")) => 'enlightment_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("GNOME")) => 'gnome_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("Icewm")) => 'icewm_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("KDE")) => 'kde_section',
	join('|', $loc->N("Graphical desktop"), $loc->N("Other")) => 'more_applications_other_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("WindowMaker")) => 'windowmaker_section',
	join('|', $loc->N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("Xfce")) => 'xfce_section',
	$loc->N("Graphics") => 'graphics_section',
	join('|', $loc->N("Graphics"), $loc->N("3D")) => 'graphics_3d_section',
	join('|', $loc->N("Graphics"), $loc->N("Editors and Converters")) => 'graphics_editors_section',
	join('|', $loc->N("Graphics"), $loc->N("Utilities")) => 'graphics_utilities_section',
	join('|', $loc->N("Graphics"), $loc->N("Photography")) => 'graphics_photography_section',
	join('|', $loc->N("Graphics"), $loc->N("Scanning")) => 'graphics_scanning_section',
	join('|', $loc->N("Graphics"), $loc->N("Viewers")) => 'graphics_viewers_section',
	$loc->N("Monitoring") => 'monitoring_section',
	$loc->N("Networking") => 'networking_section',
	join('|', $loc->N("Networking"), $loc->N("File transfer")) => 'file_transfer_section',
	join('|', $loc->N("Networking"), $loc->N("IRC")) => 'irc_section',
	join('|', $loc->N("Networking"), $loc->N("Instant messaging")) => 'instant_messaging_section',
	join('|', $loc->N("Networking"), $loc->N("Mail")) => 'mail_section',
	join('|', $loc->N("Networking"), $loc->N("News")) => 'news_section',
	join('|', $loc->N("Networking"), $loc->N("Other")) => 'other_networking',
	join('|', $loc->N("Networking"), $loc->N("Remote access")) => 'remote_access_section',
	join('|', $loc->N("Networking"), $loc->N("WWW")) => 'networking_www_section',
	$loc->N("Office") => 'office_section',
	join('|', $loc->N("Office"), $loc->N("Dictionary")) => 'office_dictionary_section',
	join('|', $loc->N("Office"), $loc->N("Finance")) => 'finances_section',
	join('|', $loc->N("Office"), $loc->N("Management")) => 'timemanagement_section',
	join('|', $loc->N("Office"), $loc->N("Organizer")) => 'timemanagement_section',
	join('|', $loc->N("Office"), $loc->N("Utilities")) => 'office_accessories_section',
	join('|', $loc->N("Office"), $loc->N("Spreadsheet")) => 'spreadsheet_section',
	join('|', $loc->N("Office"), $loc->N("Suite")) => 'office_suite',
	join('|', $loc->N("Office"), $loc->N("Word processor")) => 'wordprocessor_section',
	$loc->N("Publishing") => 'publishing_section',
	$loc->N("Sciences") => 'sciences_section',
	join('|', $loc->N("Sciences"), $loc->N("Astronomy")) => 'astronomy_section',
	join('|', $loc->N("Sciences"), $loc->N("Biology")) => 'biology_section',
	join('|', $loc->N("Sciences"), $loc->N("Chemistry")) => 'chemistry_section',
	join('|', $loc->N("Sciences"), $loc->N("Computer science")) => 'computer_science_section',
	join('|', $loc->N("Sciences"), $loc->N("Geosciences")) => 'geosciences_section',
	join('|', $loc->N("Sciences"), $loc->N("Mathematics")) => 'mathematics_section',
	join('|', $loc->N("Sciences"), $loc->N("Other")) => 'other_sciences',
	join('|', $loc->N("Sciences"), $loc->N("Physics")) => 'physics_section',
	$loc->N("Security") => 'security_section',
	$loc->N("Shells") => 'shells_section',
	$loc->N("Sound") => 'sound_section',
	join('|', $loc->N("Sound"), $loc->N("Editors and Converters")) => 'sound_editors_section',
	join('|', $loc->N("Sound"), $loc->N("Midi")) => 'sound_midi_section',
	join('|', $loc->N("Sound"), $loc->N("Mixers")) => 'sound_mixers_section',
	join('|', $loc->N("Sound"), $loc->N("Players")) => 'sound_players_section',
	join('|', $loc->N("Sound"), $loc->N("Utilities")) => 'sound_utilities_section',
	$loc->N("System") => 'system_section',
	join('|', $loc->N("System"), $loc->N("Base")) => 'system_section',
	join('|', $loc->N("System"), $loc->N("Boot and Init")) => 'boot_init_section',
	join('|', $loc->N("System"), $loc->N("Cluster")) => 'parallel_computing_section',
	join('|', $loc->N("System"), $loc->N("Configuration")) => 'configuration_section',
	join('|', $loc->N("System"), $loc->N("Fonts")) => 'chinese_section',
	join('|', $loc->N("System"), $loc->N("Fonts"), $loc->N("True type")) => '',
	join('|', $loc->N("System"), $loc->N("Fonts"), $loc->N("Type1")) => '',
	join('|', $loc->N("System"), $loc->N("Fonts"), $loc->N("X11 bitmap")) => '',
	join('|', $loc->N("System"), $loc->N("Internationalization")) => 'chinese_section',
	join('|', $loc->N("System"), $loc->N("Kernel and hardware")) => 'hardware_configuration_section',
	join('|', $loc->N("System"), $loc->N("Libraries")) => 'system_section',
	join('|', $loc->N("System"), $loc->N("Networking")) => 'networking_configuration_section',
	join('|', $loc->N("System"), $loc->N("Packaging")) => 'packaging_section',
	join('|', $loc->N("System"), $loc->N("Printing")) => 'printing_section',
	join('|', $loc->N("System"), $loc->N("Servers")) => 'servers_section',
	join('|', $loc->N("System"),
          #-PO: This is a package/product name. Only translate it if needed:
          $loc->N("X11")) => 'x11_section',
	$loc->N("Terminals") => 'terminals_section',
	$loc->N("Text tools") => 'text_tools_section',
	$loc->N("Toys") => 'toys_section',
	$loc->N("Video") => 'video_section',
	join('|', $loc->N("Video"), $loc->N("Editors and Converters")) => 'video_editors_section',
	join('|', $loc->N("Video"), $loc->N("Players")) => 'video_players_section',
	join('|', $loc->N("Video"), $loc->N("Television")) => 'video_television_section',
	join('|', $loc->N("Video"), $loc->N("Utilities")) => 'video_utilities_section',

     # for Mageia Choice:
	$loc->N("Workstation") => 'system_section',
	join('|', $loc->N("Workstation"), $loc->N("Configuration")) => 'configuration_section',
	join('|', $loc->N("Workstation"), $loc->N("Console Tools")) => 'interpreters_section',
	join('|', $loc->N("Workstation"), $loc->N("Documentation")) => 'documentation_section',
	join('|', $loc->N("Workstation"), $loc->N("Game station")) => 'amusement_section',
	join('|', $loc->N("Workstation"), $loc->N("Internet station")) => 'networking_section',
	join('|', $loc->N("Workstation"), $loc->N("Multimedia station")) => 'multimedia_section',
	join('|', $loc->N("Workstation"), $loc->N("Network Computer (client)")) => 'other_networking',
	join('|', $loc->N("Workstation"), $loc->N("Office Workstation")) => 'office_section',
	join('|', $loc->N("Workstation"), $loc->N("Scientific Workstation")) => 'sciences_section',
	$loc->N("Graphical Environment") => 'graphical_desktop_section',

	join('|', $loc->N("Graphical Environment"), $loc->N("GNOME Workstation")) => 'gnome_section',
	join('|', $loc->N("Graphical Environment"), $loc->N("IceWm Desktop")) => 'icewm_section',
	join('|', $loc->N("Graphical Environment"), $loc->N("KDE Workstation")) => 'kde_section',
	join('|', $loc->N("Graphical Environment"), $loc->N("Other Graphical Desktops")) => 'more_applications_other_section',
	$loc->N("Development") => 'development_section',
	join('|', $loc->N("Development"), $loc->N("Development")) => 'development_section',
	join('|', $loc->N("Development"), $loc->N("Documentation")) => 'documentation_section',
	$loc->N("Server") => 'servers_section',
	join('|', $loc->N("Server"), $loc->N("DNS/NIS")) => 'networking_section',
	join('|', $loc->N("Server"), $loc->N("Database")) => 'databases_section',
	join('|', $loc->N("Server"), $loc->N("Firewall/Router")) => 'networking_section',
	join('|', $loc->N("Server"), $loc->N("Mail")) => 'mail_section',
	join('|', $loc->N("Server"), $loc->N("Mail/Groupware/News")) => 'mail_section',
	join('|', $loc->N("Server"), $loc->N("Network Computer server")) => 'networking_section',
	join('|', $loc->N("Server"), $loc->N("Web/FTP")) => 'networking_www_section',

    );

sub get_icon_path {
    my ($group, $parent) = @_;

    my $path = $parent ? '/usr/share/icons/mini/' : '/usr/share/icons/';
    my $icon_path = "";
    if(defined($group_icons{$group})){
        $icon_path = join('', $path, $group_icons{$group}, '.png');
    }elsif(defined($group_icons{$parent."\|".$group})){
        $icon_path = join('', $path, $group_icons{$parent."\|".$group}, '.png');
    }else{
        $icon_path = join('', $path, 'applications_section', '.png');
    }
    unless(-e $icon_path){
        $icon_path = join('', $path, 'applications_section', '.png');
    }
    return $icon_path;
}

1;
