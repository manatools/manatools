# vim: set et ts=4 sw=4:
package ManaTools::MainDisplay;
#============================================================= -*-perl-*-

=head1 NAME

ManaTools::MainDisplay - class for ManaTools main window

=head1 SYNOPSIS

    $mainDisplay = new ManaTools::MainDisplay();
    $mainDisplay->start();
    $mainDisplay->cleanup();

=head1 METHODS

=head1 DESCRIPTION

    ManaTools::MainDisplay implements the main window panel adding buttons
    reading the configuration for every categories and modules


=head1 SUPPORT

    You can find documentation for this module with the perldoc command:

    perldoc ManaTools::MainDisplay

=head1 AUTHOR

    Steven Tucker

=head1 COPYRIGHT and LICENSE

    Copyright (C) 2012-2016, Angelo Naselli.
    Copyright (C) 2012, Steven Tucker.

    ManaTools is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    ManaTools is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with ManaTools.  If not, see <http://www.gnu.org/licenses/>.

=head1 METHODS

=cut

use Moose;
extends qw( ManaTools::Module );

use I18N::LangTags::Detect;

use diagnostics;
use ManaTools::SettingsReader;
use ManaTools::ConfigReader;
use ManaTools::Category;
use ManaTools::Module;
use ManaTools::Shared;
use ManaTools::Shared::GUI;
use ManaTools::Shared::GUI::Dialog;
use ManaTools::Shared::GUI::ReplacePoint;
use ManaTools::Shared::Locales;

use File::ShareDir ':ALL';

use yui;
with 'ManaTools::LoggingRole';

has 'configDir' => (
    is      => 'ro',
    isa     => 'Str',
);

with 'ManaTools::ConfigDirRole';

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        configDir: configuration files directory
        name:    application name, logging identity,
                 configuration subdirectory

=head3 other attributes

    title:        window title got from configuration file,
                  default is name.
    categories:   ArrayRef[ManaTools::Category]
    settings:     HashRef containing settings file content
    currCategory: Selected category
    mainWin:      Main Dialog window
    factory:      yui::YUI::widgetFactory
    menus:        HashRef containing menu items
    leftPane:     left panel layout
    rightPane:    right panel layout
  rightPaneFrame: right frame (needed for category title)
    replacePoint: replace point where to set new layout on
                  category selection
  selectedModule: module to be returned when selected

=head3 DESCRIPTION

    This method instanziates the MainWindo object, and setups
    the startup GUI.

=cut

#=============================================================
has '+name' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'mpan',
);

has '+icon' => (
    is      => 'rw',
    isa     => 'Str',
    default => File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/mageia.png'),
);

has 'title'  => (
    is       => 'rw',
    isa      => 'Str',
    init_arg => undef,
    lazy     => 1,
    builder  => '_titleInitialize',
);

sub _titleInitialize {
    my $self = shift;

    return $self->name();
}

has 'settings' => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
    default  => sub {return {};},
);

has 'categories' => (
    is => 'rw',
    isa => 'ArrayRef[ManaTools::Category]',
    init_arg => undef,
    lazy => 1,
    default => sub {[];},
);

has 'currCategory' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Category]',
    init_arg => undef,
    default => undef,
);

has 'factory' => (
    is => 'ro',
    isa => 'Maybe[yui::YWidgetFactory]',
    lazy => 1,
    init_arg => undef,
    default => sub {
       return yui::YUI::widgetFactory;
    },
);

has 'mainWin' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::Dialog]',
    init_arg => undef,
    default => undef,
);

has 'menus' => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
    default => sub {
        {
            file => {},
            help => {},
        };
    },
);

has 'leftPane' => (
    is => 'rw',
    isa => 'Maybe[yui::YLayoutBox]',
    init_arg => undef,
    default => undef,
);

has 'rightPane' => (
    is => 'rw',
    isa => 'Maybe[yui::YLayoutBox]',
    init_arg => undef,
    default => undef,
);

has 'rightPaneFrame' => (
    is => 'rw',
    isa => 'Maybe[yui::YFrame]',
    init_arg => undef,
    default => undef,
);

has 'replacePoint' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Shared::GUI::ReplacePoint]',
    init_arg => undef,
    handles => ['addEvent', 'delEvent', 'getEvent', 'addWidget', 'delWidget', 'widget', 'addItem', 'delItem', 'item'],
    default => sub {
        return undef;
    }
);

