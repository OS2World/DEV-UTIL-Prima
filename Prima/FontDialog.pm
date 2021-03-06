#
#  Copyright (c) 1997-2002 The Protein Laboratory, University of Copenhagen
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  SUCH DAMAGE.
#
#  Created by Dmitry Karasik <dk@plab.ku.dk>
#
#  $Id: FontDialog.pm,v 1.18 2002/07/22 09:30:51 dk Exp $

package Prima::FontDialog;

use strict;
use Prima::Const;
use Prima::Classes;
use Prima::Buttons;
use Prima::ComboBox;
use Prima::Label;
use Prima::MsgBox;


use vars qw( @ISA);
@ISA = qw( Prima::Dialog);

sub profile_default
{
   return {
      %{$_[ 0]-> SUPER::profile_default},
      width       => 540,
      height      => 350,
      centered    => 1,
      visible     => 0,
      designScale => [7, 16],
      text        => 'Select font',

      showHelp    => 0,
      fixedOnly   => 0,
      logFont     => $_[ 0]-> get_default_font,
   }
}

sub profile_check_in
{
   my ( $self, $p, $default) = @_;
   $self-> SUPER::profile_check_in( $p, $default);
   $p-> { logFont} = {} unless exists $p->{ logFont};
   $p-> { logFont} = Prima::Drawable-> font_match( $p->{ logFont}, $default->{ logFont}, 1);
}

sub init
{
   my $self = shift;
   my %profile = $self-> SUPER::init(@_);
   my $j;

   $self-> {showHelp}  = $profile{showHelp};
   $self-> {logFont}   = $profile{logFont};
   $self-> {fixedOnly} = $profile{fixedOnly};

   my $gr = $self-> insert( CheckBoxGroup =>
      origin => [ 10, 10],
      size   => [ 150, 150],
      name   => 'Style',
   );

   $j = $gr-> insert( CheckBox =>
      origin => [ 15, 95],
      size   => [ 96, 36],
      name   => 'FontStyleButton',
      text   => '~Bold',
      delegations => [$self, 'Click'],
   );

   $j = $gr-> insert( CheckBox =>
      origin => [ 15, 65],
      size   => [ 96, 36],
      name   => 'FontStyleButton',
      text   => '~Italic',
      delegations => [$self, 'Click'],
   );

   $j = $gr-> insert( CheckBox =>
      origin => [ 15, 35],
      size   => [ 96, 36],
      name   => 'FontStyleButton',
      text   => '~Underline',
      delegations => [$self, 'Click'],
   );

   $j = $gr-> insert( CheckBox =>
      origin => [ 15, 5],
      size   => [ 96, 36],
      name   => 'FontStyleButton',
      text   => 'Strike ~out',
      delegations => [$self, 'Click'],
   );

   my $name = $self-> insert( ComboBox =>
      origin => [ 10, 165],
      size   => [ 250, 150],
      name   => 'Name',
      style  => cs::Simple,
      onSelectItem => sub { $self-> Name_SelectItem( @_);},
   );

   $self-> insert( Label =>
      origin    => [ 10, 320],
      size      => [ 96, 18],
      text      => '~Font:',
      focusLink => $name,
   );

   my $size = $self-> insert( ComboBox =>
      origin => [ 275, 165],
      size   => [ 150, 150],
      name   => 'Size',
      style  => cs::Simple,
      delegations => ['Change'],
   );

   $self-> insert( Label =>
      origin    => [ 275, 320],
      size      => [ 96, 18],
      text      => '~Size:',
      focusLink => $size,
   );

   $gr = $self-> insert( GroupBox =>
      origin     => [ 175, 40],
      size       => [ 355, 120],
      name       => 'Sample',
   );
   
   $j = $gr-> insert( Widget =>
      origin     => [ 5, 5],
      size       => [ 345, 90],
      name       => 'Example',
      delegations=> [ $self, 'Paint', 'FontChanged'],
   );

   my $enc = $self-> insert( ComboBox =>
      origin     => [ 290, 10],
      size       => [ 240, 20],
      name       => 'Encoding',
      style      => cs::DropDownList,
      delegations=> [ 'Change' ],
   );

   $self-> insert( Label => 
      origin     => [ 175, 10],
      size       => [ 96, 18],
      text       => '~Encoding',
      focusLink  => $enc,
   );
   
   $self-> insert( Button =>
      origin      => [ 435, 280],
      size        => [ 96, 36],
      text        => '~OK',
      default     => 1,
      modalResult => mb::OK,
   );

   $self-> insert( Button =>
      origin      => [ 435, 235],
      size        => [ 96, 36],
      text        => 'Cancel',
      modalResult => mb::Cancel,
   );

   $self->insert( Button =>
      origin      => [ 435, 190],
      size        => [ 96, 36],
      name        => 'Help',
      text        => '~Help',
   ) if $self->{showHelp};

   $self-> refresh_fontlist;
   $self-> logfont_to_view;
   $self-> apply( %{$self->{logFont}});

   return %profile;
}

