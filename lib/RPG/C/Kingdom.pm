package RPG::C::Kingdom;

use strict;
use warnings;
use base 'Catalyst::Controller';

use feature 'switch';

use Carp;
use JSON;

sub auto : Private {
	my ( $self, $c ) = @_;
	
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
	
	if ($c->req->param('quest_party_id')) {
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
				    quest_type_id => $c->req->param('quest_type_id'),
				    current_type => $current_type || undef,
				},
			}
		]
	);	   
}

sub create_quest : Private {
	my ( $self, $c ) = @_;
	
	if ($c->stash->{kingdom}->gold < $c->req->param('gold_value')) {
	   # TODO: error for gold
	   return;   
	}
	
	my $quest_type = $c->model('DBIC::Quest_Type')->find(
	   {
	       quest_type_id => $c->req->param('quest_type_id'),
	   }
	);
	
	croak "Invalid quest type\n" unless $quest_type;
	
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
                   name => $town->town_name,
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

1;