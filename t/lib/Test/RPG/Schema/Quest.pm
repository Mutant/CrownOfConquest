use strict;
use warnings;

package Test::RPG::Schema::Quest;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Quest;
use Test::RPG::Builder::Quest::Destroy_Orb;

use Test::More;
use Test::MockObject;

sub startup : Tests(startup=>1) {
    my $self = shift;

    use_ok('RPG::Schema::Quest');
}

sub teardown : Tests(shutdown) {
    my $self = shift;

    $self->unmock_dice;
}

sub setup_data : Tests(setup) {
    my $self = shift;

    $self->mock_dice;

    $self->{quest_type} = $self->{schema}->resultset('Quest_Type')->create(
        {
            quest_type => 'kill_creatures_near_town',
        }
    );

    $self->{quest_param_name_1} = $self->{schema}->resultset('Quest_Param_Name')->create(
        {
            quest_param_name => 'Number Of Creatures To Kill',
            quest_type_id    => $self->{quest_type}->id,
        }
    );

    $self->{quest_param_name_2} = $self->{schema}->resultset('Quest_Param_Name')->create(
        {
            quest_param_name => 'Range',
            quest_type_id    => $self->{quest_type}->id,
        }
    );

}

sub test_create_quest : Tests(7) {
    my $self = shift;

    $self->{roll_result} = 1;

    my $quest = $self->{schema}->resultset('Quest')->create(
        {
            quest_type_id => $self->{quest_type}->id,
            town_id       => 1,
        },
    );

    isa_ok( $quest, 'RPG::Schema::Quest::Kill_Creatures_Near_Town', "Quest created with correct class" );

    $quest = $self->{schema}->resultset('Quest')->find( $quest->id );

    isa_ok( $quest, 'RPG::Schema::Quest::Kill_Creatures_Near_Town', "queried Quest with correct class" );

    my @quest_params = $quest->quest_params;
    is( scalar @quest_params, 2, "2 Quest params created" );

    my %quest_params_by_name = $quest->quest_params_by_name;
    is( $quest->param_start_value('Number Of Creatures To Kill'), 2, "Number of creatures to kill start value set correctly" );
    is( $quest->param_current_value('Number Of Creatures To Kill'), 2, "Number of creatures to kill current value set correctly" );
    is( $quest->param_current_value('Range'), 3, "Range start value set correctly" );
    is( $quest->param_start_value('Range'), 3, "Range current value set correctly" );
}

sub test_set_complete_town_quest : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, gold => 100, character_count => 2 );
    my $quest = Test::RPG::Builder::Quest::Destroy_Orb->build_quest( $self->{schema}, party_id => $party->id );
    $quest->gold_value(100);
    $quest->xp_value(100);
    $quest->update;

    # WHEN
    my @details = $quest->set_complete;

    # THEN
    $quest->discard_changes;

    is( $quest->status, 'Complete', "Quest status now complete" );

    $party->discard_changes;
    is( $party->gold, 200, "Gold added to party" );

    is( scalar @details,           2,  "2 xp details elements returned" );
    is( $details[0]->{xp_awarded}, 50, "first character got half the xp" );
    is( $details[1]->{xp_awarded}, 50, "second character got half the xp" );

    is( $quest->town->mayor_rating, 3, "Town's mayor rating increased" );

    my $party_town = $self->{schema}->resultset('Party_Town')->find(
        {
            party_id => $party->id,
            town_id  => $quest->town->id,
        }
    );
    is( $party_town->prestige, 3, "Party's prestige increased by 3" );
}

sub test_set_complete_kingdom_quest : Tests(5) {
    my $self = shift;

    # GIVEN
    my $kindgom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $quest = Test::RPG::Builder::Quest->build_quest( $self->{schema}, quest_type => 'claim_land', kingdom_id => $kindgom->id, party_id => $party->id );
    $quest->gold_value(100);
    $quest->xp_value(100);
    $quest->update;

    # WHEN
    my @details = $quest->set_complete;

    # THEN
    $quest->discard_changes;

    is( $quest->status, 'Complete', "Quest status now complete" );

    $party->discard_changes;
    is( $party->gold, 200, "Gold added to party" );

    is( scalar @details,           2,  "2 xp details elements returned" );
    is( $details[0]->{xp_awarded}, 50, "first character got half the xp" );
    is( $details[1]->{xp_awarded}, 50, "second character got half the xp" );
}

1;
