package RPG::Schema::Character;

use Moose;

with 'RPG::Schema::Role::Being';

use base 'DBIx::Class';

use Carp;
use Data::Dumper;
use List::Util qw(shuffle);
use Math::Round qw(round);
use Sub::Name;
use DateTime;

use DBIx::Class::ResultClass::HashRefInflator;

__PACKAGE__->load_components(qw/Core Numeric/);
__PACKAGE__->table('`Character`');

__PACKAGE__->resultset_class('RPG::ResultSet::Character');

__PACKAGE__->add_columns(
    qw/character_id character_name class_id race_id hit_points
        level spell_points max_hit_points party_id party_order last_combat_action stat_points town_id
        last_combat_param1 last_combat_param2 gender garrison_id offline_cast_chance creature_group_id
        mayor_of/
);

__PACKAGE__->numeric_columns(qw/hit_points spell_points/);

__PACKAGE__->add_columns( 
	xp => { accessor => '_xp' },
	strength => { accessor => '_strength'}, 
	intelligence  => { accessor => '_intelligence'}, 
	agility  => { accessor => '_agility'}, 
	divinity  => { accessor => '_divinity'}, 
	constitution => { accessor => '_constitution'}, 
);

__PACKAGE__->set_primary_key('character_id');

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' }, {cascade_delete => 0, join_type => 'LEFT'} );

__PACKAGE__->belongs_to( 'class', 'RPG::Schema::Class', { 'foreign.class_id' => 'self.class_id' } );

__PACKAGE__->belongs_to( 'race', 'RPG::Schema::Race', { 'foreign.race_id' => 'self.race_id' } );

__PACKAGE__->has_many(
    'items', 'RPG::Schema::Items',
    { 'foreign.character_id' => 'self.character_id' },
    { prefetch               => [ 'item_type' ], },
);

__PACKAGE__->has_many( 'memorised_spells', 'RPG::Schema::Memorised_Spells', { 'foreign.character_id' => 'self.character_id' }, );

__PACKAGE__->many_to_many( 'spells' => 'memorised_spells', 'spell' );

__PACKAGE__->has_many( 'character_effects', 'RPG::Schema::Character_Effect', { 'foreign.character_id' => 'self.character_id' }, );

__PACKAGE__->has_many( 'history', 'RPG::Schema::Character_History', 'character_id' );

__PACKAGE__->belongs_to( 'garrison', 'RPG::Schema::Garrison', 'garrison_id' );

__PACKAGE__->might_have( 'mayor_of_town', 'RPG::Schema::Town', { 'foreign.town_id' => 'self.mayor_of' }, {cascade_delete => 0} );

__PACKAGE__->belongs_to( 'creature_group', 'RPG::Schema::CreatureGroup', 'creature_group_id', {cascade_delete => 0} );

__PACKAGE__->might_have( 'mayoral_candidacy', 'RPG::Schema::Election_Candidate', 'character_id', {cascade_delete => 0} );

our @STATS = qw(str con int div agl);
my @LONG_STATS = qw(strength constitution intelligence divinity agility);

sub strength {
	my $self = shift;
	
	return $self->_stat_accessor('strength', @_);	
}

sub constitution {
	my $self = shift;
	
	return $self->_stat_accessor('constitution', @_);	
}

sub intelligence {
	my $self = shift;
	
	return $self->_stat_accessor('intelligence', @_);	
}

sub divinity {
	my $self = shift;
	
	return $self->_stat_accessor('divinity', @_);	
}

sub agility {
	my $self = shift;
	
	return $self->_stat_accessor('agility', @_);	
}

sub portrait {
	my $self = shift;
	
	return lc($self->race->race_name) . lc(substr $self->class->class_name, 0, 3);
}

sub _stat_accessor {
	my $self = shift;
	my $stat = shift;

	my $value;
	{
		no strict 'refs';
		my $accessor = '_' . $stat; 
		$value = $self->$accessor(@_);
	}
	
	my @items_with_stat_bonuses = $self->search_related(
		'items',
		{
			'enchantment.enchantment_name' => 'stat_bonus',
			'equip_place_id' => {'!=', undef},
		},
		{
			prefetch => {'item_enchantments' => 'enchantment'},
		}
	);
	
	foreach my $item (@items_with_stat_bonuses) {
		foreach my $enchantment ($item->item_enchantments) {
			next if ! $enchantment->variable('Stat Bonus') || $enchantment->variable('Stat Bonus') ne $stat;
			
			$value+= $enchantment->variable('Bonus');
		} 
	}
	
	return $value;
}

