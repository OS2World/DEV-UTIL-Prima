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
#  $Id: mouse_tale.pl,v 1.6 2003/08/27 18:59:25 dk Exp $
#

=pod 
=item NAME

The mouse tale from Alice In Wonderland

=item FEATURES

Demonstrates Prima::TextView capabilities

=cut

use strict;
use Prima;
use Prima::TextView;
use Prima::Application;


my @tale = split( "\n", <<TALE);
Fury said to
a mouse, That 
he met
in the
house,
"Let us
both go
to law:
I will
prosecute
you.--
Come, I'll
take no
denial;
We must
have a
trial:
For
really
this
morning
I've
nothing
to do."
Said the
mouse to
the cur,
"Such a
trial,
dear sir,
With no
jury or
judge
would be
wasting
our breath."
"I'll be
judge,
I'll be
jury,"
Said
cunning
old Fury:
"I'll try
the whole
cause,
and
condemn
you
to
death."
TALE

my @indents = (
0,2,11,14,16,15,11,9,8,4,3,5,9,11,14,21,25,26,22,20,21,27,21,19,
17,14,11,14,19,16,13,10,7,8,10,12,14,13,10,7,4,9,13,16,21,26,28,
22,24,23,24
);

my ( $w, $t);
my $initfs = 20;

$w = Prima::MainWindow-> create(
   name => 'Mouse tale',
   packPropagate => 0,
   menuItems => [
      ['~Font' => [
          [ '~Increase' , 'Ctrl+Plus' , km::Ctrl|ord('+') , sub {
             return if $initfs >= 100; 
             $initfs += 2; 
             typeset();
          }],
          [ '~Decrease' , 'Ctrl+Minus' , km::Ctrl|ord('-') , sub {
             return if $initfs < 12; 
             $initfs -= 2; 
             typeset();
          }],
      ]],
   ],
);

$t = Prima::TextView-> create(
   owner => $w,
   text     => join( "\n", @tale),
   pack     => { expand => 1, fill => 'both' },
);

sub typeset
{
   my ($i, $tb, $pos, $y, $fh, $fd, $fs, $state, $indent, $maxw, $cr, $old_from, $old_x);

   $y = 0;
   $pos = 0;
   $maxw = 0;
   $cr = length ("\n");
   $t-> {blocks} = [];

   # Since we need to calculate text widths, this way it goes faster
   $t-> begin_paint_info; 
   my $fontstate = $t-> create_state;

   # select initial font size and page width
   $$fontstate[ tb::BLK_FONT_SIZE] = $initfs;
   $t-> realize_state( $t, $fontstate, tb::REALIZE_FONTS);
   $fs = $t-> font-> height;
   $fd = $t-> font-> descent;
   $indent = $t-> get_text_width('m');
   $old_from = 0;
   $old_x = $indent * 4; # initial horizontal offset
   for ( $i = 0, $pos = 0; $i < scalar @tale; $i++, $y += $fh) {
      my $len = length($tale[$i]);

      $tb = tb::block_create();
      $fs = 12 + ( $fs - 12) * 0.97;
      if ( int($fs) != $t-> font-> size) {
         $$fontstate[ tb::BLK_FONT_SIZE] = int($fs) + tb::F_HEIGHT;
         $t-> realize_state( $t, $fontstate, tb::REALIZE_FONTS);
         $fh = $t-> font-> height;
         $fd = $t-> font-> descent;
      }
      
      my ( $from, $width) = ( $indent * $indents[$i], $indent * $len);
     
      # set block position and attributes - each block contains single line and single text op
      $$tb[ tb::BLK_TEXT_OFFSET] = $pos;
      $$tb[ tb::BLK_WIDTH]  = $t-> get_text_width( $tale[$i]);
      $$tb[ tb::BLK_HEIGHT] = $fh;
      $$tb[ tb::BLK_Y] = $y;
      $$tb[ tb::BLK_APERTURE_Y] = $fd;
      $$tb[ tb::BLK_X] = $old_x + ( $from - $old_from) * $$tb[tb::BLK_WIDTH] / $width;
      $$tb[ tb::BLK_COLOR]     = cl::Fore;
      $$tb[ tb::BLK_BACKCOLOR] = cl::Back;
      $$tb[ tb::BLK_FONT_SIZE]  = int($fs) + tb::F_HEIGHT;

      if ( $tale[$i] =~ /^you\.\-\-/) {
         # Italicize 'you' in the string
         my $w1 = $t-> get_text_width( 'you');
         my $w2 = $t-> get_text_width( '.');
         my $w3 = $t-> get_text_width( '--');
         push @$tb, 
            tb::fontStyle( fs::Italic),
            tb::text( 0, 3, $w1 + $fh / 3),
            tb::fontStyle( fs::Normal),
            tb::text( 3, 1, $w2),
         # Example of custom drawings - replace double '-' character by a long hyphen.
         # Note when copying from the selection, the '--' is still present in the text
            tb::code( \&hyphen, $w3 - 1),
         # The ::code by itself occupies no place, so ::moveto explicitly sets
         # the hyphen dimensions
            tb::moveto( $fh, $w3);
         # Since 'you' italic is a bit wider that the non-italic 'you',
         # fh/3 is here as a rough compensation. A more presice calculation
         # requires the exact width of the italicized string.
         $$tb[ tb::BLK_WIDTH] += $fh / 3;
      } else {
         # Add text op and its width, the store the full block
         push @$tb, tb::text( 0, $len, $$tb[tb::BLK_WIDTH]);
      }
      push @{$t-> {blocks}}, $tb;

      $maxw = $$tb[ tb::BLK_WIDTH] + $$tb[ tb::BLK_X] 
         if $maxw < $$tb[ tb::BLK_WIDTH] + $$tb[ tb::BLK_X]; 
      $pos += $len + $cr;
      $old_x = $$tb[ tb::BLK_X];
      $old_from = $from;
   }

   $t-> end_paint_info;

   $t-> recalc_ymap; # Need this as a finalization act to validate the position lookup table
   $t-> paneSize( $maxw + $indent * 4, $y);
}

sub hyphen
# draws a hyphen
{
   my ( $self, $canvas, $block, $state, $x, $y, $width) = @_;
   $y += $$block[ tb::BLK_HEIGHT] / 2 - $$block[ tb::BLK_APERTURE_Y];
   $canvas-> line( $x, $y, $x + $width, $y);
}

typeset;
run Prima;
