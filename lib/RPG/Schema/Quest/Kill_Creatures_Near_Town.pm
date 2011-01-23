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
	
	$self->gold_value($self->{_config}{gold_per_cg} * $self->param_start_value('Number Of Creatures To Kill'));
	$self->xp_value($self->{_config}{xp_per_cg} * $self->param_start_value('Number Of Creatures To Kill'));
	my $days_to_complete = int $self->param_start_value('Number Of Creatures To Kill') / 2;
	$days_to_complete = 3 if $days_to_complete < 3;
	$self->days_to_complete($days_to_complete);
	$self->update;	
}

# Returns the range of sectors creatures must be killed within
#  Used by templates
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

sub check_action {
	my $self = shift;
	my $party = shift;
	my $action = shift;
	
	return 0 unless $action eq 'creature_group_killed';
	
	# Doesn't count if they're in a dungeon/castle
	return 0 if $party->dungeon_grid_id;
	
	return 0 if $self->param_current_value('Number Of Creatures To Kill') == 0;
	
	my $sector_in_range = RPG::Map->is_in_range(
		{
			x => $party->location->x,
			y => $party->location->y,
		},
		$self->sector_range,
	);
	
	if ($sector_in_range) {
		my $quest_param = $self->param_record('Number Of Creatures To Kill');
		$quest_param->current_value($quest_param->current_value-1);
		$quest_param->update;
		
		return 1;
	}
	
	return 0;
}

sub ready_to_complete {
	my $self = shift;
	
	return $self->param_current_value('Number Of Creatures To Kill') == 0 ? 1 : 0;
}

1;