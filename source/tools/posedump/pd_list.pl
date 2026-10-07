# pd_list.pl -- lists the segments of an ExpandedTricks.poses.bin (a second, independent reader of the layout in
# README.md: written from that table, not from the C++ structs or the viewer).
# usage: perl pd_list.pl <poses.bin> [segment number: also prints that segment's poses, one line each]
use strict; use warnings;
my ($path, $want) = @ARGV; die "usage: perl pd_list.pl <poses.bin> [segment]\n" unless defined $path;
open my $f, '<:raw', $path or die "$path: $!"; my $size = -s $path;
my @names = ('hop-air', 'landing-blend', 'plant', 'bone-hand', 'feet-hold', 'pose-hold', 'foot-ground', 'half-turn', 'grab', 'trick-trace');
my @end = ('?', 'its windows shut', 'at its longest', 'a gap', 'switched off', 'another rig');
my ($at, $n) = (0, 0);
while ($at + 160 <= $size) {
    seek $f, $at, 0; read $f, my $h, 160;
    my ($magic, $ver, $hdr, $seg, $frames, $bones, $fh, $fb, $pre, $reason, $sflags, $seq, $any, $mod, $rigc) = unpack('a4 v v V V v v V v C C V V v v', $h);
    last unless $magic eq 'ETPD' && $fb == $fh + 24 * $bones && $seg == $hdr + $frames * $fb;
    my @when = unpack('v8', substr($h, 40, 16));
    my ($halfLen, $halfWid, $cx, $ankle, $toe) = unpack('f<5', substr($h, 64, 20));
    my @rig = unpack('s<*', substr($h, 88, 2 * $rigc));
    $n++;
    printf "%3d  run's #%-3d %04d-%02d-%02d %02d:%02d:%02d.%03d  %4d poses (%2d before its start)  %3d bones  v%d  %d bytes at %d  on: %s | ended: %s%s%s\n",
        $n, $seq, @when[0, 1, 3, 4, 5, 6, 7], $frames, $pre, $bones, $mod, $seg, $at,
        join(' ', map { $names[$_] } grep { $any & (1 << $_) } 0 .. 9) || 'nothing', $end[$reason] // '?', ($sflags & 1) ? ' (goes on from the one before)' : '',
        $at + $seg > $size ? '  CUT SHORT' : '';
    if (defined $want && $want == $n) {
        printf "     deck half length %.1f width %.1f centre %.1f; standing ankle %.1f toe %.1f; pelvis %d, thighs %d %d, calves %d %d, feet %d %d, toes %d %d, flipper %d\n",
            $halfLen, $halfWid, $cx, $ankle, $toe, @rig[0 .. 8], $rig[24];
        my $t0;
        for my $i (0 .. $frames - 1) {
            seek $f, $at + $hdr + $i * $fb, 0; last unless read($f, my $r, $fh) == $fh;
            my ($flags, $tick, $t) = unpack('V V d<', $r);
            my @mesh = unpack('f<10', substr($r, 16, 40)); my ($gz) = unpack('f<', substr($r, 92, 4));
            $t0 //= $t; $t0 = $t if $i == $pre;
        }
        for my $i (0 .. $frames - 1) {
            seek $f, $at + $hdr + $i * $fb, 0; last unless read($f, my $r, $fb) == $fb;
            my ($flags, $tick, $t) = unpack('V V d<', $r);
            my @mesh = unpack('f<10', substr($r, 16, 40)); my ($gz) = unpack('f<', substr($r, 92, 4));
            my @pg = unpack('f<3', substr($r, $fh + 12 * $rig[0], 12)); my @pd = unpack('f<3', substr($r, $fh + 12 * ($bones + $rig[0]), 12));
            printf "     #%-3d %+7.0f ms  %s%s%s  mesh (%.0f %.0f %.0f) ground %s  pelvis game (%.1f %.1f %.1f) drawn (%.1f %.1f %.1f)\n", $i, ($t - $t0) * 1000,
                join('', map { ($flags & (1 << $_)) ? substr('ALPBFHGYRT', $_, 1) : '.' } 0 .. 9), ($flags & 0x400) ? ' c' : '  ', ($flags & 0x2000000) ? '!' : ($flags & 0x800) ? '*' : '=',
                @mesh[4 .. 6], ($flags & 0x200000) ? sprintf('%.0f', $gz) : 'none', @pg, @pd;
        }
    }
    $at += $seg;
}
print "$n segment", ($n == 1 ? '' : 's'), ", $size bytes", ($at < $size ? " (stopped at byte $at: no whole segment there)" : ''), "\n";
