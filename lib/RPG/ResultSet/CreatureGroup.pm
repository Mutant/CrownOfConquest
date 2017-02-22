use strict;
use warnings;

package RPG::ResultSet::CreatureGroup;

use base 'DBIx::Class::ResultSet';

use RPG::Maths;
use RPG::Exception;
use RPG::ResultSet::RowsInSectorRange;

use List::Util qw(shuffle);
use Math::Round qw(round);

use Carp;

sub get_by_id {
    my $self              = shift;
    my $creature_group_id = shift;

    my $creature_group = $self->find(
        { creature_group_id => $creature_group_id, },
        {
            prefetch => { 'creatures' => [ 'type', 'creature_effects' ] },
            order_by => 'type.creature_type, group_order',
        },
    );

    return $creature_group;

}

sub create_in_wilderness {
    my ( $self, $land, $min_level, $max_level ) = @_;

    my $cg = $self->_create_group( $land, $min_level, $max_level );

    return unless $cg;

    $cg->land_id( $land->id );
    $cg->update;

    $land->creature_threat( $land->creature_threat + $cg->level );
    $land->update;

    return $cg;
}

sub _create_group {
    my ( $self, $sector, $min_level, $max_level, $categories ) = @_;

    # TODO: check if level range is valid, i.e. check against max creature level from DB

    return if $sector->creature_group;

    unless ( $self->{creature_types_by_level} ) {
        my %extra;
        if ($categories) {
            $extra{'category.name'} = $categories;
        }
        else {
            $extra{'category.standard'} = 1;
        }

        my @creature_types = $self->result_source->schema->resultset('CreatureType')->search(
            {
                %extra,
                'rare' => 0,
            },
            {
                join => 'category',
            },
        );

        croak "No types found\n" unless @creature_types;

        my @creature_types_by_level;
        foreach my $creature_type (@creature_types) {
            push @{ $creature_types_by_level[ $creature_type->level ] }, $creature_type;
        }

        $self->{creature_types_by_level} = \@creature_types_by_level;
    }

    my $cg = $self->create( {
            creature_group_id => undef,
    } );

    my $number_of_types = RPG::Maths->weighted_random_number( 1 .. 3 );

    my $number_in_group = int( rand 7 ) + 3;

    my %types_used;

    for ( 1 .. $number_of_types ) {
        my $level = RPG::Maths->roll_in_range( $min_level, $max_level );

        my $type;
        foreach my $available_type ( shuffle @{ $self->{creature_types_by_level}->[$level] } ) {
            next if $types_used{ $available_type->id };
            $type = $available_type;
        }

        next unless $type;

        $types_used{ $type->id } = 1;

        my $number_of_type = round $number_in_group / $number_of_types;

        for my $creature ( 1 .. $number_of_type ) {
            $cg->add_creature( $type, $creature );
        }
    }

    # Check if we found some valid creature types
    if ( $cg->creatures->count == 0 ) {
        die RPG::Exception->new(
            message => "Couldn't find any valid creature types for level range: $min_level .. $max_level",
            type => 'creature_type_error',
        );
    }

    return $cg;
}

sub create_in_dungeon {
    my ( $self, $sector, $min_level, $max_level, $categories ) = @_;

    my $cg = $self->_create_group( $sector, $min_level, $max_level, $categories );

    return unless $cg;

    $cg->dungeon_grid_id( $sector->id );
    $cg->update;

    return $cg;
}

# Find a CG in a dungeon room (ready for combat)
sub find_in_dungeon_room_for_combat {
    my $self   = shift;
    my %params = @_;

    my @cgs = $self->search(
        {
            'dungeon_grid.dungeon_room_id' => $params{sector}->dungeon_room_id,
        },
        {
            join => 'dungeon_grid',
        }
    );

    @cgs = grep { !$_->in_combat } @cgs;

    my $cg = ( shuffle @cgs )[0];

    return $cg;
}

1;
