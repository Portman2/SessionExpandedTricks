use strict; use warnings;
# sock.pl <bin> <seg> <from> <to> <step>  -- needs a v99+ recording (frame header 512+).
# In the drawn deck's own frame: the anim instance's foot sockets (location; the heading of the rotation's x axis on the
# deck) as the pose pass found them, and the feet as they ARRIVED (ankle; ankle-to-toe heading); how far apart the two
# are; the game's foot IK weights; "T" = the sockets were turned for this pose (the other stance's, a switch plant).
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
sub rotq{ my($p,$y,$r)=map{$_*0.00872664626}@_; my($SP,$CP,$SY,$CY,$SR,$CR)=(sin($p),cos($p),sin($y),cos($y),sin($r),cos($r)); [$CR*$SP*$SY-$SR*$CP*$CY, -$CR*$SP*$CY-$SR*$CP*$SY, $CR*$CP*$SY-$SR*$SP*$CY, $CR*$CP*$CY+$SR*$SP*$SY] }
my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){ die "no v99 fields (frame header $fh bytes, 512 needed)\n" if $fh<512; my @rig=unpack('s<36',substr($d,$off+88,72));
    print "   #  flags    T IK L/R | L socket (x y z) heading, L foot (x y z) heading, apart | R socket, R foot, apart\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4)); my @dk=unpack('f<7',substr($d,$o+56,28)); my $dq=[@dk[0..3]]; my $dp=[@dk[4..6]]; my $cq=[-$dq->[0],-$dq->[1],-$dq->[2],$dq->[3]];
      my @a=unpack('f<2',substr($d,$o+84,8)); my @sk=unpack('f<12',substr($d,$o+436,48)); my $more=unpack('V',substr($d,$o+508,4));
      my $D=sub{ qrot($cq,[map{$_[0][$_]-$dp->[$_]}0..2]) }; my $V=sub{ qrot($cq,$_[0]) };
      my $line=sprintf("%4d %08X %s %.1f/%.1f |",$i,$fl,($more&1)?'T':'.',@a);
      for my $k (0,1){ my $sp=$D->([@sk[$k*6..$k*6+2]]); my $sx=$V->(qrot(rotq(@sk[$k*6+3..$k*6+5]),[1,0,0]));
        my $P=sub{[unpack('f<3',substr($d,$o+$fh+$rig[$_[0]]*12,12))]}; my($an,$to)=($P->(5+$k),$P->(7+$k)); my $fp=$D->($an); my $fx=$V->([map{$to->[$_]-$an->[$_]}0..2]);
        $line.=sprintf(" (%+4.0f %+4.0f %+4.0f) %4.0f, (%+4.0f %+4.0f %+4.0f) %4.0f, %4.1f |",@$sp,atan2($sx->[1],$sx->[0])*57.29578,@$fp,atan2($fx->[1],$fx->[0])*57.29578,sqrt(($sp->[0]-$fp->[0])**2+($sp->[1]-$fp->[1])**2+($sp->[2]-$fp->[2])**2)); }
      print "$line\n"; } }
  $off+=$segBytes; }
