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
#  $Id: Outlines.pm,v 1.40 2003/06/18 16:40:44 dk Exp $

# contains:
#   OutlineViewer
#   StringOutline
#   Outline
#   DirectoryOutline

use strict;
use Cwd;
use Prima qw(Classes IntUtils StdBitmap);

package Prima::OutlineViewer;
use vars qw(@ISA @images @imageSize);
@ISA = qw(Prima::Widget Prima::MouseScroller Prima::GroupScroller);

# node record:
#  user fields:
#  0 : item text of ID
#  1 : node subreference ( undef if none)
#  2 : expanded flag
#  private fields
#  3 : item width

{
my %RNT = (
   %{Prima::Widget->notification_types()},
   SelectItem  => nt::Default,
   DrawItem    => nt::Action,
   Stringify   => nt::Action,
   MeasureItem => nt::Action,
   Expand      => nt::Action,
   DragItem    => nt::Default,
);


sub notification_types { return \%RNT; }
}

sub profile_default
{
   my $def = $_[ 0]-> SUPER::profile_default;
   my %prf = (
      autoHeight     => 1,
      autoHScroll    => 1,
      autoVScroll    => 1,
      borderWidth    => 2,
      dragable       => 1,
      hScroll        => 0,
      focusedItem    => -1,
      indent         => 12,
      itemHeight     => $def->{font}->{height},
      items          => [],
      topItem        => 0,
      offset         => 0,
      scaleChildren  => 0,
      selectable     => 1,
      showItemHint   => 1,
      vScroll        => 1,
      widgetClass    => wc::ListBox,
   );
   @$def{keys %prf} = values %prf;
   return $def;
}

sub profile_check_in
{
   my ( $self, $p, $default) = @_;
   $self-> SUPER::profile_check_in( $p, $default);
   $p-> { autoHeight}     = 0 if exists $p-> { itemHeight} && !exists $p->{autoHeight};
   $p-> {autoHScroll} = 0 if exists $p-> {hScroll};
   $p-> {autoVScroll} = 0 if exists $p-> {vScroll};
}

use constant STACK_FRAME => 64;

sub init
{
   my $self = shift;
   unless ( @images) {
      my $i = 0;
      for ( sbmp::OutlineCollaps, sbmp::OutlineExpand) {
         $images[ $i++] = Prima::StdBitmap::image($_);
      }
      if ( $images[0]) {
         @imageSize = $images[0]-> size;
      } else {
         @imageSize = (0,0);
      }
   }
   for ( qw( topItem focusedItem))
      { $self->{$_} = -1; }
   for ( qw( autoHScroll autoVScroll scrollTransaction dx dy hScroll vScroll 
      offset count autoHeight borderWidth
      rows maxWidth hintActive showItemHint dragable))
      { $self->{$_} = 0; }
   for ( qw( itemHeight indent))
      { $self->{$_} = 1; }
   $self->{items}      = [];
   my %profile = $self-> SUPER::init(@_);
   $self-> setup_indents;
   for ( qw( autoHScroll autoVScroll hScroll vScroll offset itemHeight autoHeight borderWidth 
      indent items focusedItem topItem showItemHint dragable))
      { $self->$_( $profile{ $_}); }
   $self-> reset;
   $self-> reset_scrolls;
   return %profile;
}

# iterates throughout the item tree, calling given sub for each item.
# sub's parameters are:
# 0 - current item record pointer
# 1 - parent item record pointer, undef if top-level
# 2 - index of the current item into $parent->[1] array
# 3 - index of the current item into items
# 4 - level of the item ( 0 is topmost)
# 5 - boolean, whether the current item is last item (e.g.$parent->[1]->[-1] == $parent->[1]->[$_[5]]).
#
# $full - if 0, iterates only expanded ( visible) items, if 1 - all items into the tree

sub iterate
{
   my ( $self, $sub, $full) = @_;
   my $position = 0;
   my $traverse;
   $traverse = sub {
      my ( $current, $parent, $index, $level, $lastChild) = @_;
      return $current if $sub->( $current, $parent, $index, $position, $level, $lastChild);
      $position++;
      $level++;
      if ( $current->[1] && ( $full || $current->[2])) {
         my $c = scalar @{$current->[1]};
         my $i = 0;
         for ( @{$current->[1]}) {
            my $ret = $traverse->( $_, $current, $i++, $level, --$c ? 0 : 1);
            return $ret if $ret;
         }
      }
   };
   my $c = scalar @{$self->{items}};
   my $i = 0;
   for ( @{$self->{items}}) {
      my $ret = $traverse->( $_, undef, $i++, 0, --$c ? 0 : 1);
      return $ret if $ret;
   }
}

sub adjust
{
   my ( $self, $index, $action) = @_;
   return unless defined $index;
   my ($node, $lev) = $self-> get_item( $index);
   return unless $node;
   return unless $node->[1];
   return if $node->[2] == $action;
   $self-> notify(q(Expand), $node, $action);
   $node->[2] = $action;
   my $c = $self->{count};
   my $f = $self->{focusedItem};
   $self-> reset_tree;

   my ( $ih, @a) = ( $self->{itemHeight}, $self-> get_active_area);
   $self-> scroll( 0, ( $c - $self->{count}) * $ih,
                   clipRect => [ @a[0..2], $a[3] - $ih * ( $index - $self->{topItem} + 1)]);
   $self-> invalidate_rect(
      $a[0], $a[3] - ( $index - $self->{topItem} + 1) * $ih,
      $a[2], $a[3] - ( $index - $self->{topItem}) * $ih
   );
   $self->{doingExpand} = 1;
   if ( $c > $self->{count} && $f > $index) {
      if ( $f <= $index + $c - $self->{count}) {
         $self-> focusedItem( $index);
      } else {
         $self-> focusedItem( $f + $self->{count} - $c);
      }
   } elsif ( $c < $self->{count} && $f > $index) {
      $self-> focusedItem( $f + $self->{count} - $c);
   }
   $self->{doingExpand} = 0;
   my ($ix,$l) = $self-> get_item( $self-> focusedItem);

   $self-> update_tree;

   $self-> reset_scrolls;
   $self-> offset( $self-> {offset} + $self-> {indent})
      if $action && $c != $self->{count};
}

sub expand_all
{
   my ( $self, $node) = @_;
   $node = [ 0, $self->{items}, 1] unless $node;
   $self->{expandAll}++;
   if ( $node->[1]) {
      #  - light version of adjust
      unless ( $node->[2]) {
          $node->[2] = 1;
          $self-> notify(q(Expand), $node, 1);
      }
      $self-> expand_all( $_) for @{$node->[1]};
   };
   return if --$self->{expandAll};
   delete $self->{expandAll};
   $self-> reset_tree;
   $self-> update_tree;
   $self-> repaint;
   $self-> reset_scrolls;
}

