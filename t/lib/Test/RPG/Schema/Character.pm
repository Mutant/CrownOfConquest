use strict;
use warnings;

package Test::RPG::Schema::Character;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;
use Test::Exception;
use DateTime;

use Data::Dumper;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Item;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Creature;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Garrison;
use Test::RPG::Builder::Building;
use Test::RPG::Builder::Item_Type;

sub character_startup : Tests(startup => 1) {
    my $self = shift;

	$self->{dice} = Test::MockObject->new();
    $self->{dice}->fake_module( 'Games::Dice::Advanced', roll => sub { $self->{roll_result} || 0 }, );

    use_ok('RPG::Schema::Character');
}

sub character_shutdown : Tests(shutdown) {
	my $self = shift;
	
	$self->unmock_dice;
}

sub test_get_equipped_item : Tests(2) {
    my $self = shift;

    my $char = $self->{schema}->resultset('Character')->create(
        {

        }
    );

    my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );

    my ($equipped_item) = $char->get_equipped_item('Test1');

    isa_ok( $equipped_item, 'RPG::Schema::Items', "Item record returned" );
    is( $equipped_item->id, $item->id, "Correct item returned" );

}

sub test_get_equipped_item_multiple_items : Tests(2) {
    my $self = shift;

    my $char = $self->{schema}->resultset('Character')->create(
        {

        }
    );

    my $item1 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );
    $item1->equip_place_id(undef);
    $item1->update;
    my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $char->id, );

    my ($equipped_item) = $char->get_equipped_item('Test1');

    isa_ok( $equipped_item, 'RPG::Schema::Items', "Item record returned" );
    is( $equipped_item->id, $item2->id, "Correct item returned" );

}

sub test_defence_factor : Tests(1) {
    my $self = shift;

    # Given
    my $char = $self->{schema}->resultset('Character')->create( { agility => 2, } );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    my $item2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 0,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    my $item3 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        attributes          => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 3,
            }
        ],
    );

    # WHEN
    $char->discard_changes;
    my $df = $char->defence_factor;

    # THEN
    is( $df, 8, "Includes all equipped armour except the one that's damaged" );
}

sub test_number_of_attacks : Tests(15) {
    my $self = shift;

    my $mock_char = Test::MockObject->new();
    $mock_char->set_always( 'class', $mock_char );
    $mock_char->set_true('class_name');

    $mock_char->set_always( 'effect_value', 0.5 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 1, 1 ) ), 2, '2 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 1, 2 ) ), 1, '1 attacks allowed this round because of history', );

    $mock_char->set_always( 'effect_value', 0.33 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 1, 1 ) ), 2, '2 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 1 ) ), 1, '1 attacks allowed this round because of history', );

    $mock_char->set_always( 'effect_value', 1 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 7, 2 ) ), 2, '2 attacks allowed this round because of modifier', );

    $mock_char->set_always( 'effect_value', 1.5 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 2 ) ), 3, '3 attacks allowed this round because of modifier', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 3 ) ), 2, '2 attacks allowed this round because of modifier', );

    $mock_char->set_always( 'effect_value', 1.25 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 2, 3, 2, 2 ) ), 2, '2 attacks allowed this round because of history', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 3, 2, 2, 2 ) ), 3, '3 attacks allowed this round because of modifier', );
    
    $mock_char->set_always( 'effect_value', -1 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 0, 0 ) ), 0, '0 attacks allowed this round because of modifier', );    

    $mock_char->set_always( 'effect_value', -0.5 );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 0, 1 ) ), 0, '0 attacks allowed this round because of modifier', );
    is( RPG::Schema::Character::number_of_attacks( $mock_char, ( 1, 0 ) ), 1, '1 attacks allowed this round because of modifier', );

    # Test archer's extra attacks
    $mock_char->set_always( 'class_name', 'Archer' );
    my $mock_weapon = Test::MockObject->new();
    $mock_weapon->set_always( 'item_type',     $mock_weapon );
    $mock_weapon->set_always( 'category',      $mock_weapon );
    $mock_weapon->set_always( 'item_category', 'Ranged Weapon' );

    $mock_char->set_always( 'get_equipped_item', $mock_weapon );
    $mock_char->set_always( 'effect_value',      0 );

    is( RPG::Schema::Character::number_of_attacks($mock_char), 1, '1 attacks allowed for an archer', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, (2) ), 1, '1 attacks allowed for an archer', );

    is( RPG::Schema::Character::number_of_attacks( $mock_char, (1) ), 2, '2 attacks allowed for an archer', );
}

