use strict; use warnings;
# deckpose.pl <bin> <seg> <from> <to> <step> [set: 0 arrived | 1 drawn]: joints in the DRAWN DECK's own space (x along it, y across, z up; cm)
my ($file,$sgW,$fa,$fb,$st,$set)=@ARGV; $st||=1; $set//=0;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){
    my @rig=unpack('s<36',substr($d,$off+88,72)); my $t0=unpack('d<',substr($d,$off+$hdr+$pre*$fbytes+8,8));
    printf "seg %d (%s), pose %d = 0 ms\n   #    ms  flags    | pelvis          | head            | L hand          | R hand          | L knee      | R knee      | L ankle         | R ankle\n",$seg,$set?'DRAWN':'ARRIVED',$pre;
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4)); my $t=unpack('d<',substr($d,$o+8,8));
      my @dk=unpack('f<7',substr($d,$o+56,28)); my $dq=[@dk[0..3]]; my $dp=[@dk[4..6]]; my $cq=[-$dq->[0],-$dq->[1],-$dq->[2],$dq->[3]];
      my $P=sub{ my $p=[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$rig[$_[0]]*12,12))]; qrot($cq,[map{$p->[$_]-$dp->[$_]}0..2]) };
      my $s=sprintf("%4d %5.0f %08X |",$i,($t-$t0)*1000,$fl);
      for my $b (0,17,22,23){ $s.=sprintf(" %4.0f %4.0f %4.0f  |",@{$P->($b)}); }
      for my $b (3,4){ $s.=sprintf(" %4.0f %4.0f  |",@{$P->($b)}[0,1]); }
      for my $b (5,6){ $s.=sprintf(" %4.0f %4.0f %4.0f  |",@{$P->($b)}); }
      print "$s\n"; }
  }
  $off+=$segBytes;
}
