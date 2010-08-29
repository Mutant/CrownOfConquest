package RPG::C::Town::Mayor;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use JSON;

sub auto : Private {
	my ( $self, $c ) = @_;
	
	my $town = $c->model('DBIC::Town')->find(
		{
			town_id => $c->req->param('town_id')
		},
		{
			prefetch => 'mayor',
		}
	);
	
	croak "Not mayor of this town\n" unless $town->mayor->party_id == $c->stash->{party}->id;	
	
	$c->stash->{town} = $town;
	
	return 1;		
}

sub default : Path {
	my ( $self, $c ) = @_;

	$c->forward('main');
}

sub main : Local {
	my ( $self, $c ) = @_;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/main.html',
				params => {
					town => $c->stash->{town},
					party_in_town => $c->stash->{town}->land_id == $c->stash->{party_location}->id ? 1 : 0,
					party => $c->stash->{party},
				},
			}
		]
	);
}

sub update : Local {
	my ( $self, $c ) = @_;
	
	croak "Can't update tax again today\n" if $c->stash->{town}->tax_modified_today;
	
	$c->stash->{town}->peasant_tax($c->req->param('peasant_tax'));
	$c->stash->{town}->base_party_tax($c->req->param('base_party_tax'));
	$c->stash->{town}->party_tax_level_step($c->req->param('party_tax_level_step'));
	$c->stash->{town}->sales_tax($c->req->param('sales_tax'));
	$c->stash->{town}->tax_modified_today(1);
	$c->stash->{town}->update;
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id );
}

sub guards : Local {
	my ( $self, $c ) = @_;
	
	my $castle = $c->stash->{town}->castle;
	
	my %guard_types = map { $_->id =>  $_ } $c->model('DBIC::CreatureType')->search(
		{
			'category.name' => 'Guards',
		},
		{
			join     => 'category',
			order_by => 'level',
		}
	);	
	
	my @guards = $c->model('DBIC::Creature')->search(
		{
			'dungeon_room.dungeon_id' => $castle->id,
		},
		{
			join => {'creature_group' => {'dungeon_grid' => 'dungeon_room'}},
		}
	);		
	
	foreach my $guard (@guards) {
		my $type_id = $guard->creature_type_id;
		
		$guard_types{$type_id}->{count}++;
	}
		
	foreach my $guard_type (values %guard_types) {
		my $hired = $c->model('DBIC::Town_Guards')->find_or_new(
			{
				town_id => $c->stash->{town}->id,
				creature_type_id => $guard_type->id,
			}
		);
		
		unless ($hired->in_storage) {
			$hired->amount($guard_types{$guard_type->id}->{count} || 0);
			$hired->insert;
		}		
		
		$guard_types{$guard_type->id}->{to_hire} = $hired->amount;
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/guards_tab.html',
				params => {
					guard_types => [sort { $a->level <=> $b->level } values %guard_types],					
				},
			}
		]
	);	
}

sub update_guards : Local {
	my ( $self, $c ) = @_;
	
	my $params = $c->req->params;
	
	foreach my $key (keys %$params) {
		next unless $key =~ /^type_(\d+)$/;
		
		my $type_id = $1;
		
		my $creature_type = $c->model('DBIC::CreatureType')->find(
			{
				creature_type_id => $type_id,
			},
			{
				prefetch => 'category',
			}
		);
		
		croak "Invalid creature group" unless $creature_type->category->name eq 'Guards';			
		
		my $hired = $c->model('DBIC::Town_Guards')->find(
			{
				town_id => $c->stash->{town}->id,
				creature_type_id => $type_id,
			}
		);
		
		$hired->amount($params->{$key} || 0);
		$hired->update;		
	}
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=guards' );
}

sub balance_sheet : Local {
	my ( $self, $c ) = @_;
	
	my %data;
	
	my $day_id = $c->req->param('day_id');
	my $day;
	if ($day_id) {
		$day = $c->model('DBIC::Day')->find(
			{
				day_id => $day_id,
			}
		);
		croak "Unknown day" unless $day;
	}
	else {
		$day = $c->model('DBIC::Day')->find_today;
	}
	
	for my $type (qw/income expense/) {
		my @rows = $c->model('DBIC::Town_History')->search(
			{
				town_id => $c->stash->{town}->id,
				type => $type,
				day_id => $day->id,
			},
			{
				'select' => ['message', 'sum(value)'],
				'as' => ['label', 'amount'],
				'group_by' => 'message',
			},
		);
	
		$data{$type} = \@rows;
	}
	
	my @recent_days = $c->model('DBIC::Day')->search(
		{
			day_number => {'<', $day->day_number},
		},
		{
			order_by => 'day_number desc',
			rows => 7,
		}
	);
			
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/balance_sheet_tab.html',
				params => {
					%data,
					day => $day,
					recent_days => \@recent_days,
					town_id => $c->stash->{town}->id,
				}
			}
		]
	);	
}

sub news : Local {
	my ($self, $c) = @_;
	
	$c->res->body($c->forward('/town/generate_news', [$c->stash->{town}, 7]));			
}

sub change_gold : Local {
	my ($self, $c) = @_;
	
	my $editable = $c->stash->{party_location}->id == $c->stash->{town}->land_id;
	
	return unless $editable;
	
	my $party = $c->stash->{party};
	my $town = $c->stash->{town};
		
	my $town_gold = $c->req->param('town_gold');
	my $total_gold = $town->gold + $party->gold;
	if ($town_gold > $total_gold) {
		$town_gold = $total_gold
	}
	
	$town_gold = 0 if $town_gold < 0;
	
	my $party_gold = $total_gold - $town_gold;
	
	$party->gold($party_gold);
	$party->update;
	
	$town->gold($town_gold);
	$town->update;
	
	$c->res->body(
		to_json(
			{
				party_gold => $party_gold,
				town_gold => $town_gold,
			}
		),
	);
}

1;