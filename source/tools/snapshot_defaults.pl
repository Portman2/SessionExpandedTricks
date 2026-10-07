#!/usr/bin/perl
# snapshot_defaults.pl -- bake the author's tuned ExpandedTricks.ini into main.lua's shipped defaults.
#
#   perl snapshot_defaults.pl <main.lua> <ExpandedTricks.ini> [--globals] [--dry]
#
# * The per-grab numbers (Hand/Via/Tilt/... x every grab) that differ from the rows in NATIVE.GRABS are written into
#   the NATIVE.GRAB_TUNED block of main.lua (between the GRAB_TUNED_BEGIN / GRAB_TUNED_END markers; rerunnable).
# * With --globals, the top-level settings (local S = { ... }) whose ini value differs from the default are rewritten
#   in place (strings keep their quotes). Debug/log switches are left alone (see @keep).
# A user's own ini always wins at run time; this only changes what a FRESH install starts from.
use strict; use warnings;
my ($lua, $ini, @opt) = @ARGV;
die "usage: snapshot_defaults.pl <main.lua> <ExpandedTricks.ini> [--globals] [--dry]\n" unless $lua && $ini;
my $globals = grep { $_ eq '--globals' } @opt;
my $dry = grep { $_ eq '--dry' } @opt;
local $/;
open my $f, '<', $lua or die "$lua: $!"; my $t = <$f>; close $f;
open my $i, '<', $ini or die "$ini: $!"; my $in = <$i>; close $i;

# ---- the ini
my %ini;
for my $line (split /\n/, $in) { $line =~ s/\r//; next if $line =~ /^\s*[;#]/; $ini{$1} = $2 if $line =~ /^(\w+)=(.*)$/; }

# ---- NATIVE.GRABS rows: name, id, numbers...
my ($grabsBlock) = $t =~ /NATIVE\.GRABS = \{\n(.*?)\n    \}\n/s or die "NATIVE.GRABS not found";
my @grabs;
for my $line (split /\n/, $grabsBlock) {
    next unless $line =~ /^\s*\{\s*"(\w+)",\s*(\d+),\s*([^}]*)\}/;
    my ($name, $id, $rest) = ($1, $2, $3);
    my @nums = map { s/^\s+|\s+$//gr } split /,/, $rest;
    push @grabs, [$name, $id, @nums];
}
# ---- NATIVE.PARAMS rows: prefix, suffix, idx, lo, hi, default column, desc, two-hand flag
my ($paramsBlock) = $t =~ /NATIVE\.PARAMS = \{\n(.*?)\n    \}\n/s or die "NATIVE.PARAMS not found";
my @params;
for my $line (split /\n/, $paramsBlock) {
    next unless $line =~ /^\s*\{\s*"(\w+)",\s*"(\w*)",\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(\d+),\s*"((?:[^"\\]|\\.)*)"(,\s*true)?\s*\}/;
    push @params, { pre => $1, suf => $2, idx => $3, lo => $4, hi => $5, col => $6, two => defined $8 };
}
printf "grabs: %d rows, params: %d rows, ini keys: %d\n", scalar @grabs, scalar @params, scalar keys %ini;

# ---- the per-grab differences
my %tuned; my $nTuned = 0;
for my $g (@grabs) {
    my ($name, $id) = @$g[0, 1];
    for my $p (@params) {
        next if $p->{two} && $id < 200;
        my $key = $p->{pre} . $name . $p->{suf};
        my $def = $p->{col} > 0 ? $g->[$p->{col} - 1] : 0;     # Lua g[col] is 1-based over (name, id, numbers...)
        $def = 0 unless defined $def && $def =~ /^-?[\d.]+$/;
        next unless exists $ini{$key};
        my $v = $ini{$key};
        next unless $v =~ /^-?[\d.]+$/;
        next if abs($v - $def) < 1e-6;
        $tuned{$name}{$p->{pre} . $p->{suf}} = $v + 0;
        $nTuned++;
    }
}
my $block = "    -- GRAB_TUNED_BEGIN (written by tools/snapshot_defaults.pl from the author's ExpandedTricks.ini -- do not edit by hand)\n"
          . "    -- THE RELEASE'S TUNED GRABS: per grab, only the numbers that differ from the rows above; a user's own ini still wins.\n"
          . "    NATIVE.GRAB_TUNED = {\n";
for my $g (@grabs) {
    my $name = $g->[0];
    next unless $tuned{$name};
    my @kv = map { "$_ = $tuned{$name}{$_}" } sort keys %{ $tuned{$name} };
    $block .= "        $name = { " . join(", ", @kv) . " },\n";
}
$block .= "    }\n    -- GRAB_TUNED_END\n";
if ($t =~ /    -- GRAB_TUNED_BEGIN.*?    -- GRAB_TUNED_END\n/s) {
    $t =~ s/    -- GRAB_TUNED_BEGIN.*?    -- GRAB_TUNED_END\n/$block/s;
} else {
    $t =~ s/(    \}\n)(    for _, g in ipairs\(NATIVE\.GRABS\) do\n        for _, p in ipairs\(NATIVE\.PARAMS\) do\n)/$1$block$2/
        or die "the defaults loop after NATIVE.PARAMS was not found";
}
print "per-grab tuned numbers baked: $nTuned (grabs: " . join(", ", grep { $tuned{$_} } map { $_->[0] } @grabs) . ")\n";

# ---- the globals
if ($globals) {
    my @keep = qw(GrabLog DebugBoardLog);                   # never bake the debug switches
    my ($sBlock) = $t =~ /^(local S = \{\n.*?\n\})/ms or die "local S = { ... } not found";
    my $new = $sBlock; my $n = 0;
    for my $line (split /\n/, $sBlock) {
        next unless $line =~ /^(\s+)(\w+)\s*=\s*(.+?),(\s*--.*)?$/;
        my ($ind, $key, $val, $cmt) = ($1, $2, $3, $4 // '');
        next if grep { $_ eq $key } @keep;
        next unless exists $ini{$key};
        my $iv = $ini{$key};
        my $quoted = $val =~ /^"(.*)"$/; my $bare = $quoted ? $1 : $val;
        next if $bare eq $iv;
        next if $bare =~ /^-?[\d.]+$/ && $iv =~ /^-?[\d.]+$/ && abs($bare - $iv) < 1e-6;
        next if !$quoted && $iv !~ /^-?[\d.]+$/;              # a number default must stay a number
        my $nv = $quoted ? "\"$iv\"" : $iv;
        my $old = quotemeta($line);
        my $rep = "$ind$key = $nv,$cmt";
        $new =~ s/^$old$/$rep/m and do { print "  global $key: $val -> $nv\n"; $n++ };
    }
    $t =~ s/\Q$sBlock\E/$new/;
    print "globals baked: $n\n";
}
if ($dry) { print "(dry run: nothing written)\n"; exit 0 }
open my $o, '>', $lua or die "write $lua: $!"; print $o $t; close $o;
print "written: $lua\n";
