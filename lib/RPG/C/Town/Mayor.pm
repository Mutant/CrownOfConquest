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

	$c->stash->{in_town} = $town->land_id == $c->stash->{party_location}->id ? 1 : 0;
	
	return 1;		
}

sub default : Path {
	my ( $self, $c ) = @_;

	$c->forward('main');
}

sub main : Local {
	my ( $self, $c ) = @_;
	
	my @mayors;
	
	if (! $c->stash->{in_town}) {
	    @mayors = $c->stash->{party}->search_related(
    		'characters',
    		{
    			mayor_of => {'!=', undef},
    		},
    		{
    			prefetch => 'mayor_of_town',
    		}
	   );
	}	

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/main.html',
				params => {
					town => $c->stash->{town},
					party_in_town => $c->stash->{in_town},
					party => $c->stash->{party},
					mayors => \@mayors,
					error => $c->flash->{error} || '',
				},
			}
		]
	);
}

sub select : Local {
    my ( $self, $c ) = @_;
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/select_tab.html',
				params => {
					town => $c->stash->{town},
					party_in_town => $c->stash->{in_town},
					party => $c->stash->{party},
				},
			}
		]
	);	    
}

sub tax : Local {
	my ( $self, $c ) = @_;   
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/tax_tab.html',
				params => {
					town => $c->stash->{town},
					party_in_town => $c->stash->{in_town},
					party => $c->stash->{party},
				},
			}
		]
	);	
}

sub relinquish : Local {
    my ($self, $c) = @_;
    
    my $mayor = $c->stash->{town}->mayor;
    $mayor->lose_mayoralty(0);

    $c->stash->{panel_messages} = "Mayor removed";
    
    $c->forward( '/panel/refresh', [[screen => 'close'], 'messages'] );
    
}

sub change : Local {
    my ($self, $c) = @_;
    
    croak "Not in town" unless $c->stash->{in_town};
    
    my $mayor = $c->stash->{town}->mayor;
    
    my ($new_mayor) = grep { $_->id == $c->req->param('character_id') && ! $_->is_dead } $c->stash->{party}->characters_in_party;
    
    croak "New mayor not found" unless $new_mayor;
    
    my $orig_approval = $c->stash->{town}->mayor_rating;
    
    $mayor->lose_mayoralty(0, 1);
    
    $new_mayor->mayor_of($c->stash->{town}->id);
    $new_mayor->update;
    
    $new_mayor->apply_roles;
    $new_mayor->gain_mayoralty($c->stash->{town});
    
    my $new_rating = $orig_approval - 10;
    $new_rating = -5 if $new_rating > -5;
    
    $c->stash->{town}->mayor_rating($new_rating);
    $c->stash->{town}->update;
    
    # If the party has less than the max chars, add the mayor into the party
    # (otherwise, he'll be in the town's inn).
    if (! $c->stash->{party}->is_full) {
        $mayor->status(undef);
        $mayor->status_context(undef);
        $mayor->update;
    }
	
	$c->stash->{town}->add_to_history(
   		{
			day_id  => $c->stash->{today}->id,
           	message => $mayor->character_name . " steps aside as mayor. " . $new_mayor->character_name . ", also from the party " . $c->stash->{party}->name .
           	    ", replaces " . $mayor->pronoun('objective'),
   		}
   	);
   	
   	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=mayor'], 'party'] );		
	  
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
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=tax']] );
}

sub guards : Local {
	my ( $self, $c ) = @_;
	
	my $castle = $c->stash->{town}->castle;
	
	my %guard_types = map { $_->id =>  $_ } $c->model('DBIC::CreatureType')->search(
		{
			'category.name' => 'Guard',
		},
		{
			join     => 'category',
			order_by => 'level',
		}
	);
		
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
		
		$guard_types{$guard_type->id}->{trained} = $hired->amount;
		$guard_types{$guard_type->id}->{working} = $hired->amount_working;
	}
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/mayor/guards_tab.html',
				params => {
					guard_types => [sort { $a->level <=> $b->level } values %guard_types],
					town => $c->stash->{town},					
				},
			}
		]
	);	
}

