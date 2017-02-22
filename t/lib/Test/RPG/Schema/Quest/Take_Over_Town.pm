use strict;
use warnings;

package Test::RPG::Schema::Quest::Take_Over_Town;

use base qw(Test::RPG::DB);

use Test::More;

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Land;

sub test_find_town_with_mayor_not_loyal_to_any_kingdom : Tests(1) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};

    my @land = Test::RPG::Builder::Land->build_land( $schema, x_size => 5, 'y_size' => 5 );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($schema);
    foreach my $land (@land) {
        $land->kingdom_id( $kingdom->id );
        $land->update;
    }

    my $town = Test::RPG::Builder::Town->build_town( $schema, land_id => $land[0]->id );
    my $party = Test::RPG::Builder::Party->build_party( $schema, character_count => 2, land_id => $land[5]->id );
    my $character = ( $party->characters )[0];
    $character->mayor_of( $town->id );
    $character->update;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'take_over_town' } );

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            kingdom_id    => $kingdom->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->param_start_value('Town To Take Over'), $town->id, "Town to take over set correctly" );

}

sub test_find_town_with_mayor_loyal_to_another_kingdom : Tests(1) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};

    my @land = Test::RPG::Builder::Land->build_land( $schema, x_size => 5, 'y_size' => 5 );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($schema);
    foreach my $land (@land) {
        $land->kingdom_id( $kingdom->id );
        $land->update;
    }

    my $town = Test::RPG::Builder::Town->build_town( $schema, land_id => $land[0]->id );
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($schema);
    my $party = Test::RPG::Builder::Party->build_party( $schema, character_count => 2, land_id => $land[5]->id, kindom_id => $kingdom2->id );
    my $character = ( $party->characters )[0];
    $character->mayor_of( $town->id );
    $character->update;

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'take_over_town' } );

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            kingdom_id    => $kingdom->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->param_start_value('Town To Take Over'), $town->id, "Town to take over set correctly" );

}

sub test_find_town_near_border : Tests(1) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};

    my @land = Test::RPG::Builder::Land->build_land( $schema, x_size => 5, 'y_size' => 5 );
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom($schema);
    foreach my $land (@land) {
        next if $land->x == 1 && $land->y == 1;

        $land->kingdom_id( $kingdom->id );
        $land->update;
    }
    my $town = Test::RPG::Builder::Town->build_town( $schema, land_id => $land[0]->id );

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'take_over_town' } );

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            kingdom_id    => $kingdom->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->param_start_value('Town To Take Over'), $town->id, "Town to take over set correctly" );

}

1;
