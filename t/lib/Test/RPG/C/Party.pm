use strict;
use warnings;

package Test::RPG::C::Party;

use base qw(Test::RPG);

#__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use RPG::C::Party;

use Data::Dumper;

sub test_swap_chars : Tests(37) {
	my $self = shift;
		
	my @characters;
	for (1..5) {
		my $character = Test::MockObject->new();
		$character->{party_order} = $_;
		$character->mock('party_order', sub { $_[0]->{party_order_set_to} = $_[1] if $_[1]; $_[0]->{party_order} } );
		$character->set_always('id', $_);
		$character->set_true('update');
		$character->{id} = $_;
		$character->{party_order} = $_;
		push @characters, $character;
	}	
	
	my $party = Test::MockObject->new();
	$party->mock('characters', sub { @characters });
	$party->set_always('rank_separator_position', 2);
	$party->set_always('update');
	
	$self->{stash} = {
		party => $party,
	};
	
	my @tests = (
		{
			moved => 2,
			target => 4,
			drop_pos => 'before',
		},
		{
			moved => 1,
			target => 5,			
			drop_pos => 'after',
		},
		{
			moved => 4,
			target => 2,
			drop_pos => 'after',
		},
		{
			moved => 3,
			target => 4,
			drop_pos => 'before',
		},
		{
			moved => 3,
			target => 4,
			drop_pos => 'after',
		},
	);
	
	foreach my $test (@tests) {
		map { $_->clear; $_->{party_order_set_to} = undef; } @characters;
		
		$self->{params} = $test;
		
		my $moved  = $test->{moved};
		my $target = $test->{target};

		my $operater = $moved > $target ? '+1' : '-1';
		my ($upper_bound, $lower_bound) = sort ($moved, $target);
		
		my $adjusted_target = 0;
		if ($test->{drop_pos} eq 'after' && $moved > $target) {
			$upper_bound++;
			$target++;
			$adjusted_target = 1;	
		}
		elsif ($test->{drop_pos} eq 'before' && $moved < $target) {
			$lower_bound--;
			$target--;
			$adjusted_target = 1;	
		}
		
		RPG::C::Party->swap_chars($self->{c});
		
		my ($method, $args);
		
		my $count = 1;
		foreach my $character (@characters) {
			if ($count == $moved) {
				($method, $args) = $characters[$count-1]->next_call(5);
						
				is($method, 'party_order', "Moved character $count has party order set");
				is($args->[1], $target, "Set to position of target char");
			}
			elsif ($count == $target) {
				# If the target has been adjusted (due to before/after mattering), we have one less call on the target
				#  since it wasn't the original target as far as the code is concerned
				($method, $args) = $characters[$count-1]->next_call($adjusted_target ? 6 : 7);
				
				is($method, 'party_order', "party order set on target character $count");
				is($args->[1], $character->{id} + $operater, "Set to correct position");
			}
			elsif ($count > $upper_bound and $count < $lower_bound) {
				($method, $args) = $characters[$count-1]->next_call(6);
				
				is($method, 'party_order', "party order set on character $count");
				is($args->[1], $character->{id} + $operater, "Set to correct position");
			}
			else {
				($method, $args) = $characters[$count-1]->next_call(6);
	
				is($method, undef, "party order call not made on character $count");
			}
			
			#warn "$count: " . $character->{party_order_set_to};
			
			$count++;
		}
	}
}

1;