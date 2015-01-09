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
#  $Id: Notebooks.pm,v 1.24 2003/09/28 19:52:20 dk Exp $
use strict;
use Prima::Const;
use Prima::Classes;
use Prima::IntUtils;

package Prima::TabSet;
use vars qw(@ISA);
@ISA = qw(Prima::Widget Prima::MouseScroller);


{
my %RNT = (
   %{Prima::Widget->notification_types()},
   DrawTab     => nt::Action,
   MeasureTab  => nt::Action,
);

sub notification_types { return \%RNT; }
}

use constant DefGapX   => 10;
use constant DefGapY   => 5;
use constant DefLeftX  => 5;
use constant DefArrowX => 25;

my @warpColors = (
   0x50d8f8, 0x80d8a8, 0x8090f8, 0xd0b4a8, 0xf8fca8,
   0xa890a8, 0xf89050, 0xf8d850, 0xf8b4a8, 0xf8d8a8,
);

sub profile_default
{
   my $def = $_[ 0]-> SUPER::profile_default;
   my $font = $_[ 0]-> get_default_font;
   my %prf = (
      colored          => 1,
      firstTab         => 0,
      focusedTab       => 0,
      height           => $font-> { height} > 14 ? $font-> { height} * 2 : 28,
      ownerBackColor   => 1,
      selectable       => 1,
      selectingButtons => 0,
      tabStop          => 1,
      topMost          => 1,
      tabIndex         => 0,
      tabs             => [],
   );
   @$def{keys %prf} = values %prf;
   return $def;
}


sub init
{
   my $self = shift;
   $self->{tabIndex} = -1;
   for ( qw( colored firstTab focusedTab topMost lastTab arrows)) { $self->{$_} = 0; }
   $self->{tabs}     = [];
   $self->{widths}   = [];
   my %profile = $self-> SUPER::init(@_);
   for ( qw( colored topMost tabs focusedTab firstTab tabIndex)) { $self->$_( $profile{ $_}); }
   $self-> recalc_widths;
   $self-> reset;
   return %profile;
}


sub reset
{
   my $self = $_[0];
   my @size = $self-> size;
   my $w = DefLeftX * 2 + DefGapX;
   for ( @{$self->{widths}}) { $w += $_ + DefGapX; }
   $self->{arrows} = (( $w > $size[0]) and ( scalar( @{$self->{widths}}) > 1));
   if ( $self->{arrows}) {
      my $ft = $self->{firstTab};
      $w  = DefLeftX * 2 + DefGapX;
      $w += DefArrowX if $ft > 0;
      my $w2 = $w;
      my $la = $ft > 0;
      my $i;
      my $ra = 0;
      my $ww = $self->{widths};
      for ( $i = $ft; $i < scalar @{$ww}; $i++) {
         $w += DefGapX + $$ww[$i];
         if ( $w + DefGapX + DefLeftX >= $size[0]) {
            $ra = 1;
            $i-- if $i > $ft && $w - $$ww[$i] >= $size[0] - DefLeftX - DefArrowX - DefGapX;
            last;
         }
      }
      $i = scalar @{$self->{widths}} - 1 if $i >= scalar @{$self->{widths}};
      $self->{lastTab} = $i;
      $self->{arrows} = ( $la ? 1 : 0) | ( $ra ? 2 : 0);
   } else {
      $self->{lastTab} = scalar @{$self->{widths}} - 1;
   }
}

sub recalc_widths
{
   my $self = $_[0];
   my @w;
   my $i;
   my ( $notifier, @notifyParms) = $self-> get_notify_sub(q(MeasureTab));
   $self-> begin_paint_info;
   $self-> push_event;
   for ( $i = 0; $i < scalar @{$self->{tabs}}; $i++)
   {
      my $iw = 0;
      $notifier->( @notifyParms, $i, \$iw);
      push ( @w, $iw);
   }
   $self-> pop_event;
   $self-> end_paint_info;
   $self-> {widths}    = [@w];
}

sub on_mousedown
{
   my ( $self, $btn, $mod, $x, $y) = @_;
   return if $self->{mouseTransaction};
   $self-> clear_event;
   my ( $a, $ww, $ft, $lt) = (
      $self->{arrows}, $self->{widths}, $self->{firstTab}, $self->{lastTab}
   );
   if (( $a & 1) and ( $x < DefLeftX + DefGapX * 2 + DefArrowX)) {
      $self-> firstTab( $self-> firstTab - 1);
      $self-> capture(1);
      $self->{mouseTransaction} = -1;
      $self-> scroll_timer_start;
      $self-> scroll_timer_semaphore(0);
      return;
   }
   my @size = $self-> size;
   if (( $a & 2) and ( $x >= $size[0] - DefLeftX - DefGapX * 2 - DefArrowX)) {
      $self-> firstTab( $self-> firstTab + 1);
      $self-> capture(1);
      $self->{mouseTransaction} = 1;
      $self-> scroll_timer_start;
      $self-> scroll_timer_semaphore(0);
      return;
   }
   my $w = DefLeftX;
   $w += DefGapX + DefArrowX if $a & 1;
   my $i;
   my $found = undef;
   for ( $i = $ft; $i <= $lt; $i++) {
      $found = $i, last if $x < $w + $$ww[$i] + DefGapX;
      $w += $$ww[$i] + DefGapX;
   }
   return unless defined $found;
   if ( $found == $self-> {tabIndex}) {
      $self-> focusedTab( $found);
      $self-> focus;
   } else {
      $self-> tabIndex( $found);
   }
}

sub on_mouseup
{
   my ( $self, $btn, $mod, $x, $y) = @_;
   return unless $self->{mouseTransaction};
   $self-> capture(0);
   $self-> scroll_timer_stop;
   $self->{mouseTransaction} = undef;
}


sub on_mousemove
{
   my ( $self, $mod, $x, $y) = @_;
   return unless $self->{mouseTransaction};
   return unless $self->scroll_timer_semaphore;
   $self->scroll_timer_semaphore(0);
   my $ft = $self-> firstTab;
   $self-> firstTab( $ft + $self->{mouseTransaction});
   $self-> notify(q(MouseUp),1,0,0,0) if $ft == $self-> firstTab;
}

sub on_mouseclick
{
   my $self = shift;
   $self-> clear_event;
   return unless pop;
   $self-> clear_event unless $self-> notify( "MouseDown", @_);
}