sub on_paint
{
   my ( $self, $canvas) = @_;
   my @size   = $canvas-> size;
   my @clr    = $self-> enabled ?
    ( $self-> color, $self-> backColor) :
    ( $self-> disabledColor, $self-> disabledBackColor);
   my ( $bw, $ih, $iw, $indent, $foc, @a) = (
      $self->{ borderWidth}, $self->{ itemHeight}, $self->{ maxWidth},
      $self->{indent}, $self-> {focusedItem}, $self-> get_active_area( 1, @size));
   my $i;
   my $j;
   my $locWidth = $a[2] - $a[0] + 1;
   my @clipRect = $canvas-> clipRect;
   if ( $clipRect[0] > $a[0] && $clipRect[1] > $a[1] && $clipRect[2] < $a[2] && $clipRect[3] < $a[3])
   {
      $canvas-> clipRect( @a);
      $canvas-> color( $clr[1]);
      $canvas-> bar( 0, 0, @size);
   } else {
      $canvas-> rect3d( 0, 0, $size[0]-1, $size[1]-1, $bw, $self-> dark3DColor, $self-> light3DColor, $clr[1]);
      $canvas-> clipRect( @a);
   }
   my ( $topItem, $rows) = ( $self->{topItem}, $self->{rows});
   my $lastItem  = $topItem + $rows + 1;
   my $timin = $topItem;
   $timin    += int(( $a[3] - $clipRect[3]) / $ih) if $clipRect[3] < $a[3];
   if ( $clipRect[1] >= $a[1]) {
      my $y = $a[3] - $clipRect[1] + 1;
      $lastItem = $topItem + int($y / $ih) + 1;
   }
   $lastItem     = $self->{count} - 1 if $lastItem > $self->{count} - 1;
   my $firstY    = $a[3] + 1 + $ih * $topItem;
   my $lineY     = $a[3] + 1 - $ih * ( 1 + $timin - $topItem);
   my $dyim      = int(( $ih - $imageSize[1]) / 2) + 1;
   my $dxim      = int( $imageSize[0] / 2);

# drawing lines
   my @lines;
   my @marks;
   my @texts;

   my $deltax = - $self->{offset} + ($indent/2) + $a[0];
   $canvas-> set(
      fillPattern => fp::SimpleDots,
      color       => cl::White,
      backColor   => cl::Black,
   );


   my ($array, $idx, $lim, $level) = ([['root'],$self->{items}], 0, scalar @{$self->{items}}, 0);
   my @stack;
   my $position = 0;

# preparing stack
   $i = int(( $timin + 1) / STACK_FRAME) * STACK_FRAME - 1; 
#   $i = int( $timin / STACK_FRAME) * STACK_FRAME - 1; 
   if ( $i >= 0) {
#  if ( $i > 0) {
      $position = $i;
      $j = int(( $timin + 1) / STACK_FRAME) - 1;
#     $j = int( $timin / STACK_FRAME) - 1;
      $i = $self->{stackFrames}->[$j];
      if ( $i) {
         my $k;
         for ( $k = 0; $k < scalar @{$i} - 1; $k++) {
            $idx   = $i->[$k] + 1;
            $lim   = scalar @{$array->[1]};
            push( @stack, [ $array, $idx, $lim]);
            $array = $array->[1]->[$idx - 1];
         }
         $idx   = $$i[$k];
         $lim   = scalar @{$array->[1]};
         $level = scalar @$i - 1;
         $i = $self->{lineDefs}->[$j];
         $lines[$k] = $$i[$k] while $k--;
      }
   }

# following loop is recursive call turned inside-out -
# so we can manipulate with stack
   if ( $position <= $lastItem) {
   while (1) {
      my $node      = $array->[1]->[$idx++];
      my $lastChild = $idx == $lim;

      # outlining part
      my $l = int(( $level + 0.5) * $indent) + $deltax;
      if ( $lastChild) {
         if ( defined $lines[ $level]) {
            $canvas-> bar(
               $l, $firstY - $ih * $lines[ $level],
               $l, $firstY - $ih * ( $position + 0.5))
            if $position >= $timin;
            $lines[ $level] = undef;
         } elsif ( $position > 0) {
         # first and last
            $canvas-> bar(
               $l, $firstY - $ih * ( $position - 0.5),
               $l, $firstY - $ih * ( $position + 0.5))
         }
      } elsif ( !defined $lines[$level]) {
         $lines[$level] = $position ? $position - 0.5 : 0.5;
      }
      if ( $position >= $timin) {
         $canvas-> bar( $l + 1, $lineY + $ih/2, $l + $indent - 1, $lineY + $ih/2);
         if ( defined $node->[1]) {
            my $i = $images[($node->[2] == 0) ? 1 : 0];
            push( @marks, [$l - $dxim, $lineY + $dyim, $i]) if $i;
         };
         push ( @texts, [ $node, $l + $indent * 1.5, $lineY,
            $l + $indent * 1.5 + $node->[3] - 1, $lineY + $ih - 1,
            $position, ( $foc == $position) ? 1 : 0]);
         $lineY -= $ih;
      }
      last if $position >= $lastItem;

      # recursive part
      $position++;

      if ( $node->[1] && $node->[2] && scalar @{$node->[1]}) {
         $level++;
         push ( @stack, [ $array, $idx, $lim]);
         $idx   = 0;
         $array = $node;
         $lim   = scalar @{$node->[1]};
         next;
      }
      while ( $lastChild) {
         last unless $level--;
         ( $array, $idx, $lim) = @{pop @stack};
         $lastChild = $idx == $lim;
      }
   }}

# drawing line ends
   $i = 0;
   for ( @lines) {
      $i++;
      next unless defined $_;
      my $l = ( $i - 0.5) * $indent + $deltax;;
      $canvas-> bar( $l, $firstY - $ih * $_, $l, 0);
   }
   $canvas-> set(
      fillPattern => fp::Solid,
      color       => $clr[0],
      backColor   => $clr[1],
   );

#
   $canvas-> put_image( @$_) for @marks;
   $self-> draw_items( $canvas, \@texts);
}

sub on_size
{
   my $self = $_[0];
   $self-> reset;
   $self-> reset_scrolls;
}

sub on_fontchanged
{
   my $self = $_[0];
   $self-> itemHeight( $self-> font-> height), $self->{autoHeight} = 1 if $self-> { autoHeight};
   $self-> calibrate;
}

sub point2item
{
   my ( $self, $y, $h) = @_;
   my $i = $self->{indents};
   $h = $self-> height unless defined $h;
   return $self->{topItem} - 1 if $y >= $h - $$i[3];
   return $self->{topItem} + $self->{rows} if $y <= $$i[1];
   $y = $h - $y - $$i[3];
   return $self->{topItem} + int( $y / $self->{itemHeight});
}


sub on_mousedown
{
   my ( $self, $btn, $mod, $x, $y) = @_;
   my $bw = $self-> { borderWidth};
   my @size = $self-> size;
   $self-> clear_event;
   # my ($dx,$dy,$o,$i) = ( $self->{dx}, $self->{dy}, $self->{offset}, $self->{indent});
   my ($o,$i,@a) = ( $self->{offset}, $self->{indent}, $self-> get_active_area(0, @size));
   return if $btn != mb::Left;
   return if defined $self->{mouseTransaction} ||
      $y < $a[1] || $y >= $a[3] || $x < $a[0] || $x >= $a[2];

   my $item   = $self-> point2item( $y, $size[1]);
   my ( $rec, $lev) = $self-> get_item( $item);
   if ( $rec &&
         ( $x >= ( 1 + $lev) * $i + $a[0] - $o - $imageSize[0] / 2) &&
         ( $x <  ( 1 + $lev) * $i + $a[0] - $o + $imageSize[0] / 2)
      ) {
      $self-> adjust( $item, $rec->[2] ? 0 : 1) if $rec->[1];
      return;
   }

   $self-> {mouseTransaction} = (( $mod & km::Ctrl) && $self->{dragable}) ? 2 : 1;
   $self-> focusedItem( $item >= 0 ? $item : 0);
   $self-> {mouseTransaction} = 1 if $self-> focusedItem < 0;
   if ( $self-> {mouseTransaction} == 2) {
      $self-> {dragItem} = $self-> focusedItem;
      $self-> {mousePtr} = $self-> pointer;
      $self-> pointer( cr::Move);
   }
   $self-> capture(1);
}

sub on_mouseclick
{
   my ( $self, $btn, $mod, $x, $y, $dbl) = @_;
   $self-> clear_event;
   return if $btn != mb::Left || !$dbl;
   my $bw = $self-> { borderWidth};
   my @size = $self-> size;
   my $item   = $self-> point2item( $y, $size[1]);
   my ($o,$i) = ( $self->{offset}, $self->{indent});
   my ( $rec, $lev) = $self-> get_item( $item);
   if ( $rec &&
         ( $x >= ( 1 + $lev) * $i + $self->{indents}->[0] - $o - $imageSize[0] / 2) &&
         ( $x <  ( 1 + $lev) * $i + $self->{indents}->[0] - $o + $imageSize[0] / 2)
      ) {
      $self-> adjust( $item, $rec->[2] ? 0 : 1) if $rec->[1];
      return;
   }
   $self-> notify( q(Click)) if $self->{count};
}

sub makehint
{
   my ( $self, $show, $itemid) = @_;
   return if !$show && !$self->{hintActive};
   if ( !$show) {
      $self->{hinter}-> hide;
      $self->{hintActive} = 0;
      return;
   }
   return if defined $self->{unsuccessfullId} && $self->{unsuccessfullId} == $itemid;

   return unless $self->{showItemHint};

   my ( $item, $lev) = $self-> get_item( $itemid);
   unless ( $item) {
      $self-> makehint(0);
      return;
   }


   my $w = $self-> get_item_width( $item);
   my @a = $self-> get_active_area;
   my $ofs = ( $lev + 2.5) * $self->{indent} - $self->{offset} + $self-> {indents}->[0];

   if ( $w + $ofs <= $a[2]) {
     $self-> makehint(0);
     return;
   }

   $self->{unsuccessfullId} = undef;

   unless ( $self->{hinter}) {
       $self->{hinter} = $self-> insert( Widget =>
           clipOwner      => 0,
           selectable     => 0,
           ownerColor     => 1,
           ownerBackColor => 1,
           ownerFont      => 1,
           visible        => 0,
           height         => $self->{itemHeight},
           name           => 'Hinter',
           delegations    => [qw(Paint MouseDown MouseLeave)],
       );
   }
   $self->{hintActive} = 1;
   $self->{hinter}-> {id} = $itemid;
   $self->{hinter}-> {node} = $item;
   my @org = $self-> client_to_screen(0,0);
   $self->{hinter}-> set(
      origin  => [ $org[0] + $ofs - 2,
                 $org[1] + $self-> height - $self->{indents}->[3] -
                 $self->{itemHeight} * ( $itemid - $self->{topItem} + 1),
                 ],
      width   => $w + 4,
      text    => $self-> get_item_text( $item),
      visible => 1,
   );
   $self->{hinter}-> bring_to_front;
   $self->{hinter}-> repaint;
}

