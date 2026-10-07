use strict; use warnings;
# icons.pl <outdir> <README.md>: writes the pad button icons (SVG) and the README's Controls section
my ($out,$readme)=@ARGV; mkdir $out unless -d $out;
my ($bg,$fg,$edge)=('#3a3f47','#ffffff','#9aa3ad');
sub svg { my($name,$w,$body)=@_; open my $f,'>:raw',"$out/$name.svg" or die;
  print $f qq{<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="48" viewBox="0 0 $w 48" font-family="Segoe UI,Arial,Helvetica,sans-serif" font-weight="700" text-anchor="middle">$body</svg>\n}; close $f }
sub txt { my($x,$y,$s,$t,$c)=@_; $c||=$fg; qq{<text x="$x" y="$y" font-size="$s" fill="$c">$t</text>} }
my %arrow=(up=>'24,3 31,13 17,13', down=>'24,45 31,35 17,35', left=>'3,24 13,17 13,31', right=>'45,24 35,17 35,31');
for my $s ('L','R') {
  my $stick=qq{<circle cx="24" cy="24" r="21" fill="$bg" stroke="$edge" stroke-width="2"/><circle cx="24" cy="24" r="13" fill="#555c66" stroke="$edge" stroke-width="1.5"/>};
  svg("${s}S",48,$stick.txt(24,30,16,$s));
  for my $d (sort keys %arrow) { svg("${s}S-$d",48,$stick.txt(24,30,16,$s).qq{<polygon points="$arrow{$d}" fill="#ffd34d"/>}) }
  # a click: the stick with a bold ring and a down-press mark
  svg("${s}3",48,qq{<circle cx="24" cy="24" r="21" fill="$bg" stroke="#ffd34d" stroke-width="3"/><circle cx="24" cy="24" r="13" fill="#555c66" stroke="$edge" stroke-width="1.5"/>}.txt(24,29,14,"${s}3"));
  svg("${s}B",64,qq{<rect x="3" y="12" width="58" height="26" rx="11" fill="$bg" stroke="$edge" stroke-width="2"/>}.txt(32,31,16,"${s}B"));
  svg("${s}T",48,qq{<path d="M12 44 L12 20 Q12 4 24 4 Q36 4 36 20 L36 44 Z" fill="$bg" stroke="$edge" stroke-width="2"/>}.txt(24,32,15,"${s}T"));
}
svg('Y',48,qq{<circle cx="24" cy="24" r="20" fill="#2b2f36" stroke="#f2c230" stroke-width="3"/>}.txt(24,31,20,'Y','#f2c230'));
# any stick (drop-in go / hop crouch)
svg('stick-up',48,qq{<circle cx="24" cy="24" r="21" fill="$bg" stroke="$edge" stroke-width="2"/><circle cx="24" cy="24" r="13" fill="#555c66" stroke="$edge" stroke-width="1.5"/><polygon points="$arrow{up}" fill="#ffd34d"/>});

sub i { join ' ', map { my($n,$alt)=ref $_ ? @$_ : ($_,$_); qq{<img src="docs/buttons/$n.svg" alt="$alt" height="28">} } @_ }
my $P=' + '; my $OR=' &nbsp;or&nbsp; ';
my @rows=(
 ['Hippie jump', i(['LS-down','LS down']).$P.i('R3').$OR.i(['RS-down','RS down']).$P.i('L3')],
 ['Mini hippie jump', i('L3').$P.i('R3')],
 ['Spin in a hippie jump', i('LT').$OR.i('RT').' held in the air'],
 ['Grab, front hand', i('LB').$P.i('LS').' in the air'],
 ['Grab, back hand', i('RB').$P.i('RS').' in the air'],
 ['Two-hand grab', i('LB').$P.i('RB').' in the air'],
 ['No comply', i(['LS-down','LS down']).$P.i(['RS-left','RS left'])],
 ['Boneless', i('RB').$P.i(['LS-down','LS down']).$P.i(['RS-left','RS left'])],
 ['Bean plant', i('LB').$P.i(['LS-down','LS down']).$P.i(['RS-left','RS left'])],
 ['Rolling grab', i('RB').$OR.i('LB').' while riding'],
 ['Finger flip', i('RB').$OR.i('LB').' + a flip trick\'s flick'],
 ['Drop-in', i('Y').' at an edge, on foot, board in hand; then '.i(['stick-up','stick up']).' to go, '.i('LB').' / '.i('RB').' to step back, '.i('Y').' to step off'],
 ['Jump onto the board', i('L3').$OR.i('R3').' on foot next to the board'],
);
my $c="## Controls\n\nShown for a regular rider; riding goofy or switch the sticks swap as they do for the game's own tricks.\n\n| Trick | Input |\n|---|---|\n";
$c.="| $_->[0] | $_->[1] |\n" for @rows; $c.="\n";
open my $f,'<:raw',$readme or die; local $/; my $t=<$f>; close $f;
$t=~s/## Controls\n.*?(?=## Settings)/$c/s or die "no Controls section";
open $f,'>:raw',$readme or die; print $f $t; close $f; print "ok\n";
