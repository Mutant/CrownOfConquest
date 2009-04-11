package Test::RPG::ResultSet::Character;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::Resub;

use Data::Dumper;

use RPG::ResultSet::Character;

sub test_allocate_stat_points_doesnt_exceed_max : Tests(5) {
    my $self = shift;

    # GIVEN
    my %stats = (
        'strength'     => 5,
        'agility'      => 5,
        'intelligence' => 5,
        'divinity'     => 5,
        'constitution' => 5,
    );
    my $stat_pool    = 25;
    my $stat_max     = 10;
    my $primary_stat = 'strength';

    # WHEN
    my %stats = RPG::ResultSet::Character->_allocate_stat_points( $stat_pool, $stat_max, $primary_stat, \%stats );

    # THEN
    is( $stats{strength},     10, "Strength at max" );
    is( $stats{agility},      10, "agility at max" );
    is( $stats{intelligence}, 10, "intelligence at max" );
    is( $stats{divinity},     10, "divinity at max" );
    is( $stats{constitution}, 10, "constitution at max" );

}

sub test_create_character_level_1 : Tests(12) {
    my $self = shift;

    # GIVEN
    my $race = $self->{schema}->resultset('Race')->find( { race_name => 'Human', } );
    my $class = $self->{schema}->resultset('Class')->find( { class_name => 'Mage', } );

    $self->{config}->{stats_pool}                 = 30;
    $self->{config}->{stat_max}                   = 18;
    $self->{config}->{data_file_path}             = 'data/';
    $self->{config}->{level_hit_points_max}{Mage} = 4;
    $self->{config}->{level_spell_points_max}     = 5;
    $self->{config}->{point_dividend}             = 10;

    # WHEN
    my $character = $self->{schema}->resultset('Character')->generate_character( $race, $class, 1, 0, );

    # THEN
    is( $character->race_id,  $race->id,  "Character is correct race" );
    is( $character->class_id, $class->id, "Character is correct class" );
    is( $character->level,    1,          "Character is level 1" );
    is( $character->xp,       0,          "Character has 0 xp" );
    ok( $character->max_hit_points >= 4, "Character has correct number of hit points" );
    ok( $character->spell_points >= 5,   "Character has correct number of spell points" );
    is( $character->hit_points, $character->max_hit_points, "Character's current hit points is at max" );
    ok( $character->strength >= 5     && $character->strength <= 18,     "Character's strength in correct range" );
    ok( $character->agility >= 5      && $character->agility <= 18,      "Character's agility in correct range" );
    ok( $character->divinity >= 5     && $character->divinity <= 18,     "Character's divinity in correct range" );
    ok( $character->constitution >= 5 && $character->constitution <= 18, "Character's constitution in correct range" );
    ok( $character->intelligence >= 5 && $character->intelligence <= 18, "Character's intelligence in correct range" );
}

sub test_create_character_level_1_points_not_rolled : Tests(12) {
    my $self = shift;

    # GIVEN
    my $race = $self->{schema}->resultset('Race')->find( { race_name => 'Human', } );
    my $class = $self->{schema}->resultset('Class')->find( { class_name => 'Mage', } );

    $self->{config}->{stats_pool}                 = 30;
    $self->{config}->{stat_max}                   = 18;
    $self->{config}->{data_file_path}             = 'data/';
    $self->{config}->{level_hit_points_max}{Mage} = 4;
    $self->{config}->{level_spell_points_max}     = 5;
    $self->{config}->{point_dividend}             = 10;

    # WHEN
    my $character = $self->{schema}->resultset('Character')->generate_character( $race, $class, 1, 0, 0, );

    # THEN
    is( $character->race_id,        $race->id,  "Character is correct race" );
    is( $character->class_id,       $class->id, "Character is correct class" );
    is( $character->level,          1,          "Character is level 1" );
    is( $character->xp,             0,          "Character has 0 xp" );
    is( $character->max_hit_points, undef,      "Max hit points not set" );
    is( $character->spell_points,   undef,      "Spell points not set" );
    is( $character->hit_points,     undef,      "Character's current hit points not set" );
    ok( $character->strength >= 5     && $character->strength <= 18,     "Character's strength in correct range" );
    ok( $character->agility >= 5      && $character->agility <= 18,      "Character's agility in correct range" );
    ok( $character->divinity >= 5     && $character->divinity <= 18,     "Character's divinity in correct range" );
    ok( $character->constitution >= 5 && $character->constitution <= 18, "Character's constitution in correct range" );
    ok( $character->intelligence >= 5 && $character->intelligence <= 18, "Character's intelligence in correct range" );
}

sub test_create_character_level_5 : Tests(7) {
    my $self = shift;

    # GIVEN
    my $race = $self->{schema}->resultset('Race')->find( { race_name => 'Human', } );
    my $class = $self->{schema}->resultset('Class')->find( { class_name => 'Mage', } );

    $self->{config}->{stats_pool}                 = 30;
    $self->{config}->{stat_max}                   = 18;
    $self->{config}->{data_file_path}             = 'data/';
    $self->{config}->{level_hit_points_max}{Mage} = 4;
    $self->{config}->{level_spell_points_max}     = 5;
    $self->{config}->{point_dividend}             = 10;
    $self->{config}->{stat_points_per_level}      = 3;

    # WHEN
    my $character = $self->{schema}->resultset('Character')->generate_character( $race, $class, 5, 100, );

    # THEN
    is( $character->race_id,  $race->id,  "Character is correct race" );
    is( $character->class_id, $class->id, "Character is correct class" );
    is( $character->level,    5,          "Character is level 5" );
    is( $character->xp,       100,        "Character has 100 xp" );
    ok( $character->max_hit_points >= 8, "Character has correct number of hit points" );
    ok( $character->spell_points >= 9,   "Character has correct number of spell points" );
    is( $character->hit_points, $character->max_hit_points, "Character's current hit points is at max" );
}

1;
