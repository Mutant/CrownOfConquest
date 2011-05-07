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

sub party_tax_preview : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	my $base_cost = $c->req->param('base_cost') // $town->base_party_tax;
	my $level_step = $c->req->param('level_step') // $town->party_tax_level_step;
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/party_tax_preview.html',
				params => {					
					town => $town,
					base_cost => $base_cost,
					level_step => $level_step,
				}
			}
		]
	);
}

sub elections : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/elections.html',
				params => {
					town => $town,
					current_election => $town->current_election,
				}
			}
		]
	);	
}

sub schedule_election : Local {
	my ($self, $c) = @_;	
	
	my $town = $c->stash->{town};
	
	my $election = $c->model('DBIC::Election')->schedule( $town, $c->req->param('election_day') );
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=elections' );	
}

sub garrison : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	my @garrison_chars = $c->model('DBIC::Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $c->stash->{party}->id,
		}
	);
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/garrison_tab.html',
				params => {
					town => $town,
					garrison_chars => \@garrison_chars,
					party_in_sector => $c->stash->{party_location}->id == $town->land_id ? 1 : 0,
					party => $c->stash->{party},
					last_character => $c->stash->{party}->characters_in_party->count <= 1 ? 1 : 0,
					garrison_full => scalar @garrison_chars >= $c->config->{mayor_garrison_max_characters} ? 1 : 0,
					max_chars =>  $c->config->{mayor_garrison_max_characters},
				}
			}
		]
	);
}

sub add_to_garrison : Local {
	my ($self, $c) = @_;
		
	my $town = $c->stash->{town};
	
	croak "Party not in sector\n" unless $c->stash->{party_location}->id == $town->land_id;
	
	my @characters = $c->stash->{party}->characters;
	
	croak "Can't garrison last party character" if scalar @characters <= 1;
	
	my $garrison_chars = $c->model('DBIC::Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $c->stash->{party}->id,
		}
	)->count;
	
	croak "Garrison full\n" if $garrison_chars >= $c->config->{mayor_garrison_max_characters};
	
	# Make sure the character is 'available' (i.e. loaded by the main party query)
	#  Ensures the char is not in a garrison, etc.
	my ($character) = grep { $_->id == $c->req->param('character_id') } @characters;
	
	croak "Invalid character" unless $character;
	
	$character->status('mayor_garrison');
	$character->status_context($town->id);
	$character->creature_group_id($town->mayor->creature_group_id);
	$character->update;
	
	$c->stash->{party}->adjust_order;
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=garrison' );
}

sub remove_from_garrison : Local {
	my ($self, $c) = @_;
	
	croak "Party full\n" if $c->stash->{party}->is_full;

	my $town = $c->stash->{town};

	croak "Party not in sector\n" unless $c->stash->{party_location}->id == $town->land_id;
	
	my @garrison_chars = $c->model('DBIC::Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $c->stash->{party}->id,
		}
	);	
	
	my ($character) = grep { $_->id == $c->req->param('character_id') } @garrison_chars;
	
	croak "Invalid character" unless $character;
	
	$character->status(undef);
	$character->status_context(undef);
	$character->creature_group_id(undef);
	$character->update;
	
	$c->stash->{party}->adjust_order;
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=garrison' );
}

sub advisor : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	my $current_day = $c->stash->{today}->day_number;

	my @advice = $c->model('DBIC::Town_History')->search(
		{
			town_id          => $town->id,
			'day.day_number' => { '<=', $current_day, '>=', $current_day - 7 },
			type => 'advice',
		},
		{
			prefetch => 'day',
			order_by => 'day_number desc, date_recorded',
		}
	);
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/advisor_tab.html',
				params => {
					town => $town,
					advice => \@advice,
				}
			}
		]
	);
}

sub update_advisor_fee : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	$town->advisor_fee($c->req->param('advisor_fee'));
	$town->update;
	
	$c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=advisor' );
		
}

sub kingdom : Local {
    my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	my $kingdom = $town->location->kingdom;
	
	my @kingdoms = $c->model('DBIC::Kingdom')->search(
	   {
	       active => 1,
	   },
	   {
	       order_by => 'name',
	   },	   
	);
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/kingdom_tab.html',
				params => {
					town => $town,
					kingdom => $kingdom,
					kingdoms => \@kingdoms,					
				}
			}
		]
	);	 
}

sub change_allegiance : Local {
    my ($self, $c) = @_;
    
    my $town = $c->stash->{town};
    
    my $kingdom;
    
    if ($c->req->param('kingdom_id')) {
        $kingdom = $c->model('DBIC::Kingdom')->find( $c->req->param('kingdom_id') );
        croak "Kingdom not found\n" unless $kingdom;
    }
    
    my $location = $town->location;
    my $old_kingdom = $location->kingdom;
    
    $location->kingdom_id( $c->req->param('kingdom_id') ? $kingdom->id : undef );
    $location->update;
    
    $town->decrease_mayor_rating(10);
    $town->unclaim_land;
    $town->claim_land;
    $town->update;
    
    # Adjust parties loyalty if they have a kingdom
    if (my $partys_kingdom = $c->stash->{party}->kingdom) {
        my $party_kingdom = $c->model('DBIC::Party_Kingdom')->find_or_create(
            {
                kingdom_id => $partys_kingdom->id,
                party_id => $c->stash->{party}->id,
            }           
        );
        
        if ($partys_kingdom->id == $c->req->param('kingdom_id')) {
            $party_kingdom->increase_loyalty(10);
        }
        else {
            $party_kingdom->decrease_loyalty(10);
        }
        
        $party_kingdom->update;
    }
    
    # check if this is the most towns the kingdom has had
    if ($kingdom && $kingdom->highest_town_count < $kingdom->towns->count) {
        $kingdom->highest_town_count($kingdom->towns->count);
        $kingdom->highest_town_count_day_id($c->stash->{today}->id);
        $kingdom->update;
    }
    
    # Leave messages for old/new kings
    if ($kingdom) {
        $kingdom->add_to_messages(
            {
                message => "The town of " . $town->town_name . " is now loyal to our kingdom",
                day_id => $c->stash->{today}->id,
            }
        );
    }
    if ($old_kingdom) {
        $old_kingdom->add_to_messages(
            {
                message => "The town of " . $town->town_name . " is no longer loyal to our kingdom",
                day_id => $c->stash->{today}->id,
            }
        );        
    }
    
	my $messages = $c->forward( '/quest/check_action', [ 'changed_town_allegiance', $town ] );
	# TODO: messages go no where at the moment
    
    $c->response->redirect( $c->config->{url_root} . '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=kingdom' );
       
}

1;