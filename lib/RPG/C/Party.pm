package RPG::C::Party;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Data::JavaScript;

sub main : Local {
	my ($self, $c) = @_;
	
	my $panels = $c->forward('/panel/refresh', ['messages', 'map', 'party']);

    $c->forward('RPG::V::TT',
        [{
            template => 'party/main.html',
			params => {
				party  => $c->stash->{party},
				panels => $panels, 
			},
        }]
    );
}

sub sector_menu : Local {
    my ($self, $c) = @_;
    
	my $creature_group = $c->stash->{creature_group};
	
	unless ($creature_group) {
		$creature_group = $c->stash->{party_location}->creature_group
			if $c->stash->{party_location}->creature_group;
	}
	
	my $confirm_attack = 0;
	
	if ($creature_group) {
		$confirm_attack = $creature_group->level - $c->stash->{party}->level > $c->config->{cg_attack_max_level_diff};	
	}
    
    my $parties_in_sector = $c->forward('parties_in_sector');
    
    $c->forward('RPG::V::TT',
        [{
            template => 'party/sector_menu.html',
			params => {
				creature_group => $creature_group,
				confirm_attack => $confirm_attack,
				messages => $c->stash->{messages},
				day_logs => $c->stash->{day_logs},
				location => $c->stash->{party_location},
				parties_in_sector => $parties_in_sector,
			},
			return_output => 1,
        }]
    );
}

sub parties_in_sector : Private {
	my ($self, $c) = @_;
	
	my @parties = $c->model('DBIC::Party')->search(
		{
			party_id => {'!=', $c->stash->{party}->id},
			land_id  => $c->stash->{party_location}->id,
		},
		{},
	);
	
	return unless @parties;
	
    return $c->forward('RPG::V::TT',
        [{
            template => 'party/parties_in_sector.html',
			params => {
				parties => \@parties,
			},
			return_output => 1,
        }]
    );
}

sub list : Local {
    my ($self, $c) = @_;	
    
    my $party = $c->stash->{party};

    my @characters = $c->stash->{party}->characters;    
    
    my %spells;
    foreach my $character (@characters) {
    	my %search_criteria = (
    		memorised_today => 1,
    		number_cast_today => \'< memorise_count',
    		character_id => $character->id,
		);		
		
		$party->in_combat_with ? $search_criteria{'spell.combat'} = 1 : $search_criteria{'spell.non_combat'} = 1;
    	
    	my @spells = $c->model('Memorised_Spells')->search(
			\%search_criteria,
    		{
    			prefetch => 'spell',
    		},
    	);
    	$spells{$character->id} = \@spells if @spells;
    }    
    
    my @creatures = $c->stash->{creature_group} ? $c->stash->{creature_group}->creatures : ();
    
    return $c->forward('RPG::V::TT',
        [{
            template => 'party/party_list.html',
			params => {
                party => $party,
                characters => \@characters,
                combat_actions => $c->session->{combat_action},
                creatures => \@creatures,
                spells => \%spells,
			},
			return_output => 1,
        }]
    );
}

sub status : Local {
	my ($self, $c) = @_;	
    
    my $party = $c->stash->{party};
	
    $c->forward('RPG::V::TT',
        [{
            template => 'party/status.html',
			params => {
                party => $party,
			},
			return_output => 1,
        }]
    );	
}

sub swap_chars : Local {
	my ($self, $c) = @_;
	
	return if $c->req->param('target') == $c->req->param('moved');
	
	my %characters = map { $_->id => $_ } $c->stash->{party}->characters;
	
	# Moved char moves to the position of the target char
	my $moved_char_destination = $characters{ $c->req->param('target') }->party_order;
	my $moved_char_origin      = $characters{ $c->req->param('moved') }->party_order;
	
	# Is the moved char moving up or down?
	my $moving_up = $characters{ $c->req->param('moved') }->party_order > $moved_char_destination ? 1 : 0;

	# Move the rank separator if necessary.
	# We need to do this before adjusting for drop_pos
	my $sep_pos = $c->stash->{party}->rank_separator_position;
	#warn "moving_up: $moving_up, dest: $moved_char_destination, sep_pos: $sep_pos\n";
	if ($moving_up && $moved_char_destination <= $sep_pos) {
		#warn "updating sep_pos\n";
		$c->stash->{party}->rank_separator_position($sep_pos+1);
		$c->stash->{party}->update;
	}
	elsif (! $moving_up && $moved_char_destination >= $sep_pos) {
		$c->stash->{party}->rank_separator_position($sep_pos-1);
		$c->stash->{party}->update;
	}

	# If the char was dropped after the destination and we're moving up, the destination is decremented
	$moved_char_destination++ if $moving_up && $c->req->param('drop_pos') eq 'after';

	# If the char was dropped before the destination and we're moving down, the destination is incremented
	$moved_char_destination-- if ! $moving_up && $c->req->param('drop_pos') eq 'before';
	
	# Adjust all the chars' positions	
	foreach my $character (values %characters) {
		if ($character->id == $c->req->param('moved')) {
			$character->party_order($moved_char_destination);	
		}
		elsif ($moving_up) {
			next if $character->party_order < $moved_char_destination ||
				$character->party_order > $moved_char_origin;
				
			$character->party_order($character->party_order+1);
		}
		else {
			next if $character->party_order < $moved_char_origin ||
				$character->party_order > $moved_char_destination;
				
			$character->party_order($character->party_order-1);
		}
		
		$character->update;
	}
	

}

