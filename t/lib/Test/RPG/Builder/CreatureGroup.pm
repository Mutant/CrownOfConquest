use strict;
use warnings;

package Test::RPG::Builder::CreatureGroup;

use Test::RPG::Builder::Creature;

sub build_cg {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my %cg_params;
    $cg_params{land_id} = $params{land_id} if defined $params{land_id};

    my $cg = $schema->resultset('CreatureGroup')->create( {%cg_params} );
    my $type = $schema->resultset('CreatureType')->create( { level => $params{creature_level} || 1 } );

    my $creature_count = $params{creature_count} || 3;
    for ( 1 .. $creature_count ) {
        Test::RPG::Builder::Creature->build_creature(
            $schema,
            %params,
            type_id => $type->id,
            cg_id => $cg->id,
        );
    }

    return $cg;
}

1;
