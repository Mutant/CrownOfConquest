package RPG::Schema::Party;

use Moose;

extends 'DBIx::Class';

use Data::Dumper;
use List::Util qw(sum shuffle);
use Math::Round qw(round);
use DateTime;
use Statistics::Basic qw(average);
use Carp;

use RPG::Template;
use RPG::Exception;
use RPG::DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Numeric Core/);
__PACKAGE__->table('Party');

__PACKAGE__->resultset_class('RPG::ResultSet::Party');

__PACKAGE__->add_columns(
    'party_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'party_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'player_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'player_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'land_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'land_id',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'name' => {
        'data_type'         => 'blob',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'name',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'gold' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'gold',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'turns' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'turns',
        'is_nullable'       => 0,
        'size'              => 0,
        'accessor'          => '_turns',
    },
    'in_combat_with' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'in_combat_with',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'rank_separator_position' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'rank_separator_position',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'rest' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'rest',
        'is_nullable'       => 0,
        'size'              => 0
    },
    'created' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'created',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'turns_used' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'turns_used',
        'is_nullable'       => 1,
        'size'              => 0,
    },
    'defunct' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'defunct',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'last_action' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'last_action',
        'is_nullable'       => 1,
        'size'              => 0
    },
    'dungeon_grid_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'dungeon_grid_id',
        'is_nullable'       => 0,
        'size'              => 0,
    },
    'flee_threshold' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'flee_threshold',
        'is_nullable'       => 0,
        'size'              => 0,
    },
    'combat_type' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'combat_type',
        'is_nullable'       => 0,
        'size'              => 255
    },  
    'kingdom_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'kingdom_id',
        'is_nullable'       => 1,
        'size'              => 0,
    },   
    'last_allegiance_change' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'last_allegiance_change',
        'is_nullable'       => 1,
        'size'              => 0,
    },          
    'warned_for_kingdom_co_op' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'warned_for_kingdom_co_op',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'description' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'description',
        'is_nullable'       => 1,
        'size'              => '5000'
    },     
);
__PACKAGE__->set_primary_key('party_id');

__PACKAGE__->has_many( 'characters', 'RPG::Schema::Character', 'party_id', );

__PACKAGE__->has_many( 'day_logs', 'RPG::Schema::DayLog', 'party_id', );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->belongs_to( 'cg_opponent', 'RPG::Schema::CreatureGroup', { 'foreign.creature_group_id' => 'self.in_combat_with' } );

__PACKAGE__->belongs_to( 'player', 'RPG::Schema::Player', { 'foreign.player_id' => 'self.player_id' } );

__PACKAGE__->has_many( 'quests', 'RPG::Schema::Quest', 'party_id', );

__PACKAGE__->has_many( 'party_battles', 'RPG::Schema::Battle_Participant', 'party_id', );

__PACKAGE__->has_many( 'party_effects', 'RPG::Schema::Party_Effect', 'party_id', );

__PACKAGE__->has_many( 'party_towns', 'RPG::Schema::Party_Town', 'party_id', );

__PACKAGE__->has_many( 'party_kingdoms', 'RPG::Schema::Party_Kingdom', 'party_id', );

__PACKAGE__->might_have( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

__PACKAGE__->belongs_to( 'kingdom', 'RPG::Schema::Kingdom', 'kingdom_id', { join_type => 'LEFT OUTER' } );

__PACKAGE__->belongs_to( 'last_allegiance_change_day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.last_allegiance_change' } );

__PACKAGE__->has_many( 'garrisons', 'RPG::Schema::Garrison', 
	{ 'foreign.party_id' => 'self.party_id' },
	{ where => {'land_id' => {'!=', undef}} }, 
);

__PACKAGE__->has_many( 'messages', 'RPG::Schema::Party_Messages', 'party_id', );

__PACKAGE__->has_many( 'mapped_sectors', 'RPG::Schema::Mapped_Sectors', 'party_id', );

# Can't use this for turns..
__PACKAGE__->numeric_columns(qw/gold/,
    rank_separator_position => {
        min_value => 1,
        max_value => 8,   
    }
); 

