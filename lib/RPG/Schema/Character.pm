use strict;
use warnings;

package RPG::Schema::Character;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('`Character`');

__PACKAGE__->add_columns(qw/character_id character_name class_id race_id strength intelligence agility divinity constitution hit_points
 							level spell_points max_hit_points party_id party_order last_combat_action stat_points/);
 							
__PACKAGE__->add_columns(xp => { accessor => '_xp' });
 							
__PACKAGE__->set_primary_key('character_id');

__PACKAGE__->belongs_to(
    'class',
    'RPG::Schema::Class',
    { 'foreign.class_id' => 'self.class_id' }
);

__PACKAGE__->belongs_to(
    'race',
    'RPG::Schema::Race',
    { 'foreign.race_id' => 'self.race_id' }
);

__PACKAGE__->has_many(
    'items',
    'RPG::Schema::Items',
    { 'foreign.character_id' => 'self.character_id' },
    { prefetch => ['item_type', 'item_variables'], },
);

__PACKAGE__->has_many(
    'mem_spells_link',
    'RPG::Schema::Memorised_Spells',
    { 'foreign.character_id' => 'self.character_id' },
);

__PACKAGE__->many_to_many('memorised_spells' => 'mem_spells_link', 'spell');

__PACKAGE__->has_many(
    'character_effects',
    'RPG::Schema::Character_Effect',
    { 'foreign.character_id' => 'self.character_id' },
);

our @STATS = qw(str con int div agl);

sub roll_all {
    my $self = shift;
    
    my %rolls;
    
    $rolls{hit_points}   = $self->roll_hit_points;
    $rolls{magic_points} = $self->roll_magic_points;
    $rolls{faith_points} = $self->roll_faith_points;
    
    $self->update;
    
    return %rolls;
}

# Calcuates the point bonus for a stat (e.g. hit points, magic points).
# If called as a class method, takes the value of the stat as first parameter
# If called as instance method, takes the name of the stat
sub point_bonus {
    my $self = shift;
    
    my $stat_value = shift || $self->get_column(shift);
    
    return int $stat_value / RPG->config->{'point_dividend'};
}

# Rolls hit points for the next level.
# If called as a class method, first parameter is level, second is class, third is value of con
sub roll_hit_points {
    my $self = shift;
    
    my $class;
    if (ref $self) {
        #warn $self->class_id;
        $class = $self->class->class_name;
    }
    else {
        $class = shift;
    }
       
    my $point_max = RPG->config->{level_hit_points_max}{$class};
    
    if (ref $self) {
    	my $points = $self->_roll_points('constitution', $point_max);
    	$self->max_hit_points($points);
    	
    	if ($self->level == 1) {
    		$self->hit_points($points);	
    	}
    	
        return $points;
    }        
    else {
        my $level = shift || croak 'Level not supplied';
        my $con = shift || croak 'Consitution not supplied';
        return $self->_roll_points($level, $con, $point_max);
    }
}

sub roll_magic_points {
    my $self = shift;
    
    my $point_max = RPG->config->{level_magic_points_max};
    
    if (ref $self) {
        return unless $self->class->class_name eq 'Mage';
        my $points = $self->_roll_points('intelligence',$point_max);
        $self->spell_points($self->spell_points + $points);
        
        return $points;
    }
    else {
        my $level = shift || croak 'Level not supplied';
        my $int = shift || croak 'Intelligence not supplied';
        return $self->_roll_points($level, $int, $point_max);
    }
}

sub roll_faith_points {
    my $self = shift;
    
    my $point_max = RPG->config->{level_faith_points_max};
    
    if (ref $self) {
        return unless $self->class->class_name eq 'Priest';
        my $points = $self->_roll_points('divinity',$point_max);
        
        $self->spell_points($self->spell_points + $points);
        
        return $points;
    }
    
    else {
        my $level = shift || croak 'Level not supplied';
        my $div = shift || croak 'Divinity not supplied';
        return $self->_roll_points($level, $div, $point_max);
    }
}

sub _roll_points {
    my $self = shift;

    my ($level, $stat);
       
    if (ref $self) {
        $level = $self->level;
        $stat = $self->get_column(shift);
        warn "level: $level\n";
        warn "stat: $stat\n";
    }    
    else {
        $level = shift || croak 'Level not supplied';    
        $stat  = shift || croak 'Stat not supplied';
    }        
    
    my $point_max = shift || croak 'point_max not supplied';
    
    my $points = $level == 1 ? $point_max : int rand $point_max;
    
    $points += $self->point_bonus($stat);
    
    return $points;
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
	
	# Apply effects
	my $effect_df = 0;
	map { $effect_df += $_->effect->modifier if $_->effect->modified_stat eq 'attack_factor' } $self->character_effects;
	
	return $self->get_column($af_attribute) + ($item ? $item->attribute('Attack Factor')->item_attribute_value : 0) + $effect_df;
}

