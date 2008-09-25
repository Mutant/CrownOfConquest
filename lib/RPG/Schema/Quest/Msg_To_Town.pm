package RPG::Schema::Quest::Msg_To_Town;

use base 'RPG::Schema::Quest';

use strict;
use warnings;

use RPG::Map;
use List::Util qw(shuffle);
use Data::Dumper;

sub set_quest_params {
    my $self = shift;
    
    my $town = $self->town;
    my $town_location = $town->location;
    
    my @towns_in_range;
    
    my $search_range = $self->{_config}{initial_search_range};
    
    while (! @towns_in_range) {	    
	    my ($start_point, $end_point) = RPG::Map->surrounds(
	    	$town_location->x,
	    	$town_location->y,
	    	$search_range,
	    	$search_range,
	    );
	    
	    @towns_in_range = $self->result_source->schema->resultset('Town')->search(
	    	{
	    		'location.x' => {'>=', $start_point->{x}, '<=', $end_point->{x}},
				'location.y' => {'>=', $start_point->{y}, '<=', $end_point->{y}},
				'town_id' => {'!=', $town->id},
	    	},
	    	{
	    		join => 'location',
	    	},
	    );

		# Increase the search range (if we haven't found anything)
	    $search_range+=2;
    }
    
    @towns_in_range = shuffle @towns_in_range;
    
    $self->define_quest_param('Town To Take Msg To', $towns_in_range[0]->id);
    $self->define_quest_param('Been To Town', 0);    
}

sub gold_value {
	my $self = shift;
	
	return 100;
}

sub xp_value {
	my $self = shift;
	
	return $self->type->xp_value;	
}

sub check_action {
	my $self = shift;
	my $party = shift;
	my $action = shift;
	
	return 0 unless $action eq 'townhall_visit';
	
	return 0 if $self->param_current_value('Been To Town') == 1;
	
	return 0 unless $party->location->town->id == $self->param_start_value('Town To Take Msg To');

	my $quest_param = $self->param_record('Been To Town');
	$quest_param->current_value(1);
	$quest_param->update;
	
	return 1;
}

sub ready_to_complete {
	my $self = shift;
	
	return $self->param_current_value('Been To Town');
}
	
sub town_to_take_msg_to {
	my $self = shift;
	
	return $self->result_source->schema->resultset('Town')->find($self->param_start_value('Town To Take Msg To'));
}

1;