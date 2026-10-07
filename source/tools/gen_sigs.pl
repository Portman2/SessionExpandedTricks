use strict; use warnings;
# gen_sigs.pl <exe> <pdb> <symcache> <hn_main.cpp> <out hn_sigs.h>
# Makes the native half's signature table (hn_sigs.h) from the game exe it was written against (the one with the PDB):
# for every function RVA_* in hn_main.cpp, its first bytes with everything the linker moves wildcarded (rel32 of
# call / jmp / jcc, RIP-relative displacements and what follows them in the instruction), as long as it takes to be
# found exactly once in the exe. Look-alike functions are told apart by the function one of their calls goes to; a
# data address is decoded from an instruction in a function found the same way.
# Needs PdbDis.exe (the session-mod skill's tool) for the disassembly. Run it again after the game updates and the
# RVA_* constants in hn_main.cpp have been brought up to date.
my ($exe, $pdb, $cache, $src, $outf) = @ARGV; die "usage" unless $outf;
my $dis = "$ENV{USERPROFILE}/.claude/skills/session-mod/scripts/PdbDis.exe"; $dis =~ s/\\/\//g;
# data: name => [function rva, offset of the instruction in it, the address it must decode to]
my %DATA = ( RVA_REPLAY_MGR => [0xf57880, 0x34, 0x4fc3430] );      # ASkaterCameraActor::GetCustomizableCameraComponents: mov rcx, [AReplayManager::_instance]
# look-alikes: name => [offset of a call rel32 in it, the rva that call goes to]
my %TWIN = ( RVA_FTEXT_FROMNAME => [0x1f, 0x126d430] );
# look-alikes with nothing near to tell them apart (they differ three calls down, in a lambda): name => [which of the matches by address, how many matches there must be]
my %ORDER = ( RVA_SET_ANGVEL => [0, 2], RVA_SET_LINVEL => [1, 2] );
my %SKIP = map { $_ => 1 } qw(RVA_SKM_VT_FBT RVA_DEFAULT_QUERY);  # the vtable slot comes from the live mesh; DefaultQueryParam is not used
open my $h, '<', $src or die; my (@rv, %seen);
while (<$h>) { while (/\b(RVA_[A-Z0-9_]+)\s*=\s*0x([0-9a-fA-F]+)/g) { push @rv, [$1, hex($2)] unless $seen{$1}++ } }
close $h;
open my $e, '<:raw', $exe or die; my $img; { local $/; $img = <$e>; } close $e;
my $pe = unpack('V', substr($img, 0x3c, 4)); my $stamp = unpack('V', substr($img, $pe + 8, 4));
my ($nsec, $optsz) = (unpack('v', substr($img, $pe + 6, 2)), unpack('v', substr($img, $pe + 20, 2)));
my ($tRva, $tRaw, $tSize) = (0, 0, 0);
for my $s (0 .. $nsec - 1) { my $o = $pe + 24 + $optsz + $s * 40; next unless substr($img, $o, 5) eq '.text'; ($tSize, $tRva) = unpack('V2', substr($img, $o + 8, 8)); $tRaw = unpack('V', substr($img, $o + 20, 4)); }
die "no .text" unless $tRva;
sub ins_of { my $rva = shift; my $out = `"$dis" "$exe" "$pdb" "$cache" dis 0x${\ sprintf('%x', $rva)} 2>&1`;
    my ($sym) = $out =~ /^=== (\S+) RVA=/m; my @l;
    while ($out =~ /^\s+([0-9a-f]{6}) ([0-9a-f]+)\s+(.*)$/mg) { my ($o, $hx, $as) = ($1, $2, $3); push @l, [hex($o), [map { hex } $hx =~ /../g], $as] }
    return ($sym, \@l) }
