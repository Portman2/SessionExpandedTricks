use strict; use warnings;
# turn.pl <bin> <seg> <from> <to>: world headings of the shoulder line, the hip line, the chest's facing and both hands, drawn (screen) and game
my ($file,$segWant,$fa,$fb)=@ARGV;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qrot{my($q,$v)=@_;my $p=qmul(qmul($q,[@$v,0]),qconj($q));[@$p[0..2]]}
sub yaw{my $v=shift; atan2($v->[1],$v->[0])*57.29578}
sub dang{my($a,$b)=@_; my $x=$a-$b; $x-=360 while $x>180; $x+=360 while $x<-180; $x}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$segWant){
    my @rig=unpack('s<36',substr($d,$off+88,72));
    my ($pel,$thL,$thR,$uaL,$uaR,$hdL,$hdR,$head,$neck,$chest)=@rig[0,1,2,18,19,22,23,17,16,29];
    print "seg $seg ($frames poses, $pre before the start)\n  fr  flags    | SCREEN: shoulders hips  twist | d(sh) d(hip) | head-over-hips yaw dist | GAME: shoulders hips | mesh yaw\n";
    my @prev;
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i++){ my $o=$off+$hdr+$i*$fbytes;
      my $fl=unpack('V',substr($d,$o,4)); my @mq=unpack('f<4',substr($d,$o+16,16)); my @mp=unpack('f<3',substr($d,$o+32,12));
      my $scr=(($fl&0x800)&&!($fl&0x2000000))?1:0;
      my $P=sub{my($set,$b)=@_; my $p=[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$b*12,12))]; my $w=qrot(\@mq,$p); [map{$w->[$_]+$mp[$_]}0..2]};
      my @row;
      for my $set ($scr,0){
        my $sh=[map{$P->($set,$uaR)->[$_]-$P->($set,$uaL)->[$_]}0..2]; my $hp=[map{$P->($set,$thR)->[$_]-$P->($set,$thL)->[$_]}0..2];
        my $hh=[map{$P->($set,$head)->[$_]-$P->($set,$pel)->[$_]}0..2];
        push @row,[yaw($sh),yaw($hp),yaw($hh),sqrt($hh->[0]**2+$hh->[1]**2)];
      }
      my $my=yaw(qrot(\@mq,[1,0,0]));
      my ($dsh,$dhp)=@prev?(dang($row[0][0],$prev[0]),dang($row[0][1],$prev[1])):(0,0);
      printf "%4d  %08X %s | %7.1f %7.1f %6.1f | %6.1f %6.1f | %7.1f %5.1f | %7.1f %7.1f | %7.1f\n",$i,$fl,$scr?'*':' ',$row[0][0],$row[0][1],dang($row[0][0],$row[0][1]),$dsh,$dhp,$row[0][2],$row[0][3],$row[1][0],$row[1][1],$my;
      @prev=($row[0][0],$row[0][1]);
    }
  }
  $off+=$segBytes;
}
