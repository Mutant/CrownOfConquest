package RPG::Schema::Land;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;
use Carp qw(cluck croak confess);

use RPG::ResultSet::RowsInSectorRange;
use Statistics::Basic qw(average);
use RPG::Map;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Land');

__PACKAGE__->resultset_class('RPG::ResultSet::Land');

__PACKAGE__->add_columns(
    'land_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'land_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'x' => {
        'data_type'         => 'bigint',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'x',
        'is_nullable'       => 0,
        'size'              => '20'
    },
    'y' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'y',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'terrain_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'terrain_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'creature_threat' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'creature_threat',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'variation' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => '0',
        'is_foreign_key'    => 0,
        'name'              => 'variation',
        'is_nullable'       => 0,
        'size'              => '11'
    },    
);
__PACKAGE__->set_primary_key('land_id');

__PACKAGE__->numeric_columns(
	creature_threat => {min_value => -100, max_value => 100},
);

__PACKAGE__->belongs_to( 'terrain', 'RPG::Schema::Terrain', { 'foreign.terrain_id' => 'self.terrain_id' } );

__PACKAGE__->might_have( 'town', 'RPG::Schema::Town', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'mapped_sector', 'RPG::Schema::Mapped_Sectors', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'creature_group', 'RPG::Schema::CreatureGroup', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'orb', 'RPG::Schema::Creature_Orb', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'dungeon', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'parties', 'RPG::Schema::Party', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'garrison', 'RPG::Schema::Garrison', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'building', 'RPG::Schema::Building', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'roads', 'RPG::Schema::Road', { 'foreign.land_id' => 'self.land_id' } );

sub next_to {
    my $self = shift;
    my $compare_to = shift || croak 'sector to compare to not supplied';

    my ( $current_x, $current_y ) = ( $self->x,       $self->y );
    my ( $new_x,     $new_y )     = ( $compare_to->x, $compare_to->y );

    my $x_diff = abs $current_x - $new_x;
    my $y_diff = abs $current_y - $new_y;

    # Same sector is not considered next to
    if ( $x_diff > 1 || $y_diff > 1 || ( $x_diff == 0 && $y_diff == 0 ) ) {
        return 0;
    }
    else {
        return 1;
    }
}

sub movement_cost {
    my $self = shift // confess 'base sector not supplied';
    my $movement_factor = shift // confess 'movement factor not supplied';            
    my $terrain_modifier = shift;
    my $from_sector = shift;
    
    if (! defined $terrain_modifier) {        
        if (ref $self && $self->isa('RPG::Schema::Land')) {
            $terrain_modifier = $self->terrain->modifier;
        }
        else {
            confess 'terrain modifier not supplied';
        }
    }

    my $cost = $terrain_modifier - $movement_factor;
    
    # If from sector is next to current one, factor roads into movement cost calculation
    if ($from_sector && has_road_joining_to($from_sector, $self)) {
        $cost -= 2;   
    }
    
    $cost = 1 if $cost < 1;

    return $cost;
}

# Returns the creature group in this sector, if they're "available" (i.e. not on combat)
sub available_creature_group {
    my $self = shift;

    my $creature_group = $self->search_related(
        'creature_group',
        { 
        	'in_combat_with.party_id' => undef,
        },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
            join     => 'in_combat_with',
            order_by => 'type.creature_type, group_order',
        },
    )->first;

    return unless $creature_group;

    return $creature_group if $creature_group->number_alive > 0;

    return;
}

sub get_surrounding_ctr_average {
    my $self         = shift;
    my $search_range = shift;

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => $search_range,
        increment_search_by => 0
    );

    my @ctrs;
    foreach my $land_rec (@land_rec) {
        push @ctrs, $land_rec->creature_threat;
    }

    return average(@ctrs);
}

sub get_adjacent_towns {
    my $self = shift;

    my %criteria = ( 'town.town_id' => { '!=', undef }, );

    my %attrs = ( 'prefetch' => 'town', );

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => 3,
        increment_search_by => 0,
        criteria            => \%criteria,
        attrs               => \%attrs,
    );

    my @towns = map { $_->town } @land_rec;

    return @towns;
}

