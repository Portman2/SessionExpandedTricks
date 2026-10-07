use strict; use warnings;
# hinge.pl <bin> [seg from to step]  -- needs a v99+ recording (frame header 512+: the thigh / shin rotations at 308).
# THE KNEE AS A HINGE. From plain riding poses of the file (the leg whole and bent) the normal of each leg's plane is taken
# into its thigh's own frame and its shin's: the hinge axis as the game's own legs have it. Then, per pose, how far each
# bone's axis stands off the plane's normal (deg) -- as the pose ARRIVED and as DRAWN -- and the ankle's twist about the
# shin measured with the shin BONE's own roll (not the plane's). Without a segment: per segment, the largest of each and
# the poses over 20 deg. With a segment, per pose, also v99's appended fields: the hinge roll put in, the hip joints off
# their sockets, "more" (1 sockets turned, 2 hinges known, 4 a hop's hips put back, 8 the plant foot swivels).
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))} sub nrm{my $l=len($_[0])||1;[map{$_/$l}@{$_[0]}]}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
sub qinv{my($q,$v)=@_; qrot([-$q->[0],-$q->[1],-$q->[2],$q->[3]],$v)}
sub ang{my($a,$b)=@_; my $c=dot(nrm($a),nrm($b)); $c=1 if $c>1; $c=-1 if $c<-1; atan2(sqrt(1-$c*$c),$c)*57.29578}
my @segs; my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++; push @segs,[$seg,$off,$hdr,$frames,$bones,$fh,$fbytes,$pre]; $off+=$segBytes; }
die "no v99 fields in this file (frame header ".(@segs?$segs[0][5]:0)." bytes, 512 needed)\n" if !@segs || $segs[0][5]<512;
sub leg{ my($s,$i,$set,$sd)=@_; my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; my @rig=unpack('s<36',substr($d,$o+88,72)); my $fo=$o+$hdr+$i*$fb;
  my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$set*$bones*12+$_[0]*12,12))]}; my($h,$k,$a)=map{$P->($rig[$_+$sd])}(1,3,5);
  my @q2=unpack('f<32',substr($d,$fo+308,128)); my $tq=[@q2[$set*16+$sd*4..$set*16+$sd*4+3]]; my $cq=[@q2[$set*16+8+$sd*4..$set*16+8+$sd*4+3]];
  my @q=unpack('f<40',substr($d,$fo+148,160)); my $fq=[@q[$set*20+4+$sd*4..$set*20+7+$sd*4]];
  my $th=sub3($k,$h); my $sh=sub3($a,$k); my $nn=cross($th,$sh);
  return { nn=>$nn, bent=>len($nn), tq=>$tq, cq=>$cq, fq=>$fq, th=>$th, sh=>$sh, tl=>len($th), sl=>len($sh) }; }
# the hinge, from the arrived riding poses
my (@hT,@hC,@cnt,@fRef);
for my $sd (0,1){ my @a=(0,0,0); my @b=(0,0,0); my @fr=(0,0,0); my $c=0;
  for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; for(my $i=0;$i<$frames;$i+=2){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); next if ($fl&0x3FF)||($fl&0x800);
      my $L=leg($s,$i,0,$sd); next if $L->{bent}<400 || $L->{sl}<39.5 || $L->{sl}>42.7 || $L->{tl}<41 || $L->{tl}>44.3; my $n1=nrm($L->{nn});
      my $x=qinv($L->{tq},$n1); my $y=qinv($L->{cq},$n1); my $z=qinv($L->{cq},qrot($L->{fq},[1,0,0]));   # (the foot bone's own x axis seen from the shin: how it rides on it)
      $a[$_]+=$x->[$_] for 0..2; $b[$_]+=$y->[$_] for 0..2; $fr[$_]+=$z->[$_] for 0..2; $c++; } }
  $hT[$sd]=nrm(\@a); $hC[$sd]=nrm(\@b); $fRef[$sd]=nrm(\@fr); $cnt[$sd]=$c;
  printf "%s knee's hinge from %d riding poses: in the thigh's frame (%.2f %.2f %.2f), in the shin's (%.2f %.2f %.2f); how tightly they agree: %.3f / %.3f (1 = all alike)\n",$sd?'R':'L',$c,@{$hT[$sd]},@{$hC[$sd]},$c?len(\@a)/$c:0,$c?len(\@b)/$c:0; }
sub errs{ my($L,$sd)=@_; return (undef,undef,undef) if $L->{bent}<300; my $n1=nrm($L->{nn});
  my $s=nrm($L->{sh}); my $fx=qrot($L->{fq},[1,0,0]); my $rx=qrot($L->{cq},$fRef[$sd]);          # the foot's x axis now / where it rides on this shin bone
  my $pa=sub3($fx,[map{$s->[$_]*dot($fx,$s)}0..2]); my $pb=sub3($rx,[map{$s->[$_]*dot($rx,$s)}0..2]);
  my $tw=(len($pa)>0.2&&len($pb)>0.2)? atan2(dot(cross($pb,$pa),$s),dot($pb,$pa))*57.29578 : 0;
  (ang(qrot($L->{tq},$hT[$sd]),$n1), ang(qrot($L->{cq},$hC[$sd]),$n1), $tw) }
for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb,$pre)=@$s; next if defined $sgW && $n!=$sgW;
  if(defined $sgW){ print "   #  flags    more | L: hinge off (thigh shin) arrived > drawn, ankle twist on the shin bone arrived > drawn, roll put in (thigh shin), hip gap | R: the same\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $fo=$o+$hdr+$i*$fb; my $fl=unpack('V',substr($d,$fo,4)); my @x=unpack('f<6',substr($d,$fo+484,24)); my $more=unpack('V',substr($d,$fo+508,4));
      my $line=sprintf("%4d %08X %02X |",$i,$fl,$more);
      for my $sd (0,1){ my @g=errs(leg($s,$i,0,$sd),$sd); my @dr=errs(leg($s,$i,1,$sd),$sd);
        $line.=sprintf(" %3s %3s > %3s %3s, %4s > %4s, %+4.0f %+4.0f, %4.1f |",(map{defined $_?sprintf("%.0f",$_):'-'}@g[0,1],@dr[0,1],$g[2],$dr[2]),$x[2+$sd*2],$x[3+$sd*2],$x[$sd]); }
      print "$line\n"; } next; }
  my $line=sprintf("seg %2d",$n);
  for my $sd (0,1){ my @mx=(0,0,0,0,0,0); my @nb=(0,0); for(my $i=0;$i<$frames;$i++){ my @g=errs(leg($s,$i,0,$sd),$sd); my @dr=errs(leg($s,$i,1,$sd),$sd);
      for my $j (0..2){ $mx[$j]=abs($g[$j]) if defined $g[$j] && abs($g[$j])>$mx[$j]; $mx[3+$j]=abs($dr[$j]) if defined $dr[$j] && abs($dr[$j])>$mx[3+$j]; }
      $nb[0]++ if defined $g[0] && ($g[0]>20||$g[1]>20); $nb[1]++ if defined $dr[0] && ($dr[0]>20||$dr[1]>20); }
    $line.=sprintf(" | %s hinge off most: drawn thigh %3.0f shin %3.0f (over 20 on %3d poses), arrived %3.0f %3.0f (%3d); ankle twist drawn %3.0f arrived %3.0f",$sd?'R':'L',@mx[3,4],$nb[1],@mx[0,1],$nb[0],$mx[5],$mx[2]); }
  print "$line\n"; }
