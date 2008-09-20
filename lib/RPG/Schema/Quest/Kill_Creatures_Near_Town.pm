package RPG::Schema::Quest::Kill_Creatures_Near_Town;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use Games::Dice::Advanced;
use RPG::Map;

sub set_quest_params {
    my $self = shift;
    
    my $min_cgs = $self->{_config}{min_cgs_to_kill};
    my $max_cgs = $self->{_config}{max_cgs_to_kill};

	   
	my $number_of_creatures_to_kill = Games::Dice::Advanced->roll("1d" . ($max_cgs - $min_cgs + 1)) + $min_cgs - 1;
	$self->define_quest_param('Number Of Creatures To Kill', $number_of_creatures_to_kill);
	$self->define_quest_param('Range', $self->{_config}{range});
}

# Returns the range of sectors creatures must be killed within
sub sector_range {
	my $self = shift;
	
	my $size = $self->param_start_value('Range') * 2 + 1;
	
	my $town_sector = $self->town->location;
	
	return RPG::Map->surrounds(
		$town_sector->x,
		$town_sector->y,
		$size,
		$size,
	);
}

sub gold_value {
	my $self = shift;
	
	return $self->{_config}{gold_per_cg} * $self->param_start_value('Number Of Creatures To Kill');
}

1;