# vim: set et ts=4 sw=4:
#    Copyright 2012 Steven Tucker
#
#    This file is part of AdminPanel
#
#    AdminPanel is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    AdminPanel is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.


package AdminPanel::MainDisplay;
#============================================================= -*-perl-*-

=head1 NAME

AdminPanel::MainDisplay - class for AdminPaneol main window

=head1 SYNOPSIS

       $mainDisplay = new AdminPanel::MainDisplay();
       $mainDisplay->start();
       $mainDisplay->destroy();

=head1 METHODS

=head1 DESCRIPTION

Long_description

=head1 EXPORT

exported

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

perldoc AdminPanel::MainDisplay

=head1 SEE ALSO

SEE_ALSO

=head1 AUTHOR

Steven Tucker 

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012, Steven Tucker
Copyright (C) 2014, Angelo Naselli.

AdminPanel is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

AdminPanel is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdminPanel.  If not, see <http://www.gnu.org/licenses/>.

=head1 FUNCTIONS

=cut



=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.0.0';

use strict;
use warnings;
use diagnostics;
use AdminPanel::SettingsReader;
use AdminPanel::ConfigReader;
use AdminPanel::Category;
use AdminPanel::Module;
use Data::Dumper;
use yui;

#=============================================================

=head2 new

=head3 DESCRIPTION

This method instanziates the MainWindo object, and setups
the startup GUI.

=cut

#=============================================================
sub new {

    my $self = {
        my $categories = 0,
        my $event = 0,
        my $factory = 0,
        my $mainWin = 0,
        my $mainLayout = 0,
        my $menuLayout = 0,
        my $menus = {
            my $file = 0,
            my $help = 0
        },
        my $layout = 0,
        my $leftPane = 0,
        my $rightPane = 0,
        my $currCategory = 0,
        my $confDir = 0,
        my $title   = 0,
        my $settings = 0,
        my $exitButton = 0,
#        my $justToGetRidOfERROR = 0,
        my $replacePoint = 0
    };
    bless $self, 'AdminPanel::MainDisplay';
    
## Default values
    $self->{name} =     "Administration panel";
    $self->{categories} = [];
    $self->{confDir}    = "/etc/apanel",
    $self->{title}      = "apanel",
    
    my $cmdline = new yui::YCommandLine;

    ## TODO add parameter check
    my $pos       = $cmdline->find("--name");
    if ($pos > 0)
    {
        $self->{title} = $cmdline->arg($pos+1);
    }
    $pos       = $cmdline->find("--conf_dir");
    if ($pos > 0)
    {
        $self->{confDir} = $cmdline->arg($pos+1);
    }
    else
    {
        $self->{confDir} = "/etc/$self->{title}";
    }

    $self->setupGui();

    return $self;
}

## Begin the program event loop
sub start {
    my ($self) = shift;
    my $reqExit = 0;

    ##Default category selection
    if (!$self->{currCategory}) {
        $self->{currCategory} = @{$self->{categories}}[0]; 
    }
    $self->{currCategory}->addButtons($self->{rightPane}, $self->{factory});
    $self->{rightPaneFrame}->setLabel($self->{currCategory}->{name});
    $self->{factory}->createSpacing($self->{rightPane}, 1, 1, 1.0 );
    my $launch = 0;
    while(!$launch) {

        ## Grab Event
        $self->{event} = $self->{mainWin}->waitForEvent();
        my $eventType  = $self->{event}->eventType();
        
        ## Check for window close
        if ($eventType == $yui::YEvent::CancelEvent) {
            last;
        }
        elsif ($eventType == $yui::YEvent::MenuEvent) {
            ### MENU ###
            my $item = $self->{event}->item();
            if ($item->label() eq $self->{menus}->{file}[0]->label()) {
                ## quit menu item
                last;
            }
        }        
        elsif ($eventType == $yui::YEvent::WidgetEvent) {
            my $widget = $self->{event}->widget();
            
            ## Check for Exit button push or menu
            if($widget == $self->{exitButton}) {
                last;
            }
            else {
                # category button selected?
                my $isCat = $self->_categorySelected($widget);
                if (!$isCat) {
                    # module button selected?
                    $launch = $self->_moduleSelected($widget);
                }
            }
        }                
    }

    return $launch;
}