sub on_keydown
{
   my ( $self, $code, $key, $mod) = @_;
   if ( $key == kb::Left || $key == kb::Right) {
      $self-> focusedTab( $self-> focusedTab + (( $key == kb::Left) ? -1 : 1));
      $self-> clear_event;
      return;
   }
   if ( $key == kb::PgUp || $key == kb::PgDn) {
      $self-> tabIndex( $self-> tabIndex + (( $key == kb::PgUp) ? -1 : 1));
      $self-> clear_event;
      return;
   }
   if ( $key == kb::Home || $key == kb::End) {
      $self-> tabIndex(( $key == kb::Home) ? 0 : scalar @{$self->{tabs}});
      $self-> clear_event;
      return;
   }
   if ( $key == kb::Space || $key == kb::Enter) {
      $self-> tabIndex( $self-> focusedTab);
      $self-> clear_event;
      return;
   }
}

sub on_paint
{
   my ($self,$canvas) = @_;
   my @clr  = ( $self-> color, $self-> backColor);
   @clr = ( $self-> disabledColor, $self-> disabledBackColor) if ( !$self-> enabled);
   my @c3d  = ( $self-> dark3DColor, $self-> light3DColor);
   my @size = $canvas-> size;

   $canvas-> color( $clr[1]);
   $canvas-> bar( 0, 0, @size);
   my ( $ft, $lt, $a, $ti, $ww, $tm) =
   ( $self->{firstTab}, $self->{lastTab}, $self->{arrows}, $self->{tabIndex},
     $self->{widths}, $self->{topMost});
   my $i;
   my ( $notifier, @notifyParms) = $self-> get_notify_sub(q(DrawTab));
   $self-> push_event;
   my $atX = DefLeftX;
   $atX += DefArrowX + DefGapX if $a & 1;
   my $atXti = undef;
   for ( $i = $ft; $i <= $lt; $i++) {
      $atX += $$ww[$i] + DefGapX;
   }
   my @colorSet = ( @clr, @c3d);

   $canvas-> clipRect( 0, 0, $size[0] - DefArrowX - DefGapX - DefLeftX, $size[1]) if $a & 2;
   for ( $i = $lt; $i >= $ft; $i--) {
      $atX -= $$ww[$i] + DefGapX;
      $atXti = $atX, next if $i == $ti;
      my @poly = (
         $atX, DefGapY, $atX + DefGapX, $size[1] - DefGapY - 1,
         $atX + DefGapX + $$ww[$i], $size[1] - DefGapY - 1,
         $atX + DefGapX * 2 + $$ww[$i], DefGapY
      );
      @poly[1,3,5,7] = @poly[3,1,7,5] unless $tm;
      $notifier->( @notifyParms, $canvas, $i, \@colorSet, \@poly);
   }

   my $swapDraw = ( $ti == $lt) && ( $a & 2);

   goto PaintSelTabBefore if $swapDraw;
PaintEarsThen:
   $canvas-> clipRect( 0, 0, @size) if $a & 2;
   if ( $a & 1) {
      my $x = DefLeftX;
      my @poly = (
         $x, DefGapY, $x + DefGapX, $size[1] - DefGapY - 1,
         $x + DefGapX + DefArrowX,   $size[1] - DefGapY - 1,
         $x + DefGapX * 2 + DefArrowX, DefGapY
      );
      @poly[1,3,5,7] = @poly[3,1,7,5] unless $tm;
      $notifier->( @notifyParms, $canvas, -1, \@colorSet, \@poly);
   }
   if ( $a & 2) {
      my $x = $size[0] - DefLeftX - DefArrowX - DefGapX * 2;
      my @poly = (
         $x, DefGapY, $x + DefGapX, $size[1] - DefGapY - 1,
         $x + DefGapX + DefArrowX, $size[1] - DefGapY - 1,
         $x + DefGapX * 2 + DefArrowX, DefGapY
      );
      @poly[1,3,5,7] = @poly[3,1,7,5] unless $tm;
      $notifier->( @notifyParms, $canvas, -2, \@colorSet, \@poly);
   }

   $canvas-> color( $c3d[0]);
   my @ld = $tm ? ( 0, DefGapY) : ( $size[1] - 0, $size[1] - DefGapY - 1);
   $canvas-> line( $size[0] - 1, $ld[0], $size[0] - 1, $ld[1]);
   if ($tm) {
      $canvas-> color( $c3d[1]);
      $canvas-> line( 0, $ld[1], $size[0] - 1, $ld[1]);
      $canvas-> line( 0, $ld[0], 0, $ld[1]);
   } else {
      $canvas-> line( 0, $ld[1], $size[0] - 1, $ld[1]);
      $canvas-> color( $c3d[1]);
      $canvas-> line( 0, $ld[0], 0, $ld[1]);
   }
   $canvas-> color( $clr[0]);
   goto EndOfSwappedPaint if $swapDraw;

PaintSelTabBefore:
   if ( defined $atXti) {
      my @poly = (
         $atXti, DefGapY, $atXti + DefGapX, $size[1] - DefGapY - 1,
         $atXti + DefGapX + $$ww[$ti], $size[1] - DefGapY - 1,
         $atXti + DefGapX * 2 + $$ww[$ti], DefGapY
      );
      @poly[1,3,5,7] = @poly[3,1,7,5] unless $tm;
      my @poly2 = $tm ? (
         $atXti, DefGapY, $atXti + DefGapX * 2 + $$ww[$ti], DefGapY,
         $atXti + DefGapX * 2 + $$ww[$ti] - 4, 0, $atXti + 4, 0
      ) : (
         $atXti, $size[1] - 1 - DefGapY, $atXti + DefGapX * 2 + $$ww[$ti], $size[1] - 1 - DefGapY,
         $atXti + DefGapX * 2 + $$ww[$ti] - 4, $size[1]-1, $atXti + 4, $size[1]-1
      );
      $canvas-> clipRect( 0, 0, $size[0] - DefArrowX - DefGapX - DefLeftX, $size[1]) if $a & 2;
      $notifier->( @notifyParms, $canvas, $ti, \@colorSet, \@poly, $swapDraw ? undef : \@poly2);
   }
   goto PaintEarsThen if $swapDraw;

EndOfSwappedPaint:
   $self-> pop_event;
}

sub on_size
{
   my ( $self, $ox, $oy, $x, $y) = @_;
   if ( $x > $ox && (( $self->{arrows} & 2) == 0)) {
       my $w  = DefLeftX * 2 + DefGapX;
       my $ww = $self->{widths};
       $w += DefArrowX + DefGapX if $self->{arrows} & 1;
       my $i;
       my $set = 0;
       for ( $i = scalar @{$ww} - 1; $i >= 0; $i--) {
          $w += $$ww[$i] + DefGapX;
          $set = 1, $self-> firstTab( $i + 1), last if $w >= $x;
       }
       $self-> firstTab(0) unless $set;
   }
   $self-> reset;
}
sub on_fontchanged { $_[0]-> reset; $_[0]-> recalc_widths; }
sub on_enter       { $_[0]-> repaint; }
sub on_leave       { $_[0]-> repaint; }

