use strict;
use warnings;

package Test::RPG::Builder::CreatureGroup;

use Test::RPG::Builder::Creature;

sub build_cg {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my %cg_params;
    $cg_params{land_id}         = $params{land_id}         if defined $params{land_id};
    $cg_params{dungeon_grid_id} = $params{dungeon_grid_id} if defined $params{dungeon_grid_id};
    $cg_params{creature_group_id} = $params{creature_group_id};

    my $cg = $schema->resultset('CreatureGroup')->create( {%cg_params} );
    
    unless ($params{type_id}) {
    	my $type = $schema->resultset('CreatureType')->create( { level => $params{creature_level} || 1 } );
    	
    	$params{type_id} = $type->id;
    }

    my $creature_count = $params{creature_count} || 3;
    for ( 1 .. $creature_count ) {
        Test::RPG::Builder::Creature->build_creature(
            $schema,
            %params,
            type_id => $params{type_id},
            cg_id   => $cg->id,
        );
    }

    return $cg;
}

1;
