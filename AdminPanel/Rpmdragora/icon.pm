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
use common;


our @EXPORT = qw(get_icon);
#- /usr/share/rpmlint/config (duplicates are normal, so that we are not too far away from .py)
my %group_icons = (
	N_("All") => 'system_section',
	N_("Accessibility") => 'accessibility_section',
	N_("Archiving") => 'archiving_section',
	join('|', N_("Archiving"), N_("Backup")) => 'backup_section',
	join('|', N_("Archiving"), N_("Cd burning")) => 'cd_burning_section',
	join('|', N_("Archiving"), N_("Compression")) => 'compression_section',
	join('|', N_("Archiving"), N_("Other")) => 'other_archiving',
	N_("Communications") => 'communications_section',
	join('|', N_("Communications"), N_("Bluetooth")) => 'communications_section',
	join('|', N_("Communications"), N_("Bluetooth")) => 'communications_section',
	join('|', N_("Communications"), N_("Dial-Up")) => 'communications_section',
	join('|', N_("Communications"), N_("Fax")) => 'communications_section',
	join('|', N_("Communications"), N_("Mobile")) => 'communications_section',
	join('|', N_("Communications"), N_("Radio")) => 'communications_section',
	join('|', N_("Communications"), N_("Serial")) => 'communications_section',
	join('|', N_("Communications"), N_("Telephony")) => 'communications_section',
	N_("Databases") => 'databases_section',
	N_("Development") => 'development_section',
	join('|', N_("Development"), N_("Basic")) => '',
	join('|', N_("Development"), N_("C")) => '',
	join('|', N_("Development"), N_("C++")) => '',
	join('|', N_("Development"), N_("C#")) => '',
	join('|', N_("Development"), N_("Databases")) => 'databases_section',
	join('|', N_("Development"), N_("Erlang")) => '',
	join('|', N_("Development"), N_("GNOME and GTK+")) => 'gnome_section',
	join('|', N_("Development"), N_("Java")) => '',
	join('|', N_("Development"), N_("KDE and Qt")) => 'kde_section',
	join('|', N_("Development"), N_("Kernel")) => 'hardware_configuration_section',
	join('|', N_("Development"), N_("OCaml")) => '',
	join('|', N_("Development"), N_("Other")) => 'development_tools_section',
	join('|', N_("Development"), N_("Perl")) => '',
	join('|', N_("Development"), N_("PHP")) => '',
	join('|', N_("Development"), N_("Python")) => '',
	join('|', N_("Development"), N_("Tools")) => '',
	join('|', N_("Development"), N_("X11")) => 'office_section',
	N_("Documentation") => 'documentation_section',
	N_("Editors") => 'emulators_section',
	N_("Education") => 'education_section',
	N_("Emulators") => 'emulators_section',
	N_("File tools") => 'file_tools_section',
	N_("Games") => 'amusement_section',
	join('|', N_("Games"), N_("Adventure")) => 'adventure_section',
	join('|', N_("Games"), N_("Arcade")) => 'arcade_section',
	join('|', N_("Games"), N_("Boards")) => 'boards_section',
	join('|', N_("Games"), N_("Cards")) => 'cards_section',
	join('|', N_("Games"), N_("Other")) => 'other_amusement',
	join('|', N_("Games"), N_("Puzzles")) => 'puzzle_section',
	join('|', N_("Games"), N_("Shooter")) => 'other_amusement',
	join('|', N_("Games"), N_("Sports")) => 'sport_section',
	join('|', N_("Games"), N_("Strategy")) => 'strategy_section',
	N_("Geography") => 'geosciences_section',
	N_("Graphical desktop") => 'office_section',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("Enlightenment")) => '',
	join('|', N_("Graphical desktop"), N_("FVWM based")) => '',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("GNOME")) => 'gnome_section',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("Icewm")) => '',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("KDE")) => 'kde_section',
	join('|', N_("Graphical desktop"), N_("Other")) => 'more_applications_other_section',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("Sawfish")) => '',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("WindowMaker")) => '',
	join('|', N_("Graphical desktop"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("Xfce")) => '',
	N_("Graphics") => 'graphics_section',
	join('|', N_("Graphics"), N_("3D")) => '',
	join('|', N_("Graphics"), N_("Editors")) => '',
	join('|', N_("Graphics"), N_("Other")) => '',
	join('|', N_("Graphics"), N_("Photography")) => '',
	join('|', N_("Graphics"), N_("Scanning")) => '',
	join('|', N_("Graphics"), N_("Viewers")) => '',
	N_("Monitoring") => 'monitoring_section',
	N_("Multimedia") => 'multimedia_section',
	join('|', N_("Multimedia"), N_("Video")) => 'video_section',
	N_("Networking") => 'networking_section',
	join('|', N_("Networking"), N_("Chat")) => 'chat_section',
	join('|', N_("Networking"), N_("File transfer")) => 'file_transfer_section',
	join('|', N_("Networking"), N_("IRC")) => 'irc_section',
	join('|', N_("Networking"), N_("Instant messaging")) => 'instant_messaging_section',
	join('|', N_("Networking"), N_("Mail")) => 'mail_section',
	join('|', N_("Networking"), N_("News")) => 'news_section',
	join('|', N_("Networking"), N_("Other")) => 'other_networking',
	join('|', N_("Networking"), N_("Remote access")) => 'remote_access_section',
	join('|', N_("Networking"), N_("WWW")) => 'networking_www_section',
	N_("Office") => 'office_section',
	join('|', N_("Office"), N_("Dictionary")) => '',
	join('|', N_("Office"), N_("Finance")) => '',
	join('|', N_("Office"), N_("Management")) => '',
	join('|', N_("Office"), N_("Organizer")) => '',
	join('|', N_("Office"), N_("Other")) => '',
	join('|', N_("Office"), N_("Spreadsheet")) => '',
	join('|', N_("Office"), N_("Suite")) => '',
	join('|', N_("Office"), N_("Word processor")) => '',
	N_("Public Keys") => 'packaging_section',
	N_("Publishing") => 'publishing_section',
	N_("Security") => 'packaging_section',
	N_("Sciences") => 'sciences_section',
	join('|', N_("Sciences"), N_("Astronomy")) => 'astronomy_section',
	join('|', N_("Sciences"), N_("Biology")) => 'biology_section',
	join('|', N_("Sciences"), N_("Chemistry")) => 'chemistry_section',
	join('|', N_("Sciences"), N_("Computer science")) => 'computer_science_section',
	join('|', N_("Sciences"), N_("Geosciences")) => 'geosciences_section',
	join('|', N_("Sciences"), N_("Mathematics")) => 'mathematics_section',
	join('|', N_("Sciences"), N_("Other")) => 'other_sciences',
	join('|', N_("Sciences"), N_("Physics")) => 'physics_section',
	N_("Shells") => 'shells_section',
	N_("Sound") => 'sound_section',
	join('|', N_("Sound"), N_("Editors and Converters")) => '',
	join('|', N_("Sound"), N_("Midi")) => '',
	join('|', N_("Sound"), N_("Mixers")) => '',
	join('|', N_("Sound"), N_("Players")) => '',
	join('|', N_("Sound"), N_("Utilities")) => '',
	join('|', N_("Sound"), N_("Visualization")) => '',
	N_("System") => 'system_section',
	join('|', N_("System"), N_("Base")) => 'system_section',
	join('|', N_("System"), N_("Cluster")) => 'parallel_computing_section',
	join('|', N_("System"), N_("Configuration")) => 'configuration_section',
	join('|', N_("System"), N_("Configuration"), N_("Boot and Init")) => 'boot_init_section',
	join('|', N_("System"), N_("Configuration"), N_("Hardware")) => 'hardware_configuration_section',
	join('|', N_("System"), N_("Configuration"), N_("Networking")) => 'networking_configuration_section',
	join('|', N_("System"), N_("Configuration"), N_("Other")) => 'system_other_section',
	join('|', N_("System"), N_("Configuration"), N_("Packaging")) => 'packaging_section',
	join('|', N_("System"), N_("Configuration"), N_("Printing")) => 'printing_section',
	join('|', N_("System"), N_("Fonts")) => 'chinese_section',
	join('|', N_("System"), N_("Fonts"), N_("Console")) => 'interpreters_section',
	join('|', N_("System"), N_("Fonts"), N_("True type")) => '',
	join('|', N_("System"), N_("Fonts"), N_("Type1")) => '',
	join('|', N_("System"), N_("Fonts"), N_("X11 bitmap")) => '',
	join('|', N_("System"), N_("Internationalization")) => 'chinese_section',
	join('|', N_("System"), N_("Kernel and hardware")) => 'hardware_configuration_section',
	join('|', N_("System"), N_("Libraries")) => '',
	join('|', N_("System"), N_("Printing")) => 'printing_section',
	join('|', N_("System"), N_("Servers")) => '',
	join('|', N_("System"),
          #-PO: This is a package/product name. Only translate it if needed:
          N_("X11")) => 'office_section',
	N_("Terminals") => 'terminals_section',
	N_("Text tools") => 'text_tools_section',
	N_("Toys") => 'toys_section',
	N_("Video") => 'video_section',
	join('|', N_("Video"), N_("Editors and Converters")) => '',
	join('|', N_("Video"), N_("Players")) => '',
	join('|', N_("Video"), N_("Utilities")) => '',

     # for Mageia Choice:
	N_("Workstation") => 'office_section',
	join('|', N_("Workstation"), N_("Configuration")) => 'configuration_section',
	join('|', N_("Workstation"), N_("Console Tools")) => 'interpreters_section',
	join('|', N_("Workstation"), N_("Documentation")) => 'documentation_section',
	join('|', N_("Workstation"), N_("Game station")) => 'amusement_section',
	join('|', N_("Workstation"), N_("Internet station")) => 'networking_section',
	join('|', N_("Workstation"), N_("Multimedia station")) => 'multimedia_section',
	join('|', N_("Workstation"), N_("Network Computer (client)")) => 'other_networking',
	join('|', N_("Workstation"), N_("Office Workstation")) => 'office_section',
	join('|', N_("Workstation"), N_("Scientific Workstation")) => 'sciences_section',
	N_("Graphical Environment") => 'office_section',

	join('|', N_("Graphical Environment"), N_("GNOME Workstation")) => 'gnome_section',
	join('|', N_("Graphical Environment"), N_("IceWm Desktop")) => 'icewm',
	join('|', N_("Graphical Environment"), N_("KDE Workstation")) => 'kde_section',
	join('|', N_("Graphical Environment"), N_("Other Graphical Desktops")) => 'more_applications_other_section',
	N_("Development") => 'development_section',
	join('|', N_("Development"), N_("Development")) => 'development_section',
	join('|', N_("Development"), N_("Documentation")) => 'documentation_section',
	N_("Server") => 'archiving_section',
	join('|', N_("Server"), N_("DNS/NIS")) => 'networking_section',
	join('|', N_("Server"), N_("Database")) => 'databases_section',
	join('|', N_("Server"), N_("Firewall/Router")) => 'networking_section',
	join('|', N_("Server"), N_("Mail")) => 'mail_section',
	join('|', N_("Server"), N_("Mail/Groupware/News")) => 'mail_section',
	join('|', N_("Server"), N_("Network Computer server")) => 'networking_section',
	join('|', N_("Server"), N_("Web/FTP")) => 'networking_www_section',

    );

sub get_icon {
    my ($group, $o_parent) = @_;
    my $pixbuf;
    my $path = $group =~ /\|/ ? '/usr/share/icons/mini/' : '/usr/share/icons/';
    my $create_pixbuf = sub { eval { gtknew('Pixbuf', file => join('', $path, $_[0], '.png')) } };
    $pixbuf = $create_pixbuf->($group_icons{$group});
    $pixbuf ||= $create_pixbuf->($group_icons{$o_parent}) if $o_parent;
    $pixbuf ||= $create_pixbuf->('applications_section');
}

1;
