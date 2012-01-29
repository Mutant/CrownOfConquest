package RPG::C::Party::Kingdom;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

use feature 'switch';

use JSON;
use Carp;
use HTML::Strip;
use List::Util qw(shuffle);

sub auto : Private {
    my ( $self, $c ) = @_;
    
    $c->stash->{kingdom} //= $c->stash->{party}->kingdom;
    
    return 1;
}

sub main : Local {
	my ( $self, $c ) = @_;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/main.html',
				params => {
					party => $c->stash->{party},
					kingdom => $c->stash->{kingdom},
					selected => $c->req->param('selected') // undef,
				},
			}
		]
	);
}

sub allegiance : Local {
	my ( $self, $c ) = @_;
	
	my $kingdom = $c->stash->{kingdom};
	
	my @kingdoms = $c->model('DBIC::Kingdom')->search(
	   {
	       active => 1,
	       'me.kingdom_id' => {'!=', $c->stash->{party}->kingdom_id},
	   },
	   {
	       order_by => 'name',
	   }
    );
    
    @kingdoms = grep { 
        my $party_kingdom = $_->find_related('party_kingdoms',
            {
                'party_id' => $c->stash->{party}->id,
            }
        );
        $party_kingdom && $party_kingdom->banished_for > 0 ? 0 : 1;
    } @kingdoms;
    
    my @banned = $c->model('DBIC::Party_Kingdom')->search(
        {
            party_id => $c->stash->{party}->id,
            banished_for => {'>=', 0},
        },
        {
            prefetch => 'kingdom',
        }
    );
    
	my $mayor_count = $c->stash->{party}->search_related(
		'characters',
		{
			mayor_of => {'!=', undef},
		},
	)->count;	    
	
	my $can_declare_kingdom = $c->stash->{party}->level >= $c->config->{minimum_kingdom_level} 
	   && $mayor_count >= $c->config->{town_count_for_kingdom_declaration};
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/kingdom/allegiance.html',
                params   => {
                    kingdom => $kingdom,
                    kingdoms => \@kingdoms,
                    allegiance_change_frequency => $c->config->{party_allegiance_change_frequency},
                    party => $c->stash->{party},
                    mayor_count => $mayor_count,
                    town_count_for_kingdom_declaration => $c->config->{town_count_for_kingdom_declaration},
                    minimum_kingdom_level => $c->config->{minimum_kingdom_level},
                    can_declare_kingdom => $can_declare_kingdom,
                    banned => \@banned,
                    in_combat => $c->stash->{party}->in_combat,
                },
            }
        ]
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
    
    @parties = sort { $b->level <=> $a->level } @parties;
	
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/parties.html',
				params => {
				    parties => \@parties,
				    kingdom => $c->stash->{kingdom},
				    banish_min => $c->config->{min_banish_days},
				    banish_max => $c->config->{max_banish_days},
				    is_king => $c->stash->{is_king},
				},
			}
		]
	);	 	
}

sub records : Local {
    my ($self, $c) = @_;
    
    my @capitals = $c->stash->{kingdom}->search_related(
        'capital_history',
        {
            end_date => {'!=', undef},
        },
        {
            order_by => ['start_date', 'end_date'],
        }
    );
             
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'kingdom/records.html',
				params => {
				    kingdom => $c->stash->{kingdom},
				    capitals => \@capitals,				    
				},
			}
		]
	);       
}

sub towns : Local {
    my ($self, $c) = @_;
    
	my @towns = $c->model('DBIC::Town')->search(
	   {
	       'location.kingdom_id' => $c->stash->{kingdom}->id,
	   },
	   {
	       'join' => 'location',
	       'order_by' => 'town_name',
	   }
    );   
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/towns.html',
				params => {
				    towns => \@towns,
				    kingdom => $c->stash->{kingdom},
				},
			}
		]
	);        
}

