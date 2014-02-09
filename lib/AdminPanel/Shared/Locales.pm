# vim: set et ts=4 sw=4:
#*****************************************************************************
# 
#  Copyright (c) 2013-2014 Matteo Pasotti <matteo.pasotti@gmail.com>
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
package AdminPanel::Shared::Locales; 

use Moose;
use diagnostics;
use utf8;
use Locale::gettext;
use Text::Iconv;
  
has 'domain_name' => (
    is      => 'rw',
    default => 'apanel', 
);

has 'dir_name' => (
    is      => 'rw',
    default => undef, 
);

has 'codeset' => (
    is      => 'rw',
    default => 'UTF8', 
);

has 'domain' => (
    is      => 'rw', 
    init_arg  => undef,
);

#=============================================================

=head2 BUILD

=head3 INPUT

    $self: this object

=head3 DESCRIPTION

    The BUILD method is called after a Moose object is created.
    This method  initilaizes gettext domain.

=cut

#=============================================================
sub BUILD {
    my $self = shift;

    $self->domain(Locale::gettext->domain_raw($self->domain_name));
    $self->domain->dir($self->dir_name) if $self->dir_name;
    $self->domain->codeset($self->codeset)
}


#=============================================================

=head2 P

=head3 INPUT

    $self :      this object
    $s_singular: msg id singular
    $s_plural:   msg id plural
    $nb:         value for plural

=head3 OUTPUT

    locale string

=head3 DESCRIPTION

    returns the given string localized (see dngettext)

=cut

#=============================================================
sub P {    
    my ($self, $s_singular, $s_plural, $nb, @para) = @_;
    
    sprintf($self->domain->nget($s_singular, $s_plural, $nb), @para);
}

#=============================================================

=head2 N

=head3 INPUT

    $self : this object
    $s:     msg id
    
=head3 OUTPUT

    locale string

=head3 DESCRIPTION

    returns the given string localized (see dgettext)

=cut

#=============================================================
sub N {
    my ($self, $s, @para) = @_; 
    
    sprintf($self->domain->get($s), @para);
}

#=============================================================

=head2 N_

=head3 INPUT

    $self : this object
    $s:     msg id
    
=head3 OUTPUT

    msg id

=head3 DESCRIPTION

    returns the given string

=cut

#=============================================================
sub N_ {
    my $self = shift;
    
    $_[0]; 
}


#=============================================================

=head2 from_utf8

=head3 INPUT

    $self: this object
    $s:    string to be converted

=head3 OUTPUT\

    $converted: converted string

=head3 DESCRIPTION

    convert from utf-8 to current locale

=cut

#=============================================================
sub from_utf8 {
    my ($self, $s) = @_;

    my $converter = Text::Iconv->new("utf-8", undef);
    my $converted = $converter->convert($s);

    return $converted; 
}


#=============================================================

=head2 to_utf8

=head3 INPUT

    $self: this object
    $s:    string to be converted

=head3 OUTPUT\

    $converted: converted string

=head3 DESCRIPTION

    convert to utf-8 from current locale

=cut

#=============================================================
sub to_utf8 { 
    my ($self, $s) = @_;

    my $converter = Text::Iconv->new(undef, "utf-8");
    my $converted = $converter->convert($s);

    return $converted; 
}



no Moose;
__PACKAGE__->meta->make_immutable;


1;