sub defence_factor {
	my $self = shift;
	
	my @items = $self->get_equipped_item('Armour');
	
	my $armour_df = 0;
	map { $armour_df+= $_->attribute('Defence Factor')->item_attribute_value } @items;
	
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
	warn "effect dam: $effect_dam";
	return 2 + $effect_dam unless $weapon; # nothing equipped, assume bare hands
	
	return $weapon->attribute('Damage')->item_attribute_value + $effect_dam;
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

Returns an list of equipped item records specified super category, if any.

=cut

sub get_equipped_item {
	my $self = shift;
	my $category = shift || croak 'Category not supplied';
	
	return @{$self->{equipped_item}{$category}} if ref $self->{equipped_item}{$category} eq 'ARRAY'; 

	my @items = $self->result_source->schema->resultset('Items')->search(
		{
			'character_id' => $self->id,
			'super_category.super_category_name' => $category,
		},
		{
			'join' => [				
				'equipped_in',
			],
			'prefetch' => [
				{item_type => {'item_attributes' => 'item_attribute_name'}},
				{'item_type' => {'category' => 'super_category'}},
			],
		},
	);
	
	$self->{equipped_item}{$category} = \@items;
	
	return @items;
}

sub hit {
	my $self = shift;
	my $damage = shift;
	
	my $new_hp_total = $self->hit_points - $damage;
	$new_hp_total = 0 if $new_hp_total < 0;
	
	$self->hit_points($new_hp_total);
	$self->update;
}

sub name {
	my $self = shift;
	return $self->character_name;	
}

sub is_dead {
	my $self = shift;
	
	return $self->hit_points <= 0 ? 1 : 0;		
}

=head2 equipped_items(@items)

Returns a hashref keyed by equip places, with the character's item equipped in that place as the value

If the list of items isn't passed in, it will be read from the DB.

=cut

sub equipped_items {
	my $self = shift;
	my @items = @_;
	
	my @equip_places = $self->result_source->schema->resultset('Equip_Places')->search;
	
	@items = $self->items unless @items;

	my %equipped_items;

	# Character has no items
	unless (@items) {
		%equipped_items = map {$_->equip_place_name => undef} @equip_places;
		return \%equipped_items;
	}	

	foreach my $equip_place (@equip_places) {		
		# Should only have one item equipped in a particular place
		my ($item) = grep { $_->equip_place_id && $equip_place->id == $_->equip_place_id; } @items;
		#warn $equip_place->equip_place_name . " " . $item->item_type->item_type if $item;
		$equipped_items{$equip_place->equip_place_name} = $item; 
	}
	
	#warn Dumper \%equipped_items;
	
	return \%equipped_items;
}

sub is_character {
	return 1;	
}

# Execute an attack, mainly just make sure there is ammo for ranged weapons, and deduct one from quantity
sub execute_attack {
	my $self = shift;
	
	my @items = $self->get_equipped_item('Weapon');
	
	foreach my $item (@items) {
		if ($item->item_type->category->item_category eq 'Ranged Weapon') {
			my $ammunition_item_type_id = $item->item_type->attribute('Ammunition')->value;
			
			# Get all appropriate ammunition this character has
			my @ammo = $self->search_related('items',
				{
					'me.item_type_id' => $ammunition_item_type_id,
				},
				{
					prefetch => 'item_variables',
				},
			);
			
			return {no_ammo => 1} unless @ammo; # Didn't find anything, so return - they can't attack!
			
			# Find the first ammo item and 
			foreach my $ammo (@ammo) {
				my $quantity = $ammo->variable('Quantity');
				
				if ($quantity -1 == 0) {
					# None left, delete this item
					$ammo->delete;	
				}
				else {
					$ammo->variable('Quantity',$quantity-1);
				}	
				
				last;			
			}
		}	
	}
}

# Accessor for xp. If xp updated, also checks if the character should be leveled up. If it should, returns a hash of details
#  of the stats/points gained
sub xp {
	my $self = shift;
	my $new_xp = shift;
	
	return $self->_xp unless $new_xp;
	
	$self->_xp($new_xp);
	
	# Check if we should level up
	my $level_rec = $self->result_source->schema->resultset('Levels')->find(
		{
			level_number => $self->level +1,
		},
	);
	
	if (ref $level_rec && $new_xp > $level_rec->xp_needed) {
		$self->level($self->level+1);
		
		my %rolls = $self->roll_all;
		
		# Check for Stat point addition
		if ($self->level % RPG->config->{levels_per_stat_point} == 0) {
			$self->stat_points($self->stat_points+1);
			$rolls{stat_points} = 1;	
		}
		
		return \%rolls; 
	}
}

sub resurrect_cost {
	my $self = shift;
	
	# TODO: cost should be modified by the town's prosperity

	return $self->level * RPG->config->{resurrection_cost};	
}

# Number of prayer or magic points used for spells memorised tomorrow
sub spell_points_used {
	my $self = shift;
	
	my $result = $self->result_source->schema->resultset('Memorised_Spells')->find(
		{
			character_id => $self->id,
			memorise_tomorrow => 1,
		},
		{
			join => 'spell',
			select => [{sum=>'spell.points * memorise_count_tomorrow'}],
			as => 'total_points',
		},
	);
	
	return $result->get_column('total_points') || 0;
}

sub change_hit_points {
	my $self = shift;
	my $amount = shift;
	
	$self->hit_points($self->hit_points + $amount);
	$self->hit_points($self->max_hit_points)
		if $self->hit_points > $self->max_hit_points;
		
	$self->hit_points(0) if $self->hit_points < 0;
	
	return;	
}

1;