# mirsim.pl <bin> [seg] [verbose]: native v103's rule for the goofy rider's switch landing, replayed over a recording.
# At the pose the mirror table is back (the sockets no longer turned, the mirror bit on again) a foot socket that has
# jumped across the deck's centre line -- its mirror image is where the pose before had it -- is held on its own side
# (the image's across, the game's along and up; the rotation the game's turned half round, kept in the deck's frame)
# until the game's own socket has come round to that side.
# Prints, per switch plant in the file, whether the rule would start, and with a segment number the sockets it gives.
use strict; use warnings;
use FindBin; require "$FindBin::Bin/pdlib.pl";
my ($file, $want, $verb) = @ARGV;
sub rotq { my ($p, $y, $r) = map { $_ * 0.00872664626 } @_; my ($SP,$CP,$SY,$CY,$SR,$CR) = (sin($p),cos($p),sin($y),cos($y),sin($r),cos($r));
    [$CR*$SP*$SY - $SR*$CP*$CY, -$CR*$SP*$CY - $SR*$CP*$SY, $CR*$CP*$SY - $SR*$SP*$CY, $CR*$CP*$CY + $SR*$SP*$SY] }
sub qmul { my ($a, $b) = @_; my ($ax,$ay,$az,$aw) = @$a; my ($bx,$by,$bz,$bw) = @$b;
    [$aw*$bx + $ax*$bw + $ay*$bz - $az*$by, $aw*$by - $ax*$bz + $ay*$bw + $az*$bx, $aw*$bz + $ax*$by - $ay*$bx + $az*$bw, $aw*$bw - $ax*$bx - $ay*$by - $az*$bz] }
sub qconj { [-$_[0][0], -$_[0][1], -$_[0][2], $_[0][3]] }
sub qang { my ($a, $b) = @_; my $d = abs($a->[0]*$b->[0] + $a->[1]*$b->[1] + $a->[2]*$b->[2] + $a->[3]*$b->[3]); $d = 1 if $d > 1; 2 * UB::deg(atan2(sqrt(1 - $d*$d), $d)) }
my $segs = UB::load($file);
for my $sn (1 .. scalar @$segs) {
    next if $want && $sn != $want;
    my $s = $segs->[$sn-1]; next if $s->{fh} < 512;
    my @rig = @{$s->{rig}};
    my ($prevTurned, @prevD, @mir, @mirY, @mirQ, $arm, $t0, $started, $end, @lastOut) = (0);
    my ($nStart, $held) = (0, 0);
    for my $i (0 .. $s->{frames}-1) {
        my $fr = UB::frame($s, $i);
        my @k = unpack('f<12', substr(${$s->{d}}, $fr->{fo}+436, 48));
        my @d = (UB::toDeck($fr, [@k[0..2]]), UB::toDeck($fr, [@k[6..8]]));
        my @rq = (rotq(@k[3..5]), rotq(@k[9..11]));
        my $turned = $fr->{more} & 1; my $mirror = ($fr->{flags} & 0x1000000) ? 1 : 0;
        # the tail begins on the first pose after a run of turned poses with the mirror bit back on (the goofy path: the bit is off while the table is away)
        if ($prevTurned && !$turned && $mirror && !defined $arm) { $arm = 0; $t0 = $fr->{t}; @mir = (0, 0); }
        if (defined $arm && !$end) {
            $arm++;
            my $up = UB::qrot($fr->{dq}, [0,0,1]); my $half = [@$up, 0];
            my @out = (undef, undef);
            for my $kk (0, 1) {
                if (!$mir[$kk]) {
                    next if $arm > 8 || $fr->{t} - $t0 > 0.2;
                    my $im = [$d[$kk][0], -$d[$kk][1], $d[$kk][2]];
                    my $eRaw = UB::dist($d[$kk], $prevD[$kk]); my $eIm = UB::dist($im, $prevD[$kk]);
                    next unless $d[$kk][1] * $prevD[$kk][1] < 0 && abs($d[$kk][1] - $prevD[$kk][1]) > 12 && $eIm + 8 < $eRaw && $eIm < 10 && abs($im->[1]) >= 4;
                    $mir[$kk] = 1; $mirY[$kk] = $im->[1]; $mirQ[$kk] = qmul(qconj($fr->{dq}), qmul($half, $rq[$kk])); $nStart++;
                    printf "seg %d #%d +%.0f ms: %s socket jumped across (pose before %+.0f %+.0f, the game's %+.0f %+.0f, its image %.1f cm from the pose before, raw %.1f) -> HELD\n",
                        $sn, $i, ($fr->{t}-$t0)*1000, $kk ? 'R' : 'L', @{$prevD[$kk]}[0,1], @{$d[$kk]}[0,1], $eIm, $eRaw;
                }
                my $sg = $mirY[$kk] >= 0 ? 1 : -1; my $side = $d[$kk][1] * $sg;
                if ($side >= abs($mirY[$kk]) - 2 || $fr->{t} - $t0 > 1.5) {
                    my $rawQd = qmul(qconj($fr->{dq}), $rq[$kk]);
                    printf "seg %d #%d +%.0f ms: %s the game's own socket is back on its side (%+.0f %+.0f) -> released after %d poses; the held rotation is %.0f deg from the game's now\n",
                        $sn, $i, ($fr->{t}-$t0)*1000, $kk ? 'R' : 'L', @{$d[$kk]}[0,1], $i - ($started // $i), qang($mirQ[$kk], $rawQd);
                    $mir[$kk] = 0; next;
                }
                $out[$kk] = [$d[$kk][0], $mirY[$kk], $d[$kk][2]]; $held++;
            }
            $started //= $i if $mir[0] || $mir[1];
            if ($verb && ($mir[0] || $mir[1] || $arm <= 3)) {
                my @an = map { $rig[$_] >= 0 ? UB::toDeck($fr, UB::P($fr, 0, $rig[$_])) : [0,0,0] } (25, 26);
                printf "   #%-3d out L %s R %s | the game's L %+4.0f%+4.0f R %+4.0f%+4.0f | anchors L %+4.0f%+4.0f R %+4.0f%+4.0f\n", $i,
                    $out[0] ? sprintf("%+4.0f%+4.0f*", @{$out[0]}[0,1]) : sprintf("%+4.0f%+4.0f ", @{$d[0]}[0,1]), $out[1] ? sprintf("%+4.0f%+4.0f*", @{$out[1]}[0,1]) : sprintf("%+4.0f%+4.0f ", @{$d[1]}[0,1]),
                    @{$d[0]}[0,1], @{$d[1]}[0,1], @{$an[0]}[0,1], @{$an[1]}[0,1];
            }
            @prevD = map { $out[$_] // $d[$_] } (0, 1);
            $end = 1 if $arm > 8 && !$mir[0] && !$mir[1];
        } else { @prevD = @d; }
        $prevTurned = $turned;
    }
    printf "seg %2d: %s -- %s\n", $sn, $s->{when}, defined $arm ? ($nStart ? "RULE STARTED for $nStart feet, held on $held foot-poses" : "tail seen, rule did not start") : "no goofy switch tail in it";
}
