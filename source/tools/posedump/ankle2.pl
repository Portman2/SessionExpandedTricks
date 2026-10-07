use strict; use warnings;
# ankle2.pl <bin> <seg> <from> <to> [step]: the shin against the FOOT BONE's own frame (from the foot's recorded rotation), drawn and game:
#   fwd  = the shin's lean toward the toes (dorsiflexion past the foot's own upright), deg
#   side = the shin's lean to the foot's own side (inversion / eversion), deg
# the foot's own frame is taken from the segment's first 20 riding poses: its "up" = the mesh's up there, its "toe" = ankle->toe joint
my ($file,$segWant,$fa,$fb,$st)=@ARGV; $st||=1;
open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qrot{my($q,$v)=@_;my $p=qmul(qmul($q,[@$v,0]),qconj($q));[@$p[0..2]]}
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my$s=0;$s+=$_[0][$_]*$_[1][$_] for 0..2;$s} sub len{sqrt(dot($_[0],$_[0]))}
sub norm{my$l=len($_[0])||1;[map{$_/$l}@{$_[0]}]} sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$segWant){
    my @rig=unpack('s<36',substr($d,$off+88,72));
    my $get=sub{ my($i,$set,$k)=@_; my $o=$off+$hdr+$i*$fbytes; my @q=unpack('f<40',substr($d,$o+148,160)); my $Q=[@q[$set*20+4+4*$k..$set*20+7+4*$k]];
      my $P=sub{[unpack('f<3',substr($d,$o+$fh+$set*$bones*12+$_[0]*12,12))]}; my ($K,$A,$T)=map{$P->($_)}($rig[3+$k],$rig[5+$k],$rig[7+$k]); ($Q,$K,$A,$T) };
    my @loc;   # per leg: the foot's own up, toe and side axes in its local frame
    for my $k (0,1){ my (@u,@t); my $n=0; for my $i (0..19){ my ($Q,$K,$A,$T)=$get->($i,0,$k); my $toe=norm(sub3($T,$A)); my $up=[0,0,1]; my $ul=qrot(qconj($Q),$up); my $tl=qrot(qconj($Q),$toe); $u[$_]+=$ul->[$_] for 0..2; $t[$_]+=$tl->[$_] for 0..2; $n++; }
      my $tl=norm(\@t); my $ul=norm(\@u); my $sl=norm(cross($ul,$tl)); $ul=norm(cross($tl,$sl)); $loc[$k]=[$ul,$tl,$sl]; }
    print "seg $seg | fr flags | L drawn fwd/side  game fwd/side | R drawn fwd/side  game fwd/side   (deg; riding = the first rows)\n";
    for(my $i=$fa;$i<=$fb&&$i<$frames;$i+=$st){ my $o=$off+$hdr+$i*$fbytes; my $fl=unpack('V',substr($d,$o,4)); my $scr=(($fl&0x800)&&!($fl&0x2000000))?1:0; my $out=sprintf("%4d %08X |",$i,$fl);
      for my $k (0,1){ for my $set ($scr,0){ my ($Q,$K,$A,$T)=$get->($i,$set,$k); my $s=norm(sub3($K,$A)); my ($u,$t,$l)=map{qrot($Q,$loc[$k][$_])}0..2;
          my $fw=atan2(dot($s,$t),dot($s,$u))*57.29578; my $sd=atan2(dot($s,$l),sqrt(dot($s,$u)**2+dot($s,$t)**2))*57.29578; $out.=sprintf(" %5.0f/%4.0f ",$fw,$sd); } $out.=" |"; }
      print "$out\n";
    }
  }
  $off+=$segBytes;
}
