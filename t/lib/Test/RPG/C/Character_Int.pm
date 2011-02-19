use strict;
use warnings;

package Test::RPG::C::Character_Int;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;

use RPG::C::Character;

sub test_update_spells : Tests(14) {
    my $self = shift;

    my $character = Test::RPG::Builder::Character->build_character( $self->{schema} );
    $character->spell_points(10);
    $character->character_name('Foo');
    $character->update;

    my $spell1 = $self->{schema}->resultset('Spell')->create(
        {
            points   => 1,
            class_id => $character->class_id,
            hidden   => 0,
            spell_name => 'Energy Beam', 
        }
    );

    my $spell2 = $self->{schema}->resultset('Spell')->create(
        {
            points   => 5,
            class_id => $character->class_id,
            hidden   => 0,
            spell_name => 'Shield',
        }
    );

    my $spell3 = $self->{schema}->resultset('Spell')->create(
        {
            points   => 3,
            class_id => $character->class_id,
            hidden   => 0,
            spell_name => 'Bless',
        }
    );

    my $memorised_spell1 = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id            => $character->id,
            spell_id                => $spell1->id,
            memorised_today         => 1,
            memorise_count          => 2,
            memorise_tomorrow       => 0,
            memorise_count_tomorrow => 0,
        }
    );

    my $memorised_spell2 = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id            => $character->id,
            spell_id                => $spell2->id,
            memorised_today         => 0,
            memorise_count          => 0,
            memorise_tomorrow       => 1,
            memorise_count_tomorrow => 1,
        }
    );

    my $memorised_spell3 = $self->{schema}->resultset('Memorised_Spells')->create(
        {
            character_id            => $character->id,
            spell_id                => $spell3->id,
            memorised_today         => 1,
            memorise_count          => 1,
            memorise_tomorrow       => 0,
            memorise_count_tomorrow => 0,
        }
    );

    $self->{mock_forward}{check_action_allowed} = sub { };
    $self->{mock_forward}{'/character/view'} = sub { };

    $self->{stash}{character} = $character;

    $self->{params} = {
        'mem_tomorrow_' . $spell1->id => 1,
        'mem_tomorrow_' . $spell2->id => 2,
        'mem_tomorrow_' . $spell3->id => 0,
    };

    RPG::C::Character->update_spells( $self->{c} );

    like( $self->{stash}->{error}, qr/doesn't have enough spell points to memorise those spells/,
        "Can't exceed spell points when memorising spells" );

    $self->{params} = {
        'mem_tomorrow_' . $spell1->id => 5,
        'mem_tomorrow_' . $spell2->id => 1,
        'mem_tomorrow_' . $spell3->id => 0,
    };
    $self->{stash}->{error} = undef;

    RPG::C::Character->update_spells( $self->{c} );

    is( $self->{stash}->{error}, undef, "No error occured" );

    $memorised_spell1 = $self->{schema}->resultset('Memorised_Spells')->find( $memorised_spell1->id );
    is( $memorised_spell1->memorise_tomorrow,       1, "Spell 1 memorised tomorrow" );
    is( $memorised_spell1->memorise_count_tomorrow, 5, "Spell 1 memorised tomorrow count correct" );
    is( $memorised_spell1->memorised_today,         1, "Spell 1 memorised today unaffected" );
    is( $memorised_spell1->memorise_count,          2, "Spell 1 memorised count unaffected" );

    $memorised_spell2 = $self->{schema}->resultset('Memorised_Spells')->find( $memorised_spell2->id );
    is( $memorised_spell2->memorise_tomorrow,       1, "Spell 2 memorised tomorrow" );
    is( $memorised_spell2->memorise_count_tomorrow, 1, "Spell 2 memorised tomorrow count correct" );
    is( $memorised_spell2->memorised_today,         0, "Spell 2 memorised today unaffected" );
    is( $memorised_spell2->memorise_count,          0, "Spell 2 memorised count unaffected" );


    $memorised_spell3 = $self->{schema}->resultset('Memorised_Spells')->find( $memorised_spell3->id );
    is( $memorised_spell3->memorise_tomorrow,       0, "Spell 3 not memorised tomorrow" );
    is( $memorised_spell3->memorise_count_tomorrow, 0, "Spell 3 memorised tomorrow count correct" );
    is( $memorised_spell3->memorised_today,         1, "Spell 3 memorised today unaffected" );
    is( $memorised_spell3->memorise_count,          1, "Spell 3 memorised count unaffected" );

}

sub test_bury : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3);
	$party->rank_separator_position(3);
	my @characters = $party->characters;
	
	$self->{stash}{character} = $characters[2];
	$self->{stash}{party_location} = $party->location;
	$self->{params}{epitaph} = 'epitaph';
	$self->{stash}{party} = $party;
	
	# WHEN
	RPG::C::Character->bury( $self->{c} );
	
	# THEN
	my @graves = $self->{schema}->resultset('Grave')->search;
	is(scalar @graves, 1, "Grave created");
	
	is($characters[2]->in_storage, 0, "Character deleted");
	
	$party->discard_changes;
	is($party->rank_separator_position, 1, "Rank separator moved");
	
}

1;
