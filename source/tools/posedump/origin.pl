use strict; use warnings;
# origin.pl <bin> <seg> <from> <to> <step>: the mesh origin and the pelvis' parent (AMXX_Root, rig 31) in the drawn deck's space; the deck's world speed along itself; the deck's up tilt; the mesh's world yaw and the deck's
my ($file,$sgW,$fa,$fb,$st)=@ARGV; $st||=1;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){
    my @rig=unpack('s<36',substr($d,$off+88,72)); my $t0=unpack('d<',substr($d,$off+$hdr+$pre*$fbytes+8,8)); my ($pw,$pt);
    print "   #    ms  flags    | mesh origin on the deck (x y z) | pelvis-parent arrived, drawn (x y) | deck: world speed along its x (cm/s), over ground (cm), pitch (deg) | mesh yaw, deck yaw (world deg)\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4)); my $t=unpack('d<',substr($d,$o+8,8));
      my @m=unpack('f<10',substr($d,$o+16,40)); my $mq=[@m[0..3]]; my $mp=[@m[4..6]]; my $ms=$m[7]||1;
      my @dk=unpack('f<7',substr($d,$o+56,28)); my $dq=[@dk[0..3]]; my $dp=[@dk[4..6]]; my $cq=[-$dq->[0],-$dq->[1],-$dq->[2],$dq->[3]];
      my $gz=unpack('f<',substr($d,$o+92,4));
      my $org=qrot($cq,[map{-$dp->[$_]}0..2]);
      my @pr; for my $set (0,1){ my $p=[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$rig[31]*12,12))]; push @pr, qrot($cq,[map{$p->[$_]-$dp->[$_]}0..2]); }
      my $dw=qrot($mq,[map{$_*$ms}@$dp]); $dw=[map{$dw->[$_]+$mp->[$_]}0..2];
      my $dx=qrot($mq,qrot($dq,[1,0,0])); my $sp=0; if($pw && $t>$pt){ $sp=(($dw->[0]-$pw->[0])*$dx->[0]+($dw->[1]-$pw->[1])*$dx->[1])/($t-$pt); } ($pw,$pt)=($dw,$t);
      my $mx=qrot($mq,[1,0,0]);
      printf "%4d %5.0f %08X | %5.1f %5.1f %5.1f | %5.1f %5.1f   %5.1f %5.1f | %6.0f  %5.1f  %5.1f | %6.1f %6.1f\n",$i,($t-$t0)*1000,$fl,@$org,@{$pr[0]}[0,1],@{$pr[1]}[0,1],$sp,$dw->[2]-$gz,atan2($dx->[2],sqrt($dx->[0]**2+$dx->[1]**2))*57.29578,atan2($mx->[1],$mx->[0])*57.29578,atan2($dx->[1],$dx->[0])*57.29578; }
  }
  $off+=$segBytes;
}