sub long_stats {
	return @LONG_STATS;	
}

# These allow us to use the 'Being' role
sub hit_points_current {
    my $self = shift;

    return $self->hit_points;
}

sub hit_points_max {
    my $self = shift;

    return $self->max_hit_points;
}

sub name {
    my $self = shift;
    
    my $town = $self->mayor_of ? $self->mayor_of_town : undef;

    return $self->character_name . ($town ? ', Mayor of ' . $town->town_name : '');
}

sub group_id {
    my $self = shift;

    return $self->garrison_id || $self->party_id || $self->creature_group_id;
}

sub group {
	my $self = shift;
	
	if ($self->garrison_id) {
		return $self->garrison;
	}
	elsif ($self->creature_group_id) {
		return $self->creature_group;	
	}
	else {
		return $self->party;
	}
}

sub is_spell_caster {
	my $self = shift;
	
	return $self->class->class_name eq 'Priest' || $self->class->class_name eq 'Mage' ? 1 : 0;
}

# Returns true if character is in a party (any party), and not a garrison
sub is_in_party {
	my $self = shift;
	
	return 0 unless $self->party_id;
	
	return 1 if ! $self->garrison_id && ! $self->mayor_of;

	if ($self->garrison_id) {	
		# They're in a garrison.. if the party is currently in the garrison's sector, consider the char to be in the party
		return 1 if $self->garrison->land_id == $self->party->land_id;
	}
	
	if ($self->mayor_of) {
		# See if they're in the town this mayor runs
		return 1 if $self->mayor_of_town->land_id == $self->party->land_id;	
	}
	
	return 0;
}

# Returns a list of columns that, if null, indicate the character is in the party 
sub in_party_columns {
	return qw/garrison_id mayor_of/;
}

# Returns true if character isn't owned by a player
sub is_npc {
	my $self = shift;
	
	return 0 if $self->party_id;
	
	return 1;
}

sub encumbrance {
	my $self = shift;
	
	my $total_weight_rs = $self->result_source->schema->resultset('Items')->search(
		{
			'character_id' => $self->id,
		},
		{
			prefetch => [
				'item_type',
				{ 'item_variables' => 'item_variable_name' },
			],
		},
	);
	
	$total_weight_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
	
	my $total_weight = 0;
	
	while (my $item = $total_weight_rs->next) {
		my $quantity = 1;

		if ($item->{item_variables}) {
			my @item_variables = @{$item->{item_variables}};
			
			
			foreach my $variable (@item_variables) {
				$quantity = $variable->{item_variable_value} 
					if ($variable->{item_variable_name}{item_variable_name} || '') eq 'Quantity';	
			}
		}
		
		$total_weight += ($item->{item_type}{weight} * $quantity);
	}
	
	return $total_weight;
}

sub encumbrance_allowance {
	my $self = shift;
	
	return ($self->strength + $self->constitution) * 10; 
}

sub is_overencumbered {
	my $self = shift;
	
	return 1 if $self->encumbrance > $self->encumbrance_allowance;	
}

sub roll_all {
    my $self = shift;

    my %rolls;

    $rolls{hit_points} = $self->roll_hit_points;

    if ( $self->class->class_name eq 'Mage' ) {
        $rolls{magic_points} = $self->roll_spell_points;
    }
    elsif ( $self->class->class_name eq 'Priest' ) {
        $rolls{faith_points} = $self->roll_spell_points;
    }

    $self->update;

    return %rolls;
}

# Rolls hit points for the next level.
# If called as a class method, first parameter is level, second is class, third is value of con
sub roll_hit_points {
    my $self = shift;

    my $class;
    if ( ref $self ) {
        $class = $self->class->class_name;
    }
    else {
        $class = shift;
    }

    my $point_max = RPG::Schema->config->{level_hit_points_max}{$class};

    if ( ref $self ) {
        my $points = $self->_roll_points( 'constitution', $point_max );
        $self->max_hit_points( ( $self->max_hit_points || 0 ) + $points );

        if ( $self->level == 1 ) {
            $self->hit_points($points);
        }

        return $points;
    }
    else {
        my $level = shift || croak 'Level not supplied';
        my $con   = shift || croak 'Consitution not supplied';
        return $self->_roll_points( $level, $con, $point_max );
    }
}

