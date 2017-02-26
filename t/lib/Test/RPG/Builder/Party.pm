use strict;
use warnings;

package Test::RPG::Builder::Party;

use Test::RPG::Builder::Character;

use DateTime;

sub build_party {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    unless ( $params{land_id} ) {
        my $location = $schema->resultset('Land')->find_or_create( { x => 1, y => 1 } );
        $params{land_id} = $location->id;
    }

    my $player_id;

    if ( !$params{player_id} ) {
        my $player = $schema->resultset('Player')->create(
            {
                player_name => int rand 100000000,

            }
        );

        $params{player_id} = $player->id;
    }

    my $party = $schema->resultset('Party')->create(
        {
            party_id                => $params{party_id},
            land_id                 => $params{land_id},
            player_id               => $params{player_id},
            rank_separator_position => $params{rank_separator_position} // 2,
            turns                   => $params{turns} // 100,
            gold                    => $params{gold} // 100,
            defunct                 => $params{defunct} || undef,
            last_action             => $params{last_action} || undef,
            in_combat_with          => $params{in_combat_with} || undef,
            combat_type             => $params{combat_type} || undef,
            dungeon_grid_id         => $params{dungeon_grid_id} || undef,
            kingdom_id              => $params{kingdom_id} || undef,
            turns_used              => $params{turns_used} // 0,
            created                 => $params{created} // DateTime->now(),
            name                    => $params{name} // 'test',
            last_action             => $params{last_action} || DateTime->now(),
            warned_for_kingdom_co_op => $params{warned_for_kingdom_co_op} || undef,
            bonus_turns_today => 0,

        }
    );

    if ( $params{character_count} ) {
        for ( 1 .. $params{character_count} ) {
            Test::RPG::Builder::Character->build_character(
                $schema,
                party_id    => $party->id,
                level       => $params{character_level},
                party_order => $_,
                %params,
            );
        }
    }

    return $party;
}

1;
