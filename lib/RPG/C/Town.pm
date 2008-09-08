package RPG::C::Town;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Math::Round qw(round);

sub main : Local {
	my ($self, $c, $return_output) = @_;
	
	$c->forward('RPG::V::TT',
        [{
            template => 'town/main.html',
			params => {
				town => $c->stash->{party_location}->town,
				day_logs => $c->stash->{day_logs},
			},
			return_output => $return_output || 0,
        }]
    );
}

sub back_to_main : Local {
	my ($self, $c) = @_;
	
	my $panel = $c->forward('main', [1]);
	
    push @{ $c->stash->{refresh_panels} }, ['messages', $panel];
    
    $c->forward('/panel/refresh');
}

sub shop_list : Local {
	my ($self, $c) = @_;
	
	my $panel = $c->forward('RPG::V::TT',
        [{
            template => 'town/shop_list.html',
			params => {
				town => $c->stash->{party_location}->town,
			},
			return_output => 1,
        }]
    );
    
    push @{ $c->stash->{refresh_panels} }, ['messages', $panel];
    
    $c->forward('/panel/refresh');
}

sub healer : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my @characters = $c->stash->{party}->characters;
	
	my ($cost_to_heal, @dead_chars) = _get_party_health($town, @characters);
	
	my $panel = $c->forward('RPG::V::TT',
        [{
            template => 'town/healer.html',
			params => {
				cost_to_heal => $cost_to_heal,
				dead_characters => \@dead_chars, 
				town => $town,
				messages => $c->stash->{messages},
			},
			return_output => 1,
        }]
    );
    
    push @{ $c->stash->{refresh_panels} }, ['messages', $panel];
    
    $c->forward('/panel/refresh');
}

sub heal_party : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{party_location}->town;
	
	my @characters = $c->stash->{party}->characters;
	
	my ($cost_to_heal, @dead_chars) = _get_party_health($town, @characters);
	
	my $amount_to_spend = defined $c->req->param('gold') ? $c->req->param('gold') : $cost_to_heal;
	
	my $percent_to_heal = $amount_to_spend / $cost_to_heal * 100;   
	
	if ($amount_to_spend <= $c->stash->{party}->gold) {
		$c->stash->{party}->gold($c->stash->{party}->gold - $amount_to_spend);
		$c->stash->{party}->update;
		
		foreach my $character (@characters) {
			next if $character->is_dead;
			
			my $amount_to_heal = int ($character->max_hit_points - $character->hit_points) * ($percent_to_heal / 100);
			
			$character->hit_points($character->hit_points + $amount_to_heal);
			$character->update;
		}
		
		if ($percent_to_heal == 100) {
			$c->stash->{messages} = 'The party has been fully healed';
		}
		else {
			$c->stash->{messages} = "The party has been healed for $amount_to_spend gold";
		}
	}
	else {
		# TODO: should error here.. not enough gold	for amount_to_heal
	}
	
	push @{ $c->stash->{refresh_panels} }, ('party', 'party_status');
	
	$c->forward('/town/healer');
}

sub resurrect : Local {
	my ($self, $c) = @_;

	my $town = $c->stash->{party_location}->town;
	
	my @characters = $c->stash->{party}->characters;
	
	my ($cost_to_heal, @dead_chars) = _get_party_health($town, @characters);
	
	my ($char_to_res) = grep { $_->id eq $c->req->param('character_id') } @dead_chars;
	
	if ($char_to_res) {
		if ($char_to_res->resurrect_cost > $c->stash->{party}->gold) {
			$c->stash->{error} = "You don't have enough gold to resurrect " . $char_to_res->character_name;	
		}
		else {
			$c->stash->{party}->gold($c->stash->{party}->gold - $char_to_res->resurrect_cost);
			$c->stash->{party}->update;
			
			$char_to_res->hit_points(round $char_to_res->max_hit_points * 0.1);
			my $xp_to_lose = int ($char_to_res->xp * RPG->config->{ressurection_percent_xp_to_lose} / 100);
			$char_to_res->xp($char_to_res->xp - $xp_to_lose); 
			$char_to_res->update;
			
			$c->stash->{messages} = $char_to_res->character_name . " has risen from the dead. He lost $xp_to_lose xp.";
		}
	}
	
	push @{ $c->stash->{refresh_panels} }, ('party', 'party_status');
	
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

sub news : Local {
	my ($self, $c) = @_;
	
	my $current_day = $c->model('DBIC::Day')->find(
		{			
		},
		{
			select => {max => 'day_number'},
			as => 'current_day'
		},
	)->get_column('current_day');	
	
	my @logs = $c->model('DBIC::Combat_Log')->get_logs_around_sector(
		$c->stash->{party_location}->x,
		$c->stash->{party_location}->y,
		$c->config->{combat_news_x_size},
		$c->config->{combat_news_y_size},
		$current_day - $c->config->{combat_news_day_range},	
	);	

	my $panel = $c->forward('RPG::V::TT',
        [{
            template => 'town/news.html',
			params => {
				town => $c->stash->{party_location}->town,
				combat_logs => \@logs,
			},
			return_output => 1,
        }]
    );
    
    push @{ $c->stash->{refresh_panels} }, ['messages', $panel];

	$c->forward('/panel/refresh');
}

1;