use strict; use warnings;
# menutext.pl <new main.lua> <old main.lua> <ExpandedTricks.ini> <out.txt> [check]
# The in-game menus as plain text, from the mod's own menu table (NATIVE.MENU): one block a row, for the author to edit.
# Also checks what the native half can hold: 8 pages, 48 rows a page, a label of 63 characters, a description of 239.
my ($new, $old, $ini, $out) = @ARGV;
sub slurp { open my $f, '<', $_[0] or die "$_[0]: $!"; local $/; my $t = <$f>; close $f; $t =~ s/\r\n/\n/g; return $t; }
my $t = slurp($new);

# defaults: the S table's own lines
my %def;
if ($t =~ /\nlocal S = \{\n(.*?)\n\}\n/s) {
    for my $l (split /\n/, $1) { $def{$1} = $2 if $l =~ /^\s+(\w+)\s*=\s*(-?[0-9.]+)\s*,/; }
}
# the ini's limits
my %spec;
for my $l (split /\n/, $t) { $spec{$1} = [$2, $3] if $l =~ /^\s*\{ "(\w+)",\s*"num",\s*(-?[0-9.]+),\s*(-?[0-9.]+),/; }
# the user's ini
my %cur;
if ($ini && -f $ini) { for my $l (split /\n/, slurp($ini)) { $cur{$1} = $2 if $l =~ /^(\w+)=(-?[0-9.]+)\s*$/; } }

sub rows {
    my ($text) = @_;
    my (@pages, $pg);
    my ($a, $b) = (index($text, "\nNATIVE.MENU = {\n"), index($text, "\nNATIVE.menuRow = {}\n"));
    die "no menu table" if $a < 0 || $b < 0;
    for my $l (split /\n/, substr($text, $a, $b - $a)) {
        if ($l =~ /^    \{ "([^"]+)", \{\s*$/) { $pg = { title => $1, rows => [] }; push @pages, $pg; next; }
        next unless $pg && $l =~ /^\s*\{ "(toggle|slider|page)",\s*"([^"]+)",\s*"([^"]+)",\s*(-?[0-9.]+),\s*(-?[0-9.]+),\s*"((?:[^"\\]|\\.)*)"(.*)\},?\s*$/;
        my %r = (kind => $1, key => $2, label => $3, scale => $4, step => $5, desc => $6);
        my $rest = $7;
        $r{desc} =~ s/\\"/"/g;
        ($r{lo}, $r{hi}) = ($1, $2) if $rest =~ /^\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)/;
        $r{unit} = $1 if $rest =~ /unit = "([^"]*)"/;
        push @{ $pg->{rows} }, \%r;
    }
    my @quick;
    @quick = ($1 =~ /"(\w+)"/g) if $text =~ /\nNATIVE\.MENU_QUICK = \{([^}]*)\}/;
    return (\@pages, \@quick);
}
my ($pages, $quick) = rows($t);
my ($opages) = rows(slurp($old));
my %was;
for my $p (@$opages) { for my $r (@{ $p->{rows} }) { $was{ ($r->{kind} eq 'page' ? 'page:' : '') . $r->{key} } //= $r->{label}; } }
my %oldtitle = ("Rolling Grabs and Finger Flips" => "Finger Flips", "No Comply and Boneless" => "No Comply");

sub num { my $x = sprintf("%.0f", $_[0]); $x = "0" if $x eq "-0"; return $x; }
sub deftext {
    my ($r) = @_;
    my $d = $def{ $r->{key} };
    return undef unless defined $d;
    return ($d != 0) ? "On" : "Off" if $r->{kind} eq 'toggle';
    return num($d * $r->{scale}) . (($r->{unit} // '') ne '' ? " $r->{unit}" : "");
}
sub curtext {
    my ($r) = @_;
    my $c = $cur{ $r->{key} };
    return undef unless defined $c;
    return ($c >= 0.5) ? "On" : "Off" if $r->{kind} eq 'toggle';
    return num($c * $r->{scale}) . (($r->{unit} // '') ne '' ? " $r->{unit}" : "");
}
sub wrap {
    my ($s, $ind, $w) = @_;
    my ($line, @o) = ('');
    for my $word (split / /, $s) {
        if (length($line) + length($word) + 1 > $w && $line ne '') { push @o, $line; $line = $word; }
        else { $line = ($line eq '') ? $word : "$line $word"; }
    }
    push @o, $line if $line ne '';
    return join("\n" . (' ' x $ind), @o);
}

my ($bad, $nrows, %byKey, $root) = (0, 0);
for my $p (@$pages) { for my $r (@{ $p->{rows} }) { $root = $p if $r->{kind} eq 'page'; $byKey{ $r->{key} } //= $r if $r->{kind} ne 'page'; } }
print STDERR "PAGES: " . (scalar(@$pages) + 1) . " (with Quick; the native half holds 8)\n";
$bad++ if @$pages + 1 > 8;

my $o = '';
$o .= "EXPANDED TRICKS 1.0.0 -- THE IN-GAME MENUS AS PLAIN TEXT\n";
$o .= "Made from the mod's own menu table (Lua v184) on 5 Oct 2026. This is exactly what the pause menu shows.\n\n";
$o .= "HOW TO EDIT THIS FILE\n";
$o .= "  - Change any Label: or Text: line. Leave the [Key] line alone: it says which setting the row belongs to.\n";
$o .= "  - To CUT a row from the menu, write CUT in front of its [Key] line. The setting itself stays in ExpandedTricks.ini.\n";
$o .= "  - To ADD a row, write it in at the place you want it, or just tell me. Settings that exist but have no menu row\n";
$o .= "    are listed at the end of this file.\n";
$o .= "  - To move a row, move its whole block. To rename a page, change its PAGE line.\n";
$o .= "  - Limits: a label up to 63 characters, a text up to about 215 (the game adds \"Default: ...\" after it by itself).\n";
$o .= "  - \"was:\" shows the name a row had before this pass. \"yours:\" is what your own ini has now.\n\n";

sub block {
    my ($r, $n) = @_;
    my $s = '';
    my $k = $r->{key};
    my ($lo, $hi) = ($r->{lo} // $spec{$k}[0], $r->{hi} // $spec{$k}[1]);
    my $type;
    if ($r->{kind} eq 'toggle') { $type = "switch, On / Off"; }
    else {
        my $u = (($r->{unit} // '') ne '') ? " $r->{unit}" : "";
        $type = sprintf("slider, %s to %s%s, in steps of %s", num($lo * $r->{scale}), num($hi * $r->{scale}), $u, $r->{step});
    }
    my $d = deftext($r); my $c = curtext($r);
    $s .= sprintf("  %2d. [%s]   %s   default %s%s\n", $n, $k, $type, $d // '?', (defined $c && defined $d && $c ne $d) ? "   (yours: $c)" : "");
    $s .= "      Label: $r->{label}" . ((defined $was{$k} && $was{$k} ne $r->{label}) ? "        (was: $was{$k})" : (!defined $was{$k} ? "        (NEW ROW)" : "")) . "\n";
    $s .= "      Text:  " . wrap($r->{desc}, 13, 100) . "\n\n";
    return $s;
}

# the root page first, then each page in the order the root lists them
$o .= "=" x 110 . "\n";
$o .= "PAUSE MENU ROW: $root->{title}\n";
$o .= "(the row the mod adds to the game's pause menu; it opens this list of pages)\n";
$o .= "=" x 110 . "\n\n";
my $i = 0;
for my $r (@{ $root->{rows} }) {
    $i++;
    my $w = $oldtitle{ $r->{key} } // $was{ 'page:' . $r->{key} };
    $o .= sprintf("  %2d. PAGE: %s%s\n", $i, $r->{label}, (defined $w && $w ne $r->{label}) ? "        (was: $w)" : "");
    $o .= "      Text:  " . wrap($r->{desc}, 13, 100) . "\n\n";
    if (length($r->{label}) > 63 || length($r->{desc}) > 239) { print STDERR "TOO LONG: page row $r->{label}\n"; $bad++; }
}
for my $pr (@{ $root->{rows} }) {
    $o .= "=" x 110 . "\n";
    $o .= "PAGE: $pr->{label}\n";
    $o .= "=" x 110 . "\n\n";
    if ($pr->{key} eq 'Quick') {
        $o .= "  This page has no text of its own: it repeats these rows from the other pages, in this order.\n";
        $o .= "  Cut or add a row here by editing the list.\n\n";
        my $n = 0;
        for my $k (@$quick) {
            $n++;
            my $r = $byKey{$k};
            if (!$r) { print STDERR "QUICK: no row for $k\n"; $bad++; next; }
            $o .= sprintf("  %2d. [%s]   %s\n", $n, $k, $r->{label});
        }
        $o .= "\n";
        print STDERR "Quick: $n rows (14 at most)\n"; $bad++ if $n > 14;
        next;
    }
    my ($pg) = grep { $_->{title} eq $pr->{key} } @$pages;
    if (!$pg) { print STDERR "NO PAGE for $pr->{key}\n"; $bad++; next; }
    my $n = 0;
    for my $r (@{ $pg->{rows} }) {
        $n++; $nrows++;
        my $k = $r->{key};
        if (!$spec{$k}) { print STDERR "NO INI SETTING: $k\n"; $bad++; }
        if (!defined $def{$k}) { print STDERR "NO DEFAULT: $k\n"; $bad++; }
        my $full = $r->{desc} . " Default: " . (deftext($r) // '') . ".";
        if (length($r->{label}) > 63) { print STDERR "LABEL TOO LONG: $k\n"; $bad++; }
        if (length($full) > 239) { print STDERR "TEXT TOO LONG (" . length($full) . "): $k\n"; $bad++; }
        if ($r->{desc} =~ /[^\x20-\x7E]/) { print STDERR "NOT ASCII: $k\n"; $bad++; }
        my ($lo, $hi) = ($r->{lo} // $spec{$k}[0], $r->{hi} // $spec{$k}[1]);
        if ($spec{$k} && ($lo < $spec{$k}[0] || $hi > $spec{$k}[1])) { print STDERR "RANGE WIDER THAN THE INI'S: $k\n"; $bad++; }
        if (defined $def{$k} && $r->{kind} eq 'slider' && ($def{$k} < $lo || $def{$k} > $hi)) { print STDERR "DEFAULT OUTSIDE THE SLIDER: $k ($def{$k} not in $lo..$hi)\n"; $bad++; }
        $o .= block($r, $n);
    }
    print STDERR sprintf("%-32s %2d rows\n", $pg->{title}, $n); $bad++ if $n > 48;
}
$o .= "=" x 110 . "\n";
$o .= "NOT IN THE MENU (ini only) -- the ones a player might want. Say which to add.\n";
$o .= "=" x 110 . "\n\n";
my @cand = (
    [ "Sounds", "switch", "the hippie jump's take-off and landing sounds" ],
    [ "SoundVolume", "slider", "volume of those sounds" ],
    [ "DropInSoundVolume", "slider", "volume of the drop-in sounds" ],
    [ "NeedCrouch", "switch", "the hippie jump's stick click only works while crouched" ],
    [ "GravityFactor", "slider", "hang time: heavier and snappier, or floatier" ],
    [ "LandAbsorb", "slider", "how deep you absorb a hippie jump's landing" ],
    [ "MiniCrouch", "slider", "how deep the mini hippie jump dips before it springs up" ],
    [ "VarialLandWindow", "slider", "how many degrees off a half or full turn you can land and still ride away" ],
    [ "VarialLandAssist", "slider", "how much of the air time the spin is steered toward the nearest clean landing" ],
    [ "BlockCarve", "switch", "during a jump the triggers only spin your body; the board keeps rolling straight" ],
    [ "TrickBlock", "switch", "no flip tricks while you are off the board in a hippie jump" ],
    [ "BailReturn", "switch", "after a bail in a hippie jump you are put back where the jump started" ],
    [ "MuteRevertSound", "switch", "no revert sound on a 180 hippie jump's landing" ],
    [ "BoardHopRange", "slider", "how far away the board may be for jumping onto it, cm" ],
    [ "DropInStillSpeed", "slider", "how still you must stand for Y to set up a drop-in, cm/s" ],
    [ "NoComplyInputAngle", "slider", "how exactly the sticks must match the no comply's input, degrees" ],
    [ "NoComplyPopHeightMin", "slider", "the least the board rises at a no comply's pop, cm (the menu has the most)" ],
    [ "NoComplyPopForwardMin", "slider", "the least the board is pushed forward at the pop, cm (the menu has the most)" ],
    [ "NoComplyStartPitchMin", "slider", "the least the board is scooped nose-up, degrees (the menu has the most)" ],
    [ "BonelessBoardPopMax", "slider", "the most the BOARD rises at a boneless's pop, cm" ],
    [ "NoComplyPlantTime", "slider", "the longest the planted foot stands on the ground, seconds" ],
    [ "GrabTweakDead", "slider", "degrees the stick may wander before a grab starts to tweak" ],
    [ "GrabChord", "slider", "how long a one-bumper grab waits for the other bumper (two-hand grabs), seconds" ],
    [ "MenuOwnPages", "switch", "the mod's own nested pages, or one flat page in SessionOpenMP's menu" ],
);
for my $c (@cand) {
    my ($k, $kind, $what) = @$c;
    if (!$spec{$k}) { print STDERR "CANDIDATE NOT IN THE INI: $k\n"; next; }
    $o .= sprintf("  [%s]   %s, ini range %s to %s, default %s%s\n      %s\n\n", $k, $kind, $spec{$k}[0], $spec{$k}[1], $def{$k} // '?',
        (defined $cur{$k} && defined $def{$k} && $cur{$k} != $def{$k}) ? " (yours: $cur{$k})" : "", $what);
}
$o .= "  Also ini only, by design: each grab's own hand spot, path, tilt and leg numbers (about 25 numbers a grab, 15 grabs),\n";
$o .= "  which grab each stick direction picks, and the animation fixes (hop legs, plant foot, switch plants).\n";
open my $w, '>:raw', $out or die "$out: $!"; print $w $o; close $w;
print STDERR "$nrows rows on the pages; " . ($bad ? "$bad PROBLEMS" : "all checks passed") . "\n";
exit($bad ? 1 : 0);
