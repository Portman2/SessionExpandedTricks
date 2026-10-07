use strict; use warnings;
# socksim.pl <v99 bin> [seg] [cx]: native v100's socket rule run over a v99 recording's switch plants.
# The recording has the sockets AFTER v99 turned them (on the poses marked T, about the deck's middle cx 0): they are
# un-turned to what the game had, and the new rule (continuity with a margin, the flag after four poses) is run on those.
# Prints, a swap: which poses the new rule turns against which v99 turned, and the largest step of a socket pose to pose.
my ($file, $sgW, $cx) = @ARGV; $sgW //= 0; $cx //= 0.6;
open my $f, '<:raw', $file or die; local $/; my $d = <$f>; close $f;
sub cross { my ($a, $b) = @_; [$a->[1]*$b->[2]-$a->[2]*$b->[1], $a->[2]*$b->[0]-$a->[0]*$b->[2], $a->[0]*$b->[1]-$a->[1]*$b->[0]] }
sub qrot { my ($q, $v) = @_; my ($x, $y, $z, $w) = @$q; my $u = [$x, $y, $z]; my $c1 = cross($u, $v); my $c2 = cross($u, $c1); [map { $v->[$_] + 2 * ($w * $c1->[$_] + $c2->[$_]) } 0..2] }
sub dist { my ($a, $b) = @_; sqrt(($a->[0]-$b->[0])**2 + ($a->[1]-$b->[1])**2 + ($a->[2]-$b->[2])**2) }
my $off = 0; my $seg = 0;
while ($off + 160 <= length $d) {
    my ($magic, $ver, $hdr, $segBytes, $frames, $bones, $fh, $fbytes, $pre) = unpack('a4 v v V V v v V v', substr($d, $off, 26));
    last unless $magic eq 'ETPD'; $seg++;
    if ($fh >= 512 && (!$sgW || $seg == $sgW)) {
        my (@T, @S);
        for (my $i = 0; $i < $frames; $i++) {
            my $o = $off + $hdr + $i * $fbytes;
            my @dk = unpack('f<7', substr($d, $o + 56, 28)); my $cq = [-$dk[0], -$dk[1], -$dk[2], $dk[3]]; my $dp = [@dk[4..6]];
            my @sk = unpack('f<12', substr($d, $o + 436, 48)); my $more = unpack('V', substr($d, $o + 508, 4));
            $T[$i] = ($more & 1) ? 1 : 0;
            my @s;
            for my $k (0, 1) {
                my $p = qrot($cq, [map { $sk[$k*6 + $_] - $dp->[$_] } 0..2]);
                $p = [2 * $cx - $p->[0], -$p->[1], $p->[2]] if $T[$i];      # what the game had
                push @s, $p;
            }
            $S[$i] = \@s;
        }
        my $i = 0;
        while ($i < $frames) {
            if (!$T[$i]) { $i++; next; }
            my $a = $i; my $b = $i; $b++ while $b + 1 < $frames && ($T[$b + 1] || ($b + 2 < $frames && $T[$b + 2]));
            my $from = $a - 2; $from = 0 if $from < 0; my $to = $b + 4; $to = $frames - 1 if $to >= $frames;
            # the rule
            my ($prev, $turned, $flag, $flagN, $forced, $out, $maxStepNew, $maxStepOld, $prevOld, @line) = ($S[$from], 0, 0, 0, 0, '', 0, 0);
            $prevOld = $S[$from];
            for my $j ($from + 1 .. $to) {
                my $fl = $T[$j] ? 1 : 0;
                if ($fl == $flag) { $flagN++ } else { $flag = $fl; $flagN = 1 }
                my $dd = $S[$j];
                my @t = map { [2 * $cx - $dd->[$_][0], -$dd->[$_][1], $dd->[$_][2]] } 0, 1;
                my $sRaw = dist($dd->[0], $prev->[0]) + dist($dd->[1], $prev->[1]);
                my $sTur = dist($t[0], $prev->[0]) + dist($t[1], $prev->[1]);
                my $turn = $turned ? !($sRaw + 6 < $sTur) : ($sTur + 6 < $sRaw);
                if ($flagN >= 4 && ($turn ? 1 : 0) != $flag) { $turn = $flag; $forced++; }
                my $now = $turn ? \@t : $dd;
                my $stepNew = dist($now->[0], $prev->[0]); my $s2 = dist($now->[1], $prev->[1]); $stepNew = $s2 if $s2 > $stepNew;
                $maxStepNew = $stepNew if $stepNew > $maxStepNew;
                my $oldNow = $T[$j] ? \@t : $dd;                           # what v99 fed the game
                my $stepOld = dist($oldNow->[0], $prevOld->[0]); $s2 = dist($oldNow->[1], $prevOld->[1]); $stepOld = $s2 if $s2 > $stepOld;
                $maxStepOld = $stepOld if $stepOld > $maxStepOld;
                $out .= sprintf("%s%s", $turn ? 'T' : '.', '');
                push @line, sprintf("  %4d flag %d  v99 %s  v100 %s  raw %5.1f  turned %5.1f  step v99 %5.1f  v100 %5.1f", $j, $fl, $T[$j] ? 'T' : '.', $turn ? 'T' : '.', $sRaw, $sTur, $stepOld, $stepNew) if $sgW;
                $prev = $now; $prevOld = $oldNow; $turned = $turn ? 1 : 0;
            }
            my $old = join('', map { $T[$_] ? 'T' : '.' } $from + 1 .. $to);
            printf "seg %2d poses %4d-%4d: largest socket step v99 %5.1f cm, v100 %5.1f cm; forced by the flag %d\n   v99  %s\n   v100 %s\n", $seg, $from + 1, $to, $maxStepOld, $maxStepNew, $forced, $old, $out;
            print join("\n", @line), "\n" if $sgW;
            $i = $to + 1;
        }
    }
    $off += $segBytes;
}
