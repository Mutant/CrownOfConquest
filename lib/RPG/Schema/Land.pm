package RPG::Schema::Land;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp qw(cluck croak);

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Land');

__PACKAGE__->resultset_class('RPG::ResultSet::Land');

__PACKAGE__->add_columns(
    'land_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 1,
      'default_value' => undef,
      'is_foreign_key' => 0,
      'name' => 'land_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'x' => {
      'data_type' => 'bigint',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'x',
      'is_nullable' => 0,
      'size' => '20'
    },
    'y' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'y',
      'is_nullable' => 0,
      'size' => '11'
    },
    'terrain_id' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'terrain_id',
      'is_nullable' => 0,
      'size' => '11'
    },
    'creature_threat' => {
      'data_type' => 'int',
      'is_auto_increment' => 0,
      'default_value' => '0',
      'is_foreign_key' => 0,
      'name' => 'creature_threat',
      'is_nullable' => 0,
      'size' => '11'
    },
);
__PACKAGE__->set_primary_key('land_id');

__PACKAGE__->belongs_to(
    'terrain',
    'RPG::Schema::Terrain',
    { 'foreign.terrain_id' => 'self.terrain_id' }
);

__PACKAGE__->might_have(
    'town',
    'RPG::Schema::Town',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->might_have(
    'mapped_sector',
    'RPG::Schema::Mapped_Sectors',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->might_have(
    'creature_group',
    'RPG::Schema::CreatureGroup',
    { 'foreign.land_id' => 'self.land_id' }
);

__PACKAGE__->might_have(
    'orb',
    'RPG::Schema::Creature_Orb',
    { 'foreign.land_id' => 'self.land_id' }
);

sub next_to {
    my $self = shift;
    my $compare_to = shift || croak 'sector to compare to not supplied';
   
    my ($current_x, $current_y) = ($self->x,       $self->y);
    my ($new_x,     $new_y)     = ($compare_to->x, $compare_to->y);

    my $x_diff = abs $current_x - $new_x;
    my $y_diff = abs $current_y - $new_y;
    
    # Same sector is not considered next to
    if ($x_diff > 1 || $y_diff > 1 || ($x_diff == 0 && $y_diff == 0)) {
        return 0;
    }
    else {
        return 1;
    }    
}

sub movement_cost {
	my $self = shift;
		
	my $movement_factor = shift || croak 'movement factor not supplied';
	my $terrain_modifier = shift; 
	$terrain_modifier = $self->terrain->modifier unless defined $terrain_modifier;
	
	
	my $cost = $terrain_modifier - $movement_factor;
	$cost = 1 if $cost < 1;
	
	return $cost;
}

# Returns the creature group in this sector, if they're "available" (i.e. not on combat)
sub available_creature_group {
	my $self = shift;
	
	my @creature_groups = $self->search_related('creature_group',
		{
			'in_combat_with.party_id' => undef,
		},
		{
			prefetch => {'creatures' => ['type', 'creature_effects']},
			join => 'in_combat_with',
		},
	);
	
	$self->throw_exception("More than one creature group found in this sector!")
		if scalar @creature_groups > 1;
	
	return $creature_groups[0];	
}

1;