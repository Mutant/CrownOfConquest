use strict;
use warnings;

package Test::RPG::Builder::CreatureGroup;

sub build_cg {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my %cg_params;
    $cg_params{land_id} = $params{land_id} if defined $params{land_id}; 

    my $cg = $schema->resultset('CreatureGroup')->create( 
        { 
            %cg_params
        } 
    );
    my $type = $schema->resultset('CreatureType')->create({});
    
    my $creature_count = $params{creature_count} || 3;
    for (1 .. $creature_count) {    
        my %creature_params;
        $creature_params{hit_points_current} = defined $params{creature_hit_points_current} ? $params{creature_hit_points_current} : 5;
        $schema->resultset('Creature')->create(      
            { 
                creature_group_id => $cg->id,                
                creature_type_id => $type->id,
                %creature_params, 
            } 
        );
    }
    
    return $cg;
}

1;