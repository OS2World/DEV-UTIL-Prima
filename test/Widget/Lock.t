# $Id: Lock.t,v 1.2 2000/10/18 11:58:24 tobez Exp $
print "1..3 child create lock,child unlock,lock conststency\n";

$dong = 0;
$w-> lock;
my $c = $w-> insert( Widget =>
   onPaint => sub { $dong = 1;}
);
$c-> update_view;
ok( !$dong);

$dong = 0;
$c-> repaint;
$w-> unlock;
$c-> update_view;
ok($dong);

$dong = 0;
$c-> lock;
$c-> repaint;
$c-> update_view;
ok( !$dong);
$c-> unlock;
$c-> destroy;
1;