sub test_execute_defence_basic : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
    );

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is( $result, undef, "Does nothing if armour has no durability" );
}

sub test_execute_defence_decrement_durability : Tests(2) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 5,
            },
        ],
    );

    # Force decrement
    $self->{roll_result} = 1;

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is( $result, undef, "No message returned" );
    $item1->discard_changes;
    is( $item1->variable('Durability'), 4, "Durability decremented" );
}

sub test_execute_defence_armour_broken : Tests(3) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( {agility => 10} );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Armour',
        variables           => [
            {
                item_variable_name  => 'Durability',
                item_variable_value => 1,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Defence Factor',
                item_attribute_value => 2,
            }
        ],        
    );

    # Force decrement
    $self->{roll_result} = 1;

    # WHEN
    my $result = $char->execute_defence;

    # THEN
    is_deeply( $result, { armour_broken => 1 }, "Message returned to indicate broken armour" );
    $item1->discard_changes;
    is( $item1->variable('Durability'), 0, "Durability now 0" );
    
    $char->discard_changes;
    is($char->defence_factor, 10, "Defence factor of armour no longer included");
}

sub test_attack_factor_melee_weapon : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, } );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            },
            {
                item_attribute_name  => 'Back Rank Penalty',
                item_attribute_value => 3,
            }
        ],
    );

    # WHEN
    $char->discard_changes;
    my $af = $char->attack_factor;

    # THEN
    is( $af, 8, "Attack factor set correctly" );

}

sub test_attack_factor_ranged_weapon_with_upgrade : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, agility => 3 } );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        variables           => [
            {
                item_variable_name  => 'Attack Factor Upgrade',
                item_variable_value => 3,
            },
        ],
        attributes => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 2,
            }
        ],
    );
    $item->equip_place_id(2);
    $item->update;

    # WHEN
    $char->discard_changes;
    my $af = $char->attack_factor;

    # THEN
    is( $af, 8, "Attack factor set correctly" );

}

sub test_attack_factor_melee_weapon_from_back_rank : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, } );
    my $mock_char = Test::MockObject::Extends->new($char);
    $mock_char->set_false('in_front_rank');

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $mock_char->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            },
            {
                item_attribute_name  => 'Back Rank Penalty',
                item_attribute_value => 2,
            }
        ],        
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value => 0,
                max_value => 10,
            }
        ],
    );

    # WHEN
    $char->discard_changes;
    my $af = $mock_char->attack_factor;

    # THEN
    is( $af, 6, "Attack factor set correctly" );

}

sub test_attack_factor_broken_weapon : Tests(1) {
    my $self = shift;

    # GIVEN
    my $char = $self->{schema}->resultset('Character')->create( { strength => 5, } );

    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Melee Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Attack Factor',
                item_attribute_value => 3,
            },
            {
                item_attribute_name  => 'Back Rank Penalty',
                item_attribute_value => 2,
            }
        ],
        variables => [
            {
                item_variable_name => 'Durability',
                item_variable_value => 0,
                max_value => 10,
            }
        ],
    );

    # WHEN
    $char->discard_changes;
    my $af = $char->attack_factor;

    # THEN
    is( $af, 8, "Attack factor includes broken weapon" );

}

sub test_ammunition_for_item : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 5,
            
            },
        ]
    );
    
    my $ammo2 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 20,
            },
        ],        
    );
    
    $ammo2->update({item_type_id => $ammo1->item_type_id});
    
    my $weapon = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Ammunition',
                item_attribute_value => $ammo1->item_type_id,
            },
        ],
    );
    
    # WHEN
    my $ammo = $char->ammunition_for_item($weapon);
    
    # THEN
    my $expected = [
        {   
            id => $ammo1->id,
            quantity => 5,
        },
        {
            id => $ammo2->id,
            quantity => 20,            
        }
    ];
    
    is_deeply($ammo, $expected, "Expected result returned");
}

sub test_run_out_of_ammo_has_run_out : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 0,
            
            },
        ]
    );
    
    my $weapon = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Ammunition',
                item_attribute_value => $ammo1->item_type_id,
            },
        ],
    );    
    
    # WHEN
    my $run_out = $char->run_out_of_ammo;    
    
    # THEN
    is($run_out, 1, "Character has run out");
    
}

