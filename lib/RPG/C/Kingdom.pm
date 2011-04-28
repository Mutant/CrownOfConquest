package RPG::C::Kingdom;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

use Carp;
use JSON;
use HTML::Strip;
use List::Util qw(shuffle);

use RPG::Schema::Kingdom;

sub auto : Private {
	my ( $self, $c ) = @_;
	
	return 1 if $c->action eq 'kingdom/create';
	
	my $kingdom = $c->stash->{party}->kingdom;
	my $king = $kingdom->king;
	
	croak "Party does not have a king\n" unless $king->party_id == $c->stash->{party}->id; 	
	
	$c->stash->{kingdom} = $kingdom;
	$c->stash->{king} = $king;
	
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
				template => 'kingdom/main.html',
				params => {
					kingdom => $c->stash->{kingdom},
					party => $c->stash->{party},
				},
			}
		]
	);
}

sub quests : Local {
	my ( $self, $c ) = @_;
	
	my @quests = $c->model('DBIC::Quest')->search(
	   {
	       kingdom_id => $c->stash->{kingdom}->id,
	       status => ['Not Started', 'In Progress', 'Awaiting Reward'],
	   },
	   {
	       prefetch => ['type', 'quest_params'],
	   }
	);
	
	my $quests_allowed = $c->stash->{kingdom}->quests_allowed;
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/quests.html',
				params => {
					kingdom => $c->stash->{kingdom},
					quests => \@quests,
					quests_allowed => $quests_allowed,
				},
			}
		]
	);	
}

sub new_quest : Local {
	my ( $self, $c ) = @_;
	
	if ($c->req->param('quest_party_id') && ! $c->stash->{error}) {
	   $c->forward('create_quest');
	   return;   
	}	
	
	my @types = $c->model('DBIC::Quest_Type')->search(
	   {
	       owner_type => 'kingdom',
	       hidden => 0,
	   },
    );
    
    my @params;
    my $current_type;
    if ($c->req->param('quest_type_id')) {
        ($current_type) = grep { $_->id == $c->req->param('quest_type_id') } @types;
        @params = $c->model('DBIC::Quest_Param_Name')->search(
            {
                quest_type_id => $c->req->param('quest_type_id'),
                user_settable => 1,
            }
        );   
    }
    
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/new_quest.html',
				params => {
				    quest_types => \@types,
				    params => \@params,
				    current_type => $current_type || undef,
				    error => $c->stash->{error} || undef,
				},
				fill_in_form => 1,
			}
		]
	);	   
}

sub create_quest : Private {
	my ( $self, $c ) = @_;
	
	my $current_quests = $c->model('DBIC::Quest')->search(
	   {
	       kingdom_id => $c->stash->{kingdom}->id,
	       status => ['Not Started', 'In Progress', 'Awaiting Reward'],
	   },
	)->count;
	
	if ($current_quests >= $c->stash->{kingdom}->quests_allowed) {
	   croak "Already have maximum number of quests";   
	}	
	
	if ($c->stash->{kingdom}->gold < $c->req->param('gold_value')) {
	   $c->stash->{error} = "The Kingdom does not have enough gold to pay for this quest";
	   $c->detach('new_quest');
	}
	
	$c->stash->{kingdom}->decrease_gold($c->req->param('gold_value'));
	$c->stash->{kingdom}->update;
	
	my $quest_type = $c->model('DBIC::Quest_Type')->find(
	   {
	       quest_type_id => $c->req->param('quest_type_id'),
	   }
	);
	
	croak "Invalid quest type\n" unless $quest_type;
	
	if ($c->req->param('days_to_complete') < 5 || $c->req->param('days_to_complete') > 30) {
        croak "Invalid days to complete value\n";
	}
		
	my $quest_party = $c->model('DBIC::Party')->find(
	   {
	       party_id => $c->req->param('quest_party_id'),
	   }
	);
	
	croak "Invalid quest party\n" unless $quest_party->kingdom_id == $c->stash->{kingdom}->id &&
	   $quest_party->level >= $quest_type->min_level;
	   
	
    my @param_names = $c->model('DBIC::Quest_Param_Name')->search(
        {
            quest_type_id => $c->req->param('quest_type_id'),
            user_settable => 1,
        }
    );
    
    my %params;
    foreach my $param_name (@param_names) {
        my $value = $c->req->param('param_' . $param_name->id);

        # Land is a special case
        if ($param_name->variable_type eq 'Land') {
            my ($x, $y) = $c->req->param('param_' . $param_name->id);
            my $land = $c->model('DBIC::Land')->find(
                {
                    'x' => $x,
                    'y' => $y,
                }
            );
            croak "Invalid sector: $x, $y\n" unless $land;
            $value = $land->id;
        }
        
        croak "No value for param: " . $param_name->quest_param_name unless $value;
       
        $params{$param_name->quest_param_name} = $value;   
    }
    
    my $quest = $c->model('DBIC::Quest')->create(
        {
            quest_type_id => $quest_type->id,
            kingdom_id => $c->stash->{kingdom}->id,
            party_id => $quest_party->id,
            status => 'Not Started',
            gold_value => $c->req->param('gold_value'),
            days_to_complete => $c->req->param('days_to_complete'),
            params => \%params,
            day_offered => $c->stash->{today}->id,
            xp_value => 1000,
        }
    );   
    
    $c->response->redirect( $c->config->{url_root} . '/kingdom?selected=quests' );
	
}