sub mask_of { my ($b, $asm) = @_; my $k = @$b; my @m = (1) x $k;
    if ($asm =~ /^(call|jmp)\b/ && ($b->[0] == 0xE8 || $b->[0] == 0xE9) && $k == 5) { @m[1..4] = (0) x 4; return (\@m, 1) }
    if ($asm =~ /^j\w+/ && $b->[0] == 0x0F && $k == 6) { @m[2..5] = (0) x 4; return (\@m, 2) }
    # PdbDis prints a RIP-relative operand as its absolute target, "[0x4fc3430 <name>]" or "[0x4fc3430]": no register in the brackets
    if ($asm =~ /\[0x[0-9a-f]+(?: <[^\]]*)?\]/ && $k >= 6) { my $i = 1; $i++ while $i < $k - 4 && ($b->[$i] & 0xC7) != 0x05;
        if (($b->[$i] & 0xC7) == 0x05 && $i <= $k - 5) { @m[$i+1 .. $k-1] = (0) x ($k - $i - 1); return (\@m, $i + 1) } }
    # any other direct address in the text is the linker's too: keep the first byte only
    if ($asm =~ /0x[0-9a-f]{6,} </ && $k >= 5) { @m[1 .. $k-1] = (0) x ($k - 1); return (\@m, -1) }
    return (\@m, -1) }
sub build { my ($ins, $want, $must) = @_; my (@B, @M);
    for my $x (@$ins) { last if @B >= $want && @B >= $must; my ($m) = mask_of($x->[1], $x->[2]); push @B, @{$x->[1]}; push @M, @$m; }
    return (\@B, \@M) }
sub hits { my ($B, $M) = @_; my $re = join '', map { $M->[$_] ? quotemeta(chr $B->[$_]) : '.' } 0 .. $#$B; my @at;
    pos($img) = $tRaw; while ($img =~ /$re/sg) { my $p = $-[0]; last if $p >= $tRaw + $tSize; push @at, $p - $tRaw + $tRva; pos($img) = $p + 1; } @at }