with qw/
	RPG::Schema::Role::BeingGroup
	RPG::Schema::Role::CharacterGroup
/;

sub members {
    my $self = shift;

    return $self->characters_in_party;
}

sub group_type {
	return 'party';	
}

sub display_name {
	my $self = shift;
	
	return $self->name;	
}

sub time_since_created {
    my $self = shift;
    
    return RPG::DateTime->time_since_datetime($self->created)
}

sub time_since_defunct {
    my $self = shift;
    
    return RPG::DateTime->time_since_datetime($self->defunct)
}

sub movement_factor {
    my $self = shift;

    my $base_mf;
    my @characters = $self->characters_in_party;
    foreach my $character (@characters) {
    	$base_mf +=	$character->movement_factor;
    }

    return round ($base_mf / scalar @characters);
}

sub mayors {
    my $self = shift;
    
    my @mayors = $self->search_related(
        'characters',
        {
            'mayor_of' => {'!=', undef},
        }
    );
    
    return @mayors;
}

around 'move_to' => sub {
    my $orig = shift;
    my $self = shift;
    my $land = shift;
    
    return unless $land;
    
    $self->$orig($land);
    
    return unless ( $land->isa('RPG::Schema::Land') );
    
    # Extra stuff for land move
    my @discovered = $self->discover_sectors($land);

    $self->turns( $self->turns - $land->movement_cost( $self->movement_factor, undef, $self->location ) );
    
    return @discovered;
};

sub discover_sectors {
    my $self = shift;
    my $land = shift;
    
    # Record any sectors party can now see
    my ($start, $end) = RPG::Map->surrounds_by_range(
        $land->x, $land->y, RPG::Schema->config->{party_viewing_range},
    );
    
    my $schema = $self->result_source->schema;
    
    my %mapped_sectors = map { $_->{location}{x} . ',' . $_->{location}{y} => 1} $schema->resultset('Mapped_Sectors')->find_in_range(
        $self->id,
        {
            x => $land->x,
            y => $land->y,
        },
        RPG::Schema->config->{party_viewing_range} * 2 + 1,
    );

    my @discovered;
    for my $x ($start->{x} .. $end->{x}) {
        for my $y ($start->{y} .. $end->{y}) {
            my $sector = "$x,$y";
            if (! $mapped_sectors{$sector}) {
                my $land = $schema->resultset('Land')->find(
                    {
                        x => $x,
                        y => $y,
                    }
                );
                
                next unless $land;
                
	            $self->add_to_mapped_sectors(
	                {
	                    land_id  => $land->id,
	                },
	            );
	            push @discovered, $sector;
            }
        }   
    }   
    
    return @discovered;
}

sub current_location {
	my $self = shift;
	
	return $self->location;
}

sub characters_in_party {
	my $self = shift;
	
	my %null_fields = map { $_ => undef } RPG::Schema::Character->in_party_columns;
	
	return $self->search_related('characters',
		\%null_fields,
		{
			'order_by' => 'party_order',
		},
	);
}

sub is_full {
	my $self = shift;
	
	return $self->characters_in_party->count >= RPG::Schema->config->{max_party_characters};	
}

sub characters_in_sector {
	my $self = shift;
	
	my @chars = $self->characters_in_party;
	
	my $garrison = $self->location->garrison;
	if ($garrison && $garrison->party_id == $self->id) {
		push @chars, $garrison->characters;
	}
	
	my $town = $self->location->town;
	my $mayor;
	if ($town and $mayor = $town->mayor and $mayor->party_id == $self->id) {
		push @chars, $mayor;
		
		my @garrison_chars = $self->search_related(
            'characters',
            {
                status => 'mayor_garrison',
                status_context => $town->id,
            }
        );
        push @chars, @garrison_chars;		
	}
	
	return @chars;		
}