has 'selectedModule' => (
    is => 'rw',
    isa => 'Maybe[ManaTools::Module]',
    init_arg => undef,
    default => undef,
);


#=============================================================

=head2 configName

=head3 INPUT

    $self: this object

=head3 OUTPUT

    name: application name

=head3 DESCRIPTION

    Returns the application name as configuration subdirectory.
    This method is required by ConfifDirRole

=cut

#=============================================================
sub configName {
    my $self = shift;

    return $self->name();
}

#=============================================================

=head2 identifier

=head3 INPUT

    $self: this object

=head3 OUTPUT

    name: application name

=head3 DESCRIPTION

    Returns the application name as logging identifier.
    This method is required by LoggingRole

=cut

#=============================================================
sub identifier {
    my $self = shift;

    return $self->name();
}


sub _showAboutDialog {
    my $self = shift;

    my $translators = $self->{loc}->N("_: Translator(s) name(s) & email(s)\n");
    $translators =~ s/\</\&lt\;/g;
    $translators =~ s/\>/\&gt\;/g;
    my $sh_gui = ManaTools::Shared::GUI->new();
    $sh_gui->AboutDialog({ name => $self->{name},
        version => $self->Version(),
        credits => $self->loc()->N("Copyright (C) %s Mageia community", '2013-2016'),
        license => $self->loc()->N("GPLv2"),
        description => $self->loc()->N("mpan is the ManaTools panel that collects all the utilities."),
        authors => $self->loc()->N("<h3>Developers</h3>
                                    <ul><li>%s</li>
                                        <li>%s</li>
                                    </ul>
                                    <h3>Translators</h3>
                                    <ul><li>%s</li></ul>",
                                    "Angelo Naselli &lt;anaselli\@linux.it&gt;",
                                    "Matteo Pasotti &lt;matteo.pasotti\@gmail.com&gt;",
                                    $translators
        ),

    });
}



## Begin the program event loop
=head2 start

    contains the main loop of the application
    where we can check for events

=cut

sub start {
    my $self = shift;

    $self->_setupGui();

    return $self->selectedModule();
}

#=============================================================

=head2 cleanup

=head3 INPUT

    $self:     this object

=head3 DESCRIPTION

    This method cleanup data for a further start.

=cut

#=============================================================
sub cleanup {
    my $self = shift;

    $self->mainWin(undef);
    $self->menus({
        file => {},
        help => {},
    });

    for (my $cat=0; $cat < scalar(@{$self->categories()}); $cat++ ) {
        my $catSel = @{$self->categories()}[$cat];
        $catSel->button(undef);
        $catSel->removeButtons();
    }
    $self->leftPane(undef);
    $self->rightPane(undef);
    $self->rightPaneFrame(undef);
    $self->replacePoint(undef);
}

#=============================================================

=head2 _setupGui

=head3 INPUT

    $self:     this object

=head3 DESCRIPTION

    This method load configuration and build the GUI layout.

=cut

