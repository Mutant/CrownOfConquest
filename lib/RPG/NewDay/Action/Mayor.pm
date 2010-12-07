package RPG::NewDay::Action::Mayor;
use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;
use Games::Dice::Advanced;
use List::Util qw(sum);

with 'RPG::NewDay::Role::CastleGuardGenerator';

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Town RPG::NewDay::Action::Player/ }

sub run {
	my $self = shift;

	my $c = $self->context;

	my @towns = $c->schema->resultset('Town')->search(
		{},
		{
			prefetch => 'mayor',
		}
	);

	foreach my $town (@towns) {
		$self->context->logger->debug("Processing mayor for town " . $town->id); 
		
		# Reset tax modified flag
		$town->tax_modified_today(0);
		$town->update;
		
		my $mayor = $town->mayor;
		
		unless ( $mayor ) {
			$mayor = $self->create_mayor($town);
			$town->mayor_rating(0);
			$town->peasant_state(undef);
			$town->update;
			
			$c->schema->resultset('Town_History')->create(
                {
                    town_id => $town->id,
                    day_id  => $c->current_day->id,
                    message => $town->town_name . " doesn't have a mayor! " . $mayor->character_name . " is appointed by the King",
                }
            );
		}
		
		if ($mayor->is_dead && ! $town->pending_mayor) {
			$self->refresh_mayor($mayor);
		}
		
		if ($town->pending_mayor) {
			$self->check_for_pending_mayor_expiry($town);
		}
	
		if ($mayor->is_npc) {
			# Set default tax rates
			if ($town->peasant_tax < 8 || $town->peasant_tax > 15) {
				$town->peasant_tax(Games::Dice::Advanced->roll('1d8') + 7);
			}  
			
			$town->sales_tax(10);
			$town->base_party_tax(20);
			$town->party_tax_level_step(30);
			$town->update;
			
			$self->check_for_npc_election($town);
		}

		my $revolt_started = $self->check_for_revolt($town);
		
		if ($town->peasant_tax && ! $town->peasant_state) {
			my $gold = int ((Games::Dice::Advanced->roll('2d20') + $town->prosperity * 25) * ($town->peasant_tax / 100)) * 10;
			$self->context->logger->debug("Collecting $gold peasant tax");
			$town->increase_gold($gold);
			$town->update;
			
			$c->schema->resultset('Town_History')->create(
                {
                    town_id => $town->id,
                    day_id  => $c->current_day->id,
                    message => "The mayor collected $gold gold tax from the peasants",
                }
            );
            
			$town->add_to_history(
				{
					type => 'income',
					value => $gold,
					message => 'Peasant Tax',
					day_id => $c->current_day->id,
				}
			); 
		}

    	$self->generate_guards($town->castle);
		
		$self->calculate_approval($town);

		$self->check_if_election_needed($town);

    	if (! $revolt_started && $town->peasant_state) {
    		$self->process_revolt($town);
    	}
	}
	
	# Clear all tax paid / raids today
    $c->schema->resultset('Party_Town')->search->update( { tax_amount_paid_today => 0, raids_today => 0, guards_killed => 0 } );	
}

sub create_mayor {
	my $self = shift;
	my $town = shift;
	
	my $c = $self->context;
	
	my $mayor_level = int $town->prosperity / 4;
	$mayor_level = 8  if $mayor_level < 8;
	$mayor_level = 20 if $mayor_level > 20;

	my $character = $c->schema->resultset('Character')->generate_character(
		allocate_equipment => 1,
		level              => $mayor_level,
	);

	$character->mayor_of( $town->id );
	$character->update;
	
	return $character;
}

