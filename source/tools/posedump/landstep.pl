use strict; use warnings;
# landstep.pl <bin>: every touchdown (flag 0x2 rising): per leg, the knee's largest one-pose step over landing poses 0..5, as ARRIVED and as DRAWN,
# the largest one-pose change of the drawn knee's way (deg round the leg), and the same over the 40 poses after (the legs' own-length part)
my ($file)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub perp{my($v,$ax)=@_; my $l2=dot($ax,$ax); return $v if $l2<1e-6; my $k=dot($v,$ax)/$l2; [map{$v->[$_]-$ax->[$_]*$k}0..2]}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre0)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  my @rig=unpack('s<36',substr($d,$off+88,72));
  my $P=sub{ my($i,$set,$b)=@_; [unpack('f<3',substr($d,$off+$hdr+$i*$fbytes+$fh+$set*$bones*12+$b*12,12))] };
  my $FL=sub{ unpack('V',substr($d,$off+$hdr+$_[0]*$fbytes,4)) };
  my $m=sub{ my($i,$set,$sd)=@_; my($h,$k,$a,$t)=map{$P->($i,$set,$rig[$_+$sd])}(1,3,5,7);
     my $ha=sub3($a,$h); my $kv=perp(sub3($k,$h),$ha); my $tv=perp(sub3($t,$a),$ha); my $ax=[map{$_/(len($ha)||1)}@$ha];
     my $ang=(len($kv)>0.01&&len($tv)>0.01)? atan2(dot(cross($tv,$kv),$ax),dot($tv,$kv))*57.29578 : 0;
     return { offl=>len($kv), ang=>$ang, k=>$k } };
  for(my $i=1;$i<$frames;$i++){
    next unless ($FL->($i)&2) && !($FL->($i-1)&2);
    my $out=sprintf("seg %2d #%-4d %s",$seg,$i,($FL->($i)&0x1000000)?'mir':'   ');
    for my $sd (0,1){ my @mx=(0,0,0,0,0,0); my @at=(0,0,0,0,0,0);
      for(my $j=$i;$j<=$i+45&&$j<$frames;$j++){ last if $j>$i+5 && ($FL->($j)&1);
        my($g0,$g1,$d0,$d1)=($m->($j-1,0,$sd),$m->($j,0,$sd),$m->($j-1,1,$sd),$m->($j,1,$sd)); my $w=($j<=$i+5)?0:3;
        my $gs=len(sub3($g1->{k},$g0->{k})); my $ds=len(sub3($d1->{k},$d0->{k})); my $da=$d1->{ang}-$d0->{ang}; $da-=360 while $da>180; $da+=360 while $da<-180; $da=abs($da)*(($d1->{offl}<6||$d0->{offl}<6)?0:1);
        if($gs>$mx[$w]){$mx[$w]=$gs} if($ds>$mx[$w+1]){$mx[$w+1]=$ds;$at[$w+1]=$j-$i} if($da>$mx[$w+2]){$mx[$w+2]=$da;$at[$w+2]=$j-$i} }
      $out.=sprintf(" | %s 0-5: g %4.1f d %4.1f(+%d) way %3.0f(+%d)  6-45: g %4.1f d %4.1f(+%d) way %3.0f(+%d)",$sd?'R':'L',$mx[0],$mx[1],$at[1],$mx[2],$at[2],$mx[3],$mx[4],$at[4],$mx[5],$at[5]); }
    print "$out\n";
  }
  $off+=$segBytes;
}