#=============================================================
sub _setupGui {
    my $self = shift;

    $self->selectedModule(undef);

    # fill $self->settings from settings.conf
    $self->_loadSettings();

    $DB::single = 1;
    $self->title($self->settings()->{title});
    $self->icon($self->settings()->{icon}) if $self->settings()->{icon};

    my $dialog = ManaTools::Shared::GUI::Dialog->new(
        module => $self,
        dialogType => ManaTools::Shared::GUI::Dialog::mainDialog,
        title => $self->title(),
        icon => $self->icon,
        buttons => {
            ManaTools::Shared::GUI::Dialog::aboutButton => sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $self = $event->parentDialog()->module(); #this object

                $self->_showAboutDialog();
                return 1;
            },
            ManaTools::Shared::GUI::Dialog::closeButton => sub {return 0;},
        },
        layout => sub {
            my $self = shift;
            my $layoutstart = shift;
            my $ydialog = $self->dialog();
            my $module  = $self->module();
            my $info = $self->info();
            my $factory = $self->factory();
            my $optFactory = $self->optFactory();

            my $mainLayout = $factory->createVBox($layoutstart);
            my $menuLayout = $factory->createHBox($mainLayout);

            ## Menu File
            my $align = $factory->createAlignment($menuLayout, 1, 0);
            $module->menus()->{file} = {
                    widget => $factory->createMenuButton($align, $self->loc()->N("File")),
                    quit   => new yui::YMenuItem($self->loc()->N("&Quit")),
            };


            my @ordered_menu_lines = qw(quit);
            foreach (@ordered_menu_lines) {
                $module->menus()->{file}->{widget}->addItem($module->menus()->{file}->{ $_ });
            }
            $module->menus()->{file}->{ widget }->rebuildMenuTree();

            $align = $factory->createAlignment($menuLayout, 2, 0);
            $module->menus()->{help} = {
                    widget => $factory->createMenuButton($align, $self->loc()->N("Help")),
                    help   => new yui::YMenuItem($self->loc()->N("Help")),
                    about  => new yui::YMenuItem($self->loc()->N("&About")),
            };

            ## Menu Help
            @ordered_menu_lines = qw(help about);
            foreach (@ordered_menu_lines) {
                $module->menus()->{help}->{ widget }->addItem($module->menus()->{help}->{ $_ });
            }
            $module->menus()->{help}->{ widget }->rebuildMenuTree();
            ManaTools::Shared::GUI::Event->new(
                name => 'AboutMenuEvent',
                eventHandler => $self,
                eventType => $yui::YEvent::MenuEvent,
                item      => $module->menus()->{help}->{about},
                event => sub {
                    my $event = shift;
                    my $dialog = $event->parentDialog();
                    my $self = $dialog->module(); #this object

                    $self->_showAboutDialog();

                    return 1;
                },
            );
            ManaTools::Shared::GUI::Event->new(
                name => 'QuitMenuEvent',
                eventHandler => $self,
                eventType => $yui::YEvent::MenuEvent,
                item      => $module->menus()->{file}->{quit},
                event => sub {
                    return 0;
                },
            );

            my $layout = $factory->createHBox($mainLayout);
            #create left Panel Frame no need to add a label for title
            my $leftPaneFrame = $factory->createFrame($layout, $module->settings()->{category_title});
            #create right Panel Frame no need to add a label for title (use setLabel when module changes)
            my $rightPaneFrame = $factory->createFrame($layout, "");


             # create a replacepoint on the tab
            $module->replacePoint (ManaTools::Shared::GUI::ReplacePoint->new(
                eventHandler => $self,
                parentWidget => $rightPaneFrame
             ));
            my $container =  $module->replacePoint->container();

            #create replace point for dynamically created widgets
            $module->rightPane($factory->createVBox($container));
            $module->leftPane($factory->createVBox($leftPaneFrame));
            $module->rightPaneFrame($rightPaneFrame);

            #logo from settings
            my $logofile = defined($module->settings()->{logo}) ?
                    $module->settings()->{logo} :
                    File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/logo_mageia.png'
            );

            my $logo = $factory->createImage($module->leftPane(), $logofile);
            $logo->setAutoScale(1);

            #$leftPaneFrame->setWeight(0, 1);
            $rightPaneFrame->setWeight(0, 2);

            $module->_loadCategories();

            $factory->createVStretch($module->leftPane());

            my $closeButton = $self->widget('closeButton');
            my $quitIcon = File::ShareDir::dist_file(ManaTools::Shared::distName(), 'images/quit.png');
            $closeButton->setIcon($quitIcon);

            if (!$module->currCategory()) {
                $module->currCategory(@{$module->categories()}[0]);
            }
            $module->currCategory()->addButtons($module);
            $module->rightPaneFrame()->setLabel($module->currCategory()->name());
            $factory->createSpacing($module->rightPane(), 1, 1, 1.0 );

            # Note that Since mpan is a Manatools::Module and creates other modules
            # title and application are set into BUILD (e.g. constructor) so last
            # built one is the one shown. Forcing setting again here
            yui::YUI::app()->setApplicationTitle($self->title);
            yui::YUI::app()->setApplicationIcon($self->icon);
            $module->replacePoint->finished();

            return $self->widget('layout');
        },
    );

    $self->mainWin($dialog);
    return $dialog->call();
}


## internal methods

## Check if event is from current Category View
## If icon click, returns the module to be launched

sub _moduleSelected {
    my ($self, $selectedWidget) = @_;

    for(@{$self->currCategory()->modules()}) {
        if( $_->button() == $selectedWidget ){
            return $_;
        }
    }
    return 0;
}