sub Hinter_Paint
{
   my ( $owner, $self, $canvas) = @_;
   my $c = $self-> color;
   $canvas-> color( $self-> backColor);
   my @sz = $canvas-> size;
   $canvas-> bar( 0, 0, @sz);
   $canvas-> color( $c);
   $canvas-> rectangle( 0, 0, $sz[0] - 1, $sz[1] - 1);
   my @rec = ([ $self->{node}, 2, 0,
       $sz[0] - 3, $sz[1] - 1, 0, 0
   ]);
   $owner-> draw_items( $canvas, \@rec);
}

sub Hinter_MouseDown
{
   my ( $owner, $self, $btn, $mod, $x, $y) = @_;
   $owner-> makehint(0);
   my @ofs = $owner-> screen_to_client( $self-> client_to_screen( $x, $y));
   $owner-> mouse_down( $btn, $mod, @ofs);
   $owner-> {unsuccessfullId} = $self->{id};
}

sub Hinter_MouseLeave
{
   $_[0]-> makehint(0);
}


sub on_mousemove
{
   my ( $self, $mod, $x, $y) = @_;
   my @size = $self-> size;
   my @a    = $self-> get_active_area( 0, @size);
   if ( !defined $self->{mouseTransaction} && $self->{showItemHint}) {
      my $item   = $self-> point2item( $y, $size[1]);
      my ( $rec, $lev) = $self-> get_item( $item);
      if ( !$rec || ( $x < -$self->{offset} + ($lev + 2) * $self->{indent} + $self->{indents}->[0])) {
         $self-> makehint( 0);
         return;
      }
      if (( $y >= $a[3]) || ( $y <= $a[1] + $self->{itemHeight} / 2)) {
         $self-> makehint( 0);
         return;
      }
      $y = $a[3] - $y;
      $self-> makehint( 1, $self->{topItem} + int( $y / $self->{itemHeight}));
      return;
   }
   my $item = $self-> point2item( $y, $size[1]);
   if ( $y >= $a[3] || $y < $a[1] || $x >= $a[2] || $x < $a[0])
   {
      $self-> scroll_timer_start unless $self-> scroll_timer_active;
      return unless $self->scroll_timer_semaphore;
      $self->scroll_timer_semaphore(0);
   } else {
      $self-> scroll_timer_stop;
   }
   $self-> focusedItem( $item >= 0 ? $item : 0);
   $self-> offset( $self->{offset} + 5 * (( $x < $a[0]) ? -1 : 1)) if $x >= $a[2] || $x < $a[0];
}

sub on_mouseup
{
   my ( $self, $btn, $mod, $x, $y) = @_;
   return if $btn != mb::Left;
   return unless defined $self->{mouseTransaction};
   my @dragnotify;
   if ( $self->{mouseTransaction} == 2) {
      $self-> pointer( $self-> {mousePtr});
      my $fci = $self-> focusedItem;
      @dragnotify = ($self-> {dragItem}, $fci) unless $fci == $self-> {dragItem};
   }
   delete $self->{mouseTransaction};
   delete $self->{mouseHorizontal};
   $self-> capture(0);
   $self-> clear_event;
   $self-> notify(q(DragItem), @dragnotify) if @dragnotify;
}

sub on_mousewheel
{
   my ( $self, $mod, $x, $y, $z) = @_;
   $z = int( $z/120);
   $z *= $self-> {rows} if $mod & km::Ctrl;
   my $newTop = $self-> topItem - $z;
   my $maxTop = $self-> {count} - $self-> {rows};
   $self-> topItem( $newTop > $maxTop ? $maxTop : $newTop);
}

sub on_enable  { $_[0]-> repaint; }
sub on_disable { $_[0]-> repaint; }
sub on_leave
{
   my $self = $_[0];
   if ( $self->{mouseTransaction})  {
      $self-> capture(0) if $self->{mouseTransaction};
      $self->{mouseTransaction} = undef;
   }
}


sub on_keydown
{
   my ( $self, $code, $key, $mod) = @_;
   return if $mod & km::DeadKey;
   $mod &= ( km::Shift|km::Ctrl|km::Alt);
   $self->notify(q(MouseUp),0,0,0) if defined $self->{mouseTransaction};

   return unless $self->{count};
   if (( $key == kb::NoKey) && (( $code & 0xFF) >= ord(' '))) {
      if ( chr( $code) eq '+') {
         $self-> adjust( $self->{focusedItem}, 1);
         $self-> clear_event;
         return;
      } elsif ( chr( $code) eq '-') {
         my ( $item, $lev) = $self-> get_item( $self->{focusedItem});
         if ( $item->[1] && $item->[2]) {
            $self-> adjust( $self->{focusedItem}, 0);
            $self-> clear_event;
            return;
         } elsif ( $lev > 0) {
            my $i = $self->{focusedItem};
            my ( $par, $parlev) = ( $item, $lev);
            ( $par, $parlev) = $self-> get_item( --$i) while $parlev != $lev - 1;
            $self-> adjust( $i, 0);
            $self-> clear_event;
            return;
         }
      }

      if ( !($mod & ~km::Shift))  {
         my $i;
         my ( $c, $hit, $items) = ( lc chr ( $code & 0xFF), undef, $self->{items});
         for ( $i = $self->{focusedItem} + 1; $i < $self->{count}; $i++)
         {
            my $fc = substr( $self-> get_index_text($i), 0, 1);
            next unless defined $fc;
            $hit = $i, last if lc $fc eq $c;
         }
         unless ( defined $hit) {
            for ( $i = 0; $i < $self->{focusedItem}; $i++)  {
               my $fc = substr( $self-> get_index_text($i), 0, 1);
               next unless defined $fc;
               $hit = $i, last if lc $fc eq $c;
            }
         }
         if ( defined $hit)  {
            $self-> focusedItem( $hit);
            $self-> clear_event;
            return;
         }
      }
      return;
   }

   return if $mod != 0;

   if ( scalar grep { $key == $_ } (kb::Left,kb::Right,kb::Up,kb::Down,kb::Home,kb::End,kb::PgUp,kb::PgDn))
   {
      my $newItem = $self->{focusedItem};
      my $pgStep  = $self->{rows} - 1;
      $pgStep = 1 if $pgStep <= 0;
      if ( $key == kb::Up)   { $newItem--; };
      if ( $key == kb::Down) { $newItem++; };
      if ( $key == kb::Home) { $newItem = $self->{topItem} };
      if ( $key == kb::End)  { $newItem = $self->{topItem} + $pgStep; };
      if ( $key == kb::PgDn) { $newItem += $pgStep };
      if ( $key == kb::PgUp) { $newItem -= $pgStep};
      $self-> offset( $self->{offset} + $self->{indent} * (( $key == kb::Left) ? -1 : 1))
         if $key == kb::Left || $key == kb::Right;
      $self-> focusedItem( $newItem >= 0 ? $newItem : 0);
      $self-> clear_event;
      return;
   }

   if ( $key == kb::Enter)  {
      $self-> adjust( $self->{focusedItem}, 1);
      $self-> clear_event;
      return;
   }
}


sub reset
{
   my $self = $_[0];
   my @size = $self-> get_active_area( 2);
   $self-> makehint(0);
   my $ih   = $self-> {itemHeight};
   $self->{rows}  = int( $size[1] / $ih);
   $self->{rows}  = 0 if $self->{rows} < 0;
   $self->{yedge} = ( $size[1] - $self->{rows} * $ih) ? 1 : 0;
}

