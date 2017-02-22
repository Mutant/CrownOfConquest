use strict;
use warnings;

package Test::RPG::Schema::Kingdom;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Character;

sub test_border_sectors : Tests(5) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5 );
    foreach my $land (@land) {
        next if $land->x == 1 and $land->y == 1;

        $land->kingdom_id( $kingdom->id );
        $land->update;
    }

    # WHEN
    my @border_sectors = $kingdom->border_sectors;

    # THEN
    is( scalar @border_sectors, 2, "2 border sectors" );
    is( $border_sectors[0]->{x}, 1, "Correct x location of first border sector" );
    is( $border_sectors[0]->{y}, 2, "Correct y location of first border sector" );

    is( $border_sectors[1]->{x}, 2, "Correct x location of second border sector" );
    is( $border_sectors[1]->{y}, 1, "Correct y location of second border sector" );
}

sub test_king : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );

    # WHEN
    my $king = $kingdom->king;

    # THEN
    isa_ok( $king, 'RPG::Schema::Character', "King returned" );
}

sub test_quests_allowed : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5, kingdom_id => $kingdom->id );

    $self->{config}{land_per_kingdom_quests} = 10;
    $self->{config}{minimum_kingdom_quests}  = 2;

    # WHEN
    my $quests_allowed = $kingdom->quests_allowed;

    # THEN
    is( $quests_allowed, 3, "3 quests allowed" );

}

sub test_quests_allowed_with_leadership : Tests(1) {
    my $self = shift;

    # GIVEN
    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $king    = $kingdom->king;
    my @land = Test::RPG::Builder::Land->build_land( $self->{schema}, 'x_size' => 5, 'y_size' => 5, kingdom_id => $kingdom->id );

    $self->{config}{land_per_kingdom_quests} = 10;
    $self->{config}{minimum_kingdom_quests}  = 2;

    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Leadership',
        }
    );

    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id     => $skill->id,
            character_id => $king->id,
            level        => 5,
        }
    );

    # WHEN
    my $quests_allowed = $kingdom->quests_allowed;

    # THEN
    is( $quests_allowed, 8, "8 quests allowed" );

}

1;