## Discover if a category button was selected.
## If category button is selected, sets right panel to display
## the selected Category Modules
## returns 1 if category button is selected
sub _categorySelected {
    my ($self, $selectedWidget) = @_;

    for (@{$self->categories()}) {
        if( $_->button() == $selectedWidget ) {

            #if current is already set then skips
            if ($self->currCategory() == $_) {
                ## returns 1 to skip any other checks on
                ## the selected widget
                return 1;
            }

            ## Menu item selected, set right pane
            my $ydialog = $self->mainWin()->dialog();
            $ydialog->startMultipleChanges();

            ## NOTE widget and item events (Shared::GUI:Event) created in the
            ## previous replacePoint MUST be cleaned up
            my $currCategory = $self->currCategory();
            ## Change Current Category to the selected one
            $self->currCategory($_);
            foreach my $mod (@{$currCategory->modules()}) {
                $self->mainWin()->delWidget(
                    $self->mainWin()->widget($mod->name())
                );
            }

            ## Remove existing modules
            $self->replacePoint->clear();
            $self->rightPane($self->factory()->createVBox($self->replacePoint->container()));

            ## Add new Module Buttons to Right Pane
            $self->currCategory()->addButtons($self);
            $self->rightPaneFrame()->setLabel($self->currCategory()->name());
            $self->factory()->createSpacing($self->rightPane(), 1, 1, 1.0 );

            $self->replacePoint->finished();

            $ydialog->doneMultipleChanges();

            return 1;
        }
    }

    return 0;
}

# return the localized string from a hash and given the key
# by default en value
sub _localizedValue {
    my ($self, $hash, $key) = @_;

    return if !defined($hash->{$key});

    if (ref($hash->{$key}) ne "HASH") {
        $self->logger()->W($self->loc()->N("Bad configuration file, %s has not xml:lang attribute, guessing it is a string", $key));
        # Force array is set for "title"
        return $hash->{$key}[0];
    }

    my @lang = I18N::LangTags::Detect::detect();
    # Adding default value as English (en)
    push @lang, 'en';
    foreach my $l ( @lang ) {
        return $hash->{$key}->{$l} if defined($hash->{$key}->{$l});
    }

    return;
}

## mpan settings
sub _loadSettings {
    my ($self, $force_load) = @_;

    # configuration file name
    my $fileName = $self->configPathName() . "/settings.conf";

    if (! -e $fileName) {
        my $err = $self->loc()->N("Configuration file %s is missing", $fileName);
        $self->logger()->E($err);
        die $err;
    }

    $self->logger()->I($self->loc()->N("Reading configuration file %s", $fileName));

    if (! scalar %{$self->settings()} || $force_load) {
        my $settingsReader = ManaTools::SettingsReader->new({fileName => $fileName});

        my $settings;
        my @lang = I18N::LangTags::Detect::detect();
        my $read = $settingsReader->settings();
        foreach (keys %{$read}) {
            my $key = $_;
            # localized strings
            if ($key eq "title" or $key eq "category_title") {
                # default is en
                $settings->{$key} = $self->_localizedValue(
                    $read,
                    $key
                );
                $self->logger()->I($self->loc()->N("Load settings: %s content is <<%s>>", $key, $settings->{$key}));
            }
            elsif (($key eq "icon" || $key eq "logo") && (substr( $read->{$key}, 0, 1) ne '/')) {
                # icon with relative path?
                $settings->{$key} = File::ShareDir::dist_file(ManaTools::Shared::distName(), $read->{$key});
            }
            else {
                $settings->{$key} = $read->{$key};
            }
        }

        $self->settings($settings);
    }
}

#=============================================================
#  _categoryLoaded
#
# INPUT
#
#     $self:     this object
#     $category: category to look for
#
# OUTPUT
#
#     $present: category is present or not
#
# DESCRIPTION
#
#     This method looks for the given category and if already in
#     returns true.
#
#=============================================================
sub _categoryLoaded {
    my ($self, $category) = @_;
    my $present = 0;

    if (!$category) {
        return $present;
    }

    foreach my $cat (@{$self->categories()}) {
        if ($cat->name() eq $category->name()) {
            $present = 1;
            last;
        }
    }

    return $present;
}

#=============================================================
#  _getCategory
#
#  INPUT
#
#     $self:     this object
#     $name:     category name
#
#  OUTPUT
#
#     $category: category object if exists
#
#  DESCRIPTION
#
#     This method looks for the given category name and returns
#     the realte object.
#=============================================================
sub _getCategory {
    my ($self, $name) = @_;
    my $category = undef;

    foreach $category (@{$self->categories()}) {
        if ($category->name() eq $name) {
            return $category;
        }
    }

    return $category;
}