sub rel32_at { my $rva = shift; my $p = $rva - $tRva + $tRaw; $rva + 4 + unpack('l', substr($img, $p, 4)) }
my (@tab, %help);
sub entry { my ($name, $rva, $isHelp) = @_;
    my ($frva, $site, $target) = $DATA{$name} ? @{$DATA{$name}} : ($rva, -1, 0);
    my ($sym, $ins) = ins_of($frva); die "$name: no code at " . sprintf('%x', $frva) unless $sym && @$ins;
    my ($dispAt, $insLen, $must, $callAt, $callee) = (0, 0, 0, -1, -1);
    if ($site >= 0) { my ($x) = grep { $_->[0] == $site } @$ins; die "$name: no instruction at +$site" unless $x; my (undef, $da) = mask_of($x->[1], $x->[2]); die "$name: site is not RIP-relative" if $da < 0;
        $dispAt = $da; $insLen = @{$x->[1]}; $must = $site + $insLen;
        my $got = $frva + $site + $insLen + unpack('l', pack('C4', @{$x->[1]}[$da .. $da + 3])); die sprintf("$name: decodes to %x, not %x", $got, $target) unless $got == $target; }
    if ($TWIN{$name}) { my ($co, $ct) = @{$TWIN{$name}}; $callAt = $co + 1; $must = $co + 5;
        die sprintf("$name: the call at +%x goes to %x, not %x", $co, rel32_at($frva + $callAt), $ct) unless rel32_at($frva + $callAt) == $ct;
        $help{$ct} //= entry(sprintf('HELP_%x', $ct), $ct, 1); $callee = $help{$ct}; }
    my ($B, $M, @at);
    for my $want (32, 40, 48, 64, 80, 96, 128, 160, 200, 256, 320, 400) { ($B, $M) = build($ins, $want, $must); @at = hits($B, $M); last if @at == 1; }
    my $n = @at; my $okk = ($n == 1); my ($rank, $count) = $ORDER{$name} ? @{$ORDER{$name}} : (-1, 0);
    if ($rank >= 0) { $okk = ($n == $count && $at[$rank] == $frva); }
    if ($callee >= 0) { my @right = grep { rel32_at($_ + $callAt) == $TWIN{$name}[1] } @at; $okk = (@right == 1 && $right[0] == $frva && $n <= 8); }
    die "$name: found at the wrong place" if $n == 1 && $at[0] != $frva && $rank < 0;
    printf "%-22s %-50.50s %3d bytes (%3d fixed) hits=%d %s\n", $name, $sym, scalar(@$B), scalar(grep { $_ } @$M), $n, $okk ? ($callee >= 0 ? '(told apart by its call)' : $rank >= 0 ? "(match $rank of $count by address)" : '') : '<-- NOT RESOLVED';
    push @tab, { name => $name, rva => $rva, sym => $sym, B => $B, M => $M, site => $site, dispAt => $dispAt, insLen => $insLen, ok => $okk, callAt => $callAt, callee => $callee, help => $isHelp, rank => $rank, count => $count };
    return $#tab }
for my $r (@rv) { my ($name, $rva) = @$r; next if $SKIP{$name}; entry($name, $rva, 0); }
my @bad = grep { !$_->{ok} } @tab;
open my $o, '>:raw', $outf or die; my $nl = "\r\n";
printf $o "// hn_sigs.h -- GENERATED by source/tools/gen_sigs.pl from the game exe with PE stamp %08x. Do not edit by hand.$nl", $stamp;
print $o "// The game functions the native half calls or hooks, as byte signatures: the first bytes of each with what the linker$nl// moves (rel32 of call / jmp / jcc, RIP-relative displacements and anything after them in the instruction) left out$nl// of the compare. On the exe this was made from each is found exactly once (look-alikes are told apart by where one$nl// of their calls goes). HnSigScan() in hn_main.cpp finds them in another build of the game.$nl";
print $o "#pragma once$nl#include <cstdint>$nl$nl";
printf $o "constexpr uint32_t kSigStamp = 0x%08x;$nl", $stamp;
print $o "#define HN_SIG_LIST(X) \\$nl", join(" \\$nl", map { sprintf("    X(%s, 0x%x)", $_->{name}, $_->{rva}) } grep { !$_->{help} } @tab), "$nl$nl";
print $o "#define HN_SIG_EXTERN(n, r) extern uintptr_t n;$nl", "HN_SIG_LIST(HN_SIG_EXTERN)$nl#undef HN_SIG_EXTERN$nl";
print $o "static uintptr_t $_->{name} = 0;                     // (a helper: only there to tell two look-alikes apart)$nl" for grep { $_->{help} } @tab;
print $o $nl;
for my $i (0 .. $#tab) { my $t = $tab[$i];
    printf $o "// %s  %s$nl", $t->{name}, $t->{sym};
    printf $o "static const uint8_t kSigB%d[] = { %s };$nl", $i, join(',', map { sprintf('0x%02x', $_) } @{$t->{B}});
    printf $o "static const uint8_t kSigM%d[] = { %s };$nl", $i, join(',', @{$t->{M}}); }
print $o "$nl// site >= 0: the address wanted is the target of the RIP-relative instruction at that offset (its disp32 at dispAt, its length insLen).$nl// callee >= 0: of several matches the one whose call (rel32 at callAt) goes to kSigs[callee] is taken.$nl// rank >= 0: there must be exactly `count` matches and the rank-th by address is taken (look-alikes that differ only far down their calls).$nl";
print $o "struct HnSig { const char* name; uintptr_t* rva; const uint8_t* b; const uint8_t* m; uint16_t n; int16_t site; uint8_t dispAt; uint8_t insLen; int16_t callAt; int16_t callee; int8_t rank; int8_t count; };$nl";
print $o "static const HnSig kSigs[] = {$nl";
for my $i (0 .. $#tab) { my $t = $tab[$i]; (my $short = $t->{name}) =~ s/^RVA_//;
    printf $o "    { \"%s\", &%s, kSigB%d, kSigM%d, %d, %d, %d, %d, %d, %d, %d, %d },$nl", $short, $t->{name}, $i, $i, scalar(@{$t->{B}}), $t->{site}, $t->{dispAt}, $t->{insLen}, $t->{callAt}, $t->{callee}, $t->{rank}, $t->{count}; }
print $o "};$nl", "constexpr int kSigN = (int)(sizeof(kSigs) / sizeof(kSigs[0]));$nl";
close $o;
printf "\n%d signatures (%d of them helpers) written to %s (stamp %08x); %d not resolved\n", scalar(@tab), scalar(grep { $_->{help} } @tab), $outf, $stamp, scalar(@bad);
exit(@bad ? 1 : 0);
