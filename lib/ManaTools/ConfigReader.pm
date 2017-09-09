# vim: set et ts=4 sw=4:
package ManaTools::ConfigReader;
#============================================================= -*-perl-*-

=head1 NAME

    ManaTools::ConfigReader - This module allows to load an XML configuration file

=head1 SYNOPSIS

    use ManaTools::ConfigReader;

    my $settings = new ManaTools::ConfigReader({filNema => $fileName});

=head1 DESCRIPTION

    This module allows to load a configuration file returning a Hash references with its content.


=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc ManaTools::ConfigReader

=head1 SEE ALSO

    XML::Simple
    ManaTools::MainDisplay


=head1 AUTHOR

    Angelo Naselli <anaselli@linux.it>

=head1 COPYRIGHT and LICENSE

    Copyright 2012-2017, Angelo Naselli.
    Copyright 2012, Steven Tucker.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA

=head1 METHODS

=cut


#Class ConfigReader
package ManaTools::ConfigReader;

use Moose;
use diagnostics;
use XML::Simple;

#=============================================================

=head2 new

=head3 INPUT

    hash ref containing
        fileName: configuration file name

=head3 OUTPUT attributes

    data:    Hash reference containing the configuration read
    catLen:  number of categories found
    modLen:  number of modules found
    currCat: current category
    currMod: current module

=head3 DESCRIPTION

    The constructor just loads the given file and provide accessors.

=cut

#=============================================================

has 'fileName' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'catLen' => (
    is       => 'rw',
    isa      => 'Int',
    init_arg => undef,
    lazy     => 1,
    default   => -1,
);

has 'modLen' => (
    is        => 'rw',
    isa       => 'Int',
    init_arg  => undef,
    lazy      => 1,
    default   => -1,
);

has 'data' => (
    is       => 'ro',
    isa      => 'HashRef',
    init_arg => undef,
    lazy     => 1,
    builder  => '_dataInitialize',
);

sub _dataInitialize {
    my $self = shift;

    my $xml = new XML::Simple ();
    my $data = $xml->XMLin(
        $self->fileName(),
        ContentKey => '-content',
        ForceArray => ['category', 'title', 'module'],
        KeyAttr=>{
            title => "xml:lang",
        }
    );

    $self->catLen( scalar(@{$data->{category}}) );
    $self->modLen(
        scalar(@{@{$data->{category}}[0]->{module}})
    );

    return $data;
}

has 'currCat' => (
    is        => 'rw',
    isa       => 'Int',
    init_arg  => undef,
    default   => -1,
);

has 'currMod' => (
    is        => 'rw',
    isa       => 'Int',
    init_arg  => undef,
    default   => -1,
);


#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created,
    Into this method new optional parameters are tested once,
    instead of into any other methods.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    die "Given fileName does not exsts" if (! -e $self->fileName);
    # force to read the file now, to make its content available
    $self->data();
}

#=============================================================

=head2 hasNextCat

=head3 INPUT

    $self: this object

=head3 OUTPUT

    1: if there are any other ctegories

=head3 DESCRIPTION

    This method returns if there are any categories left

=cut

#=============================================================
sub hasNextCat {
    my $self = shift;

    if($self->currCat() + 1 >= $self->catLen()) {
        return 0;
    }
    return 1;
}

#=============================================================

=head2 getNextCat

=head3 INPUT

    $self: this object

=head3 OUTPUT

    $cat: next category

=head3 DESCRIPTION

    This method returns the next category

=cut

#=============================================================
sub getNextCat {
    my $self = shift;

    if ($self->hasNextCat()) {
        $self->currCat($self->currCat()+1);
        # Reset the Module Count and Mod length for new Category
        $self->currMod(-1);
        $self->modLen(
            scalar(@{@{$self->data()->{category}}[$self->currCat()]->{module}})
        );

        my $cat = @{$self->data()->{category}}[$self->currCat()];

        return $cat;
    }

    return;
}

#=============================================================

=head2 hasNextMod

=head3 INPUT

    $self: this object

=head3 OUTPUT

    1: if there are any other modules

=head3 DESCRIPTION

    This method returns if there are any modules left

=cut

#=============================================================
sub hasNextMod {
    my $self = shift;

    if($self->currMod() + 1 >= $self->modLen()) {
        return 0;
    }
    return 1;
}

#=============================================================

=head2 getNextMod

=head3 INPUT

    $self: this object

=head3 OUTPUT

    $cat: next module

=head3 DESCRIPTION

    This method returns the next module

=cut

#=============================================================
sub getNextMod {
    my $self = shift;

    my $ret = 0;

    if ($self->hasNextMod()) {
        $self->currMod($self->currMod()+1);
        $ret = @{@{$self->data()->{category} }[$self->currCat()]->{module}}[$self->currMod()];
        return $ret;
    }

    return;
}

no Moose;
1;
