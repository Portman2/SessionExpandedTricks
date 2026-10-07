use strict; use warnings;
# lag.pl <bin>...: in plain riding (the first poses of each segment), the drawn deck's place in the mesh along the way of travel, against the speed.
# If the skater's capsule is moved AFTER the mesh's pose each frame, the deck stands speed x dt further along than at rest.
sub qconj{my $q=shift;[-$q->[0],-$q->[1],-$q->[2],$q->[3]]}
sub qmul{my($a,$b)=@_;my($ax,$ay,$az,$aw)=@$a;my($bx,$by,$bz,$bw)=@$b;[ $aw*$bx+$ax*$bw+$ay*$bz-$az*$by, $aw*$by-$ax*$bz+$ay*$bw+$az*$bx, $aw*$bz+$ax*$by-$ay*$bx+$az*$bw, $aw*$bw-$ax*$bx-$ay*$by-$az*$bz ]}
sub qrot{my($q,$v)=@_;my $p=qmul(qmul($q,[@$v,0]),qconj($q));[@$p[0..2]]}
for my $file (@ARGV){
  open my $f,'<:raw',$file or next; local $/; my $d=<$f>; close $f; my $off=0; my $seg=0;
  while($off+160<=length $d){
    my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fbytes,$pre)=unpack('a4 v v V V v v V v',substr($d,$off,26));
    last unless $magic eq 'ETPD'; $seg++;
    my ($n,$sv,$sa,$sdt)=(0,0,0,0); my (@pp,$pt);
    for(my $i=0;$i<$pre-2&&$i<$frames;$i++){ my $o=$off+$hdr+$i*$fbytes;
      my $fl=unpack('V',substr($d,$o,4)); my $t=unpack('d<',substr($d,$o+8,8)); my @mq=unpack('f<4',substr($d,$o+16,16)); my @mp=unpack('f<3',substr($d,$o+32,12));
      my @dp=unpack('f<3',substr($d,$o+72,12));
      if(@pp && ($fl&0x100000) && !($fl&0x3ff)){ my $dt=$t-$pt; if($dt>0.004&&$dt<0.05){ my @v=map{($mp[$_]-$pp[$_])/$dt}0..2; my $sp=sqrt($v[0]**2+$v[1]**2);
          if($sp>20){ my $w=qrot(\@mq,\@dp); my $al=($w->[0]*$v[0]+$w->[1]*$v[1])/$sp; $n++; $sv+=$sp; $sa+=$al; $sdt+=$dt; } } }
      @pp=@mp; $pt=$t;
    }
    printf "%-28s seg %2d: %2d poses, speed %5.0f cm/s, frame %4.1f ms, deck along the way of travel in the mesh %+6.2f cm (speed x frame = %4.1f)\n",(split m{/},$file)[-1],$seg,$n,$sv/$n,1000*$sdt/$n,$sa/$n,$sv/$n*$sdt/$n if $n>=8;
    $off+=$segBytes;
  }
}