# _loadCategory
#
# creates a new button representing a category
#
sub _loadCategory {
    my ($self, $category) = @_;

    if (!$self->_categoryLoaded($category)) {
        push ( @{$self->categories()}, $category );
        my $cat = @{$self->categories()}[-1];

        $cat->button(
            $self->factory()->createPushButton(
                $self->leftPane(),
                $cat->name()
            )
        );
        $cat->setIcon();
        $cat->button()->setStretchable(0, 1);
        $self->mainWin()->addWidget(
            $cat->name(),
            $cat->button(),  sub {
                my $event = shift; ## ManaTools::Shared::GUI::Event
                my $self = $event->parentDialog()->module(); #this object
                $self->_categorySelected($event->widget());

                return 1;
            }
        );
    }
    else {
        for (my $cat=0; $cat < scalar(@{$self->categories()}); $cat++ ) {
            my $catSelected = @{$self->categories()}[$cat];
            if( $catSelected->name() eq $category->name() &&
                !$catSelected->button())  {
                    $catSelected->button(
                        $self->factory()->createPushButton(
                            $self->leftPane(),
                            $catSelected->name()
                        )
                    );
                    $catSelected->setIcon();
                    $catSelected->button()->setStretchable(0, 1);
                    $self->mainWin()->addWidget(
                        $catSelected->name(),
                        $catSelected->button(),  sub {
                            my $event = shift; ## ManaTools::Shared::GUI::Event
                            my $self = $event->parentDialog()->module(); #this object
                            $self->_categorySelected($event->widget());

                            return 1;
                        }
                    );
                    last;

            }
        }
    }
}

sub _loadCategories {
    my $self = shift;

    # category files
    my @categoryFiles;
    my $fileName = $self->configPathName() . "/categories.conf";

    # configuration file dir
    my $directory = $self->configPathName() . "/categories.conf.d";

    push(@categoryFiles, $fileName);
    push(@categoryFiles, <$directory/*.conf>);
    my $currCategory;

    foreach $fileName (@categoryFiles) {
        $self->logger()->I($self->loc()->N("Parsing category file %s", $fileName));
        my $inFile = new ManaTools::ConfigReader({fileName => $fileName});
        my $tmpCat;
        my $tmp;
        my $hasNextCat = $inFile->hasNextCat();
        while( $hasNextCat ) {
            $tmp = $inFile->getNextCat();
            my $title = $self->_localizedValue(
                $tmp,
                'title'
            );
            $self->logger()->D($self->loc()->N("Load categories: title content is <<%s>>", $title));
            my $icon = $tmp->{icon};
            if ((substr( $icon, 0, 1) ne '/')) {
                # icon with relative path?
                $icon = File::ShareDir::dist_file(ManaTools::Shared::distName(), $tmp->{icon});
            }

            $tmpCat = $self->_getCategory($title);
            if (!$tmpCat) {
                $tmpCat = new ManaTools::Category({
                    name => $title,
                    icon => $icon,
                });
            }
            $self->_loadCategory($tmpCat);
            $hasNextCat  = $inFile->hasNextCat();
            $currCategory = $tmpCat;

            my $hasNextMod = $inFile->hasNextMod();
            while( $hasNextMod ) {
                $tmp = $inFile->getNextMod();
                my $tmpMod;
                my $loaded = 0;

                if (exists $tmp->{title}) {
                    my $title = $self->_localizedValue(
                        $tmp,
                        'title'
                    );
                    my $icon = $tmp->{icon};
                    if ((substr( $icon, 0, 1) ne '/')) {
                        # icon with relative path?
                        $icon = File::ShareDir::dist_file(ManaTools::Shared::distName(), $tmp->{icon});
                    }

                    $self->logger()->D($self->loc()->N("Load categories: module title is <<%s>>", $title));
                    if (not $currCategory->moduleLoaded($title)) {
                        $tmpMod = ManaTools::Module->create(
                            name => $title,
                            icon => $icon,
                            launch => $tmp->{launcher}
                        );
                    }
                }
                elsif (exists $tmp->{class}) {
                    if (not $currCategory->moduleLoaded(-CLASS => $tmp->{class})) {
                        $tmpMod = ManaTools::Module->create(-CLASS => $tmp->{class});
                    }
                }
                if ($tmpMod) {
                    $loaded = $currCategory->loadModule($tmpMod);
                    undef $tmpMod if !$loaded;
                }
                $hasNextMod = $inFile->hasNextMod();
            }
        }
    }
}

no Moose;
1;

