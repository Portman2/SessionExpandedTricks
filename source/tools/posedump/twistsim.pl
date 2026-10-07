use strict; use warnings;
# twistsim.pl <bin> <seg> <firstAirPose> <leg 0|1>: replays native v98's "own twist" on a recorded take-off: the knee as drawn (v97) and as v98 would draw it
my ($file,$sgW,$i0,$sd)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub add3{[map{$_[0][$_]+$_[1][$_]}0..2]} sub mul3{[map{$_[0][$_]*$_[1]}0..2]}
sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))} sub nrm{my $l=len($_[0])||1; mul3($_[0],1/$l)}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub perp{my($v,$ax)=@_; sub3($v,mul3($ax,dot($v,$ax)))}
sub sm{my $x=$_[0]; $x=0 if $x<0; $x=1 if $x>1; $x*$x*(3-2*$x)}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes)=unpack('a4 v v V V v v V',substr($d,$off,24));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){
    my @rig=unpack('s<36',substr($d,$off+88,72));
    my $P=sub{ my($i,$set,$b)=@_; [unpack('f<3',substr($d,$off+$hdr+$i*$fbytes+$fh+$set*$bones*12+$b*12,12))] };
    my $T=sub{ unpack('d<',substr($d,$off+$hdr+$_[0]*$fbytes+8,8)) };
    my ($ih,$ik,$ia)=map{$rig[$_+$sd]}(1,3,5);
    # the record, on the pose before the air: from the game's knee way to the drawn one, about the drawn hip->ankle
    my $j=$i0-1; my($gh,$gk,$ga,$dh,$dk,$da)=((map{$P->($j,0,$_)}($ih,$ik,$ia)),(map{$P->($j,1,$_)}($ih,$ik,$ia)));
    my $ax=nrm(sub3($da,$dh)); my $gax=nrm(sub3($ga,$gh));
    my $u=nrm(perp(perp(sub3($gk,$gh),$gax),$ax)); my $v=nrm(perp(sub3($dk,$dh),$ax));
    my $tw=atan2(dot(cross($u,$v),$ax),dot($u,$v)); my $t0=$T->($j);
    printf "seg %d  %s leg: kept on pose #%d: %.1f deg\n",$seg,$sd?'R':'L',$j,$tw*57.29578;
    my ($pOld,$pNew)=($dk,$dk);
    for($j=$i0;$j<$i0+22&&$j<$frames;$j++){
      my($h,$k,$a)=map{$P->($j,1,$_)}($ih,$ik,$ia); my $age=$T->($j)-$t0; my $t=($age<0.15)?$tw*(1-sm($age/0.15)):0;
      my $x=nrm(sub3($a,$h)); my $r=sub3($k,$h); my $al=mul3($x,dot($r,$x)); my $pp=sub3($r,$al);
      my $rot=add3(mul3($pp,cos($t)),mul3(cross($x,$pp),sin($t))); my $kn=add3($h,add3($al,$rot));
      printf "  +%-2d age %5.1f ms  turn %5.1f deg | knee step: recorded %4.1f cm, with v98 %4.1f cm\n",$j-$i0,$age*1000,$t*57.29578,len(sub3($k,$pOld)),len(sub3($kn,$pNew));
      ($pOld,$pNew)=($k,$kn);
    }
  }
  $off+=$segBytes;
}