sub reset_scrolls
{
   my $self = $_[0];
   $self-> makehint(0);
   if ( $self-> {scrollTransaction} != 1) {
      $self-> vScroll( $self-> {rows} < $self-> {count} ) if $self-> {autoVScroll};
      $self-> {vScrollBar}-> set(
         max      => $self-> {count} - $self->{rows},
         pageStep => $self-> {rows},
         whole    => $self-> {count},
         partial  => $self-> {rows},
         value    => $self-> {topItem},
      ) if $self-> {vScroll};
   }
   if ( $self->{scrollTransaction} != 2) { 
      my @sz = $self-> get_active_area( 2);
      my $iw = $self->{maxWidth};
      if ( $self-> {autoHScroll}) {
         my $hs = ($sz[0] < $iw) ? 1 : 0;
         if ( $hs != $self-> {hScroll}) {
            $self-> hScroll( $hs);
            @sz = $self-> get_active_area( 2);
         }
      }
      $self-> {hScrollBar}-> set(
         max      => $iw - $sz[0],
         whole    => $iw,
         value    => $self-> {offset},
         partial  => $sz[0],
         pageStep => $iw / 5,
      ) if $self-> {hScroll};
   }
}

sub reset_tree
{
   my ( $self, $i) = ( $_[0], 0);
   $self-> makehint(0);
   $self-> {stackFrames} = [];
   $self-> {lineDefs}    = [];
   my @stack;
   my @lines;
   my $traverse;
   $traverse = sub {
      my ( $node, $level, $lastChild) = @_;
      $lines[ $level] = $lastChild ? undef : ( $i ? $i - 0.5 : 0.5);
      if (( $i % STACK_FRAME) == STACK_FRAME - 1) {
         push( @{$self->{stackFrames}}, [@stack[0..$level]]);
         push( @{$self->{lineDefs}},    [@lines[0..$level]]);
      }
      $i++;
      $level++;
      if ( $node->[1] && $node->[2]) {
         $stack[$level] = 0;
         my $c = @{$node->[1]};
         for ( @{$node->[1]}) {
            $traverse->( $_, $level, --$c ? 0 : 1);
            $stack[$level]++;
         }
      }
   };

   $stack[0] = 0;
   my $c = @{$self->{items}};
   for (@{$self->{items}}) {
      $traverse->( $_, 0, --$c ? 0 : 1);
      $stack[0]++;
   }

   $self-> {count} = $i;

   my $fullc = $self->{fullCalibrate};
   my ( $notifier, @notifyParms) = $self-> get_notify_sub(q(MeasureItem));
   my $maxWidth = 0;
   my $indent = $self->{indent};
   $self-> push_event;
   $self-> begin_paint_info;
   $self-> iterate( sub {
      my ( $current, $parent, $index, $position, $level) = @_;
      my $iw = $fullc ? undef : $current->[3];
      unless ( defined $iw) {
         $notifier->( @notifyParms, $current, \$iw);
         $current->[3] = $iw;
      }
      my $iwc = $iw + ( 2.5 + $level) * $indent;
      $maxWidth = $iwc if $maxWidth < $iwc;
      return 0;
   });
   $self-> end_paint_info;
   $self-> pop_event;
   $self-> {maxWidth} = $maxWidth;
}

sub calibrate
{
   my $self = $_[0];
   $self->{fullCalibrate} = 1;
   $self-> reset_tree;
   delete $self->{fullCalibrate};
   $self-> update_tree;
}

sub update_tree
{
   my $self = $_[0];
   $self-> topItem( $self-> {topItem});
   $self-> offset( $self-> {offset});
}


sub draw_items
{
   my ($self, $canvas, $paintStruc) = @_;
   my ( $notifier, @notifyParms) = $self-> get_notify_sub(q(DrawItem));
   $self-> push_event;
   for ( @$paintStruc) { $notifier->( @notifyParms, $canvas, @$_); }
   $self-> pop_event;
}

sub set_auto_height
{
   my ( $self, $auto) = @_;
   $self-> itemHeight( $self-> font-> height) if $auto;
   $self->{autoHeight} = $auto;
}

sub set_border_width
{
   my ( $self, $bw) = @_;
   $bw = 0 if $bw < 0;
   $bw = 1 if $bw > $self-> height / 2;
   $bw = 1 if $bw > $self-> width  / 2;
   return if $bw == $self-> {borderWidth};
   $self-> SUPER::set_border_width( $bw);
   $self-> reset;
   $self-> reset_scrolls;
   $self-> repaint;
}

sub set_focused_item
{
   my ( $self, $foc) = @_;
   my $oldFoc = $self->{focusedItem};
   $foc = $self->{count} - 1 if $foc >= $self->{count};
   $foc = -1 if $foc < -1;
   return if $self->{focusedItem} == $foc;
   return if $foc < -1;
   $self-> {focusedItem} = $foc;
   $self-> notify(q(SelectItem), $foc) if $foc >= 0;
   return if $self-> {doingExpand};
   my $topSet = undef;
   if ( $foc >= 0)
   {
      my $rows = $self->{rows} ? $self->{rows} : 1;
      if ( $foc < $self->{topItem}) {
         $topSet = $foc;
      } elsif ( $foc >= $self->{topItem} + $rows) {
         $topSet = $foc - $rows + 1;
      }
   }
   $self-> topItem( $topSet) if defined $topSet;
   ( $oldFoc, $foc) = ( $foc, $oldFoc) if $foc > $oldFoc;
   my @a  = $self-> get_active_area;
   my $ih = $self->{itemHeight};
   my $lastItem = $self->{topItem} + $self->{rows};
   $self-> invalidate_rect( $a[0], $a[3] - ( $oldFoc - $self->{topItem} + 1) * $ih,
                            $a[2], $a[3] - ( $oldFoc - $self->{topItem}) * $ih) 
      if $oldFoc >= 0 && $oldFoc != $foc && $oldFoc >= $self->{topItem} && $oldFoc <= $self->{topItem} + $self->{rows};
   $self-> invalidate_rect( $a[0], $a[3] - ( $foc - $self->{topItem} + 1) * $ih,
                            $a[2], $a[3] - ( $foc - $self->{topItem}) * $ih) 
      if $foc >= 0 && $foc >= $self->{topItem} && $foc <= $self->{topItem} + $self->{rows};
#  $foc = $oldFoc if $foc < 0 || $foc < $self->{topItem} || $foc > $self->{topItem} + $self->{rows};
#  $oldFoc = $foc if $oldFoc < 0 || $oldFoc < $self->{topItem} || $oldFoc > $self->{topItem} + $self->{rows};
   #$self-> invalidate_rect(
   #   $a[0], $a[3] - ( $oldFoc - $self->{topItem} + 1) * $ih,
   #   $a[2], $a[3] - ( $foc - $self->{topItem}) * $ih
   #) if $foc >= 0;
}

sub set_indent
{
   my ( $self, $i) = @_;
   return if $i == $self->{indent};
   $i = 1 if $i < 1;
   $self->{indent} = $i;
   $self-> calibrate;
   $self-> repaint;
}


sub set_item_height
{
   my ( $self, $ih) = @_;
   $ih = 1 if $ih < 1;
   $self-> autoHeight(0);
   return if $ih == $self->{itemHeight};
   $self->{itemHeight} = $ih;
   $self->reset;
   $self->reset_scrolls;
   $self->repaint;
   $self-> {hinter}-> height( $ih) if $self-> {hinter};
}

sub validate_items
{
   my ( $self, $items) = @_;
   my $traverse;
   $traverse = sub {
      my $current  = $_[0];
      my $spliceTo = 3;
      if ( ref $current->[1] eq 'ARRAY') {
         $traverse->( $_) for @{$current->[1]};
         $current->[2] = 0 unless defined $current->[2];
      } else {
         $spliceTo = 1;
      }
      splice( @$current, $spliceTo);
   };
   $traverse->( $items);
}

sub set_items
{
   my ( $self, $items) = @_;
   $items = [] unless defined $items;
   $self-> validate_items( [ 0, $items]);
   $self-> {items} = $items;
   $self-> reset_tree;
   $self-> update_tree;
   $self-> repaint;
   $self-> reset_scrolls;
}

sub insert_items
{
   my ( $self, $where, $at, @items) = @_;
   return unless scalar @items;
   my $forceReset = 0;
   $where = [0, $self->{items}], $forceReset = 1 unless $where;
   $self-> validate_items( $_) for @items;
   return unless $where->[1];
   my $ch = scalar @{$where->[1]};
   $at = 0 if $at < 0;
   $at = $ch if $at > $ch;
   my ( $x, $l) = $self-> get_index( $where);
   splice( @{$where->[1]}, $at, 0, @items);
   return if $x < 0 && !$forceReset;
   $self-> reset_tree;
   $self-> update_tree;
   $self-> repaint;
   $self-> reset_scrolls;
}

sub delete_items
{
   my ( $self, $where, $at, $amount) = @_;
   $where = [0, $self->{items}] unless $where;
   return unless $where->[1];
   my ( $x, $l) = $self-> get_index( $where);
   $at = 0 unless defined $at;
   $amount = scalar @{$where->[1]} unless defined $amount;
   splice( @{$where->[1]}, $at, $amount);
   return if $x < 0;
   my $f = $self->{focusedItem};
   $self-> focusedItem( -1) if $f >= $x && $f < $x + $amount;
   $self-> reset_tree;
   $self-> update_tree;
   $self-> repaint;
   $self-> reset_scrolls;
}

