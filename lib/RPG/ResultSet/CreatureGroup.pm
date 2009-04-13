use strict;
use warnings;

package RPG::ResultSet::CreatureGroup;

use base 'DBIx::Class::ResultSet';

use RPG::Maths;
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

    $land->creature_threat( $land->creature_threat + 5 );
    $land->update;

    return $cg;
}

sub _create_group {
    my ( $self, $sector, $min_level, $max_level ) = @_;

    # TODO: check if level range is valid, i.e. check against max creature level from DB

    return if $sector->creature_group;

    unless ($self->{creature_types_by_level}) {
        my @creature_types = $self->result_source->schema->resultset('CreatureType')->search();

        croak "No types found\n" unless @creature_types;
        
        my @creature_types_by_level;
        foreach my $creature_type (@creature_types) {
            push @{$creature_types_by_level[$creature_type->level]}, $creature_type;
        }
        
        $self->{creature_types_by_level} = \@creature_types_by_level;
    }   

    my $cg = $self->create( {} );
    
    my $number_of_types = RPG::Maths->weighted_random_number( 1 .. 3 );

    my $number_in_group = int( rand 7 ) + 3;
        
    for (1 .. $number_of_types) {
        my $level = RPG::Maths->weighted_random_number( $min_level .. $max_level );
    
        my $type = (shuffle @{$self->{creature_types_by_level}->[$level]})[0];
        
        croak "No types found for level: $level\n" unless $type;
       
        my $number_of_type = round $number_in_group / $number_of_types;    
   
        for my $creature ( 1 .. $number_of_type ) {
            my $hps = Games::Dice::Advanced->roll( $type->level . 'd8' );
    
            $cg->add_to_creatures(
                {
                    creature_type_id   => $type->id,
                    hit_points_current => $hps,
                    hit_points_max     => $hps,
                    group_order        => $creature,
                }
            );
        }
    }

    return $cg;
}

sub create_in_dungeon {
    my ( $self, $sector, $min_level, $max_level ) = @_;

    my $cg = $self->_create_group( $sector, $min_level, $max_level );

    return unless $cg;

    $cg->dungeon_grid_id( $sector->id );
    $cg->update;

    return $cg;
}

1;
