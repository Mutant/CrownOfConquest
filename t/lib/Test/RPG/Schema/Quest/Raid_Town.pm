use strict;
use warnings;

package Test::RPG::Schema::Quest::Raid_Town;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Town;

sub test_set_quest_params : Tests(8) {
    my $self = shift;

    # GIVEN
    my $schema = $self->{schema};
    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town         = Test::RPG::Builder::Town->build_town( $schema, land_id => $land[0]->id );
    my $town_to_raid = Test::RPG::Builder::Town->build_town( $schema, land_id => $land[8]->id );

    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'raid_town' } );

    $self->{config}{quest_type_vars}{raid_town}{initial_search_range} = 3;
    $self->{config}{quest_type_vars}{raid_town}{xp_per_distance}      = 1;
    $self->{config}{quest_type_vars}{raid_town}{gold_per_distance}    = 1;
    $self->{config}{quest_type_vars}{raid_town}{min_level}            = 6;

    $self->mock_dice;
    $self->{rolls} = [ 50, 2 ];

    # WHEN
    my $quest = $schema->resultset('Quest')->create(
        {
            town_id       => $town->id,
            quest_type_id => $quest_type->id,
        }
    );

    # THEN
    is( $quest->quest_type_id, $quest_type->id, "Quest is of the correct type" );
    isa_ok( $quest, 'RPG::Schema::Quest::Raid_Town', "Quest blessed into correct class" );
    is( $quest->param_start_value('Town To Raid'), $town_to_raid->id, "Town to raid param set correctly" );
    is( $quest->param_start_value('Raided Town'),  0,                 "Raided Town param set correctly" );
    is( $quest->min_level,                         6,                 "Minimum level set correctly" );
    is( $quest->xp_value,                          2,                 "Xp value set correctly" );
    is( $quest->gold_value,                        20,                "Gold value set correctly" );
    is( $quest->days_to_complete,                  4,                 "Days to complete set correctly" );

}

1;
