use strict; use warnings;
# joints.pl <bin>: per segment and leg, in the DRAWN pose: how far the HIP JOINT (the thigh bone's root) stands from its own place in the pelvis
# (the file's riding median, in the pelvis' own frame), the foot's length (ankle to toe joint) against its own, and the same for the pose as it arrived
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
sub med{my @s=sort{$a<=>$b}@_; $s[int($#s/2)]}
my @segs; my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++; push @segs,[$seg,$off,$hdr,$frames,$bones,$fh,$fbytes,$pre]; $off+=$segBytes; }
sub hip{ my($s,$i,$set,$sd)=@_; my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; my @rig=unpack('s<36',substr($d,$o+88,72)); my $fo=$o+$hdr+$i*$fb;
  my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$set*$bones*12+$_[0]*12,12))]}; my @q=unpack('f<40',substr($d,$fo+148,160)); my $pq=[@q[$set*20..$set*20+3]]; my $cq=[-$pq->[0],-$pq->[1],-$pq->[2],$pq->[3]];
  my($pl,$th,$ft,$to)=map{$P->($rig[$_])}(0,1+$sd,5+$sd,7+$sd); return (qrot($cq,sub3($th,$pl)), len(sub3($to,$ft))); }
my (@ref,@refF); for my $sd (0,1){ my(@x,@y,@z,@fl); for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; for(my $i=0;$i<$frames;$i+=2){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); next if ($fl&0x3FF)||($fl&0x800); my($h,$l)=hip($s,$i,0,$sd); push @x,$h->[0]; push @y,$h->[1]; push @z,$h->[2]; push @fl,$l; } }
  $ref[$sd]=[med(@x),med(@y),med(@z)]; $refF[$sd]=med(@fl); printf "%s hip joint in the pelvis' frame riding: (%.1f %.1f %.1f), foot %.1f cm\n",$sd?'R':'L',@{$ref[$sd]},$refF[$sd]; }
for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb,$pre)=@$s; next if defined $sgW && $n!=$sgW;
  if(defined $sgW){ for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); my $line=sprintf("%4d %08X |",$i,$fl);
      for my $sd (0,1){ my($hg)=hip($s,$i,0,$sd); my($hd,$ld)=hip($s,$i,1,$sd); $line.=sprintf(" %s hip off: arrived %4.1f drawn %4.1f (%5.1f %5.1f %5.1f) |",$sd?'R':'L',len(sub3($hg,$ref[$sd])),len(sub3($hd,$ref[$sd])),@{sub3($hd,$ref[$sd])}); } print "$line\n"; } next; }
  my $line=sprintf("seg %2d",$n);
  for my $sd (0,1){ my($mg,$md,$ng,$nd,$fmn,$fmx)=(0,0,0,0,999,0); for(my $i=0;$i<$frames;$i++){ my($hg,$lg)=hip($s,$i,0,$sd); my($hd,$ld)=hip($s,$i,1,$sd); my $a=len(sub3($hg,$ref[$sd])); my $b=len(sub3($hd,$ref[$sd]));
      $mg=$a if $a>$mg; $md=$b if $b>$md; $ng++ if $a>4; $nd++ if $b>4; my $r=100*$ld/$refF[$sd]; $fmn=$r if $r<$fmn; $fmx=$r if $r>$fmx; }
    $line.=sprintf(" | %s hip out of its socket: drawn %4.1f cm most, over 4 cm on %3d poses (arrived %4.1f, %3d); foot %3.0f..%3.0f%%",$sd?'R':'L',$md,$nd,$mg,$ng,$fmn,$fmx); }
  print "$line\n"; }