sub delete_item
{
   my ( $self, $item) = @_;
   return unless $item;
   my ( $x, $l) = $self-> get_index( $item);

   my ( $parent, $offset) = $self-> get_item_parent( $item);
   if ( defined $parent) {
      splice( @{$parent->[1]}, $offset, 1);
   } else {
      splice( @{$self->{items}}, $offset, 1) if defined $offset;
   }
   if ( $x >= 0) {
      $self-> reset_tree;
      $self-> update_tree;
      $self-> focusedItem( -1) if $x == $self->{focusedItem};
      $self-> repaint;
      $self-> reset_scrolls;
   }
}

sub get_item_parent
{
   my ( $self, $item) = @_;
   my $parent;
   my $offset;
   return unless $item;
   $self-> iterate( sub {
      my ($cur,$par,$idx) = @_;
      $parent = $par, $offset = $idx, return 1 if $cur == $item;
   }, 1);
   return $parent, $offset;
}

sub set_offset
{
   my ( $self, $offset) = @_;
   my ( $iw, @a) = ($self->{maxWidth}, $self-> get_active_area);

   my $lc = $a[2] - $a[0];
   if ( $iw > $lc) {
      $offset = $iw - $lc if $offset > $iw - $lc;
      $offset = 0 if $offset < 0;
   } else {
      $offset = 0;
   }
   return if $self->{offset} == $offset;
   my $oldOfs = $self->{offset};
   $self-> {offset} = $offset;
   if ( $self->{hScroll} && $self->{scrollTransaction} != 2) {
      $self->{scrollTransaction} = 2;
      $self-> {hScrollBar}-> value( $offset);
      $self->{scrollTransaction} = 0;
   }
   $self-> makehint(0);
   $self-> scroll( $oldOfs - $offset, 0,
                   clipRect => \@a);
}

sub set_top_item
{
   my ( $self, $topItem) = @_;
   $topItem = 0 if $topItem < 0;   # first validation
   $topItem = $self-> {count} - 1 if $topItem >= $self-> {count};
   $topItem = 0 if $topItem < 0;   # count = 0 case
   return if $topItem == $self->{topItem};
   my $oldTop = $self->{topItem};
   $self->{topItem} = $topItem;
   my ($ih, @a) = (
      $self->{itemHeight}, $self-> get_active_area);
   $self-> makehint(0);
   if ( $self->{scrollTransaction} != 1 && $self->{vScroll}) {
      $self->{scrollTransaction} = 1;
      $self-> {vScrollBar}-> value( $topItem);
      $self->{scrollTransaction} = 0;
   }

   $self-> scroll( 0, ($topItem - $oldTop) * $ih,
                   clipRect => \@a);
}


sub VScroll_Change
{
   my ( $self, $scr) = @_;
   return if $self-> {scrollTransaction};
   $self-> {scrollTransaction} = 1;
   $self-> topItem( $scr-> value);
   $self-> {scrollTransaction} = 0;
}

sub HScroll_Change
{
   my ( $self, $scr) = @_;
   return if $self-> {scrollTransaction};
   $self-> {scrollTransaction} = 2;
   $self-> {multiColumn} ?
      $self-> topItem( $scr-> value) :
      $self-> offset( $scr-> value);
   $self-> {scrollTransaction} = 0;
}


sub set_h_scroll
{
   my ( $self, $hs) = @_;
   return if $hs == $self->{hScroll};
   $self-> SUPER::set_h_scroll( $hs);
   $self-> reset;
   $self-> reset_scrolls;
   $self-> repaint;
}

sub set_v_scroll
{
   my ( $self, $vs) = @_;
   return if $vs == $self->{vScroll};
   $self-> SUPER::set_v_scroll( $vs);
   $self-> reset;
   $self-> reset_scrolls;
   $self-> repaint;
}

sub showItemHint
{
   return $_[0]-> {showItemHint} unless $#_;
   my ( $self, $sh) = @_;
   return if $sh == $self->{showItemHint};
   $self->{showItemHint} = $sh;
   $self-> makehint(0) if !$sh && $self->{hintActive};
}

sub dragable
{
   return $_[0]-> {dragable} unless $#_;
   $_[0]->{dragable} = $_[1];
}


sub get_index
{
   my ( $self, $item) = @_;
   return -1, undef unless $item;
   my $lev;
   my $rec = -1;
   $self-> iterate( sub {
      my ( $current, $parent, $index, $position, $level, $lastChild) = @_;
      $lev = $level, $rec = $position, return 1 if $current == $item;
   });
  return $rec, $lev;
}


sub get_item
{
   my ( $self, $item) = @_;
   return if $item < 0 || $item >= $self-> {count};

   my ($array, $idx, $lim, $level) = ([['root'],$self->{items}], 0, scalar @{$self->{items}}, 0);
   my $i = int(( $item + 1) / STACK_FRAME) * STACK_FRAME - 1;
   my $position = 0;
   my @stack;
   if ( $i >= 0) {
      $position = $i;
      $i = $self-> {stackFrames}->[int( $item + 1) / STACK_FRAME - 1];
      if ( $i) {
         my $k;
         for ( $k = 0; $k < scalar @{$i} - 1; $k++) {
            $idx   = $i->[$k] + 1;
            $lim   = scalar @{$array->[1]};
            push( @stack, [ $array, $idx, $lim]);
            $array = $array->[1]->[$idx - 1];
         }
         $idx   = $$i[$k];
         $lim   = scalar @{$array->[1]};
         $level = scalar @$i - 1;
      }   
   }

   die "Internal error\n" if $position > $item;
   while (1) {
      my $node      = $array->[1]->[$idx++];
      my $lastChild = $idx == $lim;
      return $node, $level if $position == $item;
      $position++;
      if ( $node->[1] && $node->[2] && scalar @{$node->[1]}) {
         $level++;
         push ( @stack, [ $array, $idx, $lim]);
         $idx   = 0;
         $array = $node;
         $lim   = scalar @{$node->[1]};
         next;
      }
      while ( $lastChild) {
         last unless $level--;
         ( $array, $idx, $lim) = @{pop @stack};
         $lastChild = $idx == $lim;
      }
   }   
}

sub get_item_text
{
   my ( $self, $item) = @_;
   my $txt = '';
   $self-> notify(q(Stringify), $item, \$txt);
   return $txt;
}

sub get_item_width
{
   return $_[1]->[3];
}

sub get_index_text
{
   my ( $self, $index) = @_;
   my $txt = '';
   my ( $node, $lev) = $self->get_item( $index);
   $self-> notify(q(Stringify), $node, \$txt);
   return $txt;
}

sub get_index_width
{
   my ( $self, $index) = @_;
   my ( $node, $lev) = $self-> get_item( $index);
   return $node->[3];
}

sub on_drawitem
{
#  my ( $self, $canvas, $node, $left, $bottom, $right, $top, $position, $focused) = @_;
}

sub on_measureitem
{
#   my ( $self, $node, $result) = @_;
}

sub on_stringify
{
#   my ( $self, $node, $result) = @_;
}

sub on_selectitem
{
#   my ( $self, $index) = @_;
}

sub on_expand
{
#   my ( $self, $node, $action) = @_;
}

sub on_dragitem
{
    my ( $self, $from, $to) = @_;
    my ( $fx, $fl) = $self-> get_item( $from);
    my ( $tx, $tl) = $self-> get_item( $to);
    my ( $fpx, $fpo) = $self-> get_item_parent( $fx);
    return unless $fx && $tx;
    my $found_inv = 0;

    my $traverse;
    $traverse = sub {
       my $current = $_[0];
       $found_inv = 1, return if $current == $tx;
       if ( $current->[1] && $current->[2]) {
          my $c = scalar @{$current->[1]};
          for ( @{$current->[1]}) {
             my $ret = $traverse->( $_);
             return $ret if $ret;
          }
       }
    };
    $traverse->( $fx);
    return if $found_inv;


    if ( $fpx) {
      splice( @{$fpx->[1]}, $fpo, 1);
    } else {
       splice( @{$self->{items}}, $fpo, 1);
    }
    unless ( $tx-> [1]) {
       $tx->[1] = [$fx];
       $tx->[2] = 1;
    } else {
       splice( @{$tx->[1]}, 0, 0, $fx);
    }
    $self-> reset_tree;
    $self-> update_tree;
    $self-> repaint;
    $self-> clear_event;
}


