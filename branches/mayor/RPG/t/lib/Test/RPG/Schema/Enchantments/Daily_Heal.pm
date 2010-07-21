use strict;
use warnings;

package Test::RPG::Schema::Enchantments::Daily_Heal;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Item;
use Test::RPG::Builder::Character;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Item_Type;
use Test::RPG::Builder::Day;

sub test_startup : Tests(startup => 1) {
	my $self = shift;
	
	use_ok('RPG::Schema::Enchantments::Daily_Heal');
}

sub test_new_day : Tests(3) {
	my $self = shift;
	
	# GIVEN
	my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
	my $character = Test::RPG::Builder::Character->build_character($self->{schema}, hit_points => 5, max_hit_points => 10, party_id => $party->id );
	my $item = Test::RPG::Builder::Item->build_item( $self->{schema}, char_id => $character->id, enchantments => ['daily_heal'] );
	$item->variable_row('Daily Heal', '4');
	$item->variable_row('Must Be Equipped', '0');
	my $new_day = Test::RPG::Builder::Day->build_day( $self->{schema} );	
	
	my $mock_day_context = Test::MockObject->new();
	$mock_day_context->set_always('current_day', $new_day);
	
	# WHEN
	my ($enchantment) = $item->item_enchantments;
	$enchantment->new_day($mock_day_context);
	
	# THEN
	$character->discard_changes;
	is($character->hit_points, 9, "Character healed");
	
	my @logs = $party->day_logs;
	is(scalar @logs, 1, "1 daily log added");
	is($logs[0]->log, "test was healed 4 hit points by his Test1", 'log line created correctly');
	
}

1;