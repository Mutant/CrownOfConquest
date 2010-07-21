package RPG::Combat::MagicalDamage;

use strict;
use warnings;

use Games::Dice::Advanced;

use RPG::Combat::MagicalDamage::Ice;
use RPG::Combat::MagicalDamage::Fire;
use RPG::Combat::MagicalDamage::Poison;

sub opponent_resisted {
	my $self = shift;
	my $opponent = shift;
	my $type = shift;
	
	my %resistences = $opponent->resistences;
	
	my $resistence = $resistences{$type} || 0;
		
	return Games::Dice::Advanced->roll('1d100') <= $resistence;
}

1;