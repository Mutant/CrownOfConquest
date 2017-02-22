package RPG::Schema::Land;
use base 'DBIx::Class';
use strict;
use warnings;

use Moose;

use Data::Dumper;
use Carp qw(cluck croak confess);

use RPG::ResultSet::RowsInSectorRange;
use Statistics::Basic qw(average);
use Scalar::Util qw(blessed);
use RPG::Map;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Land');

__PACKAGE__->resultset_class('RPG::ResultSet::Land');

__PACKAGE__->add_columns(qw/land_id x y terrain_id creature_threat variation kingdom_id claimed_by_id claimed_by_type tileset_id/);

__PACKAGE__->set_primary_key('land_id');

__PACKAGE__->numeric_columns(
    creature_threat => { min_value => -100, max_value => 100 },
);

__PACKAGE__->belongs_to( 'terrain', 'RPG::Schema::Terrain', { 'foreign.terrain_id' => 'self.terrain_id' } );

__PACKAGE__->might_have( 'town', 'RPG::Schema::Town', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'mapped_sector', 'RPG::Schema::Mapped_Sectors', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'creature_group', 'RPG::Schema::CreatureGroup', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'orb', 'RPG::Schema::Creature_Orb', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'dungeon', 'RPG::Schema::Dungeon', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'parties', 'RPG::Schema::Party', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'garrison', 'RPG::Schema::Garrison', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->might_have( 'building', 'RPG::Schema::Building', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->has_many( 'roads', 'RPG::Schema::Road', { 'foreign.land_id' => 'self.land_id' } );

__PACKAGE__->belongs_to( 'kingdom', 'RPG::Schema::Kingdom', 'kingdom_id', { join_type => 'LEFT' } );

__PACKAGE__->might_have( 'bomb', 'RPG::Schema::Bomb', 'land_id', { where => { detonated => undef } } );

with qw/RPG::Schema::Role::Sector/;

sub label {
    my $self = shift;

    return $self->x . ', ' . $self->y;
}

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
    my $self            = shift // confess 'base sector not supplied';
    my $movement_factor = shift // confess 'movement factor not supplied';
    my $terrain_modifier = shift;
    my $has_road         = shift;

    if ( blessed $self && $self->isa('RPG::Schema::Land') ) {
        $terrain_modifier = $self->terrain->modifier;
        $has_road = $self->roads->count > 0 ? 1 : 0;
    }
    else {
        confess 'terrain modifier not supplied' unless defined $terrain_modifier;
        confess 'has_road not supplied' unless defined $has_road;
    }

    my $cost = $terrain_modifier - $movement_factor;

    # Reduce movement cost if sector has at least one road segment
    $cost -= 2 if $has_road;

    $cost = 1 if $cost < 1;

    return $cost;
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
    my $self      = shift;
    my $range     = shift || RPG::Schema->config->{garrison_min_spacing};
    my $for_party = shift;

    my %criteria = ( 'garrison.garrison_id' => { '!=', undef }, );

    my %attrs = ( 'prefetch' => 'garrison', );

    if ($for_party) {
        $criteria{'garrison.party_id'} = $for_party;
    }

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => ( $range * 2 ) + 1,
        increment_search_by => 0,
        criteria            => \%criteria,
        attrs               => \%attrs,
    );

    my @garrisons = map { $_->garrison } @land_rec;
    return @garrisons;
}

sub get_adjacent_buildings {
    my $self     = shift;
    my $range    = shift || RPG->config->{building_min_spacing};
    my %criteria = ( 'building.building_id' => { '!=', undef }, );

    my %attrs = ( 'prefetch' => 'building', );

    my @land_rec = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => ( $range * 2 ) + 1,
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

    my ( $source_x, $source_y ) = ref $self eq 'HASH' ? ( $self->{x}, $self->{y} ) : ( $self->x, $self->y );
    my ( $dest_x, $dest_y ) = ref $sector_to_check eq 'HASH' ? ( $sector_to_check->{x}, $sector_to_check->{y} ) : ( $sector_to_check->x, $sector_to_check->y );

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

    if ( !$secords_adjacent ) {
        return 0;
    }

    my $source_connects = _road_connects_sectors( $self, $sector_to_check );
    my $dest_connects = _road_connects_sectors( $sector_to_check, $self );

    return $source_connects && $dest_connects;
}

sub _road_connects_sectors {
    my $source = shift;
    my $dest   = shift;

    # Due to the directions used in RPG::Map and road positions not matching up, we need this wonderful map
    my %direction_map = (
        'North'      => 'top',
        'South'      => 'bottom',
        'West'       => 'left',
        'East'       => 'right',
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
        my @roads = ref $source eq 'HASH' ? ( map { $_ && $_->{position} } @{ $source->{roads} } ) : ( map { $_->position } $source->roads );

        my ( $source_x, $source_y ) = ref $source eq 'HASH' ? ( $source->{x}, $source->{y} ) : ( $source->x, $source->y );
        my ( $dest_x, $dest_y ) = ref $dest eq 'HASH' ? ( $dest->{x}, $dest->{y} ) : ( $dest->x, $dest->y );

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
    my $self  = shift;
    my $party = shift;

    # Not allowed if an orb is here
    return 0 if $self->orb;

    # Not allowed if a town is here
    return 0 if $self->town;

    # Not allowed if another garrison is here
    return 0 if $self->garrison;

    # Not allowed if adjacent to a town
    return 0 if $self->get_adjacent_towns;

    # Not allowed if too close to another garrison owned by this party
    return 0 if $self->get_adjacent_garrisons( undef, $party->id );

    # Ok, it's allowed
    return 1;
}

# Returns true if a building could be built here.
sub building_allowed {
    my $self  = shift;
    my $party = shift;

    # Not allowed if adjacent to a town
    return 0 if $self->get_adjacent_towns;

    # Not allowed if too close to a building
    return 0 if $self->get_adjacent_buildings();

    # Not allowed if another building is here that is not owned by us
    my $building = $self->building;
    if ( $building && $building->owner_id != $party ) {
        return 0;
    }

    return 1;
}

# returns true if there is already a building here.
sub has_building {
    my $self = shift;

    return 1 if $self->building;

    return 0;
}

# Returns true if this sector can be claimed by the kingdom passed in
sub can_be_claimed {
    my $self       = shift;
    my $kingdom_id = shift;

    return 0 if $self->kingdom_id && $kingdom_id == $self->kingdom_id;

    return 0 if $self->claimed_by_id;

    my @surrounds_in_kingdom = RPG::ResultSet::RowsInSectorRange->find_in_range(
        resultset           => $self->result_source->resultset,
        relationship        => 'me',
        base_point          => { x => $self->x, y => $self->y },
        search_range        => 3,
        increment_search_by => 0,
        rows_as_hashrefs    => 1,
        criteria            => {
            'kingdom_id' => $kingdom_id,
        },
    );

    return 0 if scalar @surrounds_in_kingdom <= 0;

    return 1;

}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );
