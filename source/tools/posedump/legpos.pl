use strict; use warnings;
# legpos.pl <bin> <seg> <frames,comma> : arrived pose, pelvis + both legs' joints (mesh space)
my ($file,$sgW,$fr)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fb)=unpack('a4 v v V V v v V',substr($d,$off,24));
  last unless $magic eq 'ETPD'; $seg++;
  if($seg==$sgW){ my @rig=unpack('s<36',substr($d,$off+88,72));
    for my $i (split /,/,$fr){ next if $i>=$frames; my $fo=$off+$hdr+$i*$fb; my $fl=unpack('V',substr($d,$fo,4));
      for my $set (0,1){ my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$set*$bones*12+$_[0]*12,12))]};
        my @p=map{$P->($rig[$_])}(0..6);
        my $L=sub{my($a,$b)=@_; sqrt(($a->[0]-$b->[0])**2+($a->[1]-$b->[1])**2+($a->[2]-$b->[2])**2)};
        printf "#%-4d %08X %s pel(%4.0f %4.0f %4.0f) | L hip(%4.0f %4.0f %4.0f) knee(%4.0f %4.0f %4.0f) ank(%4.0f %4.0f %4.0f) th %4.1f sh %4.1f | R hip(%4.0f %4.0f %4.0f) knee(%4.0f %4.0f %4.0f) ank(%4.0f %4.0f %4.0f) th %4.1f sh %4.1f\n",
          $i,$fl,$set?'drw':'arr',@{$p[0]},@{$p[1]},@{$p[3]},@{$p[5]},$L->($p[1],$p[3]),$L->($p[3],$p[5]),@{$p[2]},@{$p[4]},@{$p[6]},$L->($p[2],$p[4]),$L->($p[4],$p[6]);
      } } }
  $off+=$segBytes; }
