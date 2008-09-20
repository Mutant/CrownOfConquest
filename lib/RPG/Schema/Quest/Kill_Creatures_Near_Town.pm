package RPG::Schema::Quest::Kill_Creatures_Near_Town;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use Games::Dice::Advanced;

sub set_quest_params {
    my $self = shift;
    
    my $min_cgs = $self->{_config}{min_cgs_to_kill};
    my $max_cgs = $self->{_config}{max_cgs_to_kill};

	   
	my $number_of_creatures_to_kill = Games::Dice::Advanced->roll("1d" . ($max_cgs - $min_cgs + 1)) + $min_cgs - 1;
	$self->define_quest_param('Number Of Creatures To Kill', $number_of_creatures_to_kill);
	$self->define_quest_param('Range', $self->{_config}{range});

}

1;