sub move_rank_separator : Local {
	my ($self, $c) = @_;
	
	my $target_char = $c->model('DBIC::Character')->find(
		{
			character_id => $c->req->param('target'),
		},
	);
	
	my $new_pos = $c->req->param('drop_pos') eq 'after' ? $target_char->party_order : $target_char->party_order-1;
	
	# We don't do anything if it's been dragged to the top. the GUI should prevent this from happening.
	return if $new_pos == 0; 
	
	$c->stash->{party}->rank_separator_position($new_pos);
	$c->stash->{party}->update;
}

sub camp : Local {
	my ($self, $c) = @_;
	
	my $party = $c->stash->{party};
	
	if ($party->turns >= RPG->config->{camping_turns}) {
		warn $party->turns;
		$party->turns($party->turns - RPG->config->{camping_turns});
		$party->rest($party->rest + 1);
		$party->update;
			
		$c->stash->{messages} = "The party camps for a short period of time";
	}
	else {
		$c->stash->{error} = "You don't have enough turns left today to camp";	
	}
	
	$c->forward('/panel/refresh', ['messages', 'party_status']);
}

sub select_action : Local {
	my ($self, $c) = @_;
	
	# If we're in combat, we don't handle the action here
	if ($c->stash->{party}->in_combat_with) {
		$c->detach('/combat/select_action');	
	}
	
	if ($c->req->param('action') eq 'Cast') {
		my $character = $c->model('DBIC::Character')->find(
			{
				character_id => $c->req->param('character_id'),
				party_id => $c->stash->{party}->id,
			}
		);		
		
		my $message = $c->forward('/magic/cast',
			[
				$character,
				$c->req->param('action_param'),
			],
		);
		
		$c->stash->{messages} = $message;
		
		$c->forward('/panel/refresh', ['messages', 'party_status', 'party']);	
	}
}

sub details : Local {
	my ($self, $c) = @_;
	
    # Check if new day message should be displayed
    my @day_logs = $c->model('DBIC::DayLog')->search(
    	{
    		'party_id' => $c->stash->{party}->id,
    	},
    	{
    		order_by => 'day.date_started desc',
    		prefetch => 'day',
    		rows => 7, # TODO: config me
    	},
    );

    $c->forward('RPG::V::TT',
        [{
            template => 'party/details.html',
			params => {
                party => $c->stash->{party},
                day_logs => \@day_logs,
			},
        }]
    );
}

sub scout : Local {
	my ($self, $c) = @_;
	
	my $party = $c->stash->{party};
	
	if ($party->turns < 1) {
		$c->stash->{error} = "You do not have enough turns to scout";
		$c->forward('/panel/refresh', ['messages']);
		return;
	}
	
	my $avg_int = $party->average_stat('intelligence');
	
	my $chance_to_scout = $avg_int * $c->config->{scout_chance_per_int};
	$chance_to_scout = $c->config->{max_chance_scout} if $chance_to_scout > $c->config->{max_chance_scout};
	
	my @creatures;
	
	if (Games::Dice::Advanced->roll('1d100') < $chance_to_scout) {
		# Scout was successful, see what monsters are about
		my ($start_point, $end_point) = RPG::Map->surrounds(
	    	$party->location->x,
	    	$party->location->y,
	    	3,
	    	3,
		);
		
		my $search_rs = $c->model('Land')->search(
			{
				x => {'>=', $start_point->{x}, '<=', $end_point->{x}},
				y => {'>=', $start_point->{y}, '<=', $end_point->{y}},
			},
			{
				prefetch => 'creature_group',
			},				    	
	    );
	    
	    while (my $sector = $search_rs->next) {	    
	    	next if $sector->x == $party->location->x && $sector->y == $party->location->y;
	    	if ($sector->creature_group) {
	    		push @creatures, $sector;	
	    	}
	    }	
	}

    $c->stash->{messages} = $c->forward('RPG::V::TT',
        [{
            template => 'party/scout_messages.html',
			params => {
            	creatures_scouted => \@creatures,
			},
			return_output => 1,
        }],
    );
    
    $party->turns($party->turns-1);
    $party->update;
	
	$c->forward('/panel/refresh', ['messages', 'party_status']);
}

sub new_party_message : Local {
	my ($self, $c) = @_;

    $c->forward('RPG::V::TT',
        [{
            template => 'party/complete.html',
            params => {
            	party => $c->stash->{party},
            	town => $c->stash->{party}->location->town,
        	},
    	}]
	);	
}

1;