# Record turns used whenever number of turns are decreased
sub turns {
    my $self      = shift;
    my $new_turns = shift;

    return $self->_turns unless defined $new_turns;

    if ( $new_turns > $self->_turns ) {
        die RPG::Exception->new(
            message => "Turns must be increased by calling increase_turns() method",
            type    => 'increase_turns_error',
        );
    }

    # Update the day's turns used
    my $turns_used = $self->_turns - $new_turns;

    # XXX: the turns used might not be 100% accurate, because two separate parties could read the same value from the day table, and commit their
    #  changes separately.
    my $day = $self->result_source->schema->resultset('Day')->find_today;
    
    confess "Can't find today" unless $day;
    
    $day->turns_used( ( $day->turns_used || 0 ) + $turns_used );
    $day->update;

    # No need to call update, since something else will call it to update the new turns value
    $self->turns_used( ( $self->turns_used || 0 ) + $turns_used );

    $self->_turns($new_turns);
}

sub increase_turns {
    my $self      = shift;
    my $new_turns = shift;

    return unless defined $new_turns;

    if ( $new_turns < $self->_turns ) {
        die RPG::Exception->new(
            message => "Turns must be decreased by calling turns() method",
            type    => 'increase_turns_error',
        );
    }
    
    my $original_turns = $self->_turns;
    
    # If they've (somehow) gone above the max turns, they can keep those extra turns, but aren't allowed
    #  any more (via this method)
    my $max_turns = $original_turns > RPG::Schema->config->{maximum_turns} ? $original_turns : RPG::Schema->config->{maximum_turns}; 

    $new_turns = $max_turns if $new_turns > $max_turns;

    $self->_turns($new_turns);
}

sub new_day {
    my $self    = shift;
    my $new_day = shift;

    my @log;    # TODO: should be a template

    foreach my $character ( $self->characters ) {
        next if $character->is_dead;

		my $rest = $character->garrison_id ? 3 : $self->rest;

        # Heal chars based on amount of rest they've had during the day
        if ( $rest != 0 ) {
        	my $percentage_to_heal = RPG::Schema->config->{min_heal_percentage} + $rest * RPG::Schema->config->{max_heal_percentage} / 10;
        	
            my $hp_increase = round $character->max_hit_points * $percentage_to_heal / 100;
            $hp_increase = 1 if $hp_increase == 0;    # Always a min of 1

            my $actual_increase = $character->change_hit_points($hp_increase);

            push @log, $character->name . " was rested, and healed " . $actual_increase . " hit points"
                if $actual_increase > 0;
        }

        # Memorise new spells for the day
        my $spell_count = $character->rememorise_spells();

        push @log, $character->name . " has $spell_count spells memorised"
            if $spell_count > 0;

        $character->update;
    }

    # They're no longer rested
    $self->rest(0);
    $self->update;

    $self->add_to_day_logs(
        {
            day_id => $new_day->id,
            log    => join( "\n", @log ),
        }
    );

    return;
}

sub number_alive {
    my $self = shift;
    
    my %null_fields = map { $_ => undef } RPG::Schema::Character->in_party_columns;

    return $self->result_source->schema->resultset('Character')->count(
        {
            hit_points => { '>', 0 },
            party_id   => $self->id,
            %null_fields,
        }
    );
}

# Adjust party order numbers to make sure they're contiguous
sub adjust_order {
    my $self = shift;

    my $count = 0;
    foreach my $character ( $self->characters_in_party ) {
        $character->discard_changes;
        next unless $character->in_storage && $character->party_id == $self->id;

        $count++;
        $character->party_order($count);
        $character->update;
    }
    
    # Reset rank bar if it's gone off edge of party
    if ($self->rank_separator_position >= $count) {    	
    	my $new_pos = $count-1;
    	$new_pos = 1 if $new_pos <= 0;
    	$self->rank_separator_position($new_pos);
    	$self->update;
    }
}

sub summary {
    my $self                    = shift;
    my $include_dead_characters = shift || 0;
    my @characters              = $self->characters_in_party;

    my %summary;

    foreach my $character (@characters) {
        next if !$include_dead_characters && $character->is_dead;
        $summary{ $character->class->class_name }++;
    }

    return \%summary;
}