sub test_run_out_of_ammo_hasnt_run_out : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $char = Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $ammo1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Ammo',
        category_name       => 'Ammo',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value => 1,
            
            },
        ]
    );
    
    my $weapon = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        char_id             => $char->id,
        super_category_name => 'Weapon',
        category_name       => 'Ranged Weapon',
        attributes          => [
            {
                item_attribute_name  => 'Ammunition',
                item_attribute_value => $ammo1->item_type_id,
            },
        ],
    );    
    
    # WHEN
    my $run_out = $char->run_out_of_ammo;    
    
    # THEN
    is($run_out, 0, "Character has not run out");
    
}

sub test_level_up : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $today = $self->{stash}{today};

    my $next_level = $self->{schema}->resultset('Levels')->find(
        {
            level_number => 2,
        }
    );
    
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, level => 1, xp => $next_level->xp_needed - 20);
    
    $self->{config}{stat_points_per_level} = 3;
    $self->{config}{level_hit_points_max}{test_class} = 5;
    $self->{config}{point_dividend} = 10;
    
    # WHEN
    my $rolls = $character->xp($character->xp + 21);
    $character->update;
    
    # THEN
    $character->discard_changes;
    is($character->level, 2, "Character gone up a level");
    is($character->xp, $next_level->xp_needed + 1, "Character's xp increased");
    is($character->stat_points, 3, "Character given stat points");
    
    my @history = $character->history;
    is(scalar @history, 1, "1 item recorded in character history");
    is($history[0]->event, $character->character_name . " reached level 2", "Level up event recorded");
    is($history[0]->day_id, $today->id, "History event recorded on correct day");
}

sub test_check_for_auto_cast : Tests(10) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, last_action => DateTime->now->subtract( hours => 1 ));
	my $character = Test::RPG::Builder::Character->build_character($self->{schema});
	$character->party_id($party->id);
	$character->offline_cast_chance(50);
	$character->update;
	
	my $spell1 = $self->{schema}->resultset('Spell')->find( { spell_name => 'Energy Beam', } );
	my $spell2 = $self->{schema}->resultset('Spell')->find( { spell_name => 'Haste', } );
	
	my @tests = (
		{
			roll => 60,
			memorised_spells => [
				{
					spell_id => $spell1->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 1,
				}
			],
			expected_result => 0,
			label => 'Roll less than offline_cast_chance, no spell cast',
		},	
		{
			roll => 50,
			memorised_spells => [
				{
					spell_id => $spell1->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 1,
				}
			],
			expected_result => 1,
			label => 'Roll equal to offline_cast_chance, spell cast',
		},		
		{
			roll => 40,
			memorised_spells => [
				{
					spell_id => $spell1->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 1,
				},
				{
					spell_id => $spell2->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 0,
				},				
			],
			expected_result => 1,
			expected_spell => $spell1->id,
			label => 'Only cast spells marked to cast offline',
		},	
		{
			roll => 40,
			memorised_spells => [
				{
					spell_id => $spell1->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 1,
				},
				{
					spell_id => $spell2->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 1,
					cast_offline => 1,
				},				
			],
			expected_result => 1,
			expected_spell => $spell1->id,
			label => 'Only cast spells with casts left today',
		},	
		{
			roll => 40,
			memorised_spells => [
				{
					spell_id => $spell1->id,
					character_id => $character->id,
					memorised_today => 1,
					memorise_count => 1,
					number_cast_today => 0,
					cast_offline => 0,
				},		
			],
			expected_result => 0,
			label => 'Dont cast anything if no spells marked to cast offline',
		},							
	);
	
	$self->mock_dice;
	
	# WHEN
	my @results;
	foreach my $test (@tests) {
		$self->{schema}->resultset('Memorised_Spells')->delete;	
	
		foreach my $mem_spell (@{$test->{memorised_spells}}) {
			$self->{schema}->resultset('Memorised_Spells')->create($mem_spell);
		}
		$self->{roll_result} = $test->{roll};
		my $result = $character->check_for_auto_cast;
		push @results, $result;
	}
	
	# THEN
	my $count = 0;
	foreach my $test (@tests) {
		is($results[$count] ? 1 : 0, $test->{expected_result}, $test->{label});
		if ($results[$count]) {
			isa_ok($results[$count], 'RPG::Schema::Spell', "Result returned in a spell");	
		}		
		if ($test->{expected_spell}) {
			is($results[$count]->id, $test->{expected_spell}, "Spell returned as expected");	
		}
		$count++;
	}
	
}