sub on_measuretab
{
   my ( $self, $index, $sref) = @_;
   $$sref = $self-> get_text_width( $self->{tabs}->[$index]) + DefGapX * 4;
}

# see L<DrawTab> below for more info

sub on_drawtab
{
   my ( $self, $canvas, $i, $clr, $poly, $poly2) = @_;
   $canvas-> color(( $self->{colored} && ( $i >= 0)) ?
      ( $warpColors[ $i % scalar @warpColors]) : $$clr[1]);
   $canvas-> fillpoly( $poly);
   $canvas-> fillpoly( $poly2) if $poly2;
   $canvas-> color( $$clr[3]);
   $canvas-> polyline( [@{$poly}[0..($self->{topMost}?5:3)]]);
   $canvas-> color( $$clr[2]);
   $canvas-> polyline( [@{$poly}[($self->{topMost}?4:2)..7]]);
   $canvas-> line( $$poly[4]+1, $$poly[5], $$poly[6]+1, $$poly[7]);
   $canvas-> color( $$clr[0]);
   if ( $i >= 0) {
      my  @tx = (
         $$poly[0] + ( $$poly[6] - $$poly[0] - $self->{widths}->[$i]) / 2 + DefGapX * 2,
         $$poly[1] + ( $$poly[3] - $$poly[1] - $canvas-> font-> height) / 2
      );
      $canvas-> text_out( $self->{tabs}->[$i], @tx);
      $canvas-> rect_focus( $tx[0] - 1, $tx[1] - 1,
         $tx[0] + $self->{widths}->[$i] - DefGapX * 4 + 1, $tx[1] + $canvas-> font-> height + 1)
            if ( $i == $self->{focusedTab}) && $self-> focused;
   } elsif ( $i == -1) {
      $canvas-> fillpoly([
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.6,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.2,
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.6,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.6,
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.4,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.4,
      ]);
   } elsif ( $i == -2) {
      $canvas-> fillpoly([
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.4,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.2,
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.4,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.6,
         $$poly[0] + ( $$poly[6] - $$poly[0]) * 0.6,
         $$poly[1] + ( $$poly[3] - $$poly[1]) * 0.4,
      ]);
   }
}

sub get_item_width
{
   return $_[0]->{widths}->[$_[1]];
}

sub tab2firstTab
{
   my ( $self, $ti) = @_;
   if (( $ti >= $self->{lastTab}) and ( $self->{arrows} & 2) and ( $ti != $self->{firstTab})) {
      my $w = DefLeftX;
      $w += DefArrowX + DefGapX if $self->{arrows} & 1;
      my $i;
      my $W = $self-> width;
      my $ww = $self->{widths};
      my $moreThanOne = ( $ti - $self->{firstTab}) > 0;
      for ( $i = $self->{firstTab}; $i <= $ti; $i++) {
         $w += $$ww[$i] + DefGapX;
      }
      my $lim = $W - DefLeftX - DefArrowX - DefGapX * 2;
      $lim -= DefGapX * 2 if $moreThanOne;
      if ( $w >= $lim) {
         my $leftw = DefLeftX * 2 + DefGapX + DefArrowX;
         $leftw += DefArrowX + DefGapX if $self->{arrows} & 1;
         $leftw = $W - $leftw;
         $leftw -= $$ww[$ti] if $moreThanOne;
         $w = 0;
         for ( $i = $ti; $i >= 0; $i--) {
            $w += $$ww[$i] + DefGapX;
            last if $w > $leftw;
         }
         return $i + 1;
      }
   } elsif ( $ti < $self->{firstTab}) {
      return $ti;
   }
   return undef;
}

sub set_tab_index
{
   my ( $self, $ti) = @_;
   $ti = 0 if $ti < 0;
   my $mx = scalar @{$self->{tabs}} - 1;
   $ti = $mx if $ti > $mx;
   return if $ti == $self->{tabIndex};
   $self-> {tabIndex} = $ti;
   $self-> {focusedTab} = $ti;
   my $newFirstTab = $self-> tab2firstTab( $ti);
   defined $newFirstTab ?
      $self-> firstTab( $newFirstTab) :
      $self-> repaint;
   $self-> notify(q(Change));
}

sub set_first_tab
{
   my ( $self, $ft) = @_;
   $ft = 0 if $ft < 0;
   unless ( $self->{arrows}) {
      $ft = 0;
   } else {
      my $w = DefLeftX * 2 + DefGapX * 2;
      $w += DefArrowX if $ft > 0;
      my $haveRight = 0;
      my $i;
      my @size = $self-> size;
      for ( $i = $ft; $i < scalar @{$self->{widths}}; $i++) {
         $w += DefGapX + $self->{widths}->[$i];
         $haveRight = 1, last if $w >= $size[0];
      }
      unless ( $haveRight) {
         $w += DefGapX;
         for ( $i = $ft - 1; $i >= 0; $i--) {
            $w += DefGapX + $self->{widths}->[$i];
            if ( $w >= $size[0]) {
               $i++;
               $ft = $i if $ft > $i;
               last;
            }
         }
      }
   }
   return if $self->{firstTab} == $ft;
   $self-> {firstTab} = $ft;
   $self-> reset;
   $self-> repaint;
}

sub set_focused_tab
{
   my ( $self, $ft) = @_;
   $ft = 0 if $ft < 0;
   my $mx = scalar @{$self->{tabs}} - 1;
   $ft = $mx if $ft > $mx;
   $self->{focusedTab} = $ft;

   my $newFirstTab = $self-> tab2firstTab( $ft);
   defined $newFirstTab ?
      $self-> firstTab( $newFirstTab) :
      ( $self-> focused ? $self-> repaint : 0);
}

sub set_tabs
{
   my $self = shift;
   my @tabs = ( scalar @_ == 1 && ref( $_[0]) eq q(ARRAY)) ? @{$_[0]} : @_;
   $self-> {tabs} = \@tabs;
   $self-> recalc_widths;
   $self-> reset;
   $self-> lock;
   $self-> firstTab( $self-> firstTab);
   $self-> tabIndex( $self-> tabIndex);
   $self-> unlock;
   $self-> update_view;
}

sub set_top_most
{
   my ( $self, $tm) = @_;
   return if $tm == $self->{topMost};
   $self->{topMost} = $tm;
   $self-> repaint;
}