#=============================================================

=head2 destroy

=head3 INPUT

    $self:     this object

=head3 DESCRIPTION

    This method destroyes the main window and all the
    relevanto bojects (category and modules buttons).

=cut

#=============================================================
sub destroy {
    my ($self) = shift;
    $self->{mainWin}->destroy();
    for (my $cat=0; $cat < scalar(@{$self->{categories}}); $cat++ ) {
        @{$self->{categories}}[$cat]->{button} = 0;
        @{$self->{categories}}[$cat]->removeButtons();
    }
}

#=============================================================

=head2 setupGui

=head3 INPUT

    $self:     this object

=head3 DESCRIPTION

    This method load configuration and build the GUI layout.

=cut

#=============================================================
sub setupGui {
    my ($self) = shift;

    $self->_loadSettings();
    yui::YUILog::setLogFileName($self->{settings}->{log});
    $self->{name} = $self->{settings}->{title};
    yui::YUI::app()->setApplicationTitle($self->{name});
    yui::YUI::app()->setApplicationIcon($self->{settings}->{icon});

    $self->{factory} = yui::YUI::widgetFactory;
    $self->{mainWin} = $self->{factory}->createMainDialog;

    $self->{mainLayout} = $self->{factory}->createVBox($self->{mainWin});
    $self->{menuLayout} = $self->{factory}->createHBox($self->{mainLayout});
   
    ## Menu file
    ## TODO i8n 
    my $align = $self->{factory}->createAlignment($self->{menuLayout}, 1, 0);
    my $menu            = $self->{factory}->createMenuButton($align, "File");
    my $item = new yui::YMenuItem("Exit");

    push(@{$self->{menus}->{file}}, $item);
    $menu->addItem($item);
    $menu->rebuildMenuTree();

    $align = $self->{factory}->createAlignment($self->{menuLayout}, 2, 0);
    $menu           = $self->{factory}->createMenuButton($align, "Help");
    $item = new yui::YMenuItem("Help");
    $menu->addItem($item);
    push(@{$self->{menus}->{help}}, $item);
    $item = new yui::YMenuItem("About");
    $menu->addItem($item);
    push(@{$self->{menus}->{help}}, $item);
    $menu->rebuildMenuTree();

    $self->{layout}     = $self->{factory}->createHBox($self->{mainLayout});

    #create left Panel Frame no need to add a label for title 
    $self->{leftPaneFrame} = $self->{factory}->createFrame($self->{layout}, $self->{settings}->{category_title});
    #create right Panel Frame no need to add a label for title (use setLabel when module changes) 
    $self->{rightPaneFrame} = $self->{factory}->createFrame($self->{layout}, "");
    #create replace point for dynamically created widgets
    $self->{replacePoint} = $self->{factory}->createReplacePoint($self->{rightPaneFrame});

    $self->{rightPane} = $self->{factory}->createVBox($self->{replacePoint});
    $self->{leftPane} = $self->{factory}->createVBox($self->{leftPaneFrame});

    #logo from settings
    my $logo = $self->{factory}->createImage($self->{leftPane}, $self->{settings}->{logo});
    $logo->setAutoScale(1);

#     $self->{leftPaneFrame}->setWeight(0, 1);
    $self->{rightPaneFrame}->setWeight(0, 2);

    $self->_loadCategories();
    $self->{factory}->createVStretch($self->{leftPane});

    $self->{exitButton} = $self->{factory}->createPushButton($self->{leftPane}, "Exit");
    $self->{exitButton}->setIcon("$self->{settings}->{images_dir}/quit.png");    
    $self->{exitButton}->setStretchable(0, 1);
}


## internal methods

## Check if event is from current Category View
## If icon click, returns the module to be launched

