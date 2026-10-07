use strict; use warnings;
# kneeway.pl <bin> [pre post]: at every pose a hop's air begins (flag 0x1 rising), for each leg and for the poses pre..post round it:
# the leg's reach (hip-ankle, % of the drawn bones), the knee's distance off the hip-ankle line, the knee's WAY (deg round the leg from the toes' way)
# and the knee's step from the pose before -- for the pose as it ARRIVED (g) and as DRAWN (d). Mesh space.
my ($file,$pre,$post,$sgW,$frW)=@ARGV; $pre//=2; $post//=5;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
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
  my $T=sub{ unpack('d<',substr($d,$off+$hdr+$_[0]*$fbytes+8,8)) };
  my $m=sub{ my($i,$set,$sd)=@_; my($h,$k,$a,$t)=map{$P->($i,$set,$rig[$_+$sd])}(1,3,5,7);
     my $ha=sub3($a,$h); my $kv=perp(sub3($k,$h),$ha); my $tv=perp(sub3($t,$a),$ha); my $ax=[map{$_/ (len($ha)||1)}@$ha];
     my $ang=(len($kv)>0.01&&len($tv)>0.01)? atan2(dot(cross($tv,$kv),$ax),dot($tv,$kv))*57.29578 : 0;
     return { reach=>len($ha), bones=>len(sub3($k,$h))+len(sub3($a,$k)), offl=>len($kv), ang=>$ang, k=>$k } };
  for(my $i=1;$i<$frames;$i++){
    if(defined $sgW){ next unless $seg==$sgW && $i==$frW; } else { next unless ($FL->($i)&1) && !($FL->($i-1)&1); }
    for my $sd (0,1){
      my @rows; my $prev;
      for(my $j=$i-$pre-1;$j<=$i+$post&&$j<$frames;$j++){ next if $j<0; my($g,$dr)=($m->($j,0,$sd),$m->($j,1,$sd));
        if($prev && $j>=$i-$pre){ push @rows, sprintf("   %+d %08X  g: reach %3.0f%% off %4.1f way %5.0f step %4.1f | d: reach %3.0f%% off %4.1f way %5.0f step %4.1f",
            $j-$i,$FL->($j), 100*$g->{reach}/$dr->{bones},$g->{offl},$g->{ang},len(sub3($g->{k},$prev->[0]{k})), 100*$dr->{reach}/$dr->{bones},$dr->{offl},$dr->{ang},len(sub3($dr->{k},$prev->[1]{k}))); }
        $prev=[$g,$dr]; }
      printf "seg %d  at #%d  %s leg\n%s\n",$seg,$i,$sd?'R':'L',join("\n",@rows);
    }
  }
  $off+=$segBytes;
}