sub roll_spell_points {
    my $self = shift;

    my $point_max = RPG::Schema->config->{level_spell_points_max};
    my $point_min = RPG::Schema->config->{level_spell_points_min};

    if ( ref $self ) {
        return unless $self->class->class_name eq 'Priest' || $self->class->class_name eq 'Mage';

        my $stat = $self->class->class_name eq 'Priest' ? 'divinity' : 'intelligence';

        my $points = $self->_roll_points( $stat, $point_max, $point_min );

        $self->spell_points( ( $self->spell_points || 0 ) + $points );

        return $points;
    }

    else {
        my $level = shift || croak 'Level not supplied';
        my $div   = shift || croak 'Stat value not supplied';
        return $self->_roll_points( $level, $div, $point_max, $point_min );
    }
}

sub _roll_points {
    my $self = shift;

    my ( $level, $stat );

    if ( ref $self ) {
        $level = $self->level;
        my $stat_name = shift;
        $stat  = $self->get_column($stat_name);
        confess "stat $stat_name not defined" unless defined $stat;
    }
    else {
        $level = shift || croak 'Level not supplied';
        $stat  = shift || croak 'Stat not supplied';
    }

    my $point_max = shift || confess 'point_max not supplied';
    my $point_min = shift || 1;

    if ( $point_max < $point_min ) {
        my $message = "Can't roll stats where max is less than min (min: $point_min, max: $point_max, level: $level, stat: $stat";

        if ( ref $self ) {
            $message .= ", character: " . $self->character_name . ", id: " . $self->id;
        }

        $message .= ")";

        confess($message);
    }

    my $points = $level == 1 ? $point_max : Games::Dice::Advanced->roll( '1d' . ( $point_max - $point_min ) ) + ( $point_min - 1 );

    $points += int ($stat / RPG::Schema->config->{'point_dividend'});

    return $points;
}

# Set the default spells for a new char (if they're of the appropriate class)
sub set_default_spells {
    my $self = shift;

    return unless $self->class->class_name eq 'Priest' || $self->class->class_name eq 'Mage';

    # Get all the spells for this class, sorted by points ascending
    my @spells = $self->result_source->schema->resultset('Spell')->search(
        {
            class_id => $self->class->id,
            hidden   => 0,
        },
        { order_by => 'points', },
    );

    my $spell_points_used = 0;

    while ( $spell_points_used < $self->spell_points ) {
        foreach my $spell (@spells) {
            last if $self->spell_points < $spell_points_used + $spell->points;

            my $memorised_spell = $self->result_source->schema->resultset('Memorised_Spells')->find_or_create(
                {
                    character_id      => $self->id,
                    spell_id          => $spell->id,
                    memorised_today   => 1,
                    memorise_tomorrow => 1,
                },
            );

            $memorised_spell->memorise_count(          ( $memorised_spell->memorise_count          || 0 ) + 1 );
            $memorised_spell->memorise_count_tomorrow( ( $memorised_spell->memorise_count_tomorrow || 0 ) + 1 );
            $memorised_spell->update;

            $spell_points_used += $spell->points;
        }
    }
}

sub attack_factor {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $item = shift @items;

    # TODO possibly should be in the DB
    my $af_attribute = 'strength';
    $af_attribute = $item->item_type->category->item_category eq 'Ranged Weapon' ? 'agility' : 'strength'
        if $item;

    my $attack_factor = do {no strict 'refs'; $self->$af_attribute};

    if ($item) {

        # Add in item AF
        $attack_factor += $item->attribute('Attack Factor')->item_attribute_value || 0;

        # Subtract back rank penalty if necessary
        $attack_factor -= $item->attribute('Back Rank Penalty') && $item->attribute('Back Rank Penalty')->item_attribute_value || 0
            unless $self->in_front_rank;

        # Add in upgrade bonus
        $attack_factor += $item->variable("Attack Factor Upgrade") || 0;
    }

    # Apply effects
    my $effect_df = 0;
    map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'attack_factor' } $self->character_effects;
    $attack_factor += $effect_df;

    return $attack_factor;
}

sub defence_factor {
    my $self = shift;

    my @items = $self->get_equipped_item('Armour');
    
    # Get rid of broken items (items without a durability (i.e. not defined) are ok)
    @items = grep { my $dur = $_->variable('Durability'); !defined $dur || $dur > 0 } @items;

    my $armour_df = 0;
    map { $armour_df += $_->attribute('Defence Factor')->item_attribute_value + ( $_->variable('Defence Factor Upgrade') || 0 ) } @items;

    # Apply effects
    my $effect_df = 0;
    map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'defence_factor' } $self->character_effects;

    return $self->agility + $armour_df + $effect_df;
}