sub in_combat {
    my $self = shift;

    return $self->in_combat_with || $self->in_party_battle;
}

sub in_party_battle {
    my $self = shift;

    return $self->_get_party_battle ? 1 : 0;
}

sub initiate_combat {
	my $self = shift;
	my $opponent = shift;
	
	$self->in_combat_with($opponent->id);
	$self->combat_type($opponent->group_type);
	$self->update;	
}

sub opponents {
	my $self = shift;
	
	my $opponents;
	
	my $schema = $self->result_source->schema;
	
	if ( $self->combat_type eq 'creature_group' ) {
		$opponents = $schema->resultset('CreatureGroup')->get_by_id( $self->in_combat_with );
	}
	elsif ( my $opponent_party = $self->in_party_battle_with ) {
		$opponents = $opponent_party;
	}
	elsif ( $self->combat_type eq 'garrison' ) {
		$opponents = $schema->resultset('Garrison')->find( 
		  {
		    garrison_id => $self->in_combat_with
		  } 
		);
	}
	
	return $opponents;
}

sub in_party_battle_with {
    my $self = shift;

    my $battle = $self->_get_party_battle;

    if ($battle) {
        my $battle_participant = $self->result_source->schema->resultset('Battle_Participant')->find(
            {
                party_id  => { '!=', $self->id },
                battle_id => $battle->battle->battle_id,
            },
            { prefetch => { 'party' => { 'characters' => 'character_effects' } }, },
        );

        return $battle_participant->party;
    }

    return;
}

sub _get_party_battle {
    my $self = shift;

    return $self->{_party_battle} if defined $self->{_party_battle};

    my $battle = $self->find_related( 'party_battles', { 'battle.complete' => undef, }, { prefetch => 'battle', } );

    $self->{_party_battle} = $battle;

    return $battle;
}

sub end_combat {
    my $self = shift;

    $self->in_combat_with(undef);
	$self->combat_type(undef);
	$self->update;

    my $party_battle = $self->_get_party_battle;

    if ($party_battle) {
        $party_battle->battle->update( { complete => DateTime->now() } );
        undef $self->{_party_battle};
    }
}

sub is_online {
    my $self = shift;
    
    return $self->last_action >= DateTime->now()->subtract( minutes => RPG::Schema->config->{online_threshold} ) ? 1 : 0;
}

sub quests_in_progress {
    my $self = shift;

    return $self->search_related( 'quests', { status => 'In Progress', } );
}

sub prestige_for_town {
    my $self = shift;
    my $town = shift;
    
    my $party_town = $self->find_related(
        'party_towns',
        {

            town_id  => $town->id,
        },
    );
    
    return $party_town ? $party_town->prestige : 0;    
}

sub has_overencumbered_character {
	my $self = shift;
	
	my @characters = $self->characters;
		
	my $over_encumbered_characters = grep { $_->is_overencumbered } @characters;
	
	return $over_encumbered_characters;	
}

sub allowed_more_quests {
	my $self = shift;
	
    my $party_quests_rs = $self->search_related(
    	'quests',
        {
            status   => 'In Progress',
        },
    );

    my $number_of_quests_allowed = RPG::Schema->config->{base_allowed_quests} + ( RPG::Schema->config->{additional_quests_per_level} * $self->level );

    return $party_quests_rs->count >= $number_of_quests_allowed ? 0 : 1;
}

# Called when party is disbanded or wiped out
sub disband {
	my $self = shift;
	
	$self->deactivate;
	
	# Remove any garrisons
	$self->search_related(
		'garrisons',
		{},
	)->update(
		{
			'land_id' => undef,
		}
	);
	
	# Remove any inn/morgue/street characters
	$self->search_related(
	   'characters',
	   {
	       status => ['inn','morgue','street'],
	   }
    )->update(
        {
            status => undef,
            status_context => undef,
        }
    );
}

