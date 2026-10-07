use strict; use warnings;
# shinsim.pl <bin> <seg> <from> <to> <step> [leg]: for the poses the mod re-solved a squeezed leg after a hop's landing, the knee as DRAWN (v96: toward the toes)
# and as it would be with the knee's way taken from the RIDING shin (the shin's direction in the foot bone's own frame, learned from the segment's first riding poses)
my ($file,$segWant,$fa,$fb,$st,$k)=@ARGV; $st||=1; $k//=0;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qrot{my($q,$v)=@_;my $p=qmul(qmul($q,[@$v,0]),qconj($q));[@$p[0..2]]}
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub add3{[map{$_[0][$_]+$_[1][$_]}0..2]} sub mul3{[map{$_[0][$_]*$_[1]}0..2]} sub dot{my$s=0;$s+=$_[0][$_]*$_[1][$_] for 0..2;$s} sub len{sqrt(dot($_[0],$_[0]))}
sub norm{my$l=len($_[0])||1;[map{$_/$l}@{$_[0]}]} sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$segWant){
    my @rig=unpack('s<36',substr($d,$off+88,72)); my ($th,$ca,$ft,$to)=($rig[1+$k],$rig[3+$k],$rig[5+$k],$rig[7+$k]);
    my $get=sub{ my($i,$set)=@_; my $o=$off+$hdr+$i*$fbytes; my @q=unpack('f<40',substr($d,$o+148,160)); my $Q=[@q[$set*20+4+4*$k..$set*20+7+4*$k]];
      my $P=sub{[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$_[0]*12,12))]}; my $fl=unpack('V',substr($d,$o,4)); ($fl,$Q,map{$P->($_)}($th,$ca,$ft,$to)) };
    my (@sr,@ul,@tl); my $n=0; my ($a1,$a2)=(0,0);
    for my $i (0..25){ my ($fl,$Q,$H,$K,$A,$T)=$get->($i,0); next if $fl&0x3ff; my $sh=sub3($K,$A); next if len($sh)<39.5; my $sl=qrot(qconj($Q),norm($sh)); $sr[$_]+=$sl->[$_] for 0..2;
      my $t=qrot(qconj($Q),norm(sub3($T,$A))); my $u=qrot(qconj($Q),[0,0,1]); $tl[$_]+=$t->[$_] for 0..2; $ul[$_]+=$u->[$_] for 0..2; $a1+=len(sub3($K,$H)); $a2+=len($sh); $n++; }
    die "no riding poses" unless $n; my $ref=norm(\@sr); my $tL=norm(\@tl); my $uL=norm(\@ul); my $sL=norm(cross($uL,$tL)); $uL=norm(cross($tL,$sL)); $a1/=$n; $a2=$a1*0.965;
    printf "seg %d leg %s: riding shin in the foot's frame (%.2f %.2f %.2f) from %d poses, bones %.1f + %.1f\n   fr | game shin cm | DRAWN knee (x y z)  fwd/side | RIDING-WAY knee (x y z)  fwd/side | the two knees apart cm | new knee's step from the pose before cm\n",$seg,$k?'R':'L',@$ref,$n,$a1,$a2;
    my $prev;
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my ($fl,$Q,$H,$K,$A,$T)=$get->($i,1); my ($fl0,$Q0,$H0,$K0,$A0,$T0)=$get->($i,0);
      my $lean=sub{ my $s=norm(sub3($_[0],$A)); my ($u,$t,$l)=map{qrot($Q,$_)}($uL,$tL,$sL); (atan2(dot($s,$t),dot($s,$u))*57.29578, atan2(dot($s,$l),sqrt(dot($s,$u)**2+dot($s,$t)**2))*57.29578) };
      my $hf=sub3($A,$H); my $dl=len($hf); my $nn=norm($hf); my $s=qrot($Q,$ref); my $pp=sub3($s,mul3($nn,dot($s,$nn))); next if len($pp)<0.25; $pp=norm($pp);
      my $dd=$dl; $dd=($a1+$a2)*0.995 if $dd>($a1+$a2)*0.995; my $cosA=($a1*$a1+$dd*$dd-$a2*$a2)/(2*$a1*$dd); $cosA=1 if $cosA>1; $cosA=-1 if $cosA<-1; my $sinA=sqrt(1-$cosA*$cosA);
      my $Kn=add3(add3($H,mul3($nn,$a1*$cosA)),mul3($pp,$a1*$sinA));
      my @l0=$lean->($K); my @l1=$lean->($Kn); my $step=$prev?len(sub3($Kn,$prev)):0; $prev=$Kn;
      printf "%5d | %5.1f | (%5.1f %5.1f %5.1f) %4.0f/%4.0f | (%5.1f %5.1f %5.1f) %4.0f/%4.0f | %5.1f | %5.1f%s\n",$i,len(sub3($K0,$A0)),@$K,@l0,@$Kn,@l1,len(sub3($K,$Kn)),$step,($fl&0x800)?'':'  (not changed by the mod)';
    }
  }
  $off+=$segBytes;
}