sub quest_param_list : Local {
	my ( $self, $c ) = @_;
	
	my $quest_param = $c->model('DBIC::Quest_Param_Name')->find(
	   {
	       quest_param_name_id => $c->req->param('quest_param_name_id'),
	   },
	);
	
	return unless $quest_param;
	
	return if $quest_param->user_settable == 0;
	
	my @data;
	
	given ($quest_param->variable_type) {
	    when ('Town') {	
	       my @towns = $c->model('DBIC::Town')->search(
                { 
                    'mapped_sector.party_id' => $c->stash->{party}->id,
                },
                {
                    prefetch => { 'location' => 'mapped_sector' },
                    order_by => 'town_name',
                },
           );
    

           foreach my $town (@towns) {
               push @data, {
                   id => $town->id,
                   name => $town->label,
               }
            }
	    }
        
        when ('Building_Type') {
            my $building_type = $c->model('DBIC::Building_Type')->find(
               {
                    name => 'Tower',
                }
            );
            
            
            push @data, {
                id => $building_type->id,
                name => $building_type->name,
            }
        }
	}
	
	$c->res->body(
		to_json(
			{
			    identifier => 'id',
			    label => 'name',
				items => \@data,
			}
		),
	);
}

sub parties_to_offer : Local {
	my ( $self, $c ) = @_;
	
	my $quest_type = $c->model('DBIC::Quest_Type')->find(
	   {
	       quest_type_id => $c->req->param('quest_type_id'),
	   }
	);
	
	return unless $quest_type;
	
	my @parties = $c->stash->{kingdom}->search_related(
	   'parties',
	   {
	       party_id => {'!=', $c->stash->{party}->id},
	   },
	   {
	       order_by => 'name',
	   },
	);
	
	@parties = grep { $_->level >= $quest_type->min_level } @parties;
	
    my @data;
    foreach my $party (@parties) {
        push @data, {
            id => $party->id,
            name => $party->name . ' (Lvl ' . $party->level . ')',
        }
    }	
    
	$c->res->body(
		to_json(
			{
			    identifier => 'id',
			    label => 'name',			    
				items => \@data,
			}
		),
	);        
}

sub parties : Local {
	my ( $self, $c ) = @_;
	
	my @parties = $c->stash->{kingdom}->search_related(
	   'parties',
	   {},
	   {
	       order_by => 'name',
	       join      => 'characters',
	       '+select' => [
	           {count => 'characters.character_id'},
	       ],
	       '+as' => ['character_count'],
	       group_by  => 'me.party_id',
	   }
    );	       
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/parties.html',
				params => {
				    parties => \@parties,
				},
			}
		]
	);	 	
}

sub towns : Local {
	my ( $self, $c ) = @_;
	
	my @towns = $c->model('DBIC::Town')->search(
	   {
	       'location.kingdom_id' => $c->stash->{kingdom}->id,
	   },
	   {
	      order_by => 'town_name',
	      prefetch => [
            {'mayor' => 'party'},
            'location',
          ],	       
	   }
    );
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/towns.html',
				params => {
				    towns => \@towns,
				},
			}
		]
	);	
	
}    