sub calculate_approval {
	my $self = shift;
	my $town = shift;
	
    my $party_town_rec = $self->context->schema->resultset('Party_Town')->find(
        { town_id => $town->id, },
        {
            select => [ { sum => 'tax_amount_paid_today' }, { sum => 'raids_today' }, {sum => 'guards_killed'} ],
            as     => [ 'tax_collected', 'raids_today', 'guards_killed' ],
        }
    );   

    my $raids_today = $party_town_rec->get_column('raids_today') // 0;
    my $guards_killed = $party_town_rec->get_column('guards_killed') // 0;
    my $tax_collected = $party_town_rec->get_column('tax_collected') // 0;

	my $raids_adjustment = - $raids_today * 3;
	my $guards_killed_adjustment = - $guards_killed;
		
	my $party_tax_adjustment = int $tax_collected / 100;
	my $peasant_tax_adjustment = - $town->peasant_tax / 2; # The -3 stops it trending up for npc mayors
	
 	my $creature_rec = $self->context->schema->resultset('Creature')->find(
		{
			'dungeon_room.dungeon_id' => $town->castle->id,
		},
		{
			join => ['type', {'creature_group' => {'dungeon_grid' => 'dungeon_room'}}],
			select => 'sum(type.level)',
			as => 'level_aggregate',			
		}
	);

	my $creature_level = $creature_rec->get_column('level_aggregate') || 0;	
	$self->context->logger->debug("Level aggregate: " . $creature_level);
	my $guards_hired_adjustment = int ($creature_level / $town->prosperity);	
		
	# A random component to approval
	my $random_adjustment += Games::Dice::Advanced->roll('1d11') - 6;
	
	my $adjustment = $raids_adjustment + $guards_killed_adjustment + $party_tax_adjustment + 
		$peasant_tax_adjustment + $guards_hired_adjustment + $random_adjustment;

	$adjustment = -10 if $adjustment < -10;
	$adjustment =  10 if $adjustment >  10;
	
	$self->context->logger->debug("Approval rating adjustment: $adjustment " .
		"[Raid: $raids_adjustment; Guards Killed: $guards_killed_adjustment; Guards Hired: $guards_hired_adjustment; " . 
		"Party Tax: $party_tax_adjustment; Peasant Tax: $peasant_tax_adjustment; Random: $random_adjustment]");
	
	$town->adjust_mayor_rating($adjustment);
	$town->update;
	
	$town->add_to_history(
		{
			type => 'income',
			value => $tax_collected,
			message => 'Party Entrance Tax',
			day_id => $self->context->current_day->id,
		}
	);	

}

sub check_for_revolt {
	my $self = shift;
	my $town = shift;
	
	return if $town->peasant_state eq 'revolt';
	
	my $c = $self->context;
	
	my $start_revolt = 0;
	
	if ($town->mayor_rating < 0) {
		my $rating = $town->mayor_rating + 100;
	
		my $roll = Games::Dice::Advanced->roll('1d100');
		
		$start_revolt = 1 if $roll > $rating;
	}	
	elsif ($town->peasant_tax >= 35) {
		$start_revolt = 1;	
	}
		
	if ($start_revolt) {
		$town->peasant_state('revolt');
		$town->update;
		
		$town->add_to_history(
			{
				day_id  => $c->current_day->id,
            	message => "The peasants have had enough of being treated poorly, and revolt against the mayor!",
			}		
		);
		
		my $mayor = $town->mayor;
		
		unless ($mayor->is_npc) {
			$c->schema->resultset('Party_Messages')->create(
				{
					message => $mayor->character_name . " sends word that the peasants of " . $town->town_name . " have risen up in open rebellion",
					alert_party => 1,
					party_id => $mayor->party_id,
					day_id => $c->current_day->id,
				}
			);
		}		
	}
	
	return $start_revolt;
}