sub messages : Local {
	my ($self, $c) = @_;
	
	my @types = 'public_message';
	push @types, 'message' if $c->stash->{is_king};
	
	my @messages = $c->stash->{kingdom}->search_related(
	   'messages',
	   {
	       'day.day_number' => {'>=', $c->stash->{today}->day_number - 14},
	       'type' => \@types,
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

sub quests : Local {
    my ($self, $c) = @_;
    
    my @quests = $c->model('DBIC::Quest')->search(
        {
            party_id => $c->stash->{party}->id,
            status   => ['In Progress', 'Requested', 'Awaiting Reward'],
            kingdom_id => {'!=', undef},
        },
        { 
            prefetch => [ 'quest_params', { 'type' => 'quest_param_names' }, ],
        }
    );
    
	my @types = $c->model('DBIC::Quest_Type')->search(
	   {
	       owner_type => 'kingdom',
	       hidden => 0,
	   },
    );
    
    my $party_level = $c->stash->{party}->level;
    @types = grep { $party_level >= RPG::Schema::Quest_Type->min_level( $_->quest_type ) } @types;  
    
    my $existing_petition_count = $c->model('DBIC::Quest')->search(  
        {
            party_id => $c->stash->{party}->id,
            status => 'Requested',
            kingdom_id => $c->stash->{kingdom}->id,
        }
    )->count;
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/quests.html',
				params => {
				    quests => \@quests,
				    can_do_quests => scalar @types >= 1 ? 1 : 0,
				    has_existing_petition => $existing_petition_count > 0 ? 1 : 0,
				},
			}
		]
	);	    
}

sub request_quest : Local {
    my ($self, $c) = @_;    
    
	my @types = $c->model('DBIC::Quest_Type')->search(
	   {
	       owner_type => 'kingdom',
	       hidden => 0,
	   },
    );
    
    my $party_level = $c->stash->{party}->level;
    @types = grep {$party_level >= RPG::Schema::Quest_Type->min_level( $_->quest_type ) } @types;
    
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
				    request => 1,
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

sub create_quest_request : Local {
    my ($self, $c) = @_;
    
    my $existing_petition_count = $c->model('DBIC::Quest')->search(  
        {
            party_id => $c->stash->{party}->id,
            status => 'Requested',
            kingdom_id => $c->stash->{kingdom}->id,
        }
    )->count;
    
    croak "Already have a kingdom quest petition" if $existing_petition_count > 0;
    
	my $quest_type = $c->model('DBIC::Quest_Type')->find(
	   {
	       quest_type_id => $c->req->param('quest_type_id'),
	   }
	);    
    
    if ($c->stash->{party}->active_quests_of_type($quest_type->quest_type)->count > 0) {
        $c->stash->{error} = "You already have an active Kingdom quest of that type";
        $c->detach('/panel/refresh');
    } 
    
    my $quest = $c->forward('/kingdom/insert_quest', [$c->stash->{party}, 'Requested']);
    
    push @{$c->stash->{panel_messages}}, "Petition sent!";
    
    $c->forward( '/panel/refresh', [[screen => 'party/kingdom/main?selected=quests'], 'messages'] );   
    
}

sub cancel_petition : Local {
    my ( $self, $c ) = @_;
    
    my @petitions = $c->model('DBIC::Quest')->search(  
        {
            party_id => $c->stash->{party}->id,
            status => 'Requested',
            kingdom_id => $c->stash->{kingdom}->id,
        }
    );
    
    foreach my $petition (@petitions) {
        $petition->status('Cancelled');
        $petition->update;   
    }
    
    push @{$c->stash->{panel_messages}}, "Petition cancelled!";
    
    $c->forward( '/panel/refresh', [[screen => 'party/kingdom/main?selected=quests'], 'messages'] );        
    
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

sub tribute : Local {
    my ($self, $c) = @_;
    
    my $tribute = $c->req->param('tribute');
    
    if ($tribute >= 1) {
        if ($c->stash->{party}->gold >= $tribute) {
            $c->stash->{party}->decrease_gold($tribute);
            $c->stash->{party}->update;
            
            $c->stash->{kingdom}->increase_gold($tribute);
            $c->stash->{kingdom}->update;
            
        	$c->stash->{kingdom}->add_to_messages(
        	   {
        	       message => "The party " . $c->stash->{party}->name . " paid us $tribute gold as a tribute",
        	       day_id => $c->stash->{today}->id,
        	   }	       
        	);
        }
        else {
            push @{ $c->stash->{panel_messages} }, "You do not have enough gold to make that tribute";
        }
    }
    
    $c->forward( '/panel/refresh', [[screen => 'party/kingdom/main'], 'party_status'] );       
}

sub info : Local {
    my ($self, $c) = @_;
    
    my @kingdoms = shuffle $c->model('DBIC::Kingdom')->search(
        {
            active => 1,
        },
    );      
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/kingdom/info.html',
				params => {
				    kingdoms => \@kingdoms,
				},
			}
		]
	);	    
}

1;