sub test_stat_bonus : Tests(2) {
	my $self = shift;
	
	# GIVEN	
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, strength => 10, agility => 4);
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['stat_bonus'], no_equip_place => 1 );
	$item->variable_row('Stat Bonus', 'strength');	
	$item->variable_row('Bonus', 5);
	$item->equip_place_id(1);
	$item->update;
	
	$character->discard_changes;
	
	# WHEN
	my $str = $character->strength;
	my $agl = $character->agility;
	
	# THEN
	is($str, 15, "Bonus added to strength correctly");
	is($agl, 4, "No bonus added to agility");
}

sub test_cant_increase_hps_above_max : Tests(1) {
	my $self = shift;
	
	# GIVEN
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 10, max_hit_points => 20);
	
	# WHEN
	$character->hit_points(21);
	
	# THEN
	is($character->hit_points, 20, "Character's hps not increased above max");
}

sub test_name_of_mayor : Tests(1) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, name => 'Test1');
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $character->mayor_of($town->id);
    $character->update;
    
    # WHEN
    my $name = $character->name;
    
    # THEN
    is($name, "Test1, Mayor of Test Town", "Character's display name includes mayoralty");
}

sub test_name_of_king : Tests(1) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, name => 'Test1', gender => 'male');
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    $character->status('king');
    $character->status_context($kingdom->id);
    $character->update;
    
    # WHEN
    my $name = $character->name;
    
    # THEN
    is($name, "Test1, King of Test Kingdom", "Character's display name includes king");
}

sub test_name_of_queen : Tests(1) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, name => 'Test1', gender => 'female');
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema});
    $character->status('king');
    $character->status_context($kingdom->id);
    $character->update;
    
    # WHEN
    my $name = $character->name;
    
    # THEN
    is($name, "Test1, Queen of Test Kingdom", "Character's display name includes queen");
}

sub test_in_front_rank : Tests(4) {
    my $self = shift;  
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 4, rank_separator_position => 2);
    $party->adjust_order;
    
    my @chars = $party->search_related(
        'characters',
        {},
        {
            order_by => 'party_order',
        }
    );

    my %expected = (
        $chars[0]->id => 1,
        $chars[1]->id => 1,
        $chars[2]->id => 0,
        $chars[3]->id => 0,
    );
    
    # WHEN / THEN
    foreach my $char (@chars) {
        is($char->in_front_rank, $expected{$char->id}, "Character in correct rank");
    }
}

sub test_hit_basic : Tests(1) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 10, max_hit_points => 10);
    
    # WHEN
    $character->hit(7);
    
    # THEN
    is($character->hit_points, 3, "Character took damage");    
}

sub test_hit_character_killed_by_creature : Tests(3) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 10, max_hit_points => 10);  
    my $creature = Test::RPG::Builder::Creature->build_creature($self->{schema});
    
    # WHEN
    $character->hit(11, $creature);
    
    # THEN
    is($character->hit_points, 0, "Character took damage"); 
    my @history = $character->history;
    is(scalar @history, 1, "1 item added to history");
    is($history[0]->event, "test was slain by a Test Type");
}

sub test_hit_character_killed_by_character : Tests(3) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 7, max_hit_points => 10);  
    my $killer = Test::RPG::Builder::Character->build_character($self->{schema}, class => 'Archer');
    
    # WHEN
    $character->hit(7, $killer);
    
    # THEN
    is($character->hit_points, 0, "Character took damage"); 
    my @history = $character->history;
    is(scalar @history, 1, "1 item added to history");
    is($history[0]->event, "test was slain by an Archer");
}

sub test_hit_character_killed_by_effect : Tests(3) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 7, max_hit_points => 10);  
    
    # WHEN
    $character->hit(8, undef, 'poison');
    
    # THEN
    is($character->hit_points, 0, "Character took damage"); 
    my @history = $character->history;
    is(scalar @history, 1, "1 item added to history");
    is($history[0]->event, "test was slain by poison");
}