# Deactivate party. Could just be they've got inactive, or called via disband()
sub deactivate {
    my $self = shift;
    
    $self->defunct( DateTime->now() );
    $self->in_combat_with( undef );
    
    # They lose any mayoralties
    my @mayors = $self->search_related('characters',
    	{
    		mayor_of => {'!=', undef},
    	},
    );
    
    foreach my $mayor (@mayors) {
        $mayor->lose_mayoralty;
    }
    
    if (my $kingdom = $self->kingdom) {
        $self->cancel_kingdom_quests($kingdom, 'the party has been disbanded');
        
        if ($kingdom->king && $kingdom->king->party_id == $self->id) {
            # They have the king. Make him/her an NPC
            my $king = $kingdom->king;
            $king->party_id(undef);   
            $king->update;
        }
    }
    
    $self->update;           
}

# Party was wiped out during combat
sub wiped_out {
    my $self = shift;
    
    # Some characters get deleted, depending on party level
    my $del_char_count = round $self->level / 8;
    $del_char_count = 1 if $del_char_count < 1;
    
    my @chars = shuffle $self->members;
    
    $del_char_count = scalar @chars-1 if $del_char_count >= scalar @chars;
   
    for (1..$del_char_count) {
        my $char = shift @chars;
        $char->status('wiped_out');
        $char->status_context($self->id);
        $char->party_id(undef);
        $char->update;
    }

    # If we couldn't delete any chars (due to party size of 1), they lose some equipment
    if ($del_char_count <= 0) {
        my $char = $chars[0];
        
        my @items = shuffle $char->search_related('items',
            {
                equip_place_id => {'!=', undef},
            }
        );
        
        $items[0]->delete if @items;
    }
    
    # One char gets auto-ressed
    $chars[0]->hit_points(1);
    $chars[0]->update;
    
    # Find a nearby town to respawn in
    my $party_loc = $self->location;
    
    my $town = $party_loc->town;
    
    if (! $town) {
        my @towns = shuffle $self->result_source->schema->resultset('Town')->find_in_range(
            {
                x => $party_loc->x,
                y => $party_loc->y,
            },
            9,
            3,
            1,
            31,
        );
        $town = $towns[0]; 
    }
    
    $self->land_id($town->land_id);
    $self->dungeon_grid_id(undef);
    $self->update;
}

#  This function consumes items that are possessed by the party.  Note that this sub will accept items that are
#    both individual items and those with 'Quantity'.
sub consume_items {
	my $self = shift;
	my $category = shift;
	my $secondary_group = shift;
    my %items_to_consume = @_;

	#  Get the party's equipment.	
	my @party_equipment = $self->get_equipment($category);
	push @party_equipment, $secondary_group->get_equipment($category)
	   if $secondary_group;

	#  Go through the items, decreasing the needed counts.
	my @items_to_consume;
	foreach my $item (@party_equipment) {
		if (defined $items_to_consume{$item->item_type->item_type} and $items_to_consume{$item->item_type->item_type} > 0) {
			my $quantity = $item->variable('Quantity') // 1;

			if ($quantity <= $items_to_consume{$item->item_type->item_type}) {
				$items_to_consume{$item->item_type->item_type} -= $quantity;
				$quantity = 0;
			} else {
				$quantity -= $items_to_consume{$item->item_type->item_type};
				$items_to_consume{$item->item_type->item_type} = 0;
			}
			push @items_to_consume, {
			    item => $item, 
			    quantity => $quantity
			};
		}
	}
	
	#  If any of the counts are non-zero, we didn't have enough of the item.
	foreach my $next_key (keys %items_to_consume) {
		if ($items_to_consume{$next_key} > 0) {
			return 0;
		}
	}
	
	#  We had enough resources, so decrement quantities and possibly delete the items.
	foreach my $to_consume (@items_to_consume) {
		if ($to_consume->{quantity} == 0) {
			$to_consume->{item}->delete;
		} else {
			my $var = $to_consume->{item}->variable_row('Quantity');
			$var->item_variable_value($to_consume->{quantity});
			$var->update;
		}
	}
	return 1;
}

