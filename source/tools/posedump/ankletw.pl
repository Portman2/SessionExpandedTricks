use strict; use warnings;
# ankletw.pl <bin> [seg from to step]: THE ANKLE'S TWIST. The foot bone's turn against its shin's own frame (the shin's line + the knee's hinge
# axis = the normal of the leg's plane), as a change from how that foot stands on that shin riding (the file's median over plain riding poses):
# split into the turn ABOUT the shin (twist: what wrings the skin) and the rest (flexion / roll). For the pose as it ARRIVED and as DRAWN.
# Without a segment: per segment, the largest twist and the poses over 45 deg.
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))} sub nrm{my $l=len($_[0])||1;[map{$_/$l}@{$_[0]}]}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
sub qframe{ my($x,$y)=@_; my $z=cross($x,$y); my @m=($x->[0],$y->[0],$z->[0],$x->[1],$y->[1],$z->[1],$x->[2],$y->[2],$z->[2]); # columns x y z
  my $tr=$m[0]+$m[4]+$m[8]; my @q; if($tr>0){my $s=sqrt($tr+1)*2; @q=(($m[7]-$m[5])/$s,($m[2]-$m[6])/$s,($m[3]-$m[1])/$s,$s/4);} elsif($m[0]>$m[4]&&$m[0]>$m[8]){my $s=sqrt(1+$m[0]-$m[4]-$m[8])*2; @q=($s/4,($m[1]+$m[3])/$s,($m[2]+$m[6])/$s,($m[7]-$m[5])/$s);} elsif($m[4]>$m[8]){my $s=sqrt(1+$m[4]-$m[0]-$m[8])*2; @q=(($m[1]+$m[3])/$s,$s/4,($m[5]+$m[7])/$s,($m[2]-$m[6])/$s);} else {my $s=sqrt(1+$m[8]-$m[0]-$m[4])*2; @q=(($m[2]+$m[6])/$s,($m[5]+$m[7])/$s,$s/4,($m[3]-$m[1])/$s);} [@q] }
my @segs; my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++; push @segs,[$seg,$off,$hdr,$frames,$bones,$fh,$fbytes,$pre]; $off+=$segBytes; }
sub rel{ my($s,$i,$set,$sd)=@_; my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; my @rig=unpack('s<36',substr($d,$o+88,72)); my $fo=$o+$hdr+$i*$fb;
  my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$set*$bones*12+$_[0]*12,12))]}; my($h,$k,$a)=map{$P->($rig[$_+$sd])}(1,3,5);
  my $th=sub3($k,$h); my $sh=sub3($a,$k); my $nn=cross($th,$sh); return undef if len($nn)<60;   # (|thigh x shin| = 43*41*sin(bend): under ~2 deg of bend the plane is not known)
  my $x=nrm($sh); my $y=nrm($nn); $y=nrm(sub3($y,[map{$x->[$_]*dot($y,$x)}0..2]));
  my @q=unpack('f<40',substr($d,$fo+148,160)); my $fq=[@q[$set*20+4+$sd*4..$set*20+7+$sd*4]];
  my $r=qmul(qconj(qframe($x,$y)),$fq); $r=[map{-$_}@$r] if $r->[3]<0; return $r; }
# the riding reference: plain riding poses (no flag under 0x400 but calib), the arrived pose; a component-wise mean of the quaternions
my @ref; for my $sd (0,1){ my @acc=(0,0,0,0); my $cnt=0; for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; for(my $i=0;$i<$frames;$i+=2){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); next if ($fl&0x3FF)||($fl&0x800);
      my $r=rel($s,$i,0,$sd) or next; if($cnt && ($acc[0]*$r->[0]+$acc[1]*$r->[1]+$acc[2]*$r->[2]+$acc[3]*$r->[3])<0){$r=[map{-$_}@$r]} $acc[$_]+=$r->[$_] for 0..3; $cnt++; } }
  my $l=sqrt($acc[0]**2+$acc[1]**2+$acc[2]**2+$acc[3]**2)||1; $ref[$sd]=[map{$_/$l}@acc]; printf "riding reference %s: from %d poses\n",$sd?'R':'L',$cnt; }
sub tw{ my($r,$sd)=@_; return (undef,undef) unless $r; my $dq=qmul($r,qconj($ref[$sd])); $dq=[map{-$_}@$dq] if $dq->[3]<0;
  my $twist=2*atan2($dq->[0],$dq->[3])*57.29578; $twist-=360 if $twist>180; $twist+=360 if $twist<-180;
  my $tot=2*atan2(sqrt($dq->[0]**2+$dq->[1]**2+$dq->[2]**2),$dq->[3])*57.29578; ($twist,$tot) }
for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb,$pre)=@$s; next if defined $sgW && $n!=$sgW;
  if(defined $sgW){ print "   #   flags   | L ankle twist: arrived, drawn (total turn: arrived, drawn) | R ankle twist: arrived, drawn (total: arrived, drawn)\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); my $line=sprintf("%4d %08X |",$i,$fl);
      for my $sd (0,1){ my($tg,$og)=tw(rel($s,$i,0,$sd),$sd); my($td,$od)=tw(rel($s,$i,1,$sd),$sd); $line.=sprintf("  %5s %5s  (%4s %4s) |",map{defined $_?sprintf("%.0f",$_):'-'}($tg,$td,$og,$od)); }
      print "$line\n"; } next; }
  my $line=sprintf("seg %2d",$n);
  for my $sd (0,1){ my($mg,$md,$ng,$nd,$ig,$id)=(0,0,0,0,0,0); for(my $i=0;$i<$frames;$i++){ my($tg)=tw(rel($s,$i,0,$sd),$sd); my($td)=tw(rel($s,$i,1,$sd),$sd);
      if(defined $tg){ if(abs($tg)>$mg){$mg=abs($tg);$ig=$i} $ng++ if abs($tg)>45; } if(defined $td){ if(abs($td)>$md){$md=abs($td);$id=$i} $nd++ if abs($td)>45; } }
    $line.=sprintf(" | %s twist most: drawn %3.0f (#%d), over 45 on %3d poses; arrived %3.0f (#%d), %3d poses",$sd?'R':'L',$md,$id,$nd,$mg,$ig,$ng); }
  print "$line\n";
}
