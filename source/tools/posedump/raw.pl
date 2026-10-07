use strict; use warnings;
# raw.pl <bin> <seg> <from> <to>: in the MESH's own space, the game's pose AS IT ARRIVED (a half-turn pose's turn undone) and the pose drawn:
# heading (deg) of the hip line (thigh L->R), of the shoulder line (upper arm L->R), of the spine's lean (pelvis->neck, flat) and where the head and the hands are
my ($file,$segWant,$fa,$fb)=@ARGV;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub yaw{ atan2($_[0][1],$_[0][0])*57.29578 }
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$segWant){
    my @rig=unpack('s<36',substr($d,$off+88,72));
    my ($pel,$thL,$thR,$uaL,$uaR,$hdL,$hdR,$head,$neck,$root)=@rig[0,1,2,18,19,22,23,17,16,31];
    print "seg $seg   fr flags    | ARRIVED: hips shoulders  head(x y z)  handL(x y) handR(x y) | DRAWN: hips shoulders  head(x y z)  handL(x y) handR(x y)\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i++){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4));
      my $out=sprintf("%4d %08X |",$i,$fl);
      for my $set (0,1){ my $P=sub{ my $p=[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$_[0]*12,12))]; if($set==0 && ($fl&0x80)){ my $r=[unpack('f<3',substr($d,$o+$fh+$root*12,12))]; $p=[2*$r->[0]-$p->[0],2*$r->[1]-$p->[1],$p->[2]]; } $p };
        my ($a,$b,$c,$e,$h,$l,$r)=map{$P->($_)}($thL,$thR,$uaL,$uaR,$head,$hdL,$hdR);
        $out.=sprintf(" %6.0f %6.0f  (%4.0f %4.0f %4.0f) (%4.0f %4.0f) (%4.0f %4.0f) |",yaw([map{$b->[$_]-$a->[$_]}0..1]),yaw([map{$e->[$_]-$c->[$_]}0..1]),@$h,@$l[0,1],@$r[0,1]); }
      print "$out\n";
    }
  }
  $off+=$segBytes;
}