#  Get an array of the buildings owned by this party.
sub get_owned_buildings {
	my $self = shift;

	#  Get a list of the currently built buildings for this party.
	my @existing_buildings = $self->result_source->schema->resultset('Building')->search(
        	{
	        	'owner_id' => $self->id,
	        	'owner_type' => 'party'
	        },
	        {
	            order_by => 'building_type.name',
				join     => [ 'building_type' ],
				prefetch => 'building_type',
	        },
	);
	return @existing_buildings;
}
	
# Return a hash of characters with broken items
sub broken_equipped_items_hash {
	my $self = shift;
	
	# See if any chars have broken weapons equipped
	my @broken_equipped_items = $self->result_source->schema->resultset('Items')->search(
		{
			'belongs_to_character.party_id' => $self->id,
			'equip_place_id'                => { '!=', undef },
			-and                            => [
				'item_variables.item_variable_value'    => '0',
				'item_variable_name.item_variable_name' => 'Durability',
			],
		},
		{
			join     => [ 'belongs_to_character', { 'item_variables' => 'item_variable_name', } ],
			prefetch => 'item_type',
		}
	);

	my %broken_items_by_char_id;
	foreach my $broken_item (@broken_equipped_items) {
		push @{ $broken_items_by_char_id{ $broken_item->character_id } }, $broken_item;
	}
	
	return %broken_items_by_char_id;
}

sub can_claim_land {
    my $self = shift;
    my $land = shift;
    
    return 0 unless $self->kingdom_id;
    
    return 0 unless $self->level >= RPG::Schema->config->{minimum_land_claim_level};
        
    return $land->can_be_claimed($self->kingdom_id);
}

sub days_since_last_allegiance_change {
    my $self = shift;
    
    my $change_day = $self->result_source->schema->resultset('Day')->find(
        {
            day_id => $self->last_allegiance_change,
        }
    );
    
    return $change_day->difference_to_today_str;   
}

sub change_allegiance {
    my $self = shift;   
    my $new_kingdom = shift;
    
    my $old_kingdom = $self->kingdom;
    
    if ($old_kingdom && $old_kingdom->active && defined $old_kingdom->king->party_id && $old_kingdom->king->party_id == $self->id) {
        croak "Cannot change allegiance if you already have your own kingdom\n";   
    }
    
    if ($new_kingdom) {
        my $party_kingdom = $new_kingdom->find_related(
            'party_kingdoms',
            {
                party_id => $self->id,
            }        
        );
        
        if ($party_kingdom && $party_kingdom->banished_for > 0) {
            croak "Can't change allegiance to a kingdom you are banned from\n";            
        }
    }
    	
    my $today = $self->result_source->schema->resultset('Day')->find_today;	
    
	$self->kingdom_id($new_kingdom ? $new_kingdom->id : undef);
	$self->last_allegiance_change($today->id);
	
	my $own_kingdom = $new_kingdom && $new_kingdom->king->party_id == $self->id ? 1 : 0;
	
	if (! $own_kingdom) {
    	my $message = RPG::Template->process(
    	   RPG::Schema->config,
            'party/allegiance_change.html',
            {
                old_kingdom => $old_kingdom,
                new_kingdom => $new_kingdom,
            },
        );
    	
    	$self->add_to_messages(
    	   {
    	       day_id => $today->id,
    	       alert_party => 0,
    	       message => $message,
    	   }
    	);
	}
	
    if ($old_kingdom) {
        $old_kingdom->add_to_messages(
            {
                day_id => $today->id,
                message => "The party known as " . $self->name . " renounced their loyalty to the kingdom",
                type => 'public_message',
            }
        );
        
        # Cancel any kingdom quests
        $self->cancel_kingdom_quests($old_kingdom);
	}
	
	if ($new_kingdom) {
	    # Reset loyalty
	    my $party_kingdom = $self->result_source->schema->resultset('Party_Kingdom')->find_or_create(
	       {
	           party_id => $self->id,
	           kingdom_id => $new_kingdom->id,
	       }
	    );
	    
	    $party_kingdom->loyalty(0);
	    $party_kingdom->update;
	    
        if (! $own_kingdom) {	   
            $new_kingdom->add_to_messages(
                {
                    day_id => $today->id,
                    message => "The party known as " . $self->name . " swore allegiance, and are now loyal to the kingdom",
                    type => 'public_message',
                }
            );
        }
        
        if ($new_kingdom->highest_party_count < $new_kingdom->parties->count) {
            $new_kingdom->highest_party_count($new_kingdom->parties->count);
            $new_kingdom->highest_party_count_day_id($today->id);
            $new_kingdom->update;
        } 
	}	
}

