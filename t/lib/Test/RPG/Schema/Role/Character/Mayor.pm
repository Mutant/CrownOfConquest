use strict;
use warnings;

package Test::RPG::Schema::Role::Character::Mayor;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Party;

sub test_lose_mayoralty_not_killed : Tests(6) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, mayor_of => $town->id );
    my $garrison_char = Test::RPG::Builder::Character->build_character( $self->{schema},
        party_id => $party->id, status => 'mayor_garrison', status_context => $town->id
    );

    $mayor->update( { creature_group_id => 1 } );
    $garrison_char->update( { creature_group_id => 1 } );

    my $history_rec = $self->{schema}->resultset('Party_Mayor_History')->create(
        {
            party_id          => $party->id,
            town_id           => $town->id,
            got_mayoralty_day => 1,
        }
    );

    # WHEN
    $town->mayor->lose_mayoralty(0);

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of,          undef, "Mayor has lost mayoralty" );
    is( $mayor->creature_group_id, undef, "Mayor no longer in cg" );
    is( $mayor->status,            'inn', "Mayor moved to the inn" );

    $garrison_char->discard_changes;
    is( $garrison_char->status, 'inn', "Garrison char moved to the inn" );
    is( $garrison_char->creature_group_id, undef, "Garrison char no longer in cg" );

    $history_rec->discard_changes;
    is( $history_rec->lost_mayoralty_day, $self->{stash}{today}->id, "Lost mayoarlty day is set" );
}

sub test_lose_mayoralty_killed : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town  = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, mayor_of => $town->id );
    my $garrison_char = Test::RPG::Builder::Character->build_character( $self->{schema},
        party_id => $party->id, status => 'mayor_garrison', status_context => $town->id
    );

    $mayor->update( { creature_group_id => 1 } );
    $garrison_char->update( { creature_group_id => 1 } );

    # WHEN
    $town->mayor->lose_mayoralty(1);

    # THEN
    $mayor->discard_changes;
    is( $mayor->mayor_of,          undef,    "Mayor has lost mayoralty" );
    is( $mayor->creature_group_id, undef,    "Mayor no longer in cg" );
    is( $mayor->status,            'morgue', "Mayor moved to the morgue" );
    is( $mayor->hit_points,        0,        "Mayor is dead" );

    $garrison_char->discard_changes;
    is( $garrison_char->status, 'morgue', "Garrison char moved to the morgue" );
    is( $garrison_char->creature_group_id, undef, "Garrison char no longer in cg" );
    is( $garrison_char->hit_points, 0, "Garrison char is dead" );
}

sub test_mayors_df_increased : Tests(1) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 60 );
    my $char = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, mayor_of => $town->id, agility => 10 );
    $char->calculate_defence_factor;
    $char->update;

    my $mayor = $town->mayor;

    # WHEN
    my $df = $mayor->defence_factor;

    # THEN
    is( $df, 13, "Mayor's df increased" );

}

sub test_create_creature_group : Tests() {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, prosperity => 60 );
    my $mayor = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, mayor_of => $town->id );

    foreach my $garrison_char ( $party->characters ) {
        $garrison_char->status('mayor_garrison');
        $garrison_char->status_context( $town->id );
        $garrison_char->update;
    }

    # WHEN
    $town->mayor->create_creature_group();

    # THEN
    $mayor->discard_changes;
    my $cg = $mayor->creature_group;

    is( defined $cg, 1, "Mayor's cg created" );

    foreach my $garrison_char ( $party->characters ) {
        is( $garrison_char->creature_group_id, $cg->id, "Garrison char in CG" );
    }

}

1;
