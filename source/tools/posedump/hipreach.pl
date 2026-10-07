use strict; use warnings;
# hipreach.pl <bin> <seg...>: per segment and leg, over the poses the DRAWN hip joint is more than 4 cm out of its socket:
# hip-to-ankle as a share of the leg's length, from the joint as drawn and from the socket it belongs in (min .. max)
my ($file,@want)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
my @ref=([0,0,8.7],[0,0,-8.7]); my $L=42.6+41.1;
my $off=0; my $seg=0; my %w=map{$_=>1}@want;
while($off+160<=length $d){ my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26)); last unless $magic eq 'ETPD'; $seg++;
  if(!@want || $w{$seg}){ my @rig=unpack('s<36',substr($d,$off+88,72)); my $line="seg $seg";
    for my $sd (0,1){ my($n,$a0,$a1,$b0,$b1)=(0,9,0,9,0);
      for(my $i=0;$i<$frames;$i++){ my $fo=$off+$hdr+$i*$fbytes; my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$bones*12+$rig[$_[0]]*12,12))]};
        my @q=unpack('f<40',substr($d,$fo+148,160)); my $pq=[@q[20..23]]; my $cq=[-$pq->[0],-$pq->[1],-$pq->[2],$pq->[3]];
        my($pl,$th,$an)=map{$P->($_)}(0,1+$sd,5+$sd); my $loc=qrot($cq,sub3($th,$pl)); next if len(sub3($loc,$ref[$sd]))<4;
        my $so=[map{$pl->[$_]+qrot($pq,$ref[$sd])->[$_]}0..2]; my $ra=len(sub3($an,$th))/$L; my $rb=len(sub3($an,$so))/$L; $n++;
        $a0=$ra if $ra<$a0; $a1=$ra if $ra>$a1; $b0=$rb if $rb<$b0; $b1=$rb if $rb>$b1; }
      $line.=sprintf(" | %s: %3d poses; reach from the joint as drawn %3.0f..%3.0f%%, from its socket %3.0f..%3.0f%%",$sd?'R':'L',$n,100*$a0,100*$a1,100*$b0,100*$b1) if $n; }
    print "$line\n"; }
  $off+=$segBytes; }