=head1 damage

Max damage the character can do with the weapon they currently have equipped

=cut

sub damage {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $weapon = shift @items;

    # Apply effects
    my $effect_dam = 0;
    map { $effect_dam += $_->effect->modifier if $_->effect->modified_stat eq 'damage' } $self->character_effects;
    return 2 + $effect_dam unless $weapon;    # nothing equipped, assume bare hands

    return $weapon->attribute('Damage')->item_attribute_value + ( $weapon->variable('Damage Upgrade') || 0 ) + $effect_dam;
}

sub weapon {
    my $self = shift;

    my @items = $self->get_equipped_item('Weapon');

    # Assume only one weapon equipped.
    # TODO needs to change to support multiple weapons
    my $item = shift @items;

    return $item ? $item->item_type->item_type : 'Bare Hands';
}

=head2 get_equipped_item($super_category)

Returns a list of any equipped item records for a specified super category.

=cut

sub get_equipped_item {
    my $self           = shift;
    my $category       = shift || croak 'Category not supplied';
    my $variables_only = shift // 0; #/

    return @{ $self->{equipped_item}{$category} } if ref $self->{equipped_item}{$category} eq 'ARRAY';

    my $prefetch = [ { 'item_variables' => 'item_variable_name' }, ];

    unless ($variables_only) {
        push @$prefetch, { item_type => { 'item_attributes' => 'item_attribute_name' } };
    }

    my @items = $self->result_source->schema->resultset('Items')->search(
        {
            'character_id'                       => $self->id,
            'super_category.super_category_name' => $category,
            'equip_place_id'                     => { '!=', undef },
        },
        {
            'join'     => [ { 'item_type' => { 'category' => 'super_category' }, }, ],
            'prefetch' => $prefetch,
        },
    );

    $self->{equipped_item}{$category} = \@items;

    return @items;
}

sub hit {
    my $self   = shift;
    my $damage = shift;
    my $attacker = shift;

    my $new_hp_total = $self->hit_points - $damage;
    $new_hp_total = 0 if $new_hp_total < 0;

    $self->hit_points($new_hp_total);
    $self->update;
    
    if ($self->is_dead && $attacker) {
    	if (my $town = $self->mayor_of_town) {
    		# A mayor has died... the party that killed them is marked as 'pending mayor' of the town
    		
    		# Attacker might be a party or a character
    		my $party_id = $attacker->isa('RPG::Schema::Party') ? $attacker->id : $attacker->party_id;
    		
   			$town->pending_mayor($party_id);
   			$town->pending_mayor_date(DateTime->now());
   			$town->update;
    	}	
    }
}

sub is_dead {
    my $self = shift;

    return $self->hit_points <= 0 ? 1 : 0;
}

sub is_alive {
	my $self = shift;
	
	return ! $self->is_dead;	
}

=head2 equipped_items(@items)

Returns a hashref keyed by equip places, with the character's item equipped in that place as the value

If the list of items isn't passed in, it will be read from the DB.

=cut

sub equipped_items {
    my $self  = shift;
    my @items = @_;

    my @equip_places = $self->result_source->schema->resultset('Equip_Places')->search;

	unless (@items) {
	    @items = $self->search_related(
	    	'items',
	    	{
	    		'equip_place_id' => {'!=', undef},
	    	}
	    );
	}

    my %equipped_items;

    # Character has no equipped items
    unless (@items) {
        %equipped_items = map { $_->equip_place_name => undef } @equip_places;
        return \%equipped_items;
    }

    foreach my $equip_place (@equip_places) {

        # Should only have one item equipped in a particular place
        my ($item) = grep { $_->equip_place_id && $equip_place->id == $_->equip_place_id; } @items;

        #warn $equip_place->equip_place_name . " " . $item->item_type->item_type if $item;
        $equipped_items{ $equip_place->equip_place_name } = $item;
    }

    #warn Dumper \%equipped_items;

    return \%equipped_items;
}

sub is_character {
    return 1;
}

sub ammunition_for_item {
    my $self = shift;
    my $item = shift;

    unless ( $item->item_type->category->item_category eq 'Ranged Weapon' ) {
        return;
    }

    my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;

    # Get all appropriate ammunition this character has
    my $ammo_rs = $self->search_related(
        'items',
        {
            'me.item_type_id'                       => $ammunition_item_type_id,
            'item_variable_name.item_variable_name' => 'Quantity',
        },
        { prefetch => { 'item_variables' => 'item_variable_name' }, },
    );
    $ammo_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    my @ammo;
    while ( my $ammo_rec = $ammo_rs->next ) {
        my $quantity = $ammo_rec->{item_variables}[0]{item_variable_value};

        push @ammo,
            {
            id       => $ammo_rec->{item_id},
            quantity => $quantity,
            };
    }

    return wantarray ? @ammo : \@ammo;
}

