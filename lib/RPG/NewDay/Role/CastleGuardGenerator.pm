package RPG::NewDay::Role::CastleGuardGenerator;

use Moose::Role;
use warnings;
use Carp;

use List::Util qw(shuffle);
use Games::Dice::Advanced;
use Array::Iterator::Circular;
use Data::Dumper;

sub generate_guards {
	my $self   = shift;
	my $castle = shift;

    return unless $castle;

	my $c = $self->context;

	my $town = $castle->town;
	
	$self->context->logger->debug("Generating guards for town " . $town->id);

	return unless $town;

	my @creature_types = $c->schema->resultset('CreatureType')->search(
		{
			'category.name' => 'Guards',
		},
		{
			join     => 'category',
			order_by => 'level',
		}
	);
	
	my $mayor = $castle->town->mayor;
	
	if (! $mayor || ! $mayor->party_id) {
		# If the mayor's an NPC, caclulate how many guards the town should hire now
		$self->calculate_guards_to_hire($town, \@creature_types);
	}

	# Get the list of guards currently in the castle
	my @creatures = $c->schema->resultset('Creature')->search(
		{
			'dungeon_room.dungeon_id' => $castle->id,
		},
		{
			prefetch => 'type',
			join => {'creature_group' => {'dungeon_grid' => 'dungeon_room'}},
		}
	);
	
	# Find out how many guards we should hire
	my %guards_to_hire = map { $_->creature_type_id => $_->amount } $self->context->schema->resultset('Town_Guards')->search(
		{
			town_id => $town->id,
		},
	);
	$self->context->logger->debug("Hiring guards: " . Dumper \%guards_to_hire);
			
	my %creature_types_by_id = map { $_->id => $_ } @creature_types;

	# Pay for guards
	my $total_cost = 0;
	foreach my $type_id (sort keys %guards_to_hire) {
		next if $guards_to_hire{$type_id} <= 0;
		
		my $cost = $guards_to_hire{$type_id} * $creature_types_by_id{$type_id}->hire_cost;
	
		if ($cost < $town->gold) {
			$self->context->logger->debug("Spending $cost gold on " . $creature_types_by_id{$type_id}->creature_type);
			$town->decrease_gold($cost);	
		}
		else {
			# Can't afford them all, just get as many as they can afford
			my $number_to_hire = int ($town->gold / $creature_types_by_id{$type_id}->hire_cost);
			$self->context->logger->debug("Could only afford to hire $number_to_hire " . $creature_types_by_id{$type_id}->creature_type);
			$guards_to_hire{$type_id} = $number_to_hire;
			$cost = $number_to_hire * $creature_types_by_id{$type_id}->hire_cost;
			$town->decrease_gold($cost);
		}

		$total_cost+=$cost;		
		$town->update;
	}
	
	$self->context->logger->debug("Total cost of guards: " . $total_cost);
	
	$town->add_to_history(
		{
			type => 'expense',
			value => $total_cost,
			message => 'Guard Wages',
			day_id => $c->current_day->id,
		}
	);
	
	# Record number of guards hired
	$self->record_guards_hired($town, %guards_to_hire);

	# Factor in any guards that already exist
	foreach my $creature (@creatures) {
		$guards_to_hire{$creature->creature_type_id}--;	
	}
	
	$self->context->logger->debug("Changes required: " . Dumper \%guards_to_hire);
	
	my $highest_level_type = $creature_types[$#creature_types];
	
	my $room_iterator = Array::Iterator::Circular->new($castle->rooms);	

	# Ressurect any guards that were killed
	map { $_->hit_points_current($_->hit_points_max); $_->update } @creatures;
	
	foreach my $type_id (sort keys %guards_to_hire) {
		my $last_cg;
		my $type = $creature_types_by_id{$type_id};
		
		# Add any guards that need to be added
		while ($guards_to_hire{$type_id} > 0) {
			my $random_sector = $c->schema->resultset('Dungeon_Grid')->find_random_sector( $castle->id, $room_iterator->next->id, 1 );
			
			last unless $random_sector;
		
			$last_cg ||= $c->schema->resultset('CreatureGroup')->create(
				{
					creature_group_id => undef,
					dungeon_grid_id   => $random_sector->id,
				}
			);

			$last_cg->add_creature( $type );
			
			$guards_to_hire{$type_id}--;
			
			undef $last_cg if $last_cg->number_alive >= 8;
		}
		
		my @creatures_of_type = grep { $_->creature_type_id == $type_id } shuffle @creatures;
				
		# Remove any guards
		while ($guards_to_hire{$type_id} < 0) {
			my $to_delete = shift @creatures_of_type;
						
			my $cg = $to_delete->creature_group;

			$to_delete->delete;
			
			if ($cg->number_alive == 0) {
				$cg->delete;	
			}
			
			$guards_to_hire{$type_id}++;
		} 
	}
	
	$self->generate_mayors_group($castle, $town, $mayor);
}

sub record_guards_hired {
    my $self = shift;
    my $town = shift;
    my %hires = @_;
    
    foreach my $type_id (keys %hires) {
		my $guards_to_hire = $self->context->schema->resultset('Town_Guards')->find_or_create(
			{
				town_id => $town->id,
				creature_type_id => $type_id,
			}
		);
		
		$guards_to_hire->amount_yesterday($hires{$type_id});
		$guards_to_hire->update;
    }
   
}

sub calculate_guards_to_hire {
	my $self = shift;
	my $town = shift;
	my $creature_types = shift;	

	my $levels_aggregate = $town->prosperity * 7;
	
	$levels_aggregate += int ($town->gold / 1000) * 40;
	
	my $max_level = int $town->prosperity / 2.5;
	$max_level = 6 if $max_level < 6;
		
	my $lowest_level = $creature_types->[0]->level;
	
	my %guards_to_hire;
	while ($levels_aggregate > $lowest_level) {
		my $type = ( shuffle @$creature_types )[0];
		
		next if $type->level > $max_level;
		
		$guards_to_hire{$type->id}++;
		
		$levels_aggregate -= $type->level;
	}
	
	foreach my $type_id (keys %guards_to_hire) {
		my $guards_to_hire = $self->context->schema->resultset('Town_Guards')->find_or_create(
			{
				town_id => $town->id,
				creature_type_id => $type_id,
			}
		);
		
		$guards_to_hire->amount($guards_to_hire{$type_id});
		$guards_to_hire->update;
	}
}

sub generate_mayors_group {
    my $self = shift;
    my $castle = shift;
    my $town = shift;
    my $mayor = shift;
    
    my $c = $self->context;
	
	# See if the mayor has a group (if there is one)
	return unless $mayor && $castle && $town;
	
	return if $mayor->is_dead;
	
	my $mayors_group;
	$mayors_group = $c->schema->resultset('CreatureGroup')->find(
		{
			'creature_group_id' => $mayor->creature_group_id,
		},
	) if $mayor->creature_group_id;
	
	unless ($mayors_group) {
	    $self->context->logger->debug("Mayor doesn't have a group - generating a new one");
	    
		my @groups = $c->schema->resultset('CreatureGroup')->search(
			{
				'dungeon_room.dungeon_id' => $castle->id,
			},
			{
				join => {'dungeon_grid' => 'dungeon_room'},
			}
		);
		
		if (@groups) {
			$mayors_group = (shuffle @groups)[0];			
		}
		else {
            $mayors_group = $c->schema->resultset('CreatureGroup')->create(
				{
					creature_group_id => undef,
				}
			);
		}

		$mayor->creature_group_id($mayors_group->id);
		$mayor->update;
				
		if (! $mayor->is_npc) {
		    # Record creature group of mayor
    		my $history_rec = $c->schema->resultset('Party_Mayor_History')->find(
                {
                    party_id => $mayor->party_id,
                    town_id => $town->id,
                    lost_mayoralty_day => undef,
                }
            );
            
            if ($history_rec) {
                $history_rec->creature_group_id($mayors_group->id);
                $history_rec->update;
            }
		}
    		      
		
        # Move the group into a sector away from the stairs
        unless ($mayors_group->in_combat) {
    		my $sector;
    		my $sector_rs = $castle->find_sectors_not_near_stairs(1);
    		
    		while ($sector = $sector_rs->next) {
                next if $sector->creature_group;
                last;
    		}
    		
    		if ($sector) {
                $mayors_group->dungeon_grid_id($sector->id);
                $mayors_group->update;
    		}
        }
	}
	
	# Ensure mayor's group has a sector. Could be that finding a sector not near stairs didn't give them one
	if (! $mayors_group->dungeon_grid_id) {
	    $self->context->logger->debug("Mayors CG does not have a sector in the castle - giving them one");
        my $random_sector = $c->schema->resultset('Dungeon_Grid')->find_random_sector( $castle->id, undef, 1 );
        $mayors_group->dungeon_grid_id($random_sector->id);
        $mayors_group->update; 
	}
	
	# Add any garrisoned chars into the group
	my @garrison_chars = $c->schema->resultset('Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
		}
	);
	
	foreach my $character (@garrison_chars) {
		$character->creature_group_id($mayors_group->id);
		$character->update;
	}	    
}

sub check_for_mayor_replacement {
    my $self = shift;
    my $town = shift;
    my $mayor = shift;
    
    my $c = $self->context;
    
	if ($mayor && $mayor->is_dead) {
        # Hmm, the mayor is dead. This can happen if the mayor is killed, but a party flees,
        #  or they party doesn't take over the mayoralty.
        $self->context->logger->debug("Mayor found dead - forcing generation of new one");
        $mayor->lose_mayoralty;
        undef $mayor; # Force new mayor to be generated
	}
	
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

1;