sub autoHeight    {($#_)?$_[0]->set_auto_height    ($_[1]):return $_[0]->{autoHeight}     }
sub focusedItem   {($#_)?$_[0]->set_focused_item   ($_[1]):return $_[0]->{focusedItem}    }
sub indent        {($#_)?$_[0]->set_indent( $_[1])        :return $_[0]->{indent}         }
sub items         {($#_)?$_[0]->set_items( $_[1])         :return $_[0]->{items}          }
sub itemHeight    {($#_)?$_[0]->set_item_height    ($_[1]):return $_[0]->{itemHeight}     }
sub offset        {($#_)?$_[0]->set_offset         ($_[1]):return $_[0]->{offset}         }
sub topItem       {($#_)?$_[0]->set_top_item       ($_[1]):return $_[0]->{topItem}        }

package Prima::StringOutline;
use vars qw(@ISA);
@ISA = qw(Prima::OutlineViewer);

sub draw_items
{
   my ($self, $canvas, $paintStruc) = @_;
   for ( @$paintStruc) {
      my ( $node, $left, $bottom, $right, $top, $position, $focused) = @$_;
      if ( $focused) {
         my $c = $canvas-> color;
         $canvas-> color( $self-> hiliteBackColor);
         $canvas-> bar( $left, $bottom, $right, $top);
         $canvas-> color( $self-> hiliteColor);
         $canvas-> text_out( $node->[0], $left, $bottom);
         $canvas-> color( $c);
      } else {
         $canvas-> text_out( $node->[0], $left, $bottom);
      }
   }
}

sub on_measureitem
{
   my ( $self, $node, $result) = @_;
   $$result = $self-> get_text_width( $node->[0]);
}

sub on_stringify
{
   my ( $self, $node, $result) = @_;
   $$result = $node->[0];
}

package Prima::Outline;
use vars qw(@ISA);
@ISA = qw(Prima::OutlineViewer);

sub draw_items
{
   my ($self, $canvas, $paintStruc) = @_;
   for ( @$paintStruc) {
      my ( $node, $left, $bottom, $right, $top, $position, $focused) = @$_;
      if ( $focused) {
         my $c = $canvas-> color;
         $canvas-> color( $self-> hiliteBackColor);
         $canvas-> bar( $left, $bottom, $right, $top);
         $canvas-> color( $self-> hiliteColor);
         $canvas-> text_out( $node->[0]->[0], $left, $bottom);
         $canvas-> color( $c);
      } else {
         $canvas-> text_out( $node->[0]->[0], $left, $bottom);
      }
   }
}

sub on_measureitem
{
   my ( $self, $node, $result) = @_;
   $$result = $self-> get_text_width( $node->[0]->[0]);
}

sub on_stringify
{
   my ( $self, $node, $result) = @_;
   $$result = $node->[0]->[0];
}

package Prima::DirectoryOutline;
use vars qw(@ISA);
@ISA = qw(Prima::OutlineViewer);

# node[0]:
#  0 : node text
#  1 : parent path, '' if none
#  2 : icon width
#  3 : drive icon, only for roots

my $unix = Prima::Application-> get_system_info->{apc} == apc::Unix || $^O =~ /cygwin/;
my @images;
my @drvImages;

{
   my $i = 0;
   my @idx = (  sbmp::SFolderOpened, sbmp::SFolderClosed);
   $images[ $i++] = Prima::StdBitmap::icon( $_) for @idx;
   unless ( $unix) {
      $i = 0;
      for ( sbmp::DriveFloppy, sbmp::DriveHDD,    sbmp::DriveNetwork,
            sbmp::DriveCDROM,  sbmp::DriveMemory, sbmp::DriveUnknown) {
         $drvImages[ $i++] = Prima::StdBitmap::icon($_);
      }
   }
}

sub profile_default
{
   return {
      %{$_[ 0]-> SUPER::profile_default},
      path           => '',
      dragable       => 0,
      openedGlyphs   => 1,
      closedGlyphs   => 1,
      openedIcon     => undef,
      closedIcon     => undef,
      showDotDirs    => 0,
   }
}

sub init_tree
{
   my $self = $_[0];
   my @tree;
   if ( $unix) {
      push ( @tree, [[ '/', ''], [], 0]);
   } else {
      my @drv = split( ' ', Prima::Utils::query_drives_map('A:'));
      for ( @drv) {
         my $type = Prima::Utils::query_drive_type($_);
         push ( @tree, [[ $_, ''], [], 0]);
      }
   }
   $self-> items( \@tree);
}

sub init
{
   my $self = shift;
   my %profile = @_;
   $profile{items} = [];
   %profile = $self-> SUPER::init( %profile);
   for ( qw( files filesStat items))             { $self->{$_} = []; }
   for ( qw( openedIcon closedIcon openedGlyphs closedGlyphs indent showDotDirs))
      { $self->{$_} = $profile{$_}}
   $self-> {openedIcon} = $images[0] unless $self-> {openedIcon};
   $self-> {closedIcon} = $images[1] unless $self-> {closedIcon};
   $self->{fontHeight} = $self-> font-> height;
   $self-> recalc_icons;
   $self-> init_tree;
   $self-> {cPath} = $profile{path};
   return %profile;
}

sub on_create
{
   my $self = $_[0];
# path could invoke adjust(), thus calling notify(), which
# fails until init() ends.
   $self-> path( $self-> {cPath}) if length $self-> {cPath};
}

sub draw_items
{
   my ($self, $canvas, $paintStruc) = @_;
   for ( @$paintStruc) {
      my ( $node, $left, $bottom, $right, $top, $position, $focused) = @$_;
      my $c;
      my $dw = length $node->[0]->[1] ?
         $self->{iconSizes}->[0] :
         $node->[0]->[2];
      if ( $focused) {
         $c = $canvas-> color;
         $canvas-> color( $self-> hiliteBackColor);
         $canvas-> bar( $left - $self->{indent} / 4, $bottom, $right, $top);
         $canvas-> color( $self-> hiliteColor);
      }
      my $icon = (length( $node->[0]->[1]) || $unix) ?
         ( $node->[2] ? $self->{openedIcon} : $self->{closedIcon}) : $node->[0]->[3];
      $canvas-> put_image(
        $left - $self->{indent} / 4,
        int($bottom + ( $self->{itemHeight} - $self->{iconSizes}->[1]) / 2),
        $icon);
      $canvas-> text_out( $node->[0]->[0], $left + $dw,
        int($bottom + ( $self->{itemHeight} - $self->{fontHeight}) / 2));
      $canvas-> color( $c) if $focused;
   }
}

sub recalc_icons
{
   my $self = $_[0];
   my $hei = $self-> font-> height + 2;
   my ( $o, $c) = (
      $self->{openedIcon} ? $self->{openedIcon}-> height : 0,
      $self->{closedIcon} ? $self->{closedIcon}-> height : 0
   );
   my ( $ow, $cw) = (
      $self->{openedIcon} ? ($self->{openedIcon}-> width / $self->{openedGlyphs}): 0,
      $self->{closedIcon} ? ($self->{closedIcon}-> width / $self->{closedGlyphs}): 0
   );
   $hei = $o if $hei < $o;
   $hei = $c if $hei < $c;
   unless ( $unix) {
      for ( @drvImages) {
         next unless defined $_;
         my @s = $_->size;
         $hei = $s[1] + 2 if $hei < $s[1] + 2;
      }
   }
   $self-> itemHeight( $hei);
   my ( $mw, $mh) = ( $ow, $o);
   $mw = $cw if $mw < $cw;
   $mh = $c  if $mh < $c;
   $self-> {iconSizes} = [ $mw, $mh];
}

sub on_fontchanged
{
   my $self = shift;
   $self-> recalc_icons;
   $self->{fontHeight} = $self-> font-> height;
   $self-> SUPER::on_fontchanged(@_);
}

sub on_measureitem
{
   my ( $self, $node, $result) = @_;
   my $tw = $self-> get_text_width( $node->[0]->[0]) + $self->{indent} / 4;

   unless ( length $node->[0]->[1]) { #i.e. root
      if ( $unix) {
         $node->[0]->[2] = $self->{iconSizes}->[0];
      } else {
         my $dt = Prima::Utils::query_drive_type($node->[0]->[0]) - dt::Floppy;
         $node->[0]->[2] = $drvImages[$dt] ? $drvImages[$dt]-> width : 0;
         $node->[0]->[3] = $drvImages[$dt];
      }
      $tw += $node->[0]->[2];
   } else {
      $tw += $self->{iconSizes}->[0];
   }
   $$result = $tw;
}

sub on_stringify
{
   my ( $self, $node, $result) = @_;
   $$result = $node->[0]->[0];
}

sub get_directory_tree
{
   my ( $self, $path) = @_;
   my @fs = Prima::Utils::getdir( $path);
   return [] unless scalar @fs;
   my $oldPointer = $::application-> pointer;
   $::application-> pointer( cr::Wait);
   my $i;
   my @fs1;
   my @fs2;
   for ( $i = 0; $i < scalar @fs; $i += 2) {
      push( @fs1, $fs[ $i]);
      push( @fs2, $fs[ $i + 1]);
   }

   $self-> {files}     = \@fs1;
   $self-> {filesStat} = \@fs2;
   my @d;
   if ( $self->{showDotDirs}) {
      @d   = grep { $_ ne '.' && $_ ne '..' } $self-> files( 'dir');
      push @d, grep { -d "$path/$_" } $self-> files( 'lnk');
   } else {
      @d = grep { !/\./ } $self-> files( 'dir');
      push @d, grep { !/\./ && -d "$path/$_" } $self-> files( 'lnk');
   }
   @d = sort @d;
   my $ind = 0;
   my @lb;
   for (@d)  {
      my $pathp = "$path/$_";
      @fs = Prima::Utils::getdir( "$path/$_");
      @fs1 = ();
      @fs2 = ();
      for ( $i = 0; $i < scalar @fs; $i += 2) {
         push( @fs1, $fs[ $i]);
         push( @fs2, $fs[ $i + 1]);
      }
      $self-> {files}     = \@fs1;
      $self-> {filesStat} = \@fs2;
      my @dd;
      if ( $self-> {showDotDirs}) {
         @dd   = grep { $_ ne '.' && $_ ne '..' } $self-> files( 'dir');
         push @dd, grep { -d "$pathp/$_" } $self-> files( 'lnk');
      } else {
         @dd = grep { !/\./ } $self-> files( 'dir');
         push @dd, grep { !/\./ && -d "$pathp/$_" } $self-> files( 'lnk');
      }
      push @lb, [[ $_, $path . ( $path eq '/' ? '' : '/')], scalar @dd ? [] : undef, 0];
   }
   $::application-> pointer( $oldPointer);
   return \@lb;
}

sub files {
   my ( $fn, $fs) = ( $_[0]->{files}, $_[0]-> {filesStat});
   return wantarray ? @$fn : $fn unless ($#_);
   my @f;
   for ( my $i = 0; $i < scalar @$fn; $i++)
   {
      push ( @f, $$fn[$i]) if $$fs[$i] eq $_[1];
   }
   return wantarray ? @f : \@f;
}

sub on_expand
{
   my ( $self, $node, $action) = @_;
   return unless $action;
   my $x = $self-> get_directory_tree( $node->[0]->[1].$node->[0]->[0]);
   $node->[1] = $x;
#  valid way to do the same -
#  $self-> delete_items( $node);
#  $self-> insert_items( $node, 0, @$x); but since on_expand is never called directly,
#  adjust() will call necessary update functions for us.
}

sub path
{
   my $self = $_[0];
   unless ( $#_) {
      my ( $n, $l) = $self-> get_item( $self-> focusedItem);
      return '' unless $n;
      return $n->[0]->[1].$n->[0]->[0];
   }
   my $p = $_[1];
   $p =~ s{^([^\\\/]*[\\\/][^\\\/]*)[\\\/]$}{$1};
   unless ( scalar( stat $p)) {
      $p = "";
   } else {
      $p = eval { Cwd::abs_path($p) };
      $p = "." if $@;
      $p = "" unless -d $p;
      $p = '' if !$self->{showDotDirs} && $p =~ /\./;
      $p .= '/' unless $p =~ m![/\\]$!;
   }
   $self-> {path} = $p;
   if ( $p eq '/') {
      $self-> focusedItem(0);
      return;
   }
   $p = lc $p unless $unix;
   my @ups = split /[\/\\]/, $p;
   my $root;
   if ( $unix) {
      shift @ups if $ups[0] eq '';
      $root = $self->{items}->[0];
   } else {
      my $lr = shift @ups;
      for ( @{$self->{items}}) {
         my $drive = lc $_->[0]->[0];
         $root = $_, last if $lr eq $drive;
      }
      return unless defined $root;
   }

   UPS: for ( @ups) {
      last UPS unless defined $root->[1];
      my $subdir = $_;
      unless ( $root->[2]) {
         my ( $idx, $lev) = $self-> get_index( $root);
         $self-> adjust( $idx, 1);
      }
      BRANCH: for ( @{$root->[1]}) {
         next unless lc($_->[0]->[0]) eq lc($subdir);
         $root = $_;
         last BRANCH;
      }
   }
   my ( $idx, $lev) = $self-> get_index( $root);
   $self-> focusedItem( $idx);
   $self-> adjust( $idx, 1);
   $self-> topItem( $idx);
}

sub openedIcon
{
   return $_[0]->{openedIcon} unless $#_;
   $_[0]-> {openedIcon} = $_[1];
   $_[0]-> recalc_icons;
   $_[0]-> calibrate;
}

sub closedIcon
{
   return $_[0]->{closedIcon} unless $#_;
   $_[0]->{closedIcon} = $_[1];
   $_[0]-> recalc_icons;
   $_[0]-> calibrate;
}

sub openedGlyphs
{
   return $_[0]->{openedGlyphs} unless $#_;
   $_[1] = 1 if $_[1] < 1;
   $_[0]->{openedGlyphs} = $_[1];
   $_[0]-> recalc_icons;
   $_[0]-> calibrate;
}

sub closedGlyphs
{
   return $_[0]->{closedGlyphs} unless $#_;
   $_[1] = 1 if $_[1] < 1;
   $_[0]->{closedGlyphs} = $_[1];
   $_[0]-> recalc_icons;
   $_[0]-> calibrate;
}

sub showDotDirs
{
   return $_[0]->{showDotDirs} unless $#_;
   my $p = $_[0]-> path;
   $_[0]->{showDotDirs} = $_[1];
   $_[0]-> init_tree;
   $_[0]->{path} = '';
   $_[0]->path($p);
}

1;

__DATA__

=pod

=head1 NAME

Prima::Outlines - tree view widgets

=head1 DESCRIPTION

The module provides a set of widget classes, designed to display a tree-like
hierarchy of items. C<Prima::OutlineViewer> presents a generic class that
contains basic functionality and defines the interface for the descendants, which are
C<Prima::StringOutline>, C<Prima::Outline>, and C<Prima::DirectoryOutline>.

=head1 SYNOPSIS

  my $outline = Prima::StringOutline-> create(
    items => [
       [  'Simple item' ],
       [[ 'Embedded item ']],
       [[ 'More embedded items', [ '#1', '#2' ]]],
    ],
  );
  $outline-> expand_all;

=head1 Prima::OutlineViewer

Presents a generic interface for browsing the tree-like lists.
A node in a linked list represents each item.
The format of node is predefined, and is an anonymous array
with the following definitions of indices:

=over

=item 0

Item id with non-defined format. The simplest implementation, C<Prima::StringOutline>, 
treats the scalar as a text string. The more complex classes store 
references to arrays or hashes here. See C<items> article of a concrete class
for the format of a node record.

=item 1

Reference to a child node. C<undef> if there is none.

=item 2

A boolean flag, which selects if the node shown as expanded, e.g.
all its immediate children are visible.

=item 3

Width of an item in pixels.

=back

The indices above 3 should not be used, because eventual changes to the
implementation of the class may use these. It should be enough item 0 to store 
any value.

To support a custom format of node, it is sufficient to overload the following 
notifications: C<DrawItem>, C<MeasureItem>, C<Stringify>. Since C<DrawItem> is
called for every item, a gross method C<draw_items> can be overloaded instead.
See also L<Prima::StringOutline> and L<Prima::Outline>.

The class employs two addressing methods, index-wise and item-wise. The index-wise
counts only the visible ( non-expanded ) items, and is represented by an integer index.
The item-wise addressing cannot be expressed by an integer index, and the full
node structure is used as a reference. It is important to use a valid reference here,
since the class does not always perform the check if the node belongs to internal node list due to 
the speed reasons.

C<Prima::OutlineViewer> is a descendant of C<Prima::GroupScroller> and C<Prima::MouseScroller>, 
so some properties and methods are not described here. See L<Prima::IntUtils> for these.

The class is not usable directly.

=head2 Properties

=over

=item autoHeight INTEGER

If set to 1, changes C<itemHeight> automatically according to the widget font height.
If 0, does not influence anything.  When C<itemHeight> is set explicitly, 
changes value to 0.

Default value: 1

=item dragable BOOLEAN

If 1, allows the items to be dragged interactively by pressing control key
together with left mouse button. If 0, item dragging is disabled.

Default value: 1

=item focusedItem INTEGER

Selects the focused item index. If -1, no item is focused.
It is mostly a run-time property, however, it can be set
during the widget creation stage given that the item list is 
accessible on this stage as well.

=item indent INTEGER

Width in pixels of the indent between item levels.

Default value: 12

=item itemHeight INTEGER

Selects the height of the items in pixels. Since the outline classes do 
not support items with different vertical dimensions, changes to this property 
affect all items.

Default value: default font height

=item items ARRAY

Provides access to the items as an anonymous array. The format of items is
described in the opening article ( see L<Prima::OutlineViewer> ).

Default value: []

=item offset INTEGER

Horizontal offset of an item list in pixels.

=item topItem INTEGER

Selects the first item drawn.

=item showItemHint BOOLEAN

If 1, allows activation of a hint label when the mouse pointer is hovered above
an item that does not fit horizontally into the widget inferiors. If 0,
the hint is never shown.

See also: L<makehint>.

Default value: 1

=back

=head2 Methods

=over

=item adjust INDEX, EXPAND

Performs expansion ( 1 ) or collapse ( 0 ) of INDEXth item, depending on EXPAND
boolean flag value.

=item calibrate

Recalculates the node tree and the item dimensions. 
Used internally.

=item delete_items [ NODE = undef, OFFSET = 0, LENGTH = undef ]

Deletes LENGTH children items of NODE at OFFSET. 
If NODE is C<undef>, the root node is assumed. If LENGTH 
is C<undef>, all items after OFFSET are deleted.

=item delete_item NODE

Deletes NODE from the item list.

=item draw_items CANVAS, PAINT_DATA

Called from within C<Paint> notification to draw
items. The default behavior is to call C<DrawItem>
notification for every visible item. PAINT_DATA
is an array of arrays, where each array consists
of parameters, passed to C<DrawItem> notification.

This method is overridden in some descendant classes,
to increase the speed of the drawing routine.

See L<DrawItem> for PAINT_DATA parameters description.

=item get_index NODE

Traverses all items for NODE and finds if it is visible.
If it is, returns two integers: the first is item index
and the second is item depth level. If it is not visible,
C<-1, undef> is returned.

=item get_index_text INDEX

Returns text string assigned to INDEXth item.
Since the class does not assume the item storage organization,
the text is queried via C<Stringify> notification.

=item get_index_width INDEX

Returns width in pixels of INDEXth item, which is a
cached result of C<MeasureItem> notification, stored
under index #3 in node.

=item get_item INDEX

Returns two scalars corresponding to INDEXth item: 
node reference and its depth level. If INDEX is outside
the list boundaries, empty array is returned.

=item get_item_parent NODE

Returns two scalars, corresponding to NODE:
its parent node reference and offset of NODE in the parent's
immediate children list.

=item get_item_text NODE

Returns text string assigned to NODE.
Since the class does not assume the item storage organization,
the text is queried via C<Stringify> notification.

=item get_item_width NODE

Returns width in pixels of INDEXth item, which is a
cached result of C<MeasureItem> notification, stored
under index #3 in node.

=item expand_all [ NODE = undef ].

Expands all nodes under NODE. If NODE is C<undef>, the root node
is assumed. If the tree is large, the execution can take
significant amount of time.

=item insert_items NODE, OFFSET, @ITEMS

Inserts one or more ITEMS under NODE with OFFSET.
If NODE is C<undef>, the root node is assumed.

=item iterate ACTION, FULL

Traverses the item tree and calls ACTION subroutine
for each node. If FULL boolean flag is 1, all nodes
are traversed. If 0, only the expanded nodes are traversed.

ACTION subroutine is called with the following parameters:

=over

=item 0

Node reference

=item 1

Parent node reference; if C<undef>, the node is the root.

=item 2

Node offset in parent item list.

=item 3

Node index.

=item 4

Node depth level. 0 means the root node.

=item 5

A boolean flag, set to 1 if the node is the last child in parent node list,
set to 0 otherwise.

=back

=item makehint SHOW, INDEX

Controls hint label upon INDEXth item. If a boolean flag SHOW is set to 1,
and C<showItemHint> property is 1, and the item index does not fit horizontally
in the widget inferiors then the hint label is shown. 
By default the label is removed automatically as the user moves the mouse pointer
away from the item. If SHOW is set to 0, the hint label is hidden immediately.

=item point2item Y, [ HEIGHT ]

Returns index of an item that contains horizontal axis at Y in the widget coordinates.
If HEIGHT is specified, it must be the widget height; if it is
not, the value is fetched by calling C<Prima::Widget::height>.
If the value is known, passing it to C<point2item> thus achieves
some speed-up.

=item validate_items ITEMS

Traverses the array of ITEMS and puts every node to 
the common format: cuts scalars above index #3, if there are any,
or adds default values to a node if it contains less than 3 scalars.

=back

=head2 Events

=over

=item Expand NODE, EXPAND

Called when NODE is expanded ( 1 ) or collapsed ( 0 ). 
The EXPAND boolean flag reflects the action taken.

=item DragItem OLD_INDEX, NEW_INDEX

Called when the user finishes the drag of an item
from OLD_INDEX to NEW_INDEX position. The default action
rearranges the item list in accord with the dragging action.

=item DrawItem CANVAS, NODE, X1, Y1, X2, Y2, INDEX, FOCUSED

Called when INDEXth item, contained in NODE is to be drawn on 
CANVAS. X1, Y1, X2, Y2 coordinated define the exterior rectangle
of the item in widget coordinates. FOCUSED boolean flag is set to
1 if the item is focused; 0 otherwise.

=item MeasureItem NODE, REF

Puts width of NODE item in pixels into REF
scalar reference. This notification must be called 
from within C<begin_paint_info/end_paint_info> block.

=item SelectItem INDEX

Called when INDEXth item gets focused.

=item Stringify NODE, TEXT_REF

Puts text string, assigned to NODE item into TEXT_REF
scalar reference.

=back

=head1 Prima::StringOutline

Descendant of C<Prima::OutlineViewer> class, provides standard 
single-text items widget. The items can be set by merely
supplying a text as the first scalar in node array structure:

  $string_outline-> items([ 'String', [ 'Descendant' ]]);

=head1 Prima::Outline

A variant of C<Prima::StringOutline>, with the only difference
that the text is stored not in the first scalar in a node but
as a first scalar in an anonymous array, which in turn is
the first node scalar. The class does not define neither format nor
the amount of scalars in the array, and as such presents a half-abstract
class.

=head1 Prima::DirectoryOutline

Provides a standard widget with the item tree mapped to the directory
structure, so each item is mapped to a directory. Depending on the type 
of the host OS, there is either single root directory ( unix ), or
one or more disk drive root items ( win32, os2 ).

The format of a node is defined as follows:

=over

=item 0

Directory name, string.

=item 1

Parent path; an empty string for the root items.

=item 2

Icon width in pixels, integer.

=item 3

Drive icon; defined only for the root items under non-unix hosts
in order to reflect the drive type ( hard, floppy, etc ).

=back

=head2 Properties

=over

=item closedGlyphs INTEGER

Number of horizontal equal-width images, contained in C<closedIcon>
property.

Default value: 1

=item closedIcon ICON

Provides an icon representation for the collapsed items.

=item openedGlyphs INTEGER

Number of horizontal equal-width images, contained in C<openedIcon>
property.

Default value: 1

=item openedIcon OBJECT

Provides an icon representation for the expanded items.

=item path STRING

Runtime-only property. Selects current file system path.

=item showDotDirs BOOLEAN

Selects if the directories with the first dot character
are shown the tree view. The treatment of the dot-prefixed names
as hidden is traditional to unix, and is of doubtful use under
win32 and os2.

Default value: 0

=back

=head2 Methods

=over

=item files [ FILE_TYPE ]

If FILE_TYPE value is not specified, the list of all files in the
current directory is returned. If FILE_TYPE is given, only the files
of the types are returned. The FILE_TYPE is a string, one of those
returned by C<Prima::Utils::getdir> ( see L<Prima::Utils/getdir> ).

=item get_directory_tree PATH

Reads the file structure under PATH and returns a newly created hierarchy 
structure in the class node format. If C<showDotDirs> property value is 0,
the dot-prefixed names are not included.

Used internally inside C<Expand> notification.

=back

=head1 AUTHOR

Dmitry Karasik, E<lt>dmitry@karasik.eu.orgE<gt>.

=head1 SEE ALSO

L<Prima>, L<Prima::Widget>, L<Prima::IntUtils>, <examples/outline.pl>.

=cut
