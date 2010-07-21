use strict;
use warnings;

package Test::RPG::Builder::Creature;

sub build_creature {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;
    
    unless ($params{type_id}) {
        my $type = $schema->resultset('CreatureType')->create( { level => $params{creature_level} || 1 } );
        $params{type_id} = $type->id;        
    }

    my %creature_params;
    $creature_params{hit_points_current} = defined $params{creature_hit_points_current} ? $params{creature_hit_points_current} : 5;
    $creature_params{hit_points_max} =  $params{hit_points_max} // $creature_params{hit_points_current};
    my $creature = $schema->resultset('Creature')->create(
        {
            creature_group_id => $params{cg_id} || 1,
            creature_type_id  => $params{type_id},
            %creature_params,
        }
    );

    return $creature;
}

1;