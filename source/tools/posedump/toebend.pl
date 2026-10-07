use strict; use warnings;
# toebend.pl <bin>: per segment, the toe joint's turn against its foot, as a change from riding (deg): most, drawn and arrived
my ($file)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
my @segs; my $off=0; my $seg=0;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++; push @segs,[$seg,$off,$hdr,$frames,$fbytes]; $off+=$segBytes; }
sub rel{ my($s,$i,$set,$sd)=@_; my($n,$o,$hdr,$frames,$fb)=@$s; my @q=unpack('f<40',substr($d,$o+$hdr+$i*$fb+148,160)); my $fq=[@q[$set*20+4+$sd*4..$set*20+7+$sd*4]]; my $tq=[@q[$set*20+12+$sd*4..$set*20+15+$sd*4]]; my $r=qmul(qconj($fq),$tq); $r=[map{-$_}@$r] if $r->[3]<0; $r }
my @ref; for my $sd (0,1){ my @acc=(0,0,0,0); my $c=0; for my $s (@segs){ my($n,$o,$hdr,$frames,$fb)=@$s; for(my $i=0;$i<$frames;$i+=3){ my $fl=unpack('V',substr($d,$o+$hdr+$i*$fb,4)); next if ($fl&0x3FF)||($fl&0x800); my $r=rel($s,$i,0,$sd); $acc[$_]+=$r->[$_] for 0..3; $c++; } } my $l=sqrt($acc[0]**2+$acc[1]**2+$acc[2]**2+$acc[3]**2)||1; $ref[$sd]=[map{$_/$l}@acc]; }
for my $s (@segs){ my($n,$o,$hdr,$frames,$fb)=@$s; my $line=sprintf("seg %2d",$n);
  for my $sd (0,1){ my($md,$mg,$nd)=(0,0,0); for(my $i=0;$i<$frames;$i++){ for my $set (0,1){ my $dq=qmul(rel($s,$i,$set,$sd),qconj($ref[$sd])); my $w=abs($dq->[3]); $w=1 if $w>1; my $a=2*atan2(sqrt(1-$w*$w),$w)*57.29578; if($set){ $md=$a if $a>$md; $nd++ if $a>35; } else { $mg=$a if $a>$mg; } } }
    $line.=sprintf(" | %s toe bend most: drawn %3.0f (over 35 on %3d poses), arrived %3.0f",$sd?'R':'L',$md,$nd,$mg); }
  print "$line\n"; }
