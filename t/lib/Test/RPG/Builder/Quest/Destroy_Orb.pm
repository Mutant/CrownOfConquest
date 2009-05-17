use strict;
use warnings;

package Test::RPG::Builder::Quest::Destroy_Orb;

use Test::RPG::Builder::Land;

sub build_quest {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my @land = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, } );

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'destroy_orb' } );

    my $orb = $schema->resultset('Creature_Orb')->create(
        {
            level   => 1,
            land_id => $land[0]->id,
        }
    );

    my %create_params;
    if ( $params{party_id} ) {
        $create_params{party_id} = $params{party_id};
    }

    my $quest = $schema->resultset('Quest')->create(
        {
            town_id       => $town->id,
            quest_type_id => $quest_type->id,
            status        => $params{status} || 'Not Started',
            %create_params,
        }
    );

    return $quest;

}

1;
