use strict;
use warnings;

package RPG::Schema::Character;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('`Character`');

__PACKAGE__->add_columns(
    'character_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'character_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'character_name' => {
      'data_type' => 'char',
      'is_auto_increment' => 0,
      'default_value' => '',
      'is_foreign_key' => 0,
      'name' => 'character_name',
      'is_nullable' => 0,
      'size' => '255'
    },
    'xp' => {
      'data_type' => 'bigint',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'xp',
      'is_nullable' => 0,
      'size' => '20'
    },
    'class_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'class_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'race_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'race_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'strength' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'strength',
      'is_nullable' => 0,
      'size' => '11'
    },
    'intelligence' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'intelligence',
      'is_nullable' => 0,
      'size' => '11'
    },
    'agility' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'agility',
      'is_nullable' => 0,
      'size' => '11'
    },
    'divinity' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'divinity',
      'is_nullable' => 0,
      'size' => '11'
    },
    'constitution' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'constitution',
      'is_nullable' => 0,
      'size' => '11'
    },
    'hit_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'hit_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'level' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '1',
      'is_foreign_key' => 0,
      'name' => 'level',
      'is_nullable' => 0,
      'size' => '11'
    },
    'magic_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'magic_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'faith_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'faith_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'max_hit_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'max_hit_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'max_magic_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'max_magic_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'max_faith_points' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'max_faith_points',
      'is_nullable' => 0,
      'size' => '11'
    },
    'party_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'max_faith_points',
      'is_nullable' => 1,
      'size' => '11'
    },
    'party_order' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'max_faith_points',
      'is_nullable' => 0,
      'size' => '11'
    },    

);
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
    { prefetch => 'item_type' },
);

our @STATS = qw(str con int div agl);

sub roll_all {
    my $self = shift;
    my $c = shift;
    
    $self->roll_hit_points($c);
    $self->roll_magic_points($c);
    $self->roll_faith_points($c);
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
        $self->max_hit_points($self->max_hit_points + $points);
        $self->update;
        
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
        $self->max_magic_points($self->max_magic_points + $points);
        $self->update;
        
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
        
        $self->max_faith_points($self->max_faith_points + $points);
        $self->update;
        
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
    }    
    else {
        $level = shift || croak 'Level not supplied';    
        $stat = shift || croak 'Stat not supplied';
    }        
    
    my $point_max = shift || croak 'point_max not supplied';
    
    my $points = $level == 1 ? $point_max : int rand $point_max;
    
    $points += $self->point_bonus($stat);
    
    return $points;
    
    # XXX: instance should update values here.
}

sub attack_factor {
	my $self = shift;
	
	return $self->strength + $self->_calculate_equipped_modifier('Weapon'); 
}

sub defence_factor {
	my $self = shift;
		
	return $self->agility + $self->_calculate_equipped_modifier('Armour');
	
}

=head1 damage

Max damage the character can do with the weapon they currently have equipped

=cut

sub damage {
	my $self = shift;
	
	my $eq_rs = $self->_get_equipped_items('Weapon');
	
	my $weapon = $eq_rs->first;
	
	return 2 unless $weapon; # nothing equipped, assume bare hands
	
	my $attribute = $weapon->item_type->search_related('item_attributes', { 'item_attribute_id' => 'Damage' })->first;
	
	return $attribute->item_attribute_value;
}

=head2 _calculate_equipped_modifier($equipment_cateogry)

Calculate the modifier of all equipment of a particular category (e.g. "Weapon") equipped by this character.
Will return '0' if no equipment of that type is worn.

=cut

sub _calculate_equipped_modifier {
	my $self = shift;
	my $category = shift || croak 'Category not supplied';
	
	return $self->{_equip_modifier}{$category} if defined $self->{_equip_modifier}{$category};
	
	my $eq_rs = $self->_get_equipped_items($category);
	
	my $modifier = 0;
	while (my $item = $eq_rs->next) {
		next unless $item;
		$modifier += $item->item_type->basic_modifier + $item->magic_modifier;
	}
	
	$self->{_equip_modifier}{$category} = $modifier;
	
	return $modifier;
}

=head2 _get_equipped_items($category)

Return a record set of equipped items for a given category

=cut

# TODO: join onto Equip_Places and only get equipped items

sub _get_equipped_items {
	my $self = shift;
	my $category = shift || croak 'Category not supplied';

	my $eq_rs = $self->result_source->schema->resultset('Items')->search(
		{
			'character_id' => $self->id,
			'category.item_category' => $category,
		},
		{
			'join' => {'item_type' => 'category'},
			'prefetch' => 'item_type',
			'cache' => 1,
		},
	);
	
	return $eq_rs;
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
		my ($item) = grep { $equip_place->id == $_->id; } @items;
		$equipped_items{$equip_place->equip_place_name} = $item; 
	}
	
	return \%equipped_items;
}

1;