sub train_guards : Local {
	my ( $self, $c ) = @_;
	
	my $params = $c->req->params;
	
	my $creature_type = $c->model('DBIC::CreatureType')->find(
		{
			creature_type_id => $c->req->param('guard_type_id'),
		},
		{
			prefetch => 'category',
		}
	);
	
	croak "Invalid creature group" unless $creature_type && $creature_type->category->name eq 'Guard';
	
	croak "Invalid amount" unless $c->req->param('amount') >= 0;
	
	my $cost = $creature_type->hire_cost * $c->req->param('amount');
	if ($cost > $c->stash->{town}->gold) {
	    $c->stash->{error} = "The town does not have enough gold";
	}
    else {
        $c->stash->{town}->decrease_gold($cost);
        $c->stash->{town}->update;
        
        $c->stash->{town}->add_to_history(
            {
                day_id => $c->stash->{today}->id,
                type => 'expense',
                message => 'Guard Training',
                value => $cost,
            },                
        );
        
    	my $hired = $c->model('DBIC::Town_Guards')->find(
    		{
    			town_id => $c->stash->{town}->id,
    			creature_type_id => $c->req->param('guard_type_id'),
    		}
    	);
    		
    	$hired->increase_amount($c->req->param('amount'));
    	$hired->update;
    	
    	# Add them to the castle
    	$c->stash->{town}->castle->add_or_remove_creatures(
    	   {
    	       type => $creature_type,
    	       amount => $c->req->param('amount'),
    	   }
        );
    }
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=guards']] );
}

sub fire_guards : Local {
	my ( $self, $c ) = @_;
	
	my $params = $c->req->params;
	
	my $creature_type = $c->model('DBIC::CreatureType')->find(
		{
			creature_type_id => $c->req->param('guard_type_id'),
		},
		{
			prefetch => 'category',
		}
	);
	
	croak "Invalid creature group" unless $creature_type && $creature_type->category->name eq 'Guard';
	
	croak "Invalid amount" unless $c->req->param('amount') >= 0;

	my $hired = $c->model('DBIC::Town_Guards')->find(
		{
			town_id => $c->stash->{town}->id,
			creature_type_id => $c->req->param('guard_type_id'),
		}
	);
	
	if ($hired->amount < $c->req->param('amount')) {
	   $c->stash->{error} = "You do not have that many guards of that type";
	}
    else {		
    	$hired->decrease_amount($c->req->param('amount'));
    	$hired->amount_working($hired->amount) if $hired->amount_working > $hired->amount;
    	$hired->update;
    	
    	# Remove them from the castle
    	$c->stash->{town}->castle->add_or_remove_creatures(
    	   {
    	       type => $creature_type,
    	       amount => -$c->req->param('amount'),
    	   }
        );    	
    }
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=guards']] );
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

sub adjust_gold : Local {
	my ($self, $c) = @_;
		
	my $party = $c->stash->{party};
	my $town = $c->stash->{town};
	
	if ($c->req->param('action') eq 'add' && $party->gold < $c->req->param('gold')) {
	    $c->stash->{error} = "You don't have enough party gold to add that amount to the town";   
	    $c->detach('/panel/refresh');
	}

	if ($c->req->param('action') eq 'take' && $town->gold < $c->req->param('gold')) {
	    $c->stash->{error} = "There's not enough gold in the town to take that amount";   
	    $c->detach('/panel/refresh');
	}
	
	if ($c->req->param('action') eq 'add') {
	   $party->decrease_gold($c->req->param('gold'));
	   $town->increase_gold($c->req->param('gold'));
	}
	if ($c->req->param('action') eq 'take') {
	   $town->decrease_gold($c->req->param('gold'));
	   $party->increase_gold($c->req->param('gold'));	    
	}
	
	$party->update;	
	$town->update;
	
	$c->forward('/panel/refresh', ['party_status', ['screen' => 'town/mayor?town_id=' . $town->id]]);
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

sub schedule_election : Local {
	my ($self, $c) = @_;	
	
	my $town = $c->stash->{town};
	
	my $election = $c->model('DBIC::Election')->schedule( $town, $c->req->param('election_day') );
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=select']] );
}

sub garrison : Local {
	my ($self, $c) = @_;
	
	my $town = $c->stash->{town};
	
	my @garrison_chars = $c->model('DBIC::Character')->search(
		{
			status => 'mayor_garrison',
			status_context => $town->id,
			party_id => $c->stash->{party}->id,
		},
		{
		    order_by => 'character_name',
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
	
	$character->status_context($town->id);
	$character->status('mayor_garrison');
	$character->creature_group_id($town->mayor->creature_group_id);
	$character->update;
	
	$c->stash->{party}->adjust_order;
		
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=garrison'], 'party'] );
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
	
	$character->status_context(undef);
	$character->status(undef);
	$character->creature_group_id(undef);
	$character->update;
	
	$c->stash->{party}->adjust_order;
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=garrison'], 'party'] );
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
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=advisor']] );
		
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
        
    	my $king = $kingdom->king;
    	if (! $king->is_npc && $c->stash->{party}->is_suspected_of_coop_with($king->party)) {
            $c->stash->{error} = "You can't change the town's allegiance to that kingdom, as you have IP addresses in common with the king's party";
            $c->forward('/panel/refresh');
            return;
    	}        
    }
    
    $town->change_allegiance($kingdom);
    
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
    
	my $messages = $c->forward( '/quest/check_action', [ 'changed_town_allegiance', $town ] );
	# TODO: messages go no where at the moment
    
    $c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=kingdom']] );       
}

sub set_character_heal_budget : Local {
    my ($self, $c) = @_;   
    
	$c->stash->{town}->character_heal_budget($c->req->param('character_heal_budget'));
	$c->stash->{town}->update;
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=garrison']] );    
}

sub combat_log : Local {
    my ($self, $c) = @_;
    
    my $cg = $c->model('DBIC::CreatureGroup')->find(
        {
            creature_group_id => $c->stash->{town}->mayor->creature_group_id,
        }
    );
    
    my @logs;
    
    if ($cg) {    
        @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_creature_group($cg, 20);        
    }
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/mayor/combat_log.html',
                params   => {
                    logs  => \@logs,
                    cg    => $cg,
                },
            }
        ]
    );       
}

