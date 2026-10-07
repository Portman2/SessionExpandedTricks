use strict; use warnings;
# yaws.pl <bin> <seg> <from> <to> <step>: WORLD headings (deg): the mesh, the drawn deck, the hips' line (R->L hip joint) and each foot (ankle->toe), as ARRIVED and as DRAWN
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){ my @rig=unpack('s<36',substr($d,$off+88,72));
    print "   #  flags    | mesh  deck | hips: arr drawn | L foot: arr drawn | R foot: arr drawn | (foot minus hips, drawn: L R)\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4));
      my @m=unpack('f<10',substr($d,$o+16,40)); my $mq=[@m[0..3]]; my @dk=unpack('f<7',substr($d,$o+56,28)); my $dq=[@dk[0..3]];
      my $Y=sub{ my $v=qrot($mq,$_[0]); atan2($v->[1],$v->[0])*57.29578 };
      my $P=sub{ my($set,$b)=@_; [unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$rig[$b]*12,12))] };
      my $D=sub{ my($set,$a,$b)=@_; my($p,$q)=($P->($set,$a),$P->($set,$b)); $Y->([map{$q->[$_]-$p->[$_]}0..2]) };
      my @h=map{$D->($_,2,1)}(0,1); my @l=map{$D->($_,5,7)}(0,1); my @r=map{$D->($_,6,8)}(0,1);
      my $w=sub{my $a=shift; $a-=360 while $a>180; $a+=360 while $a<-180; $a};
      printf "%4d %08X | %5.0f %5.0f | %5.0f %5.0f | %5.0f %5.0f | %5.0f %5.0f | %5.0f %5.0f\n",$i,$fl,$Y->([1,0,0]),$Y->(qrot($dq,[1,0,0])),@h,@l,@r,$w->($l[1]-$h[1]),$w->($r[1]-$h[1]); } }
  $off+=$segBytes; }