sub get_adjacent_garrisons {
    my $self = shift;
    my $range = shift || RPG->config->{garrison_min_spacing};
    my %criteria = ( 'garrison.garrison_id' => { '!=', undef }, );

    my %attrs = ( 'prefetch' => 'garrison', );

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => ($range * 2) + 1,
        increment_search_by => 0,
        criteria            => \%criteria,
        attrs               => \%attrs,
    );

    my @garrisons = map { $_->garrison } @land_rec;
    return @garrisons;
}

sub get_adjacent_buildings {
    my $self = shift;
    my $range = shift || RPG->config->{building_min_spacing};
    my %criteria = ( 'building.building_id' => { '!=', undef }, );

    my %attrs = ( 'prefetch' => 'building', );

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => ($range * 2) + 1,
        increment_search_by => 0,
        criteria            => \%criteria,
        attrs               => \%attrs,
    );

    my @buildings = map { $_->building } @land_rec;
    return @buildings;
}

sub has_road_joining_to {
    my $self = shift;
    my $sector_to_check = shift || confess "sector_to_check not supplied";
    
    my ($source_x, $source_y) = ref $self eq 'HASH' ? ($self->{x}, $self->{y}) : ($self->x, $self->y);
    my ($dest_x, $dest_y) = ref $sector_to_check eq 'HASH' ? ($sector_to_check->{x}, $sector_to_check->{y}) : ($sector_to_check->x, $sector_to_check->y);

    my $secords_adjacent = RPG::Map->is_adjacent_to(
        {
            x => $source_x,
            y => $source_y,
        },
        {
            x => $dest_x,
            y => $dest_y,
        }
    );        
   
    if (! $secords_adjacent) {   
        return 0;   
    }
    
    my $source_connects = _road_connects_sectors($self, $sector_to_check);
    my $dest_connects = _road_connects_sectors($sector_to_check, $self);
    
    return $source_connects && $dest_connects;
}

sub _road_connects_sectors {
    my $source = shift;
    my $dest = shift;
   
    # Due to the directions used in RPG::Map and road positions not matching up, we need this wonderful map
    my %direction_map = (
        'North' => 'top',
        'South' => 'bottom',
        'West' => 'left',
        'East' => 'right',
        'North West' => 'top left',
        'North East' => 'top right',
        'South West' => 'bottom left',
        'South East' => 'bottom right',
    );    
    
    my $connects;
    
    my $has_town = ref $source eq 'HASH' ? $source->{town_id} : $source->town;
    if ($has_town) {
        $connects = 1;   
    }
    else {        
        my @roads = ref $source eq 'HASH' ? (map {$_ && $_->{position}} @{$source->{roads}}) : (map {$_->position} $source->roads);
        
        my ($source_x, $source_y) = ref $source eq 'HASH' ? ($source->{x}, $source->{y}) : ($source->x, $source->y);
        my ($dest_x, $dest_y) = ref $dest eq 'HASH' ? ($dest->{x}, $dest->{y}) : ($dest->x, $dest->y);
        
        
        my $direction = RPG::Map->get_direction_to_point(
            {
                x => $source_x,
                y => $source_y,
            },
            {
                x => $dest_x,
                y => $dest_y,
            },
        );
        
        confess "Couldn't find direction between points" unless $direction;
                
        $connects = grep { $_ && $_ eq $direction_map{$direction} } @roads;
    }  
    
    return $connects;
}

# Returns true if this sector is allowed to have a garrison
sub garrison_allowed {
	my $self = shift;
	
	# Not allowed if an orb is here
	return 0 if $self->orb;
	
	# Not allowed if a town is here
	return 0 if $self->town;
	
	# Not allowed if another garrison is here
	return 0 if $self->garrison;
	
	# Not allowed if adjacent to a town
	return 0 if $self->get_adjacent_towns;
	
	# Not allowed if too close to a garrison
	return 0 if $self->get_adjacent_garrisons();
	
	# Ok, it's allowed
	return 1;
}

# Returns true if a building could be built here.
sub building_allowed {
	my $self = shift;
	my $party = shift;
	
	# Not allowed if adjacent to a town
	return 0 if $self->get_adjacent_towns;

	# Not allowed if too close to a building
	return 0 if $self->get_adjacent_buildings();
	
	# Not allowed if another building is here that is not owned by us
	foreach my $next_building ($self->building) {
		if ($next_building->owner_id != $party) {
			return 0;
		}
	}

	return 1;
}

# returns true if there is already a building here.
sub has_building {
	my $self = shift;
	
	return 1 if $self->building;

	return 0;
}

1;
