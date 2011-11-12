use strict;
use warnings;

package Test::RPG::NewDay::Mayor;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use DateTime;

use Test::MockObject::Extends;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Dungeon;

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;
}

sub startup : Test(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::NewDay::Action::Mayor');
	
	$self->mock_dice;	
	
} 

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	undef $self->{roll_result};
	$self->unmock_dice;	
}

sub test_process_revolt_overthrow : Tests(7) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 20;
	
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->peasant_state('revolt');
	$town->update;	
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	$character->mayor_of($town->id);
	$character->update;
	
	my $garrison_character = Test::RPG::Builder::Character->build_character($self->{schema});
	$garrison_character->status('mayor_garrison');
	$garrison_character->status_context($town->id);
	$garrison_character->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	$self->{config}{level_hit_points_max}{test_class} = 6;
	
	# WHEN
	$action->process_revolt($town);
	
	# THEN
	$character->discard_changes;
	is($character->mayor_of, undef, "Character no longer mayor of town");
	
	$town->discard_changes;
	is($town->peasant_state, undef, "Peasants no longer in revolt");
	is($town->mayor_rating, 0, "Mayor approval reset");
	
	my $new_mayor = $self->{schema}->resultset('Character')->find(
		{
			mayor_of => $town->id,
		}
	);
	is(defined $new_mayor, 1, "New mayor generated");
	
	$garrison_character->discard_changes;
	is($garrison_character->status, 'morgue', "Garrison character placed in morgue");
	is($garrison_character->status_context, $town->id, "Garrsion character has correct status context");
	is($garrison_character->hit_points, 0, "Garrison character has 0 hps");
}

sub test_process_revolt_with_negotiation : Tests(1) {
	my $self = shift;
	
	# GIVEN
	$self->{roll_result} = 20;
	
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->peasant_state('revolt');
	$town->update;	
	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	$character->mayor_of($town->id);
	$character->update;
	
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Negotiation',
        }
    ); 
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $character->id,
            level => 10,
        }
    );
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	$self->{config}{level_hit_points_max}{test_class} = 6;
	
	# WHEN
	$action->process_revolt($town);
	
	# THEN
	$character->discard_changes;
	is(defined $character->mayor_of, 1, "Character still mayor of town due to negotaition bonus");	
}

sub test_check_for_pending_mayor_expiry : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, );
	$town->pending_mayor(1);
	$town->pending_mayor_date(DateTime->now()->subtract( hours => 24, seconds => 10 ));
	$town->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->check_for_pending_mayor_expiry($town);
	
	# THEN
	$town->discard_changes;
	is($town->pending_mayor, undef, "Pending mayor cleared");
	is($town->pending_mayor_date, undef, "Pending mayor date cleared");
}

sub test_refresh_mayor : Tests(5) {
	my $self = shift;
	
	# GIVEN
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 5, max_hit_point => 10 );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
	my $ammo_type = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
		variables => [{name => 'Quantity', create_on_insert => 1}],
	);
	my $ranged = Test::RPG::Builder::Item_Type->build_item_type( $self->{schema},
		category_name => 'Ranged Weapon',
		attributes => [{item_attribute_name => 'Ammunition', item_attribute_value => $ammo_type->id}]
	);
	my $item = Test::RPG::Builder::Item->build_item($self->{schema}, 
		item_type_id => $ranged->id, 
		char_id => $character->id,
		variables => [{item_variable_name=>'Durability', item_variable_value => 10, max_value => 100}],		
	);	
	my $ammo = Test::RPG::Builder::Item->build_item($self->{schema}, 
		item_type_id => $ammo_type->id, 
		char_id => $character->id,
	);		
	$ammo->variable('Quantity', 10);
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->refresh_mayor($character, $town);
	
	# THEN
	$character->discard_changes;
	is($character->hit_points, 10, "Mayor healed to full hit points");
	my @items = $character->items;
	is(scalar @items, 3, "Mayor now has 2 items");
	my ($new_ammo) = grep { $_->id != $item->id && $_->id != $ammo->id } @items;
	is($new_ammo->item_type_id, $ammo_type->id, "Ammo created with correct item type");
	is($new_ammo->variable('Quantity'), 200, "Quantity of ammo set correctly");
	
	$item->discard_changes;
	is($item->variable('Durability'), 100, "Weapon repaired");
}