sub run_out_of_ammo {
    my $self = shift;

    my ($weapon) = $self->get_equipped_item('Weapon');

    return 0 unless $weapon;

    unless ( $weapon->item_type->category->item_category eq 'Ranged Weapon' ) {
        return 0;
    }

    my @ammo = $self->ammunition_for_item($weapon);

    my $run_out = 1;

    foreach my $ammo (@ammo) {
        next unless $ammo;
        if ( $ammo->{quantity} >= 1 ) {
            $run_out = 0;
            last;
        }
    }

    return $run_out;
}

# Called when character is attacked. Used to take damage to armour
sub execute_defence {
    my $self = shift;

    my @items = $self->get_equipped_item( 'Armour', 1 );

    my $armour_now_broken = 0;
    foreach my $item (@items) {
    	next if $item->variable('Indestructible');
    	
        my $durability_rec = $item->variable_row('Durability');
        if ($durability_rec) {
            return if $durability_rec->item_variable_value == 0;

            my $new_durability = $self->_check_damage_to_item($durability_rec);

            if ( $new_durability == 0 ) {

                # Armour is now broken
                $armour_now_broken = 1;
            }
        }
    }

    return $armour_now_broken ? { armour_broken => 1 } : undef;

}

# Checks if we should deal damage to an item (i.e. decrements durability). Damage is dealt based on chance
# Returns the new durability, or undef if it was already broken
sub _check_damage_to_item {
    my $self           = shift;
    my $durability_rec = shift;

    if ( $durability_rec->item_variable_value == 0 ) {
        return undef;
    }
    else {
        my $weapon_damage_roll = Games::Dice::Advanced->roll('1d3');

        my $durability = $durability_rec->item_variable_value;

        if ( $weapon_damage_roll == 1 ) {
            $durability--;
            $durability_rec->item_variable_value($durability);
            $durability_rec->update;
        }

        return $durability;
    }
}

# Accessor for xp. If xp updated, also checks if the character should be leveled up. If it should, returns a hash of details
#  of the stats/points gained
sub xp {
    my $self   = shift;
    my $new_xp = shift;

    return $self->_xp unless $new_xp;

    $self->_xp($new_xp);

    # Check if we should level up
    my $level_rec = $self->result_source->schema->resultset('Levels')->find( { level_number => $self->level + 1, }, );

    if ( ref $level_rec && $new_xp > $level_rec->xp_needed ) {
        $self->level( $self->level + 1 );

        my %rolls = $self->roll_all;

        # Add stat points
        $self->stat_points( $self->stat_points + RPG::Schema->config->{stat_points_per_level} );
        $rolls{stat_points} = RPG::Schema->config->{stat_points_per_level};

        my $today = $self->result_source->schema->resultset('Day')->find_today;

        $self->add_to_history(
            {
                day_id => $today->id,
                event  => $self->character_name . " reached level " . $self->level,
            },
        );

        return \%rolls;
    }
}

sub resurrect_cost {
    my $self = shift;

    # TODO: cost should be modified by the town's prosperity

    return $self->level * RPG::Schema->config->{resurrection_cost};
}

# Number of prayer or magic points used for spells memorised tomorrow
#  Takes optional parameter of a spell to *exclude* from this count
sub spell_points_used {
    my $self             = shift;
    my $exclude_spell_id = shift;

    my %where;
    if ($exclude_spell_id) {
        $where{'spell_id'} = { '!=', $exclude_spell_id };
    }

    my $result = $self->result_source->schema->resultset('Memorised_Spells')->find(
        {
            character_id      => $self->id,
            memorise_tomorrow => 1,
            %where,
        },
        {
            join   => 'spell',
            select => [ { sum => 'spell.points * memorise_count_tomorrow' } ],
            as     => 'total_points',
        },
    );

    return $result->get_column('total_points') || 0;
}