sub process_revolt {
	my $self = shift;
	my $town = shift;
	
	return unless $town->peasant_state eq 'revolt';
	
	my $c = $self->context;
	
	my $castle = $town->castle;
	my $guard_bonus = 0;
		
	if ($castle) {
		my $guards_rec = $self->context->schema->resultset('Creature')->find(
			{
				'dungeon_room.dungeon_id' => $town->castle->id,
			},
			{
				join => [{'creature_group' => {'dungeon_grid' => 'dungeon_room'}}, 'type' ],
				select => [{sum => 'type.level'}],
				as => 'level_aggregate',
			}
	    );
	    
	    $guard_bonus = int ($guards_rec->get_column('level_aggregate') // 0) / 100;
	}
	
    my $prosp_penalty = int $town->prosperity / 10;

	$c->logger->debug("Checking for overthrow of mayor; guard bonus: $guard_bonus; prosp penalty: $prosp_penalty");

    my $roll = Games::Dice::Advanced->roll('1d100') + $guard_bonus - $prosp_penalty;
    
    $c->logger->debug("Overthrow roll: $roll");

    my $mayor = $town->mayor;
        
    if ($roll < 20) {
    	$mayor->mayor_of(undef);
    	$mayor->creature_group(undef);
    	
    	my $new_mayor = $self->create_mayor($town);
    	
    	$town->add_to_history(
    		{
				day_id  => $c->current_day->id,
	            message => "The peasants overthrow Mayor " . $mayor->character_name . ". They replace " . $mayor->pronoun('objective') . ' with the ' .
	            	' much more agreeable ' . $new_mayor->character_name,
    		}
    	);
    	$town->mayor_rating(0);
    	$town->peasant_state(undef);
    	$town->last_election(undef);    	
    	$town->update;
    	    	    	
    	if ($mayor->party_id) {
    		$mayor->status('morgue');
			$mayor->status_context($town->id);
			$mayor->hit_points(0);
    		
			$c->schema->resultset('Party_Messages')->create(
				{
					message => $mayor->character_name . " was overthown by the peasants of " . $town->town_name . " and is no longer mayor. " 
						. ucfirst $mayor->pronoun('posessive-subjective') . " body has been interred in the town cemetery, and "
						. $mayor->pronoun('posessive') . " may be ressurrected there.",
					alert_party => 1,
					party_id => $mayor->party_id,
					day_id => $c->current_day->id,
				}
			);
    	}
    	$mayor->update;
    }
    elsif ($roll > 80) {
    	$town->increase_mayor_rating(19);
    	$town->peasant_state(undef);
    	$town->update;

    	$town->add_to_history(
    		{
				day_id  => $c->current_day->id,
            	message => "Mayor " . $mayor->character_name . " and his guards crush the peasant rebellion. The troublemakers are taken out back and given " .
            		"a stern talking to",
    		}
    	);
    	
    	if ($mayor->party_id) {
			$c->schema->resultset('Party_Messages')->create(
				{
					message => $mayor->character_name . " reports " . lcfirst $mayor->pronoun('subjective') . "'s successfully crushed the peasant rebellion in"
						. $town->town_name,
					alert_party => 1,
					party_id => $mayor->party_id,
					day_id => $c->current_day->id,
				}
			);
    	}    	
    }
    else {
    	$town->add_to_history(
    		{
				day_id  => $c->current_day->id,
            	message => "The peasants are still in revolt!",
    		}
    	);
    }    
}

sub check_for_pending_mayor_expiry {
	my $self = shift;
	my $town = shift;
	
	# See if the pending mayor's been waiting for too long to accept mayoralty
	if (DateTime->compare($town->pending_mayor_date, DateTime->now()->subtract( hours => 24 )) == -1) {
		$town->pending_mayor(undef);
		$town->pending_mayor_date(undef);
		$town->update;
	}	
}

sub refresh_mayor {
	my $self = shift;
	my $mayor = shift;
		
	$mayor->hit_points($mayor->max_hit_points);
	$mayor->update;
	
	# Mayor gets items auto-repaired, and ammo stocked up
	my @items = $mayor->items;
	foreach my $item (@items) {
		next unless $item->equipped;
		
		if (my $variable = $item->variable_row('Durability')) {
			$variable->item_variable_value($variable->max_value);
			$variable->update;
		}
				
		if ($item->item_type->category->item_category eq 'Ranged Weapon') {
			my @ammo = $mayor->ammunition_for_item($item);
			
			my $total_ammo = (sum map { $_->quantity } @ammo) // 0;
			
			if ($total_ammo < 100) {
				# Create some more ammo
				my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;
				
				my $new_ammo = $self->context->schema->resultset('Items')->create(
					{
						item_type_id => $ammunition_item_type_id,
						character_id => $mayor->id,
					},
				);
				
				$new_ammo->variable( 'Quantity', 200 );
			}
		}
	}	
}

sub check_for_npc_election {
	my $self = shift;
	my $town = shift;
	
	return if $town->current_election || ! $town->mayor;
		
	return unless Games::Dice::Advanced->roll('1d100') <= 1;
	
	my $days = Games::Dice::Advanced->roll('1d11') + 4;
	
	$self->context->logger->debug("NPC Mayor in town " . $town->id . " schedules election for $days days time");
	$self->context->schema->resultset('Election')->schedule( $town, $days );		
}

sub check_if_election_needed {
	my $self = shift;
	my $town = shift;
	
	return unless $town->last_election;
	
	my $days_since_last_election = $self->context->current_day->day_number - $town->last_election;
	
	if ($days_since_last_election >= 15 && $days_since_last_election % 3 == 0) {
		$town->decrease_mayor_rating(10);
		$town->update;
		
    	$town->add_to_history(
    		{
				day_id  => $self->context->current_day->id,
	            message => "There hasn't been an election in $days_since_last_election days! The peasants demand their right to vote be honoured",
    		}
    	);		
	}	
}

1;
