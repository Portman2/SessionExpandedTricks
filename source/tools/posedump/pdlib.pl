# pdlib.pl -- a reader of the pose file and vector maths, for mirsim.pl and for new tools (package UB). Layout: posedump/README.md section 2.
# Bone indices of the live 70-bone rig (from the Lua log line "native: bones: ..."):
#   2 pelvis | 11 12 13 spine1-3 | 14 L clavicle 15 L upper arm 16 L forearm 17 L hand | 34 neck 35 head
#   36 R clavicle 37 R upper arm 38 R forearm 39 R hand | 3 4 5 6 R thigh calf foot toe | 7 8 9 10 L thigh calf foot toe
use strict; use warnings;
package UB;
our %B = (pelvis=>2, sp1=>11, sp2=>12, sp3=>13, clavL=>14, uarmL=>15, farmL=>16, handL=>17, neck=>34, head=>35,
          clavR=>36, uarmR=>37, farmR=>38, handR=>39, thighR=>3, calfR=>4, footR=>5, toeR=>6, thighL=>7, calfL=>8, footL=>9, toeL=>10,
          root=>1, master=>0, flipper=>59);
sub v3  { [@_] }
sub add { [map { $_[0][$_] + $_[1][$_] } 0..2] }
sub sub3{ [map { $_[0][$_] - $_[1][$_] } 0..2] }
sub mul { [map { $_[0][$_] * $_[1] } 0..2] }
sub dot { $_[0][0]*$_[1][0] + $_[0][1]*$_[1][1] + $_[0][2]*$_[1][2] }
sub len { sqrt(dot($_[0], $_[0])) }
sub norm{ my $l = len($_[0]); $l < 1e-9 ? [0,0,0] : mul($_[0], 1/$l) }
sub cross { my ($a,$b)=@_; [$a->[1]*$b->[2]-$a->[2]*$b->[1], $a->[2]*$b->[0]-$a->[0]*$b->[2], $a->[0]*$b->[1]-$a->[1]*$b->[0]] }
sub qrot { my ($q,$v)=@_; my ($x,$y,$z,$w)=@$q; my $u=[$x,$y,$z]; my $c1=cross($u,$v); my $c2=cross($u,$c1); [map { $v->[$_] + 2*($w*$c1->[$_] + $c2->[$_]) } 0..2] }
sub qinvrot { my ($q,$v)=@_; qrot([-$q->[0], -$q->[1], -$q->[2], $q->[3]], $v) }
sub dist { len(sub3($_[0], $_[1])) }
sub wrap { my $a = shift; $a -= 360 while $a > 180; $a += 360 while $a < -180; $a }
sub deg  { $_[0] * 57.29578 }
sub ang  { my ($a,$b)=@_; my $la=len($a); my $lb=len($b); return 0 if $la<1e-6||$lb<1e-6; my $c=dot($a,$b)/($la*$lb); $c=1 if $c>1; $c=-1 if $c<-1; deg(atan2(sqrt(1-$c*$c),$c)) }
sub median { my @s = sort { $a <=> $b } @_; @s ? $s[int($#s/2)] : 0 }
sub load {
    my ($file) = @_; open my $f, '<:raw', $file or die "$file: $!"; local $/; my $d = <$f>; close $f;
    my @segs; my $off = 0; my $n = 0;
    while ($off + 160 <= length $d) {
        my ($magic,$ver,$hdr,$segBytes,$frames,$bones,$fh,$fb,$pre,$reason,$sflags,$seq,$any,$mod,$rigc) = unpack('a4 v v V V v v V v C C V V v v', substr($d,$off,40));
        last unless $magic eq 'ETPD' && $fb == $fh + 24*$bones; $n++;
        my @when = unpack('v8', substr($d,$off+40,16));
        my ($hl,$hw,$cx,$fa,$ft) = unpack('f<5', substr($d,$off+64,20));
        my @rig = unpack('s<36', substr($d,$off+88,72));
        my @par = unpack("s<$bones", substr($d,$off+160,2*$bones));
        push @segs, { n=>$n, off=>$off, hdr=>$hdr, frames=>$frames, bones=>$bones, fh=>$fh, fb=>$fb, pre=>$pre, reason=>$reason, seq=>$seq, any=>$any, mod=>$mod,
                      when=>sprintf('%02d-%02d %02d:%02d:%02d.%03d', @when[1,3,4,5,6,7]), hl=>$hl, hw=>$hw, cx=>$cx, rig=>\@rig, par=>\@par, d=>\$d };
        $off += $segBytes;
    }
    return \@segs;
}
# one pose: its header fields and an accessor for bone positions. set 0 = as it ARRIVED (g_C), 1 = as DRAWN (g_Ct)
sub frame {
    my ($s, $i) = @_; my $d = $s->{d}; my $fo = $s->{off} + $s->{hdr} + $i*$s->{fb};
    my ($flags,$tick,$t) = unpack('V V d<', substr($$d,$fo,16));
    my @m = unpack('f<10', substr($$d,$fo+16,40)); my @dk = unpack('f<7', substr($$d,$fo+56,28));
    my ($gz,@gn) = unpack('f<4', substr($$d,$fo+92,16));
    my @w = unpack('f<7', substr($$d,$fo+108,28)); my @st = unpack('s<6', substr($$d,$fo+136,12));
    my @q = unpack('f<40', substr($$d,$fo+148,160));
    my $more = $s->{fh} >= 512 ? unpack('V', substr($$d,$fo+508,4)) : 0;
    my $fr = { i=>$i, flags=>$flags, t=>$t, mq=>[@m[0..3]], mp=>[@m[4..6]], ms=>[@m[7..9]], dq=>[@dk[0..3]], dp=>[@dk[4..6]], gz=>$gz, gn=>\@gn,
               plantD=>$w[0], plantW=>$w[1], hopFrac=>$w[2], boneW=>$w[4], fholdW=>$w[5], legFixW=>$w[6],
               plantFoot=>$st[0], plantStage=>$st[1], grabKind=>$st[4], stance=>$st[5], more=>$more,
               pelvQ=>[[@q[0..3]], [@q[20..23]]], fo=>$fo, s=>$s };
    return $fr;
}
sub P { my ($fr,$set,$bone)=@_; my $s=$fr->{s}; [unpack('f<3', substr(${$s->{d}}, $fr->{fo}+$s->{fh}+$set*$s->{bones}*12+$bone*12, 12))] }
# the pose the SCREEN had: the drawn set only where 'changed' (0x800) is on and 'rejected' (0x2000000) is off
sub shown { my ($fr)=@_; (($fr->{flags} & 0x800) && !($fr->{flags} & 0x2000000)) ? 1 : 0 }
sub toWorld { my ($fr,$p)=@_; add($fr->{mp}, qrot($fr->{mq}, [$p->[0]*$fr->{ms}[0], $p->[1]*$fr->{ms}[1], $p->[2]*$fr->{ms}[2]])) }
sub dirWorld { my ($fr,$v)=@_; qrot($fr->{mq}, [$v->[0]*$fr->{ms}[0], $v->[1]*$fr->{ms}[1], $v->[2]*$fr->{ms}[2]]) }
sub toDeck { my ($fr,$p)=@_; qinvrot($fr->{dq}, sub3($p, $fr->{dp})) }          # mesh space -> the drawn deck's frame (along, across, up)
sub fromDeck { my ($fr,$p)=@_; add($fr->{dp}, qrot($fr->{dq}, $p)) }
sub deckOk { ($_[0]{flags} & 0x100000) ? 1 : 0 }
# distance of a deck-frame point from the deck's top plate (a box: along cx +- hl, across +- hw, at height 0)
sub deckDist { my ($s,$p)=@_; my $dx = abs($p->[0]-$s->{cx}) - $s->{hl}; $dx = 0 if $dx < 0; my $dy = abs($p->[1]) - $s->{hw}; $dy = 0 if $dy < 0; sqrt($dx*$dx + $dy*$dy + $p->[2]*$p->[2]) }
sub flagstr { my $f = shift; join('', map { ($f & (1 << $_)) ? substr('ALPBFHGYRT', $_, 1) : '.' } 0..9) . (($f & 0x1000000) ? 'm' : '-') . (($f & 0x2000000) ? '!' : ($f & 0x800) ? '*' : '=') }
# the way the skater travels over a span of poses: the mesh origin's horizontal world path, a unit vector (world) and the speed cm/s
sub travel {
    my ($s, $a, $b) = @_; $a = 0 if $a < 0; $b = $s->{frames}-1 if $b > $s->{frames}-1;
    my $fa = frame($s,$a); my $fb = frame($s,$b); my $d = sub3($fb->{mp}, $fa->{mp}); $d->[2] = 0; my $dt = $fb->{t} - $fa->{t};
    return (norm($d), $dt > 0 ? len($d)/$dt : 0);
}
1;
