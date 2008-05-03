package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Math::Round qw(round);

sub main : Local {
	my ($self, $c) = @_;
	
	return $c->forward('RPG::V::TT',
        [{
            template => 'town/main.html',
			params => {
				town => $c->stash->{party}->location->town,
			},
			return_output => 1,
        }]
    );
}

sub shop_list : Local {
	my ($self, $c) = @_;
	
	$c->stash->{bottom_panel} = $c->forward('RPG::V::TT',
        [{
            template => 'town/shop_list.html',
			params => {
				town => $c->stash->{party}->location->town,
			},
			return_output => 1,
        }]
    );
    
    $c->forward('/party/main');
}

sub healer : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party}->location->town;
	
	my @characters = $c->stash->{party}->characters;
	
	my ($cost_to_heal, @dead_chars) = _get_party_health($town, @characters);
	
	$c->stash->{bottom_panel} = $c->forward('RPG::V::TT',
        [{
            template => 'town/healer.html',
			params => {
				cost_to_heal => $cost_to_heal,
				dead_characters => \@dead_chars, 
				town => $town,
			},
			return_output => 1,
        }]
    );
    
    $c->forward('/party/main');
}

sub heal_party : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party}->location->town;
	
	my @characters = $c->stash->{party}->characters;
	
	my ($cost_to_heal, @dead_chars) = _get_party_health($town, @characters);
	
	# TODO: if they don't have enough gold, we should just heal as much as we can
	if ($cost_to_heal <= $c->stash->{party}->gold) {
		$c->stash->{party}->gold($c->stash->{party}->gold - $cost_to_heal);
		$c->stash->{party}->update;
		
		foreach my $character (@characters) {
			next if $character->is_dead;
			$character->hit_points($character->max_hit_points);
			$character->update;
		}
	}
	
	$c->forward('/town/healer');
	
		
}

sub _get_party_health {
	my ($town, @characters) = @_;
	
	my $per_hp_heal_cost = round(RPG->config->{min_healer_cost} + (100-$town->prosperity)/100 * RPG->config->{max_healer_cost});
	my $cost_to_heal = 0;
	my @dead_chars;
	
	foreach my $character (@characters) {
		if ($character->is_dead) {
			push @dead_chars, $character;
			next;	
		}
		
		$cost_to_heal += $per_hp_heal_cost * ($character->max_hit_points - $character->hit_points);
	}
	
	return ($cost_to_heal, @dead_chars);	
}

1;