sub _moduleSelected {
    my ($self, $selectedWidget) = @_;
    
    for(@{$self->{currCategory}->{modules}}) {
        if( $_->{button} == $selectedWidget ){
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
    for (@{$self->{categories}}) {
        if( $_->{button} == $selectedWidget ) {
            
            #if current is already set then skips
            if ($self->{currCategory} == $_) {
                ## returns 1 to skip any other checks on 
                ## the selected widget
                return 1;
            }
            ## Menu item selected, set right pane
            $self->{mainWin}->startMultipleChanges();
            ## Remove existing modules
            $self->{replacePoint}->deleteChildren();
            $self->{rightPane} = $self->{factory}->createVBox($self->{replacePoint});

            ## Change Current Category to the selected one
            $self->{currCategory} = $_;
            ## Add new Module Buttons to Right Pane
            $self->{currCategory}->addButtons($self->{rightPane}, $self->{factory});
            $self->{rightPaneFrame}->setLabel($self->{currCategory}->{name});
            $self->{factory}->createSpacing($self->{rightPane}, 1, 1, 1.0 );
            $self->{replacePoint}->showChild();
            $self->{mainWin}->recalcLayout();
            $self->{mainWin}->doneMultipleChanges();

            return 1;
        }
    }

    return 0;
}

## adpanel settings
sub _loadSettings {
    my ($self, $force_load) = @_;
    # configuration file name
    my $fileName = "$self->{confDir}/settings.conf";
    if (!$self->{settings} || $force_load) {
        $self->{settings} = new AdminPanel::SettingsReader($fileName);
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

    foreach my $cat (@{$self->{categories}}) { 
        if ($cat->{name} eq $category->{name}) {
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

    foreach $category (@{$self->{categories}}) { 
        if ($category->{name} eq $name) {
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
        push ( @{$self->{categories}}, $category );

        @{$self->{categories}}[-1]->{button} = $self->{factory}->createPushButton(
                                                                    $self->{leftPane},
                                                                    $self->{categories}[-1]->{name}
                                                                    );
        @{$self->{categories}}[-1]->setIcon();

        @{$self->{categories}}[-1]->{button}->setStretchable(0, 1);
    }
    else {
        for (my $cat=0; $cat < scalar(@{$self->{categories}}); $cat++ ) {
            if( @{$self->{categories}}[$cat]->{name} eq $category->{name} &&
                !@{$self->{categories}}[$cat]->{button})  {
                    @{$self->{categories}}[$cat]->{button} = $self->{factory}->createPushButton(
                                                                    $self->{leftPane},
                                                                    $self->{categories}[$cat]->{name}
                                                                    );
                    @{$self->{categories}}[$cat]->setIcon();
                    @{$self->{categories}}[$cat]->{button}->setStretchable(0, 1);
                    last;

            }
        }
    }
}

sub _loadCategories {
    my ($self) = @_;

    # category files 
    my @categoryFiles;
    my $fileName = "$self->{confDir}/categories.conf";
    
    
    # configuration file dir
    my $directory = "$self->{confDir}/categories.conf.d";
    
    push(@categoryFiles, $fileName);
    push(@categoryFiles, <$directory/*.conf>);
    my $currCategory;
    
    foreach $fileName (@categoryFiles) {
        my $inFile = new AdminPanel::ConfigReader($fileName);
        my $tmpCat;
        my $tmp;
        my $hasNextCat = $inFile->hasNextCat();
        while( $hasNextCat ) {
            $tmp = $inFile->getNextCat();
            $tmpCat = $self->_getCategory($tmp->{title});
            if (!$tmpCat) {
                $tmpCat = new AdminPanel::Category($tmp->{title}, $tmp->{icon});
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
                    if (not $currCategory->moduleLoaded($tmp->{title})) {
                        $tmpMod = AdminPanel::Module->create(name => $tmp->{title}, 
                                                             icon => $tmp->{icon},
                                                             launch => $tmp->{launcher}
                        );
                    }
                } 
                elsif (exists $tmp->{class}) {
                    if (not $currCategory->moduleLoaded(-CLASS => $tmp->{class})) {
                        $tmpMod = AdminPanel::Module->create(-CLASS => $tmp->{class});
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

1;

=pod

=head2 start

    contains the main loop of the application
    where we can check for events

=head2 setupGui

    creates a popupDialog using a YUI::WidgetFactory
    and then populate this dialog with some components

=cut
