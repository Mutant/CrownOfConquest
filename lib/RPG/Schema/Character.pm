use strict;
use warnings;

package RPG::Schema::Character;

use base 'DBIx::Class';

use Carp;
use Data::Dumper;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('`Character`');

__PACKAGE__->add_columns(qw/character_id character_name xp class_id race_id strength intelligence agility divinity constitution hit_points
 							level magic_points faith_points max_hit_points max_magic_points max_faith_points party_id party_order 
 							last_combat_action/);
 							
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
		
	my @items = $self->get_equipped_item('Weapon');
	
	# Assume only one weapon equipped. 
	# TODO needs to change to support multiple weapons
	my $item = shift @items;
	
	return $self->strength + ($item ? $item->attribute('Attack Factor')->item_attribute_value : 0);
}

sub defence_factor {
	my $self = shift;
	
	my @items = $self->get_equipped_item('Armour');
	
	my $armour_df = 0;
	map { $armour_df+= $_->attribute('Defence Factor')->item_attribute_value } @items;
			
	return $self->agility + $armour_df;	
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
	
	return 2 unless $weapon; # nothing equipped, assume bare hands
	
	return $weapon->attribute('Damage')->item_attribute_value;
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
				{'item_type' => {'category' => 'super_category'}},
				'equipped_in',
			],
			'prefetch' => {item_type => {'item_attributes' => 'item_attribute_name'}},
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
		warn $equip_place->equip_place_name . " " . $item->item_type->item_type if $item;
		$equipped_items{$equip_place->equip_place_name} = $item; 
	}
	
	#warn Dumper \%equipped_items;
	
	return \%equipped_items;
}

sub is_character {
	return 1;	
}

1;