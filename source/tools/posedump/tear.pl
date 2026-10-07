use strict; use warnings;
# tear.pl <bin> [seg]: per segment and leg, in the DRAWN pose (and the pose as it ARRIVED):
#   bone lengths (thigh, shin) as % of the leg's own (the recording's median of the arrived thigh / the longest common shin),
#   the knee's way round the leg from the toes' way (deg), the foot's heading against the pelvis' (deg)
# with a segment number: one line a pose.
my ($file,$sgW)=@ARGV; open my $f,'<:raw',$file or die; local $/; my $d=<$f>; close $f;
sub sub3{[map{$_[0][$_]-$_[1][$_]}0..2]} sub dot{my($a,$b)=@_;$a->[0]*$b->[0]+$a->[1]*$b->[1]+$a->[2]*$b->[2]} sub len{sqrt(dot($_[0],$_[0]))}
sub cross{my($a,$b)=@_;[$a->[1]*$b->[2]-$a->[2]*$b->[1],$a->[2]*$b->[0]-$a->[0]*$b->[2],$a->[0]*$b->[1]-$a->[1]*$b->[0]]}
sub perp{my($v,$ax)=@_; my $l2=dot($ax,$ax); return $v if $l2<1e-6; my $k=dot($v,$ax)/$l2; [map{$v->[$_]-$ax->[$_]*$k}0..2]}
sub qrot{my($q,$v)=@_; my($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map{$v->[$_]+2*($w*$c1->[$_]+$c2->[$_])}0..2]}
sub wrap{my $a=shift; $a-=360 while $a>180; $a+=360 while $a<-180; $a}
my @segs; my $off=0; my $seg=0;
while($off+160<=length $d){
  my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes)=unpack('a4 v v V V v v V',substr($d,$off,24));
  last unless $magic eq 'ETPD'; $seg++; push @segs,[$seg,$off,$hdr,$frames,$bones,$fh,$fbytes]; $off+=$segBytes; }
# the legs' own lengths: over the whole file, the 90th percentile of the ARRIVED thigh and shin (the game never draws them longer than their own for long)
my @ref; for my $sd (0,1){ my(@t,@c); for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; my @rig=unpack('s<36',substr($d,$o+88,72));
    for(my $i=0;$i<$frames;$i+=3){ my $P=sub{[unpack('f<3',substr($d,$o+$hdr+$i*$fb+$fh+$_[0]*12,12))]}; my($h,$k,$a)=map{$P->($rig[$_+$sd])}(1,3,5); push @t,len(sub3($k,$h)); push @c,len(sub3($a,$k)); } }
  @t=sort{$a<=>$b}@t; @c=sort{$a<=>$b}@c; $ref[$sd]=[$t[int($#t*0.5)],$c[int($#c*0.9)]]; }
printf "legs' own: L thigh %.1f shin %.1f   R thigh %.1f shin %.1f\n",@{$ref[0]},@{$ref[1]};
for my $s (@segs){ my($n,$o,$hdr,$frames,$bones,$fh,$fb)=@$s; next if defined $sgW && $n!=$sgW;
  my @rig=unpack('s<36',substr($d,$o+88,72)); my $line=sprintf("seg %2d %4d poses",$n,$frames);
  for my $sd (0,1){ my %mx=(tmin=>999,tmax=>0,cmin=>999,cmax=>0,way=>0,wayg=>0,fp=>0,fpg=>0); my($nw,$nwg,$nc,$ncg,$nfp,$nfpg,$N)=(0,0,0,0,0,0,0);
    for(my $i=0;$i<$frames;$i++){ my $fo=$o+$hdr+$i*$fb; my $fl=unpack('V',substr($d,$fo,4)); my @q=unpack('f<40',substr($d,$fo+148,160));
      my @r; for my $set (0,1){ my $P=sub{[unpack('f<3',substr($d,$fo+$fh+$set*$bones*12+$_[0]*12,12))]}; my($h,$k,$a,$t)=map{$P->($rig[$_+$sd])}(1,3,5,7);
        my $ha=sub3($a,$h); my $kv=perp(sub3($k,$h),$ha); my $tv=perp(sub3($t,$a),$ha); my $ax=[map{$_/(len($ha)||1)}@$ha];
        my $way=(len($kv)>6&&len($tv)>0.5)? atan2(dot(cross($tv,$kv),$ax),dot($tv,$kv))*57.29578 : 0;
        my $pq=[@q[$set*20+0..$set*20+3]]; my $pf=qrot($pq,[0,1,0]);   # (some fixed axis of the pelvis: only its CHANGE against the foot's heading counts)
        my $toe=sub3($t,$a); my $fp=wrap((atan2($toe->[1],$toe->[0])-atan2($pf->[1],$pf->[0]))*57.29578);
        $r[$set]={th=>100*len(sub3($k,$h))/$ref[$sd][0], ca=>100*len(sub3($a,$k))/$ref[$sd][1], way=>$way, fp=>$fp, reach=>len($ha)}; }
      my($g,$dr)=@r; $N++;
      $mx{tmin}=$dr->{th} if $dr->{th}<$mx{tmin}; $mx{tmax}=$dr->{th} if $dr->{th}>$mx{tmax}; $mx{cmin}=$dr->{ca} if $dr->{ca}<$mx{cmin}; $mx{cmax}=$dr->{ca} if $dr->{ca}>$mx{cmax};
      $mx{way}=abs($dr->{way}) if abs($dr->{way})>$mx{way}; $mx{wayg}=abs($g->{way}) if abs($g->{way})>$mx{wayg};
      $nw++ if abs($dr->{way})>60; $nwg++ if abs($g->{way})>60; $nc++ if $dr->{ca}<90||$dr->{ca}>104; $ncg++ if $g->{ca}<90||$g->{ca}>104;
      printf "  #%-4d %08X %s | arrived: thigh %3.0f%% shin %3.0f%% way %5.0f foot-pelvis %5.0f | drawn: thigh %3.0f%% shin %3.0f%% way %5.0f foot-pelvis %5.0f\n",$i,$fl,$sd?'R':'L',$g->{th},$g->{ca},$g->{way},$g->{fp},$dr->{th},$dr->{ca},$dr->{way},$dr->{fp} if defined $sgW && (!defined $ARGV[2] || ($i>=$ARGV[2] && $i<=$ARGV[3]));
    }
    $line.=sprintf(" | %s shin %3.0f..%3.0f%% (off its length on %3d poses; arrived %3d) way max %3.0f (>60 on %3d; arrived %3.0f, %3d)",$sd?'R':'L',$mx{cmin},$mx{cmax},$nc,$ncg,$mx{way},$nw,$mx{wayg},$nwg); }
  print "$line\n" unless defined $sgW;
}
