use strict;
use warnings;

package Test::RPG::C::Party;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use RPG::C::Party;

use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party;

use Data::Dumper;

sub test_swap_chars : Tests(65) {
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
	$party->mock('rank_separator_position',  sub { $_[0]->{rank_sep_set_to} = $_[1] if $_[1]; $_[0]->{rank_sep} } );	
	$party->set_always('update');
	
	$self->{stash} = {
		party => $party,
	};	
	
	my @tests = (
		{
			moved => 2,
			target => 4,
			drop_pos => 'before',
			rank_separator_expected => 2,
		},
		{
			moved => 1,
			target => 5,			
			drop_pos => 'after',
			rank_separator_expected => 2,
		},
		{
			moved => 4,
			target => 2,
			drop_pos => 'after',
			rank_separator_expected => 4,
		},
		{
			moved => 3,
			target => 4,
			drop_pos => 'before',
			rank_separator_expected => 2,
		},
        {
			moved => 2,
			target => 3,
			drop_pos => 'after',
		},
        {
			moved => 3,
			target => 4,
			drop_pos => 'after',
			rank_separator_expected => 2,
		},
        {
			moved => 4,
			target => 3,
			drop_pos => 'after',
			rank_separator_expected => 4,
		},
        {
			moved => 4,
			target => 3,
			drop_pos => 'before',
			rank_separator_expected => 4,
		},
		
	);
	
	foreach my $test (@tests) {
		map { $_->clear; $_->{party_order_set_to} = undef; } @characters;
		$party->{rank_sep} = 3;
		$party->{rank_sep_set_to} = undef;
		
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
				
		is($party->{rank_sep_set_to}, $test->{rank_separator_expected}, "Rank separator in expected position");
		
		#warn "rank sep: " . $party->{rank_sep_set_to};
	}
}

sub test_sector_menu_confirm_attack_set : Tests {
    my $self = shift;
    
    # GIVEN    
    $self->{config}->{cg_attack_max_level_above_party} = 2;
    $self->{config}->{cg_attack_max_level_below_party} = 4;
    
    my @tests = (
        {
            cg_level => 1,
            party_level => 1,
            expected_result => 0,   
            name => 'cg and party level the same',
        },
        {
            cg_level => 3,
            party_level => 1,
            expected_result => 0,   
            name => 'cg level on the threshold',
        },    
        {
            cg_level => 4,
            party_level => 1,
            expected_result => 1,   
            name => 'cg level above the threshold',
        },            
    );
    
    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_ };
    
    $self->{mock_forward}->{'parties_in_sector'} = sub {};
    $self->{mock_forward}->{'/party/party_messages_check'} = sub {};
    
    my $mock_location = Test::MockObject->new();
    $mock_location->set_always('orb');
    $mock_location->set_always('id');
    
    $self->{c}->stash->{party_location} = $mock_location;    
    
    # WHEN
    my %results;
    foreach my $test (@tests) {
    
        my $creature_group = Test::RPG::Builder::CreatureGroup->build_cg(
            $self->{schema},
            creature_level => $test->{cg_level},
        );
        
        $self->{c}->stash->{creature_group} = $creature_group;
        
        my $party = Test::RPG::Builder::Party->build_party(
            $self->{schema},
            character_count => 3,
            character_level => $test->{party_level},
        );
        
        $self->{c}->stash->{party} = $party;
        
        RPG::C::Party->sector_menu($self->{c});
        
        $results{$test->{name}} = $template_args->[0][0]{params}{confirm_attack};        
    }    
    
    # THEN
    foreach my $test (@tests) {
        is($results{$test->{name}}, $test->{expected_result}, $test->{name} . " - Confirm attack set correctly");
    }
    
}

1;