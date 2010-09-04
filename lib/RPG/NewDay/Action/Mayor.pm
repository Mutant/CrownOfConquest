package RPG::NewDay::Action::Mayor;
use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;
use Games::Dice::Advanced;

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
			$mayor->hit_points($mayor->max_hit_points);
			$mayor->update;
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
		}
				
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

    	if ($town->peasant_state) {
    		$self->process_revolt($town);
    	}
    	else {
    		$self->check_for_revolt($town);
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
            as     => [ 'tax_collected', 'raids_today' ],
        }
    );   
	
	my $adjustment = - $party_town_rec->get_column('raids_today') * 3;
	$adjustment -= $party_town_rec->get_column('guaurds_killed');
		
	$adjustment += int $party_town_rec->get_column('tax_collected') / 100;
	$adjustment -= $town->peasant_tax - 3; # The -3 stops it trending down for npc mayors
	
 	my $creature_rec = $self->context->schema->resultset('Creature')->search(
		{
			'dungeon_room.dungeon_id' => $town->castle->id,
		},
		{
			join => ['type', {'creature_group' => {'dungeon_grid' => 'dungeon_room'}}],
			select => 'sum(type.level)',
			as => 'level_aggregate',
		}
	);
	
	$adjustment += int ($creature_rec->get_column('level_aggregate') / $town->prosperity);	
		
	# A random component to approval
	$adjustment += Games::Dice::Advanced->roll('1d11') - 6;

	$adjustment = -10 if $adjustment < -10;
	$adjustment =  10 if $adjustment >  10;
	
	$town->adjust_mayor_rating($adjustment);
	$town->update;
	
	$town->add_to_history(
		{
			type => 'income',
			value => $party_town_rec->get_column('tax_collected') || 0,
			message => 'Party Entrance Tax',
			day_id => $self->context->current_day->id,
		}
	);	

}

sub check_for_revolt {
	my $self = shift;
	my $town = shift;
	
	my $c = $self->context;
	
	return if $town->mayor_rating >= 0;
	
	my $rating = $town->mayor_rating + 100;
	
	my $roll = Games::Dice::Advanced->roll('1d100');
	
	if ($roll >= $rating) {
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
	    
	    $guard_bonus = int $guards_rec->get_column('level_aggregate') / 100;
	}
	
    my $prosp_penalty = int $town->prosperity / 10;

	$c->logger->debug("Checking for overthrow of mayor; guard bonus: $guard_bonus; prosp penalty: $prosp_penalty");

    my $roll = Games::Dice::Advanced->roll('1d100') + $guard_bonus - $prosp_penalty;
    
    $c->logger->debug("Overthrow roll: $roll");

    my $mayor = $town->mayor;
        
    if ($roll < 20) {
    	$mayor->mayor_of(undef);
    	$mayor->update;
    	
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
    	$town->update;
    	
    	if ($mayor->party_id) {
			$c->schema->resultset('Party_Messages')->create(
				{
					message => $mayor->character_name . " was overthown by the peasants of " . $town->town_name . " and is no longer mayor. " 
						. lcfirst $mayor->pronoun('subjective') . " has returned to the party in shame",
					alert_party => 1,
					party_id => $mayor->party_id,
					day_id => $c->current_day->id,
				}
			);
    	}
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

1;
