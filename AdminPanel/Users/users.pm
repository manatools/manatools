package AdminPanel::Users::users; 

use diagnostics;
use strict;

#-######################################################################################
#- misc imports
#-######################################################################################
use common;

use run_program;

use base qw(Exporter);

our @EXPORT = qw(
                facesdir
                face2png
                facenames
                addKdmIcon
                valid_username
                valid_groupname
                GetFaceIcon
                );

sub facesdir() {
    "$::prefix/usr/share/mga/faces/";
}
sub face2png {
    my ($face) = @_;
    facesdir() . $face . ".png";
}
sub facenames() {
    my $dir = facesdir();
    my @l = grep { /^[A-Z]/ } all($dir);
    map { if_(/(.*)\.png/, $1) } (@l ? @l : all($dir));
}

sub addKdmIcon {
    my ($user, $icon) = @_;
    my $dest = "$::prefix/usr/share/faces/$user.png";
    eval { cp_af(facesdir() . $icon . ".png", $dest) } if $icon;
}


sub valid {
    return (0, "Name field is empty please provide a name") if (!$_[0] );

    $_[0] =~ /^[a-z]+?[a-z0-9_\-\.]*?$/ or do {
        return (0, "The name must contain only lower cased latin letters, numbers, `.', `-' and `_'");
    };
    return (0, "Name is too long") if (! (length($_[0]) <= $_[1]));
    return (1, "Ok");
}

sub valid_username {
     return valid($_[0], 32);
}

sub valid_groupname {
    return valid($_[0], 16);
}

##################################################
## GetFaceIcon
## params
##
## 'name' icon name for the given name
## 'next' get next icon from the given 'name' 
##
## return
## 'user_icon' icon name
##
sub GetFaceIcon {
    my ($name, $next) = @_;
    my @icons = facenames();
    my $i;
    my $current_icon;
    # remove shortcut "&" from label
    $name =~ s/&// if ($name); 
    my $user_icon = face2png($name) if ($name);
   

    if ($name && -e $user_icon) {
        my $current_md5 = common::md5file($user_icon);
        eval { $i = find_index { common::md5file(face2png($_)) eq $current_md5 } @icons };
        if (!$@) { #- current icon found in @icons, select it
            $current_icon = $icons[$i];
        } else { #- add and select current icon in @icons
            push @icons, $user_icon;
            $current_icon = $user_icon;
            $i = @icons - 1;
        }
    } else {
        #- no icon yet, select a random one
        $current_icon = $icons[$i = rand(@icons)];
    }

    if ($next) {
        $current_icon = $icons[$i = defined $icons[$i+1] ? $i+1 : 0];
    }
    return $current_icon;
}





1;