sub test_refresh_mayor_dead_garrison_characters : Test(4) {
	my $self = shift;
	
	# GIVEN
	my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 300, character_heal_budget => 310 );
	my $char1 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
	my $char2 = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 2 );
	
	for my $char ($char1, $char2) {
    	$char->status('mayor_garrison');
    	$char->status_context($town->id);
    	$char->update;
	}
	
    my $hist_rec = $self->{schema}->resultset('Town_History')->create(
        {
            town_id => $town->id,
            type => 'expense',
            message => 'Town Garrison Healing',
            value => 10,
            day_id => $self->{mock_context}->current_day->id,
        }
    );	
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->refresh_mayor($mayor, $town);	
	
	# THEN  
	$char1->discard_changes;
	is($char1->hit_points, 1, "Character 1 ressurected");

	$char2->discard_changes;
	is($char2->hit_points, 1, "Character 2 ressurected");
	
	$town->discard_changes;
	is($town->gold, 0, "Town used up gold");
	
    $hist_rec->discard_changes;
    is($hist_rec->value, 310, "Cost of healing recorded");	
   
}

sub test_refresh_mayor_dead_garrison_characters_not_enough_budget : Test(2) {
	my $self = shift;
	
	# GIVEN
	my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 100, character_heal_budget => 100 );
	my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
	$char->status('mayor_garrison');
	$char->status_context($town->id);
	$char->update;
	
    my $hist_rec = $self->{schema}->resultset('Town_History')->create(
        {
            town_id => $town->id,
            type => 'expense',
            message => 'Town Garrison Healing',
            value => 10,
            day_id => $self->{mock_context}->current_day->id,
        }
    );	
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->refresh_mayor($mayor, $town);	
	
	# THEN  
	$char->discard_changes;
	is($char->hit_points, 0, "Character not resurrected");
	
	$town->discard_changes;
	is($town->gold, 100, "Town still has gold");
   
}

sub test_refresh_mayor_dead_garrison_characters_not_enough_gold : Test(2) {
	my $self = shift;
	
	# GIVEN
	my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema} );
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 90, character_heal_budget => 100 );
	my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, hit_points => 0, max_hit_points => 10, level => 1 );
	$char->status('mayor_garrison');
	$char->status_context($town->id);
	$char->update;
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	# WHEN
	$action->refresh_mayor($mayor, $town);	
	
	# THEN  
	$char->discard_changes;
	is($char->hit_points, 0, "Character not resurrected");
	
	$town->discard_changes;
	is($town->gold, 90, "Town still has gold");
   
}

sub test_generate_advice : Tests(2) {
	my $self = shift;
	
	# GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, advisor_fee => 50, gold => 20 );
	
	my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
	
	undef $self->{roll_result};
	
	# WHEN
	$action->generate_advice($town);
	
	# THEN
	my $advice = $self->{schema}->resultset('Town_History')->find(
	   {
	       town_id => $town->id,
	       type => 'advice',
	   }
	);
	is(defined $advice, 1, "Advice generated");
	
	$town->discard_changes;
	is($town->gold, 0, "Town gold reduced");
}

sub test_calculate_kingdom_tax : Tests(2) {
    my $self = shift;
    
    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema}, mayor_tax => 10, gold => 100 );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 1000, kingdom_id => $kingdom->id );
    
    my $day = $self->{mock_context}->current_day;
    
    $town->add_to_history(
		{
			type => 'income',
			value => 100,
			message => 'Income 1',
			day_id => $day->id,
		}        
    );

    $town->add_to_history(
		{
			type => 'income',
			value => 150,
			message => 'Income 2',
			day_id => $day->id,
		}        
    );
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->calculate_kingdom_tax($town);
    
    # THEN
    $town->discard_changes;
    is($town->gold, 975, "Town gold decreased");
    
    $kingdom->discard_changes;
    is($kingdom->gold, 125, "Kingdom gold increased");       
}

sub test_calculate_kingdom_tax_free_town : Tests(1) {
    my $self = shift;
    
    # GIVEN        
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, gold => 1000 );
    
    my $day = $self->{mock_context}->current_day;
    
    $town->add_to_history(
		{
			type => 'income',
			value => 100,
			message => 'Income 1',
			day_id => $day->id,
		}        
    );

    $town->add_to_history(
		{
			type => 'income',
			value => 150,
			message => 'Income 2',
			day_id => $day->id,
		}        
    );
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->calculate_kingdom_tax($town);
    
    # THEN
    $town->discard_changes;
    is($town->gold, 1000, "No tax paid, as this is a free town");    
    
}