sub cancel_kingdom_quests {
    my $self = shift;
    my $kingdom = shift;
    my $reason = shift;
    
    my @kingdom_quests = $self->search_related(
        'quests',
        {
            kingdom_id => $kingdom->id,
            status => ['Not Started', 'In Progress'],
        }
    );
    
    foreach my $quest (@kingdom_quests) {
        my $kingdom_message = RPG::Template->process(
            RPG::Schema->config,
            'quest/kingdom/terminated.html',
             { 
                quest => $quest,
                reason => $reason // 'the party is no longer loyal to our kingdom',
             }
        );
        
        $quest->terminate(
            kingdom_message => $kingdom_message,
        );
        
        $quest->update;
    }       
}

sub loyalty_for_kingdom {
    my $self = shift;
    my $kingdom_id = shift;
    
    return $self->{_loyalty}{$kingdom_id} if defined $self->{_loyalty}{$kingdom_id};
    
    my $party_kingdom = $self->find_related(
        'party_kingdoms',
        {
            kingdom_id => $kingdom_id,
        }
    );
    
    unless ($party_kingdom) {
        $party_kingdom = $self->result_source->schema->resultset('Party_Kingdom')->create(
            {
                party_id => $self->id,
                kingdom_id => $kingdom_id,
            }
        );   
    }
    
    $self->{_loyalty}{$kingdom_id} = $party_kingdom->loyalty;
    
    return $self->{_loyalty}{$kingdom_id} // 0;   
}

sub banish_from_kingdom {
    my $self = shift;
    my $kingdom = shift;
    my $duration = shift;
    
    $self->kingdom_id(undef);
    $self->update;

    my $today = $self->result_source->schema->resultset('Day')->find_today;
    
    my $party_kingdom = $self->result_source->schema->resultset('Party_Kingdom')->find_or_create(
        {
            party_id => $self->id,
            kingdom_id => $kingdom->id,
        }
    );
    $party_kingdom->banished_for($duration);
    $party_kingdom->update;
    
    $self->cancel_kingdom_quests($kingdom);
   
    $self->add_to_messages(
        {
	       day_id => $today->id,
	       alert_party => 1,
	       message => "We were banished from the Kingdom of " . $kingdom->name . " for $duration days!",
        }
    );           
}

# Return a resultset of active quests of a given type
sub active_quests_of_type {
    my $self = shift;
    my $quest_type_name = shift;
    
    return $self->search_related(
        'quests', 
        { 
            'type.quest_type' => $quest_type_name,
            'status' => ['In Progress','Not Started','Requested'],
        },
        {
            join => 'type',
        }
   );
}

sub is_suspected_of_coop_with {
    my $self = shift;
    my $party = shift;
    
    return 0 unless $party;
    
    my $player1 = $self->player;
    my $player2 = $party->player;
    
    return 0 unless $player1 && $player2; 
    
    return $player1->has_ips_in_common_with($player2) ? 1 : 0;  
}

# Returns true if party has the king of the specified kingdom,
#  or their own kingdom, if it's not passed 
sub has_king_of {
    my $self = shift;
    my $kingdom = shift // $self->kingdom;
    
    return 0 unless $kingdom;
    
    return 1 if $kingdom->king->party_id == $self->id;
    
    return 0;
    
}

# Return the % of the world the party has explored
sub world_explored {
    my $self = shift;
    
    my $world_size = $self->result_source->schema->resultset('Land')->search->count;
    my $explored = $self->search_related('mapped_sectors')->count;
    
    return ($explored / $world_size) * 100;   
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);


1;

