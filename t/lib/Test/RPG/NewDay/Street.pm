use strict;
use warnings;

package Test::RPG::NewDay::Street;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Town;
use Test::RPG::Builder::Day;
use Test::RPG::Builder::Item;

sub setup : Test(setup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Action::Street';

    $self->setup_context;    
}

sub test_character_killed : Tests(4) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	my $day = Test::RPG::Builder::Day->build_day($self->{schema});
	
	$character->status('street');
	$character->status_context($town->id);
	$character->update;
	
	$self->mock_dice;
	$self->{roll_result} = 3;
	
	my $action = RPG::NewDay::Action::Street->new( context => $self->{mock_context} );
	
	# WHEN
	$action->run();
	
	# THEN
	$character->discard_changes;
	is($character->status, 'morgue', "Character is now in the morgue");
	is($character->status_context, $town->id, "Character still in same town");
	is($character->hit_points, 0, "Character on 0 hit points");
	
	my @messages = $party->messages;
	is(scalar @messages, 1, "1 party message created");	
}

sub test_character_robbed : Tests(5) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party($self->{schema});
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, party_id => $party->id);
	my $town = Test::RPG::Builder::Town->build_town($self->{schema});
	my $day = Test::RPG::Builder::Day->build_day($self->{schema});
	my $item = Test::RPG::Builder::Item->build_item($self->{schema}, char_id => $character->id);
	
	$character->status('street');
	$character->status_context($town->id);
	$character->update;
	
	$self->mock_dice;
	$self->{rolls} = [50, 3, 1];
	
	my $action = RPG::NewDay::Action::Street->new( context => $self->{mock_context} );
	
	# WHEN
	$action->run();
	
	# THEN
	$character->discard_changes;
	is($character->status, 'street', "Character is still on the street");
	is($character->status_context, $town->id, "Character still in same town");
	
	$item->discard_changes;
	is($item->in_storage, 0, "Item deleted");
	
	my @messages = $party->messages;
	is(scalar @messages, 1, "1 party message created");
	like($messages[0]->message, qr/lost the following items: Test1/, "Correct party message");
}

1;