sub traps : Local {
    my ($self, $c) = @_;
    
    my $town = $c->stash->{town};
    
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'town/mayor/traps.html',
                params   => {
                    town => $town,
                    trap_maint_cost => $town->trap_level   * $c->config->{town_trap_maint_cost},
                    trap_upgrade_cost => ($town->trap_level + 1) * $c->config->{town_trap_upgrade_cost},
                    trap_max_level => $c->config->{town_trap_max_level},
                },
            }
        ]
    );     
}

sub upgrade_traps : Local {
    my ($self, $c) = @_;
    
    my $town = $c->stash->{town};
    my $upgrade_cost = ($town->trap_level + 1) * $c->config->{town_trap_upgrade_cost};
   
    if ($town->gold >= $upgrade_cost) {
        $town->increment_trap_level;
        $town->decrease_gold($upgrade_cost);
        $town->update;
        
    	$town->add_to_history(
    		{
    			type => 'expense',
    			value => $upgrade_cost,
    			message => 'Trap Upgrade',
    			day_id => $c->stash->{today}->id,
    		}
    	);         
    }
    else {
        push @{$c->stash->{panel_messages}}, "The town does not have enough gold for the upgrade";
    }
	
	$c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=traps']] );
}

sub downgrade_traps : Local {
    my ($self, $c) = @_;
    
    $c->stash->{town}->decrement_trap_level;
    $c->stash->{town}->update;
    
    $c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=traps']] );
}

sub buildings : Local {
    my ($self, $c) = @_;
    
    if ($c->stash->{town}->location->building->count > 0) {
        $c->forward('/building/manage', [$c->stash->{town}]);
    }
    else {    
        $c->forward('/building/construct', [$c->stash->{town}]);
    }
}

sub build : Local {
    my ($self, $c) = @_;
    
    $c->forward('/building/build', [$c->stash->{town}]);    
    
    $c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=buildings']] );
}

sub building_upgrade : Local {
    my ($self, $c) = @_;
    
    $c->forward('/building/upgrade', [$c->stash->{town}]);    
    
    $c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=buildings']] );
    
}

sub building_build_upgrade : Local {
    my ($self, $c) = @_;
    
    $c->forward('/building/build_upgrade', [$c->stash->{town}]);    
    
    $c->forward( '/panel/refresh', [[screen => '/town/mayor?town_id=' . $c->stash->{town}->id . '&tab=buildings']] );
    
}

1;