sub test_hit_killed_mayor : Tests(2) {
    my $self = shift;    
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 7, max_hit_points => 10);
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $character->mayor_of($town->id);
    $character->update;      
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});    
    my $killer = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
    
    # WHEN
    $character->hit(9, $killer);
    
    # THEN
    is($character->hit_points, 0, "Character took damage");
    
    $town->discard_changes;
    is($town->pending_mayor, $party->id, "Party set to pending mayor");
}

sub test_hit_killed_mayor_by_effect : Tests(2) {
    my $self = shift;    
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 7, max_hit_points => 10);
    my $town = Test::RPG::Builder::Town->build_town($self->{schema});
    $character->mayor_of($town->id);
    $character->update;      
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema});
    
    # WHEN
    $character->hit(9, $party, 'poison');
    
    # THEN
    is($character->hit_points, 0, "Character took damage");
    
    $town->discard_changes;
    is($town->pending_mayor, $party->id, "Party set to pending mayor");
}

sub test_get_item_action_usable_item : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
    my $item = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 1,
            }
        ],
        character_id => $character->id,
    );
    
    # WHEN
    my $action = $character->get_item_action($item->id);
    
    # THEN
    is($action->id, $item->id, "Item returned");        
}

sub test_get_item_action_enchantment : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day'], character_id => $character->id );
	my ($enchantment) = $item->item_enchantments;
	$enchantment->variable('Spell', 'Heal');
	$enchantment->variable_max('Casts Per Day', 2);
	$enchantment->variable('Spell Level', 3);	
    
    # WHEN
    my $action = $character->get_item_action($enchantment->id);
    
    # THEN
    is($action->id, $enchantment->id, "Enchantment returned");        
}

sub test_get_item_action_invaid : Tests(1) {
    my $self = shift;   
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema});
    
    # WHEN
    dies_ok( sub { $character->get_item_action(99) }, "Action doesn't exist");
        
}

sub test_get_item_actions : Tests(3) {
    my $self = shift;
    
    # GIVEN   
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 9, max_hit_points => 10);
    
    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        usable => 1,
        variables => [
            {
                item_variable_name => 'Quantity',
                item_variable_value  => 1,
            }
        ],
        character_id => $character->id,
    );    
    
	my $item2 = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day'], character_id => $character->id );
	my ($enchantment) = $item2->item_enchantments;
	$enchantment->variable('Spell', 'Heal');
	$enchantment->variable_max('Casts Per Day', 2);
	$enchantment->variable('Spell Level', 3);    
	
	my $item3 = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['spell_casts_per_day'] );
	
	my $item4 = Test::RPG::Builder::Item->build_item( $self->{schema}, enchantments => ['daily_heal'], character_id => $character->id );
	
	# WHEN
	my @actions = $character->get_item_actions(1);
	
	# THEN
	is(scalar @actions, 2, "2 actions found");
	
	my $action1 = $actions[0]->isa('RPG::Schema::Items') ? $actions[0] : $actions[1];
	
	is($action1->id, $item1->id, "Usable item returned");
	is($actions[1]->id, $enchantment->id, "Enchantment returned");    
}

sub test_critical_hit_chance : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, divinity => 10, level => 3);
    
    $self->{config}{character_divinity_points_per_chance_of_critical_hit} = 10;	
	$self->{config}{character_level_per_bonus_point_to_critical_hit} = 1;
	
	# WHEN
	my $chance = $character->critical_hit_chance;
	
	# THEN
	is($chance, 4, "Critical hit chance correct");
}

sub test_critical_hit_chance_with_eagle_eye : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $character = Test::RPG::Builder::Character->build_character($self->{schema}, divinity => 10, level => 3);
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Eagle Eye',
        }
    );
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $character->id,
            level => 5,
        }
    );    
    
    $self->{config}{character_divinity_points_per_chance_of_critical_hit} = 10;	
	$self->{config}{character_level_per_bonus_point_to_critical_hit} = 1;
	
	# WHEN
	my $chance = $character->critical_hit_chance;
	
	# THEN
	is($chance, 9, "Critical hit chance correct with eagle eye");
}

sub test_garrison_character_gets_bonus_in_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	
	my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	$character1->garrison_id($garrison->id);
	$character1->update;
	
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $party->id, owner_type => 'party' );
	
	# WHEN
    $character1->calculate_defence_factor;
    
    # THEN
    is($character1->defence_factor, 14, "Character has correct DF");
}