sub refresh_fontlist
{
   my $self = $_[0];
   my %fontList;
   my @fontItems;

   for ( sort { $a->{name} cmp $b->{name}} @{$::application-> fonts})
   {
      next if $self->{fixedOnly} and $_->{pitch} != fp::Fixed;
      $fontList{$_->{name}} = $_;
      push ( @fontItems, $_->{name});
   }

   $self->{fontList}  = \%fontList;
   $self->{fontItems} = \@fontItems;

   $self-> Name-> items( \@fontItems);
   $self-> Name-> text( $self->{logFont}->{name});
   $self-> reset_sizelist( 1);
}

sub reset_sizelist
{
   my ( $self, $name_changed) = @_;
   my $Name = $self-> Name;
   my $fn   = $Name-> List-> get_items( $Name-> focusedItem);
   my @sizes;

   if ( defined $fn) {
      my $current_encoding = $self-> Encoding-> List-> get_items( $self-> Encoding-> List-> focusedItem) || '';
      
      my @list = @{$::application-> fonts( $fn, $name_changed ? '' : $current_encoding)};

      if ( $name_changed) {
         my %enc;
         my @enc_items;
         for ( map { $_-> {encoding}} @list) {
            next if $enc{$_};
            push ( @enc_items, $_ );
            $enc{$_} = 1;
         }
         my $found = 0;
         my $i = 0;
         
         for ( @enc_items) {
            $found = $i, last if $_ eq $current_encoding;
            $i++;
         }
         $self-> Encoding-> List-> items( \@enc_items);
         $self-> Encoding-> text( $current_encoding = $enc_items[ $found]);
      }
      
      for ( @list)
      {
         next if $current_encoding ne $_->{encoding};
         if ( $_->{ vector})
         {
            @sizes = qw( 8 9 10 11 12 14 16 18 20 22 24 26 28 32 48 72);
            last;
         } else {
            push ( @sizes, $_->{size});
         }
      }
      my %k = map { $_ => 1 } @sizes;
      @sizes = sort { $a <=> $b } keys %k;
      @sizes = (10) unless scalar @sizes;
   }
   $self-> Size-> items( \@sizes);
   $self-> Size-> focusedItem(0);
   return $fn;
}

sub logfont_to_view
{
   my $self = $_[0];
   my %f = %{$self-> {logFont}};
   $self-> Name-> text( $f{name});
   $self-> Size-> text( $f{size});
   $self-> Encoding-> text( $f{encoding});
   my $grp = $self-> Style;
   my $style = $f{style};
   $grp-> value( 0 |
     (( $style & fs::Bold)       ? 1 : 0) |
     (( $style & fs::Italic)     ? 2 : 0) |
     (( $style & fs::Underlined) ? 4 : 0) |
     (( $style & fs::StruckOut)  ? 8 : 0)
  );
}

sub apply
{
   my ( $self, %hash) = @_;
   delete $hash{$_} for ( qw( width height direction));
   $self-> {logFont} = $self-> font_match( \%hash, $self-> {logFont}, 0);
   delete $self->{logFont}->{$_} for ( qw( width height direction));
   $self->{fixedOnly} ? $self->{logFont}->{pitch} = fp::Fixed : delete $self->{logFont}->{pitch};
   $self-> { normalFontSet} = 1;
   $self-> Sample-> Example-> font( $self-> {logFont});
   delete $self-> { normalFontSet};
}

