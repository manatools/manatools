# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013 - 2015 Angelo Naselli <anaselli@linux.it>
#  from drakx services
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

# NOTE this module has not been ported and does not work
# TODO porting it if it is really needed nowadays
package AdminPanel::Module::AdminMouse;

#leaving them atm
use lib qw(/usr/lib/libDrakX);

# i18n: IMPORTANT: to get correct namespace (drakx-kbd-mouse-x11 instead of libDrakX)
BEGIN { unshift @::textdomains, 'drakx-kbd-mouse-x11' }

use common;
use modules;
use mouse;
use c;

use AdminPanel::Shared;

use yui;
use Moose;

extends qw( AdminPanel::Module );

has '+icon' => (
    default => "/usr/share/mcc/themes/default/mousedrake-mdk.png",
);

has '+name' => (
    default => N("AdminMouse"), 
);

sub start {
    my $self = shift;

    $self->_adminMouseDialog();
}

sub _getUntranslatedName {
    my ($self, $name, $list) = @_;
    
    foreach my $n (@{$list}) {
        my @names  = split(/\|/, $n);
        for (my $lev=0; $lev < scalar(@names); $lev++) {
            if (translate($names[$lev]) eq $name) {
                return $names[$lev];
            }
        }
    }

    return undef;
}


sub _adminMouseDialog {
    my $self = shift;
     
    my $datavalue = "TEST";
    
    my $appTitle = yui::YUI::app()->applicationTitle();
    
    ## set new title to get it in dialog
    yui::YUI::app()->setApplicationTitle($self->name);
    ## set icon if not already set by external launcher
    yui::YUI::app()->setApplicationIcon($self->icon);

    my $factory      = yui::YUI::widgetFactory;
    
    my $dialog     = $factory->createMainDialog;
    my $vbox       = $factory->createVBox( $dialog );
    my $frame      = $factory->createFrame ($vbox, N("Please choose your type of mouse."));
    my $treeWidget = $factory->createTree($frame, "");
    
    my $modules_conf = modules::any_conf->read;

    my $mouse = mouse::read();

    if (!$::noauto) {
        my $probed_mouse = mouse::detect($modules_conf);
        $mouse = $probed_mouse if !$mouse->{Protocol} || !$probed_mouse->{unsafe};
    }
    
    if (!$mouse || !$::auto) {
        $mouse ||= mouse::fullname2mouse('Universal|Any PS/2 & USB mice');
        
        my $prev = my $fullname = $mouse->{type} . '|' . $mouse->{name};
        my $selected = $mouse->{name};
        
        my $fullList = { list => [ mouse::_fullnames() ], items => [], separator => '|', val => \$fullname, 
                     format => sub { join('|', map { translate($_) } split('\|', $_[0])) } } ;
        my $i;             
        
        my $itemColl = new yui::YItemCollection;
        my @items;
        for ($i=0; $i<scalar(@{$fullList->{list}}); $i++) {
            my @names  = split(/\|/, $fullList->{list}[$i]);
            for (my $lev=0; $lev < scalar(@names); $lev++) {
                $names[$lev] = N($names[$lev]);
            }
            if ($i == 0 || $names[0] ne $items[0]->{label}) {
                if ($i != 0) {
                    $itemColl->push($items[0]->{item}); 
                    push @{$fullList->{items}}, $items[-1]->{item};;
                }
                @items = undef;                
                my $item = new yui::YTreeItem ($names[0]);
         
                if ($selected eq $self->_getUntranslatedName($item->label(), $fullList->{list})) {
                    $item->setSelected(1) ;
                    $item->setOpen(1);
                    my $parent = $item;  
                    while($parent = $parent->parent()) {
                        $parent->setOpen(1);                                
                    }
                }
                $item->DISOWN();
                @items = ({item => $item, label => $names[0], level => 0});
                for (my $lev=1; $lev < scalar(@names); $lev++) {
                    $item = new yui::YTreeItem ($items[$lev-1]->{item}, $names[$lev]);
                    
                    if ($selected eq $self->_getUntranslatedName($item->label(), $fullList->{list})) {
                        $item->setSelected(1) ;
                        $item->setOpen(1);
                        my $parent = $item;  
                        while($parent = $parent->parent()) {
                            $parent->setOpen(1);                                
                        }
                    }
                    $item->DISOWN();
                    if ($lev < scalar(@names)-1) {
                        push @items, {item => $item, label => $names[$lev], level => $lev};
                    }                    
                }
            }
            else {
                my $prevItem = 0;
                for (my $lev=1; $lev < scalar(@names); $lev++) {
                    my $it;
                    for ($it=1; $it < scalar(@items); $it++){
                        if ($items[$it]->{label} eq $names[$lev] && $items[$it]->{level} == $lev) {
                            $prevItem = $it;
                            last;
                        }                        
                    }
                    if ($it == scalar(@items)) {
                        my $item = new yui::YTreeItem ($items[$prevItem]->{item}, $names[$lev]);

                        if ($selected eq $self->_getUntranslatedName($item->label(), $fullList->{list})) {
                            $item->setSelected(1) ;
                            $item->setOpen(1);
                            my $parent = $item;  
                            while($parent = $parent->parent()) {
                                $parent->setOpen(1);                                
                            }
                        }
                        $item->DISOWN();
                        push @items, {item => $item, label => $names[$lev], level => $lev};                        
                    }
                }
            }
        }
        $itemColl->push($items[0]->{item});
        push @{$fullList->{items}}, $items[-1]->{item};

        $treeWidget->addItems($itemColl);
        my $align        = $factory->createLeft($vbox);
        my $hbox         = $factory->createHBox($align);
        my $aboutButton  = $factory->createPushButton($hbox, N("About") );
        $align = $factory->createRight($hbox);
        $hbox     = $factory->createHBox($align);
        my $cancelButton = $factory->createPushButton($hbox, N("Cancel") );
        my $okButton = $factory->createPushButton($hbox, N("Ok") );

        while(1) {
            my $event     = $dialog->waitForEvent();
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
                elsif ($widget == $aboutButton) {
                    my $license = translate($AdminPanel::Shared::License);
                    AdminPanel::Shared::AboutDialog(
                          { name => N("AdminMouse"),
                            version => $self->VERSION, 
                            copyright => N("Copyright (C) %s Mageia community", '2014'),
                            license => $license, 
                            comments => N("AdminMouse is the Mageia mouse management tool \n(from the original idea of Mandriva mousedrake)."),
                            website => 'http://www.mageia.org',
                            website_label => N("Mageia"),
                            authors => "Angelo Naselli <anaselli\@linux.it>\nMatteo Pasotti <matteo.pasotti\@gmail.com>",
                            translator_credits =>
                            #-PO: put here name(s) and email(s) of translator(s) (eg: "John Smith <jsmith@nowhere.com>")
                            N("_: Translator(s) name(s) & email(s)\n")}
                    );
                }
                elsif ($widget == $okButton) {
                    my $continue = 1;
                    my $selectedItem = $treeWidget->selectedItem();
                    
                    my $it=$selectedItem;
                    my $fullname = $self->_getUntranslatedName($it->label(), $fullList->{list});
                    while($it = yui::toYTreeItem($it)->parent()) {
                        $fullname = join("|", $self->_getUntranslatedName($it->label(), $fullList->{list}), $fullname);
                    }
                    
                    if ($fullname ne $prev) {
                        my $mouse_ = mouse::fullname2mouse($fullname, device => $mouse->{device});
                        if ($fullname =~ /evdev/) {
                            $mouse_->{evdev_mice} = $mouse_->{evdev_mice_all} = $mouse->{evdev_mice_all};
                        }
                        %$mouse = %$mouse_;
                    }
                    
                    if ($mouse->{nbuttons} < 3 ) {
                        $mouse->{Emulate3Buttons} = AdminPanel::Shared::ask_YesOrNo('', N("Emulate third button?"));
                    }
                    if ($mouse->{type} eq 'serial') {
                        my @list = ();
                        foreach (detect_devices::serialPorts()) {
                            push @list, detect_devices::serialPort2text($_);
                        }
                        my $choice = AdminPanel::Shared::ask_fromList(N("Mouse Port"), 
                                                         N("Please choose which serial port your mouse is connected to."),
                                                         \@list);
                        if ( !$choice ) {
                            $continue = 0;
                        }
                        else {
                            $mouse->{device} = $choice;
                        }
                    }
                    
                    if ($continue) {
                        last;
                    }
                }
            }
        }
        
    }

 #  TODO manage write conf without interactive things
 #  mouse::write_conf($in->do_pkgs, $modules_conf, $mouse, 1);
    system('systemctl', 'try-restart', 'gpm.service') if -e '/usr/lib/systemd/system/gpm.service';
   
    AdminPanel::Shared::infoMsgBox(N("Not implemented yet: configuration is not changed"));
    
    $dialog->destroy();
    
    #restore old application title
    yui::YUI::app()->setApplicationTitle($appTitle);
}

1;
