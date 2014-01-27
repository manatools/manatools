# vim: set et ts=4 sw=4:
package AdminPanel::Rpmdragora::icon;
#*****************************************************************************
#
#  Copyright (c) 2002 Guillaume Cottenceau
#  Copyright (c) 2002-2007 Thierry Vignaud <tvignaud@mandriva.com>
#  Copyright (c) 2003, 2004, 2005 MandrakeSoft SA
#  Copyright (c) 2005-2007 Mandriva SA
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
our @ISA = qw(Exporter);
use lib qw(/usr/lib/libDrakX);
use POSIX;
use common;

# TO WORKAROUND LOCALIZATION ISSUE
use AdminPanel::Rpmdragora::localization;

our @EXPORT = qw(get_icon_path);
#- /usr/share/rpmlint/config (duplicates are normal, so that we are not too far away from .py)
my %group_icons = (
	N("All") => 'system_section',
	N("Accessibility") => 'accessibility_section',
	N("Archiving") => 'archiving_section',
	join('|', N("Archiving"), N("Backup")) => 'backup_section',
	join('|', N("Archiving"), N("Cd burning")) => 'cd_burning_section',
	join('|', N("Archiving"), N("Compression")) => 'compression_section',
	join('|', N("Archiving"), N("Other")) => 'other_archiving',
	N("Communications") => 'communications_section',
	join('|', N("Communications"), N("Bluetooth")) => 'communications_bluetooth_section',
	join('|', N("Communications"), N("Dial-Up")) => 'communications_dialup_section',
	join('|', N("Communications"), N("Fax")) => 'communications_fax_section',
	join('|', N("Communications"), N("Mobile")) => 'communications_mobile_section',
	join('|', N("Communications"), N("Radio")) => 'communications_radio_section',
	join('|', N("Communications"), N("Serial")) => 'communications_serial_section',
	join('|', N("Communications"), N("Telephony")) => 'communications_phone_section',
	N("Databases") => 'databases_section',
	N("Development") => 'development_section',
	join('|', N("Development"), N("Basic")) => '',
	join('|', N("Development"), N("C")) => '',
	join('|', N("Development"), N("C++")) => '',
	join('|', N("Development"), N("C#")) => '',
	join('|', N("Development"), N("Databases")) => 'databases_section',
	join('|', N("Development"), N("Debug")) => '',
	join('|', N("Development"), N("Erlang")) => '',
	join('|', N("Development"), N("GNOME and GTK+")) => 'gnome_section',
	join('|', N("Development"), N("Java")) => '',
	join('|', N("Development"), N("KDE and Qt")) => 'kde_section',
	join('|', N("Development"), N("Kernel")) => '',
	join('|', N("Development"), N("OCaml")) => '',
	join('|', N("Development"), N("Other")) => '',
	join('|', N("Development"), N("Perl")) => '',
	join('|', N("Development"), N("PHP")) => '',
	join('|', N("Development"), N("Python")) => '',
	join('|', N("Development"), N("Tools")) => 'development_tools_section',
	join('|', N("Development"), N("X11")) => '',
	N("Documentation") => 'documentation_section',
	N("Editors") => 'editors_section',
	N("Education") => 'education_section',
	N("Emulators") => 'emulators_section',
	N("File tools") => 'file_tools_section',
	N("Games") => 'amusement_section',
	join('|', N("Games"), N("Adventure")) => 'adventure_section',
	join('|', N("Games"), N("Arcade")) => 'arcade_section',
	join('|', N("Games"), N("Boards")) => 'boards_section',
	join('|', N("Games"), N("Cards")) => 'cards_section',
	join('|', N("Games"), N("Other")) => 'other_amusement',
	join('|', N("Games"), N("Puzzles")) => 'puzzle_section',
	join('|', N("Games"), N("Shooter")) => 'shooter_section',
	join('|', N("Games"), N("Simulation")) => 'simulation_section',
	join('|', N("Games"), N("Sports")) => 'sport_section',
	join('|', N("Games"), N("Strategy")) => 'strategy_section',
	N("Geography") => 'geography_section',
	N("Graphical desktop") => 'graphical_desktop_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("Enlightenment")) => 'enlightment_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("GNOME")) => 'gnome_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("Icewm")) => 'icewm_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("KDE")) => 'kde_section',
	join('|', N("Graphical desktop"), N("Other")) => 'more_applications_other_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("WindowMaker")) => 'windowmaker_section',
	join('|', N("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("Xfce")) => 'xfce_section',
	N("Graphics") => 'graphics_section',
	join('|', N("Graphics"), N("3D")) => 'graphics_3d_section',
	join('|', N("Graphics"), N("Editors and Converters")) => 'graphics_editors_section',
	join('|', N("Graphics"), N("Utilities")) => 'graphics_utilities_section',
	join('|', N("Graphics"), N("Photography")) => 'graphics_photography_section',
	join('|', N("Graphics"), N("Scanning")) => 'graphics_scanning_section',
	join('|', N("Graphics"), N("Viewers")) => 'graphics_viewers_section',
	N("Monitoring") => 'monitoring_section',
	N("Networking") => 'networking_section',
	join('|', N("Networking"), N("File transfer")) => 'file_transfer_section',
	join('|', N("Networking"), N("IRC")) => 'irc_section',
	join('|', N("Networking"), N("Instant messaging")) => 'instant_messaging_section',
	join('|', N("Networking"), N("Mail")) => 'mail_section',
	join('|', N("Networking"), N("News")) => 'news_section',
	join('|', N("Networking"), N("Other")) => 'other_networking',
	join('|', N("Networking"), N("Remote access")) => 'remote_access_section',
	join('|', N("Networking"), N("WWW")) => 'networking_www_section',
	N("Office") => 'office_section',
	join('|', N("Office"), N("Dictionary")) => 'office_dictionary_section',
	join('|', N("Office"), N("Finance")) => 'finances_section',
	join('|', N("Office"), N("Management")) => 'timemanagement_section',
	join('|', N("Office"), N("Organizer")) => 'timemanagement_section',
	join('|', N("Office"), N("Utilities")) => 'office_accessories_section',
	join('|', N("Office"), N("Spreadsheet")) => 'spreadsheet_section',
	join('|', N("Office"), N("Suite")) => 'office_suite',
	join('|', N("Office"), N("Word processor")) => 'wordprocessor_section',
	N("Publishing") => 'publishing_section',
	N("Sciences") => 'sciences_section',
	join('|', N("Sciences"), N("Astronomy")) => 'astronomy_section',
	join('|', N("Sciences"), N("Biology")) => 'biology_section',
	join('|', N("Sciences"), N("Chemistry")) => 'chemistry_section',
	join('|', N("Sciences"), N("Computer science")) => 'computer_science_section',
	join('|', N("Sciences"), N("Geosciences")) => 'geosciences_section',
	join('|', N("Sciences"), N("Mathematics")) => 'mathematics_section',
	join('|', N("Sciences"), N("Other")) => 'other_sciences',
	join('|', N("Sciences"), N("Physics")) => 'physics_section',
	N("Security") => 'security_section',
	N("Shells") => 'shells_section',
	N("Sound") => 'sound_section',
	join('|', N("Sound"), N("Editors and Converters")) => 'sound_editors_section',
	join('|', N("Sound"), N("Midi")) => 'sound_midi_section',
	join('|', N("Sound"), N("Mixers")) => 'sound_mixers_section',
	join('|', N("Sound"), N("Players")) => 'sound_players_section',
	join('|', N("Sound"), N("Utilities")) => 'sound_utilities_section',
	N("System") => 'system_section',
	join('|', N("System"), N("Base")) => 'system_section',
	join('|', N("System"), N("Boot and Init")) => 'boot_init_section',
	join('|', N("System"), N("Cluster")) => 'parallel_computing_section',
	join('|', N("System"), N("Configuration")) => 'configuration_section',
	join('|', N("System"), N("Fonts")) => 'chinese_section',
	join('|', N("System"), N("Fonts"), N("True type")) => '',
	join('|', N("System"), N("Fonts"), N("Type1")) => '',
	join('|', N("System"), N("Fonts"), N("X11 bitmap")) => '',
	join('|', N("System"), N("Internationalization")) => 'chinese_section',
	join('|', N("System"), N("Kernel and hardware")) => 'hardware_configuration_section',
	join('|', N("System"), N("Libraries")) => 'system_section',
	join('|', N("System"), N("Networking")) => 'networking_configuration_section',
	join('|', N("System"), N("Packaging")) => 'packaging_section',
	join('|', N("System"), N("Printing")) => 'printing_section',
	join('|', N("System"), N("Servers")) => 'servers_section',
	join('|', N("System"),
          #-PO: This is a package/product name. Only translate it if needed:
          N("X11")) => 'x11_section',
	N("Terminals") => 'terminals_section',
	N("Text tools") => 'text_tools_section',
	N("Toys") => 'toys_section',
	N("Video") => 'video_section',
	join('|', N("Video"), N("Editors and Converters")) => 'video_editors_section',
	join('|', N("Video"), N("Players")) => 'video_players_section',
	join('|', N("Video"), N("Television")) => 'video_television_section',
	join('|', N("Video"), N("Utilities")) => 'video_utilities_section',

     # for Mageia Choice:
	N("Workstation") => 'system_section',
	join('|', N("Workstation"), N("Configuration")) => 'configuration_section',
	join('|', N("Workstation"), N("Console Tools")) => 'interpreters_section',
	join('|', N("Workstation"), N("Documentation")) => 'documentation_section',
	join('|', N("Workstation"), N("Game station")) => 'amusement_section',
	join('|', N("Workstation"), N("Internet station")) => 'networking_section',
	join('|', N("Workstation"), N("Multimedia station")) => 'multimedia_section',
	join('|', N("Workstation"), N("Network Computer (client)")) => 'other_networking',
	join('|', N("Workstation"), N("Office Workstation")) => 'office_section',
	join('|', N("Workstation"), N("Scientific Workstation")) => 'sciences_section',
	N("Graphical Environment") => 'graphical_desktop_section',

	join('|', N("Graphical Environment"), N("GNOME Workstation")) => 'gnome_section',
	join('|', N("Graphical Environment"), N("IceWm Desktop")) => 'icewm_section',
	join('|', N("Graphical Environment"), N("KDE Workstation")) => 'kde_section',
	join('|', N("Graphical Environment"), N("Other Graphical Desktops")) => 'more_applications_other_section',
	N("Development") => 'development_section',
	join('|', N("Development"), N("Development")) => 'development_section',
	join('|', N("Development"), N("Documentation")) => 'documentation_section',
	N("Server") => 'servers_section',
	join('|', N("Server"), N("DNS/NIS")) => 'networking_section',
	join('|', N("Server"), N("Database")) => 'databases_section',
	join('|', N("Server"), N("Firewall/Router")) => 'networking_section',
	join('|', N("Server"), N("Mail")) => 'mail_section',
	join('|', N("Server"), N("Mail/Groupware/News")) => 'mail_section',
	join('|', N("Server"), N("Network Computer server")) => 'networking_section',
	join('|', N("Server"), N("Web/FTP")) => 'networking_www_section',

    );

sub get_icon_path {
    my ($group, $parent) = @_;
    my $path;
    if(isdigit($parent) && $parent == 0){
        $path = '/usr/share/icons/';
    }else{
        $path = '/usr/share/icons/mini/';
    }
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