sub colored      {($#_)?($_[0]->{colored}=$_[1],$_[0]->repaint)         :return $_[0]->{colored}}
sub focusedTab   {($#_)?($_[0]->set_focused_tab(    $_[1]))             :return $_[0]->{focusedTab}}
sub firstTab     {($#_)?($_[0]->set_first_tab(    $_[1]))               :return $_[0]->{firstTab}}
sub tabIndex     {($#_)?($_[0]->set_tab_index(    $_[1]))               :return $_[0]->{tabIndex}}
sub topMost      {($#_)?($_[0]->set_top_most (    $_[1]))               :return $_[0]->{topMost}}
sub tabs         {($#_)?(shift->set_tabs     (    @_   ))               :return $_[0]->{tabs}}

package Prima::Notebook;
use vars qw(@ISA);
@ISA = qw(Prima::Widget);

sub profile_default
{
   my $def = $_[ 0]-> SUPER::profile_default;
   my %prf = (
      defaultInsertPage => undef,
      pageCount         => 0,
      pageIndex         => 0,
      tabStop           => 0,
      ownerBackColor    => 1,
   );
   @$def{keys %prf} = values %prf;
   return $def;
}

sub init
{
   my $self = shift;
   $self->{pageIndex} = -1;
   $self->{pageCount} = 0;
   my %profile = $self-> SUPER::init(@_);
   $self-> {pageCount} = $profile{pageCount};
   $self-> {pageCount} = 0 if $self-> {pageCount} < 0;
   my $j = $profile{pageCount};
   push (@{$self-> {widgets}},[]) while $j--;
   for ( qw( pageIndex defaultInsertPage)) { $self->$_( $profile{ $_}); }
   return %profile;
}

sub set_page_index
{
   my ( $self, $pi) = @_;
   $pi = 0 if $pi < 0;
   $pi = $self->{pageCount} - 1 if $pi > $self->{pageCount} - 1;
   my $sel = $self-> selected;
   return if $pi == $self->{pageIndex};
   $self-> lock;
   my $cp = $self->{widgets}->[$self->{pageIndex}];
   if ( defined $cp) {
      for ( @$cp) {
         $$_[1] = $$_[0]-> enabled;
         $$_[2] = $$_[0]-> visible;
         $$_[3] = $$_[0]-> current;
         $$_[0]-> visible(0);
         $$_[0]-> enabled(0);
      }
   }
   $cp = $self->{widgets}->[$pi];
   if ( defined $cp) {
      my $hasSel;
      for ( @$cp) {
         $$_[0]-> enabled($$_[1]);
         $$_[0]-> visible($$_[2]);
         if ( !defined $hasSel && $$_[3]) {
            $hasSel = 1;
            $$_[0]-> select if $sel;
         }
         $$_[0]-> current($$_[3]);
      }
   }
   my $i = $self->{pageIndex};
   $self->{pageIndex} = $pi;
   $self-> notify(q(Change), $i, $pi);
   $self-> unlock;
   $self-> update_view;
}

sub insert_page
{
   my ( $self, $at) = @_;
   $at = -1 unless defined $at;
   $at = $self->{pageCount} if $at < 0 || $at > $self->{pageCount};
   splice( @{$self->{widgets}}, $at, 0, []);
   $self->{pageCount}++;
   $self-> pageIndex(0) if $self->{pageCount} == 1;
}

sub delete_page
{
   my ( $self, $at, $removeChildren) = @_;
   $removeChildren = 1 unless defined $removeChildren;
   $at = -1 unless defined $at;
   $at = $self->{pageCount} - 1 if $at < 0 || $at >= $self->{pageCount};
   my @r = splice( @{$self->{widgets}}, $at, 1);
   $self-> {pageCount}--;
   $self-> pageIndex( $self-> pageIndex);
   if ( $removeChildren) {
      $$_[0]-> destroy for @{$r[0]};
   }
}

sub attach_to_page
{
   my $self  = shift;
   my $page  = shift;
   $self-> insert_page if $self-> {pageCount} == 0;
   $page = $self-> {pageCount} - 1 if $page > $self-> {pageCount} - 1 || $page < 0;
   my $cp = $self->{widgets}->[$page];
   for ( @_) {
      next unless $_-> isa('Prima::Widget');
      # $_->add_notification( Enable  => \&_enable  => $self);
      # $_->add_notification( Disable => \&_disable => $self);
      # $_->add_notification( Show    => \&_show    => $self);
      # $_->add_notification( Hide    => \&_hide    => $self);
      my @rec = ( $_, $_->enabled, $_->visible, $_->current);
      push( @{$cp}, [@rec]);
      next if $page == $self->{pageIndex};
      $_-> visible(0);
      $_-> autoEnableChildren(0);
      $_-> enabled(0);
   }
}

sub insert
{
   my $self = shift;
   my $page = defined $self-> {defaultInsertPage} ? $self-> {defaultInsertPage} : $self->pageIndex;
   return $self-> insert_to_page( $page, @_);
}

sub insert_to_page
{
   my $self  = shift;
   my $page  = shift;
   my $sel   = $self-> selected;
   $page = $self-> {pageCount} - 1 if $page > $self-> {pageCount} - 1 || $page < 0;
   $self-> lock;
   my @ctrls = $self-> SUPER::insert( @_);
   $self-> attach_to_page( $page, @ctrls);
   $ctrls[0]-> select if $sel && scalar @ctrls && $page == $self->{pageIndex} && 
      $ctrls[0]-> isa('Prima::Widget');
   $self-> unlock;
   return wantarray ? @ctrls : $ctrls[0];
}

sub insert_transparent
{
   shift-> SUPER::insert( @_);
}

sub contains_widget
{
   my ( $self, $ctrl) = @_;
   my $i;
   my $j;
   my $cptr = $self->{widgets};
   for ( $i = 0; $i < $self->{pageCount}; $i++) {
      my $cp = $$cptr[$i];
      my $j = 0;
      for ( @$cp) {
         return ( $i, $j) if $$_[0] == $ctrl;
         $j++;
      }
   }
   return;
}

sub widgets_from_page
{
   my ( $self, $page) = @_;
   return if $page < 0 or $page >= $self->{pageCount};
   my @r;
   push( @r, $$_[0]) for @{$self->{widgets}->[$page]};
   return @r;
}

sub detach
{
   my ( $self, $widget, $killFlag) = @_;
   $self-> detach_from_page( $widget);
   $self->SUPER::detach( $widget, $killFlag);
}

sub detach_from_page
{
   my ( $self, $ctrl)   = @_;
   my ( $page, $number) = $self-> contains_widget( $ctrl);
   return unless defined $page;
   splice( @{$self->{widgets}->[$page]}, $number, 1);
}

sub delete_widget
{
   my ( $self, $ctrl)   = @_;
   my ( $page, $number) = $self-> contains_widget( $ctrl);
   return unless defined $page;
   $ctrl-> destroy;
}

sub move_widget
{
   my ( $self, $widget, $newPage) = @_;
   my ( $page, $number) = $self-> contains_widget( $widget);
   return unless defined $page;
   @{$self->{widgets}->[$newPage]} = splice( @{$self->{widgets}->[$page]}, $number, 1);
   $self-> repaint if $self->{pageIndex} == $page || $self->{pageIndex} == $newPage;
}


sub set_page_count
{
   my ( $self, $pageCount) = @_;
   $pageCount = 0 if $pageCount < 0;
   return if $pageCount == $self->{pageCount};
   if ( $pageCount < $self->{pageCount}) {
      splice(@{$self-> {widgets}}, $pageCount);
      $self->{pageCount} = $pageCount;
      $self->pageIndex($pageCount - 1) if $self->{pageIndex} < $pageCount - 1;
   } else {
      my $i = $pageCount - $self->{pageCount};
      push (@{$self-> {widgets}},[]) while $i--;
      $self->{pageCount} = $pageCount;
      $self->pageIndex(0) if $self->{pageIndex} < 0;
   }
}

my %virtual_properties = (
   enabled => 1,
   visible => 2,
   current => 3,
);

sub widget_get
{
   my ( $self, $widget, $property) = @_;
   return $widget-> $property() if ! $virtual_properties{$property};
   my ( $page, $number) = $self-> contains_widget( $widget);
   return $widget-> $property() if ! defined $page || $page == $self-> {pageIndex};
   return $self->{widgets}->[$page]->[$number]->[$virtual_properties{$property}];
}

sub widget_set
{
   my ( $self, $widget) = ( shift, shift );
   my ( $page, $number) = $self-> contains_widget( $widget);
   if ( ! defined $page || $page == $self-> {pageIndex} ) {
      $widget-> set( @_ );
      return;
   }
   $number = $self-> {widgets}-> [$page]-> [$number];
   my %profile;
   my $clear_current_flag = 0;
   while ( @_ ) {
      my ( $property, $value) = ( shift, shift );
      if ( $virtual_properties{$property} ) {
         $number-> [ $virtual_properties{ $property } ] = ( $value ? 1 : 0 );
         $clear_current_flag = 1 if $property eq 'current' && $value;
      } else {
         $profile{$property} = $value;
      }
   }
   if ( $clear_current_flag) {
      for ( @{$self->{widgets}->[$page]} ) {
         $$_[3] = 0 if $$_[0] != $widget;
      }
   }
   $widget-> set( %profile ) if scalar keys %profile;
}

sub defaultInsertPage
{
   $_[0]-> {defaultInsertPage} = $_[1];
}

sub pageIndex     {($#_)?($_[0]->set_page_index   ( $_[1]))    :return $_[0]->{pageIndex}}
sub pageCount     {($#_)?($_[0]->set_page_count   ( $_[1]))    :return $_[0]->{pageCount}}

package Prima::TabbedNotebook;
use vars qw(@ISA %notebookProps);
@ISA = qw(Prima::Widget);

use constant DefBorderX   => 11;
use constant DefBookmarkX => 32;

%notebookProps = (
   pageCount      => 1, defaultInsertPage=> 1,
   attach_to_page => 1, insert_to_page   => 1, insert         => 1, insert_transparent => 1,
   delete_widget  => 1, detach_from_page => 1, move_widget    => 1, contains_widget    => 1,
   widget_get     => 1, widget_set       => 1, widgets_from_page => 1,
);

for ( keys %notebookProps) {
   eval <<GENPROC;
   sub $_ { return shift-> {notebook}-> $_(\@_); }
GENPROC
}

sub profile_default
{
   return {
      %{Prima::Notebook->profile_default},
      %{$_[ 0]-> SUPER::profile_default},
      ownerBackColor      => 1,
      tabs                => [],
      tabIndex            => 0,
      tabsetClass         => 'Prima::TabSet',
      tabsetProfile       => {},
      tabsetDelegations   => ['Change'],
      notebookClass       => 'Prima::Notebook',
      notebookProfile     => {},
      notebookDelegations => ['Change'],
   }
}

sub init
{
   my $self = shift;
   my %profile = @_;
   my $visible       = $profile{visible};
   my $scaleChildren = $profile{scaleChildren};
   $profile{visible} = 0;
   $self->{tabs}     = [];
   %profile = $self-> SUPER::init(%profile);
   my @size = $self-> size;
   my $maxh = $self-> font-> height * 2;
   $self->{tabSet} = $profile{tabsetClass}-> create(
      owner     => $self,
      name      => 'TabSet',
      left      => 0,
      width     => $size[0],
      top       => $size[1] - 1,
      growMode  => gm::Ceiling,
      height    => $maxh > 28 ? $maxh : 28,
      buffered  => 1,
      designScale => undef,
      delegations => $profile{tabsetDelegations},
      %{$profile{tabsetProfile}},
   );
   $self->{notebook} = $profile{notebookClass}-> create(
      owner      => $self,
      name       => 'Notebook',
      origin     => [ DefBorderX + 1, DefBorderX + 1],
      size       => [ $size[0] - DefBorderX * 2 - 5,
         $size[1] - DefBorderX * 2 - $self->{tabSet}-> height - DefBookmarkX - 4],
      growMode   => gm::Client,
      scaleChildren => $scaleChildren,
      (map { $_  => $profile{$_}} keys %notebookProps),
      designScale => undef,
      pageCount  => scalar @{$profile{tabs}},
      delegations => $profile{notebookDelegations},
      %{$profile{tabsetProfile}},
   );
   $self-> {notebook}-> designScale( $self-> designScale); # propagate designScale
   $self-> tabs( $profile{tabs});
   $self-> pageIndex( $profile{pageIndex});
   $self-> visible( $visible);
   return %profile;
}

sub Notebook_Change
{
   my ( $self, $book) = @_;
   return if $self->{changeLock};
   $self-> pageIndex( $book-> pageIndex);
}

sub on_paint
{
   my ($self,$canvas) = @_;
   my @clr  = ( $self-> color, $self-> backColor);
   @clr = ( $self-> disabledColor, $self-> disabledBackColor) if ( !$self-> enabled);
   my @c3d  = ( $self-> dark3DColor, $self-> light3DColor);
   my @size = $canvas-> size;
   $canvas-> color( $clr[1]);
   $canvas-> bar( 0, 0, @size);
   $size[1] -= $self->{tabSet}-> height;
   $canvas-> rect3d( 0, 0, $size[0] - 1, $size[1] - 1 + Prima::TabSet::DefGapY, 1, reverse @c3d);
   $canvas-> rect3d( DefBorderX, DefBorderX, $size[0] - 1 - DefBorderX,
      $size[1] - DefBorderX + Prima::TabSet::DefGapY, 1, @c3d);
   my $y = $size[1] - DefBorderX + Prima::TabSet::DefGapY;
   my $x  = $size[0] - DefBorderX - DefBookmarkX;

   return if $y < DefBorderX * 2 + DefBookmarkX;
   $canvas-> color( $c3d[0]);
   $canvas-> line( DefBorderX + 2,  $y - 2, $x - 2, $y - 2);
   $canvas-> line( $x + DefBookmarkX - 4, $y - DefBookmarkX + 1, $x + DefBookmarkX - 4, DefBorderX + 2);

   my $fh = 24;
   my $a  = 0;
   my ($pi, $mpi) = ( $self->{notebook}->pageIndex, $self->{notebook}->pageCount - 1);
   $a |= 1 if $pi > 0;
   $a |= 2 if $pi < $mpi;
   $canvas-> line( DefBorderX + 4, $y - $fh * 1.6, $x - 6, $y - $fh * 1.6);
   $canvas-> polyline([ $x - 2, $y - 2, $x - 2, $y - DefBookmarkX, $x + DefBookmarkX - 4, $y - DefBookmarkX]);
   $canvas-> line( $x - 1, $y - 3, $x + DefBookmarkX - 5, $y - DefBookmarkX + 1);
   $canvas-> line( $x - 1, $y - 4, $x + DefBookmarkX - 6, $y - DefBookmarkX + 1);
   $canvas-> line( $x - 0, $y - 2, $x + DefBookmarkX - 4, $y - DefBookmarkX + 2);
   $canvas-> line( $x + 5, $y - DefBookmarkX - 2, $x + DefBookmarkX - 5, $y - DefBookmarkX - 2);
   $canvas-> polyline([
       $x + 4, $y - DefBookmarkX + 6,
       $x + 10, $y - DefBookmarkX + 6,
       $x + 10, $y - DefBookmarkX + 8]) if $a & 1;
   my $dx = DefBookmarkX / 2;
   my ( $x1, $y1) = ( $x + $dx, $y - $dx);
   $canvas-> line( $x1 + 1, $y1 + 4, $x1 + 3, $y1 + 4) if $a & 2;
   $canvas-> line( $x1 + 5, $y1 + 6, $x1 + 5, $y1 + 8) if $a & 2;
   $canvas-> polyline([ $x1 + 3, $y1 + 2, $x1 + 5, $y1 + 2,
      $x1 + 5, $y1 + 4, $x1 + 7, $y1 + 4, $x1 + 7, $y1 + 6]) if $a & 2;
   $canvas-> color( $c3d[1]);
   $canvas-> line( $x - 1, $y - 7, $x + DefBookmarkX - 9, $y - DefBookmarkX + 1);
   $canvas-> line( DefBorderX + 4, $y - $fh * 1.6 - 1, $x - 6, $y - $fh * 1.6 - 1);
   $canvas-> polyline([ $x + 4, $y1 - 9, $x + 4, $y1 - 8, $x + 10, $y1 - 8]) if $a & 1;
   $canvas-> line( $x1 + 3, $y1 + 2, $x1 + 3, $y1 + 3) if $a & 2;
   $canvas-> line( $x1 + 6, $y1 + 6, $x1 + 7, $y1 + 6) if $a & 2;
   $canvas-> polyline([ $x1 + 1, $y1 + 4, $x1 + 1, $y1 + 6,
       $x1 + 3, $y1 + 6, $x1 + 3, $y1 + 8, $x1 + 5, $y1 + 8]) if $a & 2;
   $canvas-> color( cl::Black);
   $canvas-> line( $x - 1, $y - 2, $x + DefBookmarkX - 4, $y - DefBookmarkX + 1);
   $canvas-> line( $x + 5, $y - DefBookmarkX - 1, $x + DefBookmarkX - 5, $y - DefBookmarkX - 1);
   $canvas-> color( $clr[0]);
   my $t = $self->{tabs};
   if ( scalar @{$t}) {
      my $tx = $self->{tabSet}-> tabIndex;
      my $t1 = $$t[ $tx * 2];
      my $yh = $y - $fh * 0.8 - $self-> font-> height / 2;
      $canvas-> clipRect( DefBorderX + 1, $y - $fh * 1.6 + 1, $x - 4, $y - 3);
      $canvas-> text_out( $t1, DefBorderX + 4, $yh);
      if ( $$t[ $tx * 2 + 1] > 1) {
         $t1 = sprintf("Page %d of %d ", $self->pageIndex - $self->tab2page( $tx) + 1, $$t[ $tx * 2 + 1]);
         my $tl1 = $size[0] - DefBorderX - 3 - DefBookmarkX - $self-> get_text_width( $t1);
         $canvas-> text_out( $t1, $tl1, $yh) if $tl1 > 4 + DefBorderX + $fh * 3;
      }
   }
}

sub on_mousedown
{
   my ( $self, $btn, $mod, $x, $y) = @_;
   $self-> clear_event;
   my @size = $self-> size;
   my $th = $self->{tabSet}-> height;
   $x -= $size[0] - DefBorderX - DefBookmarkX - 1;
   $y -= $size[1] - DefBorderX - $th - DefBookmarkX + 4;
   return if $x < 0 || $x > DefBookmarkX || $y < 0 || $y > DefBookmarkX;
   $self-> pageIndex( $self-> pageIndex + (( -$x + DefBookmarkX < $y) ? 1 : -1));
}

sub on_mouseclick
{
   my $self = shift;
   $self-> clear_event;
   return unless pop;
   $self-> clear_event unless $self-> notify( "MouseDown", @_);
}


sub page2tab
{
   my ( $self, $index) = @_;
   my $t = $self->{tabs};
   return 0 unless scalar @$t;
   my $i = $$t[1] - 1;
   my $j = 0;
   while( $i < $index) {
      $j++;
      $i += $$t[ $j*2 + 1];
   }
   return $j;
}

sub tab2page
{
   my ( $self, $index) = @_;
   my $t = $self->{tabs};
   my $i;
   my $j = 0;
   for ( $i = 0; $i < $index; $i++) { $j += $$t[ $i * 2 + 1]; }
   return $j;
}

sub TabSet_Change
{
   my ( $self, $tabset) = @_;
   return if $self->{changeLock};
   $self-> pageIndex( $self-> tab2page( $tabset-> tabIndex));
}


sub set_tabs
{
   my $self = shift;
   my @tabs = ( scalar @_ == 1 && ref( $_[0]) eq q(ARRAY)) ? @{$_[0]} : @_;
   my @nTabs;
   my @loc;
   my $prev  = undef;
   for ( @tabs) {
      if ( defined $prev && $_ eq $prev) {
         $loc[-1]++;
      } else {
         push( @loc,   $_);
         push( @loc,   1);
         push( @nTabs, $_);
      }
      $prev = $_;
   }
   my $pages = $self-> {notebook}-> pageCount;
   $self-> {tabs} = \@loc;
   $self-> {tabSet}-> tabs( \@nTabs);
   my $i;
   if ( $pages > scalar @tabs) {
      for ( $i = scalar @tabs; $i < $pages; $i++) {
         $self-> {notebook}-> delete_page( $i);
      }
   } elsif ( $pages < scalar @tabs) {
      for ( $i = $pages; $i < scalar @tabs; $i++) {
         $self-> {notebook}-> insert_page;
      }
   }
}

sub get_tabs
{
   my $self = $_[0];
   my $i;
   my $t = $self->{tabs};
   my @ret;
   for ( $i = 0; $i < scalar @{$t} / 2; $i++) {
      my $j;
      for ( $j = 0; $j < $$t[$i*2+1]; $j++) { push( @ret, $$t[$i*2]); }
   }
   return \@ret;
}

sub set_page_index
{
   my ( $self, $pi) = @_;
   my ($pix, $mpi) = ( $self->{notebook}->pageIndex, $self->{notebook}->pageCount - 1);
   $self->{changeLock} = 1;
   $self->{notebook}-> pageIndex( $pi);
   $self->{tabSet}-> tabIndex( $self-> page2tab( $self->{notebook}-> pageIndex));
   delete $self->{changeLock};
   my @size = $self-> size;
   my $th = $self->{tabSet}-> height;
   my $a  = 0;
   $a |= 1 if $pix > 0;
   $a |= 2 if $pix < $mpi;
   my $newA = 0;
   $pi = $self->{notebook}-> pageIndex;
   $newA |= 1 if $pi > 0;
   $newA |= 2 if $pi < $mpi;
   $self->invalidate_rect(
      DefBorderX + 1, $size[1] - DefBorderX - $th - DefBookmarkX - 1,
      $size[0] - DefBorderX - (( $a == $newA) ? DefBookmarkX + 2 : 0),
      $size[1] - DefBorderX - $th + 3
   );
   $self-> notify(q(Change), $pix, $pi);
}

sub tabIndex     {($#_)?($_[0]->{tabSet}->tabIndex( $_[1]))   :return $_[0]->{tabSet}->tabIndex}
sub pageIndex    {($#_)?($_[0]->set_page_index   ( $_[1]))    :return $_[0]->{notebook}->pageIndex}
sub tabs         {($#_)?(shift->set_tabs     (    @_   ))     :return $_[0]->get_tabs}

1;

__DATA__

=pod

=head1 NAME

Prima::Notebooks - multipage widgets

=head1 DESCRIPTION

The module contains several widgets useful for organizing multipage ( notebook )
containers. C<Prima::Notebook> provides basic functionality of a widget container.
C<Prima::TabSet> is a page selector control, and C<Prima::TabbedNotebook> combines
these two into a ready-to-use multipage control with interactive navigation.

=head1 SYNOPSIS

   my $nb = Prima::TabbedNotebook-> create(
      tabs => [ 'First page', 'Second page', 'Second page' ],
   );
   $nb-> insert_to_page( 1, 'Prima::Button' );
   $nb-> insert_to_page( 2, [
      [ 'Prima::Button', bottom => 10  ],
      [ 'Prima::Button', bottom => 150 ],
   ]);
   $nb-> Notebook-> backColor( cl::Green );

=head1 Prima::Notebook

=head2 Properties

Provides basic widget container functionality. Acts as merely
a grouping widget, hiding and showing the children widgets when 
C<pageIndex> property is changed. 

=over

=item defaultInsertPage INTEGER

Selects the page where widgets, attached by C<insert>
call are assigned to. If set to C<undef>, the default
page is the current page.

Default value: C<undef>.

=item pageCount INTEGER

Selects number of pages. If the number of pages is reduced, 
the widgets that belong to the rejected pages are removed
from the notebook's storage. 

=item pageIndex INTEGER

Selects the index of the current page. Valid values are
from 0 to C<pageCount - 1>.

=back

=head2 Methods

=over

=item attach_to_page INDEX, @WIDGETS

Attaches list of WIDGETS to INDEXth page. The widgets are not
necessarily must be children of the notebook widget. If the 
page is not current, the widgets get hidden and disabled;
otherwise their state is not changed.

=item contains_widget WIDGET

Searches for WIDGET in the attached widgets list. If
found, returns two integers: location page index and 
widget list index. Otherwise returns an empty list.

=item delete_page [ INDEX = -1, REMOVE_CHILDREN = 1 ]

Deletes INDEXth page, and detaches the widgets associated with
it. If REMOVE_CHILDREN is 1, the detached widgets are
destroyed. 

=item delete_widget WIDGET

Detaches WIDGET from the widget list and destroys the widget.

=item detach_from_page WIDGET

Detaches WIDGET from the widget list.

=item insert CLASS, %PROFILE [[ CLASS, %PROFILE], ... ]

Creates one or more widgets with C<owner> property set to the 
caller widget, and returns the list of references to the newly 
created widgets. 

See L<Prima::Widget/insert> for details. 

=item insert_page [ INDEX = -1 ]

Inserts a new empty page at INDEX. Valid range
is from 0 to C<pageCount>; setting INDEX equal
to C<pageCount> is equivalent to appending a page
to the end of the page list.

=item insert_to_page INDEX, CLASS, %PROFILE, [[ CLASS, %PROFILE], ... ]

Inserts one ore more widgets to INDEXth page. The semantics
of setting CLASS and PROFILE, as well as the return values
are fully equivalent to C<insert> method.

See L<Prima::Widget/insert> for details.

=item insert_transparent CLASS, %PROFILE, [[ CLASS, %PROFILE], ... ]

Inserts one or more widgets to the notebook widget, but does not
add widgets to the widget list, so the widgets are not flipped
together with pages. Useful for setting omnipresent ( or
transparent ) widgets, visible on all pages.

The semantics of setting CLASS and PROFILE, as well as 
the return values are fully equivalent to C<insert> method.

See L<Prima::Widget/insert> for details.

=item move_widget WIDGET, INDEX

Moves WIDGET from its old page to INDEXth page.

=item widget_get WIDGET, PROPERTY

Returns PROPERTY value of WIDGET. If PROPERTY is
affected by the page flipping mechanism, the internal
flag value is returned instead.

=item widget_set WIDGET, %PROFILE

Calls C<set> on WIDGET with PROFILE and
updates the internal visible, enabled, and current flags
if these are present in PROFILE. 

See L<Prima::Object/set>.   

=item widgets_from_page INDEX

Returns list of widgets, associated with INDEXth page.

=back

=head2 Events

=over

=item Change OLD_PAGE_INDEX, NEW_PAGE_INDEX

Called when C<pageIndex> value is changed from
OLD_PAGE_INDEX to NEW_PAGE_INDEX. Current implementation
invokes this notification while the notebook widget
is in locked state, so no redraw requests are honored during
the notification execution.

=back

=head2 Bugs

Since the notebook operates directly on children widgets'
C<::visible> and C<::enable> properties, there is a problem when
a widget associated with a non-active page must be explicitly hidden 
or disabled. As a result, such a widget would become visible and enabled anyway.
This happens because Prima API does not cache property requests. For example,
after execution of the following code

   $notebook-> pageIndex(1);
   my $widget = $notebook-> insert_to_page( 0, ... );
   $widget-> visible(0);
   $notebook-> pageIndex(0);

C<$widget> will still be visible. As a workaround, C<widget_set> method
can be suggested, to be called together with the explicit state calls.
Changing 

   $widget-> visible(0);

code to

   $notebook-> widget_set( $widget, visible => 0);

solves the problem, but introduces an inconsistency in API.

=head1 Prima::TabSet

C<Prima::TabSet> class implements functionality of an interactive
page switcher. A widget is presented as a set of horizontal
bookmark-styled tabs with text identifiers.  

=head2 Properties

=over

=item colored BOOLEAN

A boolean property, selects whether each tab uses unique color
( OS/2 Warp 4 style ), or all tabs are drawn with C<backColor>.

Default value: 1

=item firstTab INTEGER

Selects the first ( leftmost ) visible tab.

=item focusedTab INTEGER

Selects the currently focused tab. This property value is almost
always equals to C<tabIndex>, except when the widget is navigated
by arrow keys, and tab selection does not occur until the user
presses the return key. 

=item topMost BOOLEAN

Selects the way the widget is oriented. If 1, the widget is drawn
as if it resides on top of another widget. If 0, it is drawn as
if it is at bottom.

Default value: 1

=item tabIndex INDEX

Selects the INDEXth tab. When changed, C<Change> notification 
is triggered.

=item tabs ARRAY

Anonymous array of text scalars. Each scalar corresponds to
a tab and is displayed correspondingly. The class supports
single-line text strings only; newline characters are not respected.

=back

=head2 Methods

=over

=item get_item_width INDEX

Returns width in pixels of INDEXth tab.

=item tab2firstTab INDEX

Returns the index of a tab, that will be drawn leftmost if
INDEXth tab is to be displayed.

=back

=head2 Events

=over

=item Change

Triggered when C<tabIndex> property is changed.

=item DrawTab CANVAS, INDEX, COLOR_SET, POLYGON1, POLYGON2

Called when INDEXth tab is to be drawn on CANVAS. COLOR_SET is an array
reference, and consists of the four cached color values: foreground, background,
dark 3d color, and light 3d color. POLYGON1 and POLYGON2 are array references, 
and contain four points as integer pairs in (X,Y)-coordinates. POLYGON1
keeps coordinates of the larger polygon of a tab, while POLYGON2 of the smaller. Text is
displayed inside the larger polygon:

   POLYGON1
   
        [2,3]        [4,5]
          o..........o
         .            .
   [0,1].   TAB_TEXT   . [6,7]
       o................o

   POLYGON2

    [0,1]               [2,3]
       o................o
   [6,7]o..............o[4,5]

Depending on C<topMost> property value, POLYGON1 and POLYGON2 change 
their mutual vertical orientation.

The notification is always called from within C<begin_paint/end_paint> block.

=item MeasureTab INDEX, REF

Puts width of INDEXth tab in pixels into REF scalar value.
This notification must be called from within C<begin_paint_info/end_paint_info> 
block.

=back

=head1 Prima::TabbedNotebook

The class combines functionality of C<Prima::TabSet> and C<Prima::Notebook>,
providing the interactive multipage widget functionality. The page indexing
scheme is two-leveled: the first level is equivalent to the C<Prima::TabSet> - 
provided tab scheme. Each first-level tab, in turn, contains one or more second-level
pages, which can be switched using native C<Prima::TabbedNotebook> controls.

First-level tab is often referred as I<tab>, and second-level as I<page>.

=head2 Properties

=over

=item defaultInsertPage INTEGER

Selects the page where widgets, attached by C<insert>
call are assigned to. If set to C<undef>, the default
page is the current page.

Default value: C<undef>.

=item notebookClass STRING

Assigns the notebook widget class.

Create-only property.

Default value: C<Prima::Notebook>

=item notebookProfile HASH

Assigns hash of properties, passed to the notebook widget during the creation.

Create-only property.

=item notebookDelegations ARRAY

Assigns list of delegated notifications to the notebook widget.

Create-only property.

=item pageIndex INTEGER

Selects the INDEXth page or a tabset widget ( the second-level tab ).
When this property is triggered, C<tabIndex> can change its value,
and C<Change> notification is triggered.

=item tabIndex INTEGER

Selects the INDEXth tab on a tabset widget using the first-level tab numeration.

=item tabs ARRAY

Governs number and names of notebook pages. ARRAY is an anonymous array
of text scalars, where each corresponds to a single first-level tab
and a single notebook page, with the following exception. To define second-level
tabs, the same text string must be repeated as many times as many second-level
tabs are desired. For example, the code

    $nb-> tabs('1st', ('2nd') x 3);

results in creation of a notebook of four pages and two first-level
tabs. The tab C<'2nd'> contains three second-level pages.

The property implicitly operates the underlying notebook's C<pageCount> property.
When changed at run-time, its effect on the children widgets is therefore the same.
See L<pageCount> for more information.

=item tabsetClass STRING

Assigns the tab set widget class.

Create-only property.

Default value: C<Prima::TabSet>

=item tabsetProfile HASH

Assigns hash of properties, passed to the tab set widget during the creation.

Create-only property.

=item tabsetDelegations ARRAY

Assigns list of delegated notifications to the tab set widget.

Create-only property.

=back

=head2 Methods

The class forwards the following methods of C<Prima::Notebook>, which are described
in L<Prima::Notebook>: C<attach_to_page>, C<insert_to_page>, C<insert>, C<insert_transparent>, 
C<delete_widget>, C<detach_from_page>, C<move_widget>, C<contains_widget>, 
C<widget_get>, C<widget_set>, C<widgets_from_page>.

=over

=item tab2page INDEX

Returns second-level tab index, that corresponds to the INDEXth first-level tab.

=item page2tab INDEX

Returns first-level tab index, that corresponds to the INDEXth second-level tab.

=back

=head2 Events

=over

=item Change OLD_PAGE_INDEX, NEW_PAGE_INDEX

Triggered when C<pageIndex> property is changes it s value from
OLD_PAGE_INDEX to NEW_PAGE_INDEX.

=back

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<Prima::Widget>, F<examples/notebook.pl>.

=cut