sub test_garrison_character_gets_building_bonus_when_moved_into_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	
	my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );

	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $party->id, owner_type => 'party' );
	
	# WHEN
	$character1->garrison_id($garrison->id);
	$character1->update;
    
    # THEN
    is($character1->defence_factor, 14, "Character has correct DF");   
}

sub test_garrison_character_loses_building_bonus_when_moved_out_of_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	
	my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
		
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $party->id, owner_type => 'party' );
	
	$character1->garrison_id($garrison->id);
	$character1->update;
	
	# WHEN
	$character1->garrison_id(undef);
	$character1->update;
    
    # THEN
    is($character1->defence_factor, 10, "Character has correct DF");   
}

sub test_mayor_gets_bonus_in_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );	
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[4]->id );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10, mayor_of => $town->id );

	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $town->id, owner_type => 'town' );
	
	# WHEN
    $character->calculate_defence_factor;
    
    # THEN
    is($character->defence_factor, 14, "Character has correct DF");
}

sub test_mayor_garrison_char_gets_bonus_in_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );	
	my $town = Test::RPG::Builder::Town->build_town($self->{schema}, land_id => $land[4]->id );
	my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10, 
	   status => 'mayor_garrison', status_context => $town->id );

	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $town->id, owner_type => 'town' );
	
	# WHEN
    $character->calculate_defence_factor;
    
    # THEN
    is($character->defence_factor, 14, "Character has correct DF");
}

sub test_garrison_character_gets_upgrade_bonus_in_building : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	
	my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, strength => 10, agility => 10 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	$character1->garrison_id($garrison->id);
	$character1->update;
	
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, land_id => $land[4]->id, owner_id => $party->id, owner_type => 'party' );
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Attack',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );	
	
	# WHEN
    $character1->calculate_attack_factor;
    
    # THEN
    is($character1->attack_factor, 14, "Character has correct AF");
}

sub test_calculate_resistance_bonuses_with_items : Tests(2) {
    my $self = shift;
    
    # GIVEN
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, constitution => 20);
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'resistances' ],
	);	

	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
			item_type_id => $item_type->id,
			character_id => $character->id,
		},
		{
			number_of_enchantments => 1,
		},
	);	
	$item->variable('Resistance Bonus', 3);
	$item->variable('Resistance Type', 'ice');
	$item->update;
	
	# WHEN
	$character->calculate_resistance_bonuses;
	$character->update;
	
	# THEN
	$character->discard_changes;
	is($character->resist_ice_bonus, 3, "Resist ice bonus increased");
	is($character->resistance('Ice'), 3, "Resistance to ice calculated correctly");       
}

sub test_calculate_resistance_bonuses_with_items_and_buildings : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema} );
    
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, constitution => 20);
	
	my $item_type = Test::RPG::Builder::Item_Type->build_item_type( 
		$self->{schema}, 
		enchantments => [ 'resistances' ],
	);	

	my $item = $self->{schema}->resultset('Items')->create_enchanted(
		{
			item_type_id => $item_type->id,
			character_id => $character->id,
		},
		{
			number_of_enchantments => 1,
		},
	);	
	$item->variable('Resistance Bonus', 3);
	$item->variable('Resistance Type', 'ice');
	$item->update;
	
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
	my $garrison = Test::RPG::Builder::Garrison->build_garrison( $self->{schema}, party_id => $party->id, land_id => $land[4]->id, );
	
	$character->garrison_id($garrison->id);
	$character->update;
	
	my $building = Test::RPG::Builder::Building->build_building( $self->{schema}, owner_id => $party->id, owner_type => 'party', land_id => $land[4]->id, );
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Protection',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );		
	
	# WHEN
	$character->calculate_resistance_bonuses;
	$character->update;
	
	# THEN
	$character->discard_changes;
	is($character->resist_ice_bonus, 7, "Resist ice bonus increased");
	is($character->resistance('Ice'), 7, "Resistance to ice calculated correctly");       
	
	is($character->resist_fire_bonus, 4, "Resist Fire bonus increased");
	is($character->resistance('Fire'), 4, "Resistance to Fire calculated correctly");  
	
	is($character->resist_poison_bonus, 4, "Resist Poison bonus increased");
	is($character->resistance('Poison'), 4, "Resistance to Poison calculated correctly");  	
}

1;