sub rememorise_spells {
    my $self = shift;

    my @spells_to_memorise = $self->memorised_spells;

    my $spell_count = 0;

    foreach my $spell (@spells_to_memorise) {
        if ( $spell->memorise_tomorrow ) {
            $spell->memorised_today(1);
            $spell->memorise_count( $spell->memorise_count_tomorrow );
            $spell->number_cast_today(0);
            $spell->update;

            $spell_count += $spell->memorise_count_tomorrow;
        }
        else {

            # Spell no longer memorised, so delete the record
            $spell->delete;
        }
    }

    return $spell_count;
}

sub change_hit_points {
    my $self   = shift;
    my $amount = shift;

    return if $self->is_dead;

    my $actual_amount = $amount;

    # Reduce amount if it would take us beyond the maximum hit points
    if ( $self->max_hit_points < $amount + $self->hit_points ) {
        $actual_amount = $self->max_hit_points - $self->hit_points;
    }

    $self->hit_points( $self->hit_points + $actual_amount );

    return $actual_amount;
}

# Returns true if character is in the front rank
sub in_front_rank {
    my $self = shift;

    # If character isn't in a party, say they're in the front rank
    return 1 unless $self->party_id;

    return $self->party->rank_separator_position > $self->party_order;
}

# Return the number of attacks allowed by this character
around 'number_of_attacks' => sub {
	my $orig = shift;
    my $self           = shift;
    my @attack_history = @_;	
    
    my $modifier = 0;
    
    if ( $self->class->class_name eq 'Archer' ) {
        my @weapons = $self->get_equipped_item('Weapon');

        my $ranged_weapons = grep { $_->item_type->category->item_category eq 'Ranged Weapon' } @weapons;

        $modifier = 0.5 if $ranged_weapons >= 1;
    }
    
    return $self->$orig($modifier, @attack_history);
};

sub effect_value {
    my $self = shift;
    my $effect = shift || croak "Effect not supplied";

    my $modifier;
    map { $modifier += $_->effect->modifier if $_->effect->modified_stat eq $effect } $self->character_effects;

    return $modifier;
}

sub resistences {
	my $self = shift;
	
	return (
		Fire => $self->level * 5,
		Ice => $self->level * 5,
		Poison => $self->level * 5,
	);
}

sub value {
    my $self = shift;

    return $self->{value} if defined $self->{value};

    my $value = int 150 + $self->xp * 0.8;
    $value += int $self->hit_points;
    $value += int $self->spell_points;

    foreach my $item ( $self->items ) {
        $value += int $item->sell_price(0);
    }

    $self->{value} = $value;

    return $self->{value};
}

sub sell_value {
    my $self = shift;

    return int $self->value * 0.8;
}

my %starting_equipment = (
    'Warrior' => [ 'Short Sword', 'Wooden Shield' ],
    'Archer'  => [ 'Sling',       'Sling Stones' ],
    'Priest'  => [ 'Short Sword', 'Wooden Shield' ],
    'Mage'    => [ 'Dagger',      'Wooden Shield' ],
);

sub set_starting_equipment {
    my $self = shift;

    my $schema = $self->result_source->schema;

    foreach my $starting_item ( @{ $starting_equipment{ $self->class->class_name } } ) {
        my $item_type = $schema->resultset('Item_Type')->find( { item_type => $starting_item } );

        my $item = $schema->resultset('Items')->create( { item_type_id => $item_type->id, } );

        $item->add_to_characters_inventory($self);

        if ( $item->variable('Quantity') ) {
            $item->variable( 'Quantity', 250 );
        }
    }
}

# Returns the spell to cast if there is one, undef otherwise
sub check_for_offline_cast {
	my $self = shift;
	
	my $cast_roll = Games::Dice::Advanced->roll('1d100');
	if ($cast_roll <= $self->offline_cast_chance) {
		my %params;
		unless ($self->is_npc) {
			# pc chars restricted to spells they've marked to cast offline
			$params{cast_offline} = 1;
		}			
		
		my @spells = $self->search_related(
			'memorised_spells',
			\%params,
			{
				prefetch => 'spell',
			}
		);
		
		@spells = grep { $_->casts_left_today > 0 } @spells;
		
		return unless @spells;
		
		return (shuffle @spells)[0]->spell; 
	}	
}

# Get item actions (i.e. all items that can be used)
sub get_item_actions {
	my $self = shift;
	my $combat = shift;
	
	my @items = $self->search_related('items',
		{
			'item_enchantments.enchantment_id' => {'!=', undef},
		},
		{
			prefetch => 'item_enchantments',
		}			
	);
		
	my @actions;
	foreach my $item (@items) {
		push @actions, $item->usable_actions($combat);		
	}
	
	return @actions;	
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