sub Example_Paint
{
   my ( $owner, $self, $canvas) = @_;
   my @size = $canvas-> size;
   $canvas-> color( $canvas-> get_nearest_color( $self-> backColor));
   $canvas-> bar( 0, 0, @size);
   $canvas-> color( cl::Black);
   my $f = $self-> font;
   my $line = 'AaBbYyZz';
   $canvas-> text_out(
      $line,
      ( $size[0] - $canvas-> get_text_width( $line)) / 2,
      ( $size[1] - $f-> height) / 2
   );
}

sub Example_FontChanged
{
   my ( $owner, $example) = @_;
   return if $owner-> {normalFontSet};
   $owner-> logFont( $example-> font);
}

sub Name_SelectItem
{
   my ( $owner, $self, $index, $state) = @_;
   my $sz  = $owner-> {logFont}->{size};
   my $fn = $owner-> reset_sizelist(1);
   $owner-> Size-> InputLine-> text( $sz);
   $owner-> apply( name => $fn, size => $sz, encoding => $owner-> Encoding-> text);
}

sub Size_Change
{
   my ( $owner, $self) = @_;
   my $sz = $self-> text;
   return unless $sz =~ m/^\s*([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\s*$/;
   return if $sz < 2 or $sz > 2048;
   $owner-> apply( size => $sz);
}

sub Encoding_Change
{
   my ( $owner, $self) = @_;
   my $sz = $owner-> {logFont}->{size};
   my $fn = $owner-> reset_sizelist(0);
   $owner-> Size-> InputLine-> text( $sz);
   $owner-> apply( size => $sz, encoding => $owner-> Encoding-> text);
}

sub FontStyleButton_Click
{
   my $self = $_[0];
   my $v    = $self-> Style-> value;
   $self -> apply( style => 0 |
      (( $v & 1) ? fs::Bold       : 0) |
      (( $v & 2) ? fs::Italic     : 0) |
      (( $v & 4) ? fs::Underlined : 0) |
      (( $v & 8) ? fs::StruckOut  : 0)
   );
}


sub set_fixed_only
{
   my ( $self, $fo) = @_;
   return if $fo == $self->{fixedOnly};
   $self->{fixedOnly} = $fo;
   $self-> refresh_fontlist;
}

sub logFont
{
   my $self = $_[0];
   return $self-> Sample-> Example-> get_font unless $#_;
   $self-> {logFont} = $self-> font_match( $_[1], $self->{logFont}, 1);
   $self-> logfont_to_view;
   $self-> apply( %{$self->{logFont}});
}

sub showHelp         { ($#_)? shift->raise_ro('showHelp')  : return $_[0]->{showHelp}};
sub fixedOnly        { ($#_)? shift->set_fixed_only($_[1]) : return $_[0]->{fixedOnly}};

1;

__DATA__

=head1 NAME

Prima::FontDialog - standard font dialog

=head1 DESCRIPTION

The dialog provides selection of font by name, style, size, and encoding.
The font selected is returned by L<logFont> property.

=head1 SYNOPSIS

   use Prima::FontDialog;
   my $f = Prima::FontDialog-> create;
   return unless $f-> execute == mb::OK;
   $f = $f-> logFont;
   print "$_:$f->{$_}\n" for sort keys %$f;

=head1 API

=head2 Properties

=over

=item fixedOnly BOOLEAN

Selects whether only the fonts of fixed pitch ( 1 ) or all fonts ( 0 )
are displayed in the selection list.

Default value: 0

=item logFont FONT

Provides access to the interactive font selection as a hash reference.
FONT format is fully compatible with C<Prima::Drawable::font>.

=item showHelp BOOLEAN

Create-only property.

Specifies if the help button is displayed in the dialog.

Default value: 0

=back

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<Prima::Window>, L<Prima::Drawable>.

=cut
