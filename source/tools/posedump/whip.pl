use strict; use warnings;
# whip.pl <bin> <seg> <from> <to>: per pose, how far each bone of the SCREEN's pose moves in the world in one pose (the skater's own travel taken out), the three fastest
my ($file,$segWant,$fa,$fb)=@ARGV;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qrot{my($q,$v)=@_;my $p=qmul(qmul($q,[@$v,0]),qconj($q));[@$p[0..2]]}
my %nm=(0=>'pelvis',1=>'thighL',2=>'thighR',3=>'calfL',4=>'calfR',5=>'footL',6=>'footR',7=>'toeL',8=>'toeR',16=>'neck',17=>'head',18=>'uarmL',19=>'uarmR',20=>'farmL',21=>'farmR',22=>'handL',23=>'handR',24=>'flipper',29=>'chest',30=>'spine1',31=>'root');
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$segWant){
    my @rig=unpack('s<36',substr($d,$off+88,72)); my %name; for my $k (keys %nm){ $name{$rig[$k]}=$nm{$k} if $rig[$k]>=0 }
    my (@prev,@pm);
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i++){ my $o=$off+$hdr+$i*$fbytes;
      my $fl=unpack('V',substr($d,$o,4)); my @mq=unpack('f<4',substr($d,$o+16,16)); my @mp=unpack('f<3',substr($d,$o+32,12));
      my $set=(($fl&0x800)&&!($fl&0x2000000))?1:0; my @cur;
      for my $b (0..$bones-1){ my $p=[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$b*12,12))]; my $w=qrot(\@mq,$p); $cur[$b]=[map{$w->[$_]+$mp[$_]}0..2]; }
      if(@prev){ my @mv=map{$mp[$_]-$pm[$_]}0..2; my @r;
        for my $b (0..$bones-1){ next unless exists $name{$b}; my $dd=sqrt(($cur[$b][0]-$prev[$b][0]-$mv[0])**2+($cur[$b][1]-$prev[$b][1]-$mv[1])**2+($cur[$b][2]-$prev[$b][2]-$mv[2])**2); push @r,[$dd,$name{$b}]; }
        @r=sort{$b->[0]<=>$a->[0]}@r; printf "%4d %08X %s | %s\n",$i,$fl,$set?'drawn':'game ',join('  ',map{sprintf "%-7s %5.1f",$_->[1],$_->[0]}@r[0..5]);
      }
      @prev=@cur; @pm=@mp;
    }
  }
  $off+=$segBytes;
}
