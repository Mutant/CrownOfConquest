package RPG::Combat::MagicalDamage;

use strict;
use warnings;

use Games::Dice::Advanced;

use RPG::Combat::MagicalDamage::Ice;

sub opponent_resisted {
	my $self = shift;
	my $opponent = shift;
	my $type = shift;
	
	my %resistences = $opponent->resistences;
	
	my $resistence = $resistences{$type} || 0;
	
	return $resistence <= Games::Dice::Advanced->roll('1d100');
}

1;