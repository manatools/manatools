#!/usr/bin/perl -w
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright: 2012-2017 by Matteo Pasotti <matteo.pasotti@gmail.com>

package ManaTools::Module::PkgDownloader;

use strict;
use warnings;
use diagnostics;
use Modern::Perl '2011';
use English;
use Term::ANSIColor qw(:constants);
# use Getopt::Long qw(:config permute);
use Moose;
use Moose::Autobox;
use ManaTools::Shared::urpmi_backend::DB;
use ManaTools::Shared qw(trim);

with 'MooseX::Getopt';

# extends qw( ManaTools::Module );

my $PKG_QUERYMAKER = "urpmq";
my $QUERY_LISTMEDIA_PARM = "--list-media";
my $QUERY_LISTURL_PARM = "--list-url";
my $QUERY_LOOKFORSRPM_PARM = "--sourcerpm";
my $QUERY_PKG_FULL = "-f";
my $DLDER = "--wget";

has 'use_wget' => (
   is      => 'rw',
   isa     => 'Bool',
   default => sub { return 0; },
);

has 'use_axel' => (
   is      => 'rw',
   isa     => 'Bool',
   default => sub { return 0; },
);

has 'srpm' => (
   is      => 'rw',
   isa     => 'Bool',
   default => sub { return 0; },
);

has 'use_major' => (
   is      => 'rw',
   isa     => 'Bool',
   default => sub { return 0; },
);

has 'packagelist' => (
   is   => 'rw',
   isa  => 'Str',
   required => 1,
   default => sub { return ""; },
);

has 'packages' => (
   is   => 'rw',
   isa  => 'ArrayRef',
   default => sub { [] },
);

sub process_args {
	my ($self, $pkglist) = @_;
	return 0 if(ManaTools::Shared::trim($pkglist)=~m/^$/g);
	my @items = split(/\s/,$pkglist);
	if(scalar(@items)>0){
		for(@items){
			push @{$self->packages()}, $_;
		}
		return 1;
	}
}

sub download {
	my $self = shift();
	my $url = shift();
	my $rpm = shift();
	if($self->use_wget()){
		`wget "$url/$rpm" -O $rpm`;
	}elsif($self->use_axel()){
		`axel -a "$url/$rpm" -o $rpm`;
	}else{
		`curl -s "$url/$rpm" -o $rpm`;
	}
}


# IMPORTANT!
# THOSE TWO ROUTINES MUST BE PORTED TO THE URPMI_BACKEND FROM MANATOOLS:
# *  retrieve_brpm_pkgname
# *  retrieve_srpm_pkgname

# ----------------------------------------------------------------------
# retrieve the binary rpm's pkg name - array
# ----------------------------------------------------------------------
sub retrieve_brpm_pkgname {
    my $pkg = shift();
    my @lista_brpms = `$PKG_QUERYMAKER -a $QUERY_PKG_FULL $pkg | grep "^$pkg" | sort -u`;
    return @lista_brpms;
}

# ----------------------------------------------------------------------
# retrieve the srpm's pkg name - array
# ----------------------------------------------------------------------
sub retrieve_srpm_pkgname {
    my $pkg = shift();
    my @lista_srpms = `$PKG_QUERYMAKER $QUERY_LOOKFORSRPM_PARM $pkg | sort -u | grep "$pkg:" | awk -F':' '{print \$2}'`;
    return @lista_srpms;
}

sub start {
	my $self = shift;
	my $pkg = "";
	my $rpmbackend = ManaTools::Shared::urpmi_backend::DB->new();
	my $urpm = $rpmbackend->fast_open_urpmi_db();
	my @media_urls=map { if(!$self->srpm()) {
			$_->{url}
		}else{
			my @a = split(/\//,$_->{url});
			my $newurl = "";
			my $i = 0;
			for($i=0;$i<scalar(@a)-4;$i++)
			{
				$newurl .= $a[$i]."/";	
			}
			$newurl."SRPMS/".$a[scalar(@a)-2]."/".$a[scalar(@a)-1];
		}
	} $rpmbackend->get_active_media($urpm,$self->srpm());

	if(!$self->process_args($self->packagelist()))
	{
		return 4;
	}


	if(scalar(@media_urls) lt 1)
	{
		print BOLD, WHITE, "== ", RESET, RED, $self->loc->N("no active media found\n");
		return 3;
	}

	if(scalar(@{$self->packages()}) gt 0){
		for $pkg(@{$self->packages()}){
			my @lista_srpms;
			if($self->srpm()){
				@lista_srpms = retrieve_srpm_pkgname($pkg);
			}else{
				@lista_srpms = retrieve_brpm_pkgname($pkg);
			}
			#print "@lista_srpms\n";
			if($self->use_major()){
				#print "Using only major version\n";
				for(my $i=0;$i<scalar(@lista_srpms)-1;$i++){
					shift @lista_srpms;
					#print "@lista_srpms\n";
				}
			}
			for my $srpm(@lista_srpms){
				$srpm =~s/^\s+//g;
				chomp $srpm;
				$srpm = $srpm.".rpm" if(!$self->srpm());
				print BOLD, WHITE, $self->loc->N("== Processing ")."$srpm\n", RESET;
				for my $url(@media_urls){
					chomp $url;
					my @protocol = split(':',$url);
					if($protocol[0] eq "http"){
						print BOLD, WHITE, "== ", RESET, $self->loc->N("protocol in use: "), BOLD, GREEN, $protocol[0], RESET, "\n"; 
						print BOLD, WHITE, "== ", RESET, $self->loc->N("trying with ")."$url/$srpm\n";
						my $check = `curl -s --head "$url/$srpm" | head -n 1 | grep "200 OK" > /dev/null ; echo \$?`;
						chomp $check;
						if($check eq "0"){
							$self->download($url,$srpm);
							last;
						}
					}elsif($protocol[0] eq "ftp"){
						print BOLD, WHITE, "== ", $self->loc->N("protocol in use: "), BOLD, GREEN, $protocol[0], RESET, "\n"; 
						my $check = `curl -s --head "$url/$srpm"`;
						$check =~s/\n/ /g;
						$check =~s/^\s+//g;
						$check =~s/\s+$//g;
						if($check ne ""){
							$self->download($url,$srpm);
							last;
						}
					}elsif($protocol[0] eq "rsync"){
						print BOLD, WHITE, "== ", $self->loc->N("protocol in use: "), BOLD, GREEN, $protocol[0], RESET, "\n"; 
					}
				}
				print BOLD, WHITE, "== ", GREEN, "$srpm", RESET, $self->loc->N(" downloaded successfully\n");
			}
		}
		return 0;
	}else{
		print BOLD, WHITE, "== ", RED, $self->loc->N("no packages passed as argument\n"), RESET;
		return 2;
	}
}

1;
