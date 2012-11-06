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


#Class ConfigReader
package ConfigReader;

use strict;
use warnings;
use diagnostics;
use XML::Simple;
use Data::Dumper;

sub new {
    my ($class, $fileName) = @_;
    
    my $self = {
	my $data = 0,
	my $catLen = 0,
        my $currCat = 0,
	my $modLen = 0,
	my $currMod = 0,
	my $placeHolder = 0
    };
    bless $self, 'ConfigReader';
    
    my $xml = new XML::Simple (KeyAttr=>[]);
    $self->{data} = $xml->XMLin($fileName);
    $self->{catLen} = scalar(@{$self->{data}->{category}});
    $self->{currCat} = -1;
    
    if(ref(@{$self->{data}->{category}}[0]->{module}) eq "ARRAY") {
        $self->{modLen} = scalar(@{@{$self->{data}->{category}}[0]->{module}});
    } else {
	$self->{modLen} = 1;
    }
    $self->{currMod} = -1;

    return $self;
}

sub hasNextCat {
    my ($self) = @_;
    
    if($self->{currCat} + 1 >= $self->{catLen}) {
	return 0;
    }
    return 1;
}

sub getNextCat {
    my ($self) = @_;
    
    $self->{currCat}++;
    if($self->{currCat} >= $self->{catLen}) {
	return 0;
    }
    
    # Reset the Module Count and Mod length for new Category
    $self->{currMod} = -1;
    if(ref(@{$self->{data}->{category}}[$self->{currCat}]->{module}) eq "ARRAY") {
        $self->{modLen} = scalar(@{@{$self->{data}->{category}}[$self->{currCat}]->{module}});
    } else {
	$self->{modLen} = 1;
    }

    my $tmp = @{$self->{data}->{category}}[$self->{currCat}];
    
    return $tmp;
}

sub hasNextMod {
    my ($self) = @_;

    if($self->{currMod} + 1 >= $self->{modLen}) {
	return 0;
    }
    return 1;
}

sub getNextMod {
    my ($self) = @_;

    my $ret = 0;

    $self->{currMod}++;

    if($self->{modLen} == 1) {
	$ret = @{$self->{data}->{category}}[$self->{currCat}]->{module};
    } else {
	$ret = @{@{$self->{data}->{category} }[$self->{currCat}]->{module}}[$self->{currMod}];
    }

    return $ret;
}

1;
