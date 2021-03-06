use strict;
use warnings;

package Test::RPG::Builder::Character;

sub build_character {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

    my $race = $schema->resultset('Race')->create( { 'race_name' => 'test_race' } );

    my $class = $schema->resultset('Class')->create( { 'class_name' => $params{class} || 'test_class' } );

    my $character = $schema->resultset('Character')->create(
        {
            party_id                  => $params{party_id},
            race_id                   => $race->id,
            class_id                  => $class->id,
            hit_points                => $params{hit_points} // 10,
            max_hit_points            => $params{max_hit_points} // 10,
            party_order               => $params{party_order} || 1,
            character_name            => $params{name} || 'test',
            level                     => $params{level} || 1,
            gender                    => $params{gender} || 'male',
            xp                        => $params{xp} || 0,
            strength                  => $params{strength} || 10,
            constitution              => $params{constitution} || 10,
            agility                   => $params{agility} || 10,
            intelligence              => $params{intelligence} || 10,
            divinity                  => $params{divinity} || 10,
            stat_points               => 0,
            garrison_id               => $params{garrison_id},
            encumbrance               => 0,
            status                    => $params{status} || undef,
            status_context            => $params{status_context} || undef,
            mayor_of                  => $params{mayor_of} || undef,
            creature_group_id         => $params{creature_group_id} // undef,
            resist_fire               => 0,
            resist_ice                => 0,
            resist_poison             => 0,
            resist_fire_bonus         => 0,
            resist_ice_bonus          => 0,
            resist_poison_bonus       => 0,
            has_usable_actions_combat => 0,
            has_usable_actions_non_combat => 0,
        }
    );

    return $character;
}

1;
