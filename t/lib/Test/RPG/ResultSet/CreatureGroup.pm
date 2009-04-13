package Test::RPG::ResultSet::CreatureGroup;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::RPG::Builder::Land;

use Test::More;

sub test_create_in_wilderness_simple : Tests(5) {
    my $self = shift;

    # GIVEN
    my @land = Test::RPG::Builder::Land->build_land($self->{schema});

    $self->{creature_type_1} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 1,
        }
    );

    $self->{creature_type_2} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 2,
        }
    );

    $self->{creature_type_3} = $self->{schema}->resultset('CreatureType')->create(
        {
            creature_type => 'creature type',
            level         => 3,
        }
    );
    
    # WHEN
    my $cg = $self->{schema}->resultset('CreatureGroup')->create_in_wilderness(
        $land[0],
        1,
        1,
    );
    
    # THEN
    is($cg->land_id, $land[0]->id, "CG created in correct land");
    my @creatures = $cg->creatures;
    ok(scalar @creatures >= 3, "At least 3 creatures");
    ok(scalar @creatures <= 10, "No more than 10 creatures");
    is($creatures[0]->creature_type_id, $self->{creature_type_1}->id, "Creatures created of correct type");
    $land[0]->discard_changes;
    is($land[0]->creature_threat, 15, "Creature threat increased");

}

1;