sub test_check_for_allegiance_change : Tests(1) {
    my $self = shift;
    
    # GIVEN        
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom3 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => 10,
            $kingdom2->id => 20,
            $kingdom3->id => 30,
        }
     );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 5;
    
    # WHEN
    $action->check_for_allegiance_change($town);
    
    # THEN
    $town->discard_changes;
    is($town->location->kingdom_id, $kingdom3->id, "Allegiance of town changed");           
}

sub test_check_for_allegiance_change_negative_loyalty : Tests(1) {
    my $self = shift;
    
    # GIVEN        
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom3 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom4 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, active => 0);
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => -10,
            $kingdom2->id => -5,
        }
     );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 3;
    
    # WHEN
    $action->check_for_allegiance_change($town);
    
    # THEN
    $town->discard_changes;
    is($town->location->kingdom_id, $kingdom3->id, "Allegiance of town changed");           
}

sub test_check_for_allegiance_change_existing_kingdom_ok : Tests(1) {
    my $self = shift;
    
    # GIVEN        
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, kingdom_id => $kingdom1->id,
        kingdom_loyalty => {
            $kingdom1->id => 98,
            $kingdom2->id => 97,
        }
     );

    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    $self->{roll_result} = 3;
    
    # WHEN
    $action->check_for_allegiance_change($town);
    
    # THEN
    $town->discard_changes;
    is($town->location->kingdom_id, $kingdom1->id, "Allegiance of town not changed");           
}

sub test_caclulate_approval_basic : Tests(1) {
    my $self = shift;
    
    # GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle', land_id => $town->land_id);
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->calculate_approval($town);
    
    # THEN
    $town->discard_changes;
    is($town->mayor_rating, -4, "Mayor rating reduced");
           
}

sub test_caclulate_approval_mayoralty_changed : Tests(1) {
    my $self = shift;
    
    # GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle', land_id => $town->land_id);
    
    my $pmh = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            town_id => $town->id,
            got_mayoralty_day => $self->{mock_context}->yesterday->id,
            mayor_name => 'Mayor',
            character_id => $mayor->id,
            party_id => 1,
        }
    );
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->calculate_approval($town);
    
    # THEN
    $town->discard_changes;
    is($town->mayor_rating, 0, "Mayor rating unchanged");
           
}

sub test_caclulate_approval_with_charisma : Tests(1) {
    my $self = shift;
    
    # GIVEN
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    my $castle = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, type => 'castle', land_id => $town->land_id);
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Charisma',
        }
    );    
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $mayor->id,
            level => 4,
        }
    );    
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->calculate_approval($town);
    
    # THEN
    $town->discard_changes;
    is($town->mayor_rating, -2, "Mayor rating reduced");
           
}

sub test_collect_tax : Tests(6) {
    my $self = shift;
    
    # GIVEN    
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_tax => 10, gold => 0 );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    
    $self->{roll_result} = 20;
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->collect_tax($town, $mayor);  
    
    # THEN
    $town->discard_changes;
    is($town->gold, 770, "Tax collected");
    
    is($town->history->count, 2, "Messages added to town's history");
    my @history = $town->history;
    is($history[0]->message, "The mayor collected 770 gold tax from the peasants", "Correct town message");

    
    is($history[1]->type, "income", "Second history line records income");
    is($history[1]->value, "770", "Second history line records income value");
    is($history[1]->message, "Peasant Tax", "Second history line records income label");        
}

sub test_collect_tax_with_leadership : Tests(1) {
    my $self = shift;
    
    # GIVEN    
	my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 50, peasant_tax => 10, gold => 0 );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, mayor_of => $town->id );
    
    $self->{roll_result} = 20;
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Leadership',
        }
    );    
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $mayor->id,
            level => 5,
        }
    );      
    
    my $action = RPG::NewDay::Action::Mayor->new( context => $self->{mock_context} );
    
    # WHEN
    $action->collect_tax($town, $mayor);  
    
    # THEN
    $town->discard_changes;
    is($town->gold, 1270, "Tax collected"); 
}


1;