sub change_gold : Local {
	my ($self, $c) = @_;
		
	my $party = $c->stash->{party};
	my $kingdom = $c->stash->{kingdom};
		
	my $kingdom_gold = $c->req->param('kingdom_gold');
	my $total_gold = $kingdom->gold + $party->gold;
	if ($kingdom_gold > $total_gold) {
		$kingdom_gold = $total_gold
	}
	
	$kingdom_gold = 0 if $kingdom_gold < 0;
	
	my $party_gold = $total_gold - $kingdom_gold;
	
	$party->gold($party_gold);
	$party->update;
	
	$kingdom->gold($kingdom_gold);
	$kingdom->update;
	
	$c->res->body(
		to_json(
			{
				party_gold => $party_gold,
				kingdom_gold => $kingdom_gold,
			}
		),
	);
}

sub messages : Local {
	my ($self, $c) = @_;
	
	my @messages = $c->stash->{kingdom}->search_related(
	   'messages',
	   {
	       'day.day_number' => {'>=', $c->stash->{today}->day_number - 14},
	   },
	   {
	       prefetch => 'day',
	       order_by => ['day.day_id desc', 'message_id desc'],
	   }
	);
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/messages.html',
				params => {
				    messages => \@messages,
				},
			}
		]
	);		  
}

sub tax : Local {
    my ($self, $c) = @_;
    
    if ($c->req->param('mayor_tax')) {
        $c->stash->{kingdom}->mayor_tax($c->req->param('mayor_tax'));
        $c->stash->{kingdom}->update;
        
        $c->response->redirect( $c->config->{url_root} . '/kingdom?selected=tax' );
        
        return;
    }
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/tax.html',
				params => {
				    kingdom => $c->stash->{kingdom},
				},
			}
		]
	);	     
}

sub create : Local {
    my ($self, $c) = @_;
    
    my $mayor_count = $c->stash->{party}->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
	)->count;
    
    my $can_declare_kingdom = $c->stash->{party}->level >= $c->config->{minimum_kingdom_level} 
	   && $mayor_count >= $c->config->{town_count_for_kingdom_declaration};
	   
    croak "Not allowed to declare a kingdom\n" unless $can_declare_kingdom;
    
    my $hs = HTML::Strip->new();
    
    my $kingdom_name = $hs->parse( $c->req->param('kingdom_name') );    
    
    unless ($kingdom_name) {
        $c->flash->{error} = 'Please enter a valid Kingdom name';
        $c->res->redirect( $c->config->{url_root} . '/party/details?tab=kingdom' );
        return;   
    }
    
    my ($king) = grep { $_->id == $c->req->param('king') } $c->stash->{party}->characters_in_party;
    croak "Invalid king" unless $king && ! $king->is_dead;
    
    my $colour;
    foreach my $test_colour (shuffle RPG::Schema::Kingdom::colours()) {
        my $existing = $c->model('DBIC::Kingdom')->find(
            {
                colour => $test_colour,
            }
        );
        if (! $existing) {
            $colour = $test_colour;
            last;
        }
    }
    
    my $kingdom = $c->model('DBIC::Kingdom')->create(
        {
            name => $kingdom_name,
            colour => $colour,
        },
    );
    
    $king->status('king');
    $king->status_context($kingdom->id);
    $king->update;
    
    # Set all towns to new kingdom
    my @towns = $c->model('DBIC::Town')->search(
        {
            'mayor.party_id' => $c->stash->{party}->id,
        },
        {
            join => 'mayor',
            prefetch => 'location',
        }
    );
    
    foreach my $town (@towns) {
        my $location = $town->location;
        $location->kingdom_id($kingdom->id);
        $location->update;
        
        $town->unclaim_land;
        $town->claim_land;
    }
    
    $c->stash->{party}->change_allegiance($kingdom);
    $c->stash->{party}->update;
    
    $c->stash->{party}->add_to_messages(
        {
	       day_id => $c->stash->{today}->id,
	       alert_party => 0,
	       message => "We declared the Kingdom of $kingdom_name, and appoint " . $king->character_name . " as the " . 
	           ($king->gender eq 'male' ? 'King' : 'Queen') . ". What an historic day!",
        }
    );
    
    $c->res->redirect( $c->config->{url_root} . 'kingdom' );
}

1;