package RPG::C::Quest;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;
use Text::Wrap;

use Carp;

sub offer : Local {
    my ( $self, $c ) = @_;

    my $quest = $c->model('DBIC::Quest')->find(
        {
            quest_id => $c->req->param('quest_id'),
            town_id  => $c->stash->{party_location}->town->id,
            party_id => undef,
        },
    );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'quest/offer.html',
                params   => {
                    town  => $c->stash->{party_location}->town,
                    quest => $quest,
                    party_below_min_level => $c->stash->{party}->level < $quest->min_level ? 1 : 0,
                },
            }
        ]
    );
}

sub accept : Local {
    my ( $self, $c ) = @_;

    my $quest = $c->model('DBIC::Quest')->find(
        {
            quest_id => $c->req->param('quest_id'),
            status => 'Not Started',
        },
    );
    
    croak "Quest not found" unless $quest;
    
    if ($quest->town_id) {
        unless ($c->stash->{party}->allowed_more_quests) {
    		croak "Not allowed any more quests";	
    	}
        
        my $town = $c->stash->{party_location}->town;
        
        croak "Accepting a quest from another town" unless $town->id == $quest->town_id;
        
        croak "Accepting a quest for another party" unless ! defined $quest->party_id;
    }
    elsif ($quest->kingdom_id) {
        croak "Accepting a quest for another kingdom" unless $quest->kingdom_id == $c->stash->{party}->kingdom_id;
        
        croak "Accepting a quest for another party" unless $quest->party_id == $c->stash->{party}->party_id;
    }
    
    if ($c->stash->{party}->level < $quest->min_level) {
    	croak "Too low level to accept quest";	
    }

    $quest->party_id( $c->stash->{party}->id );
    $quest->status('In Progress');
    $quest->update;

    my $message;
    my $accept_template = 'quest/accept_message/' . $quest->type->quest_type . '.html';
    if (-f $c->path_to('root') . '/' . $accept_template) {
	    $message = $c->forward(
	        'RPG::V::TT',
	        [
	            {
	                template => $accept_template,
	                params   => { quest => $quest, },
	                return_output => 1,
	            }
	        ]
	    );
    };
    
    $c->res->body($message);
    
    if ($quest->kingdom_id) {
        $c->res->redirect( $c->config->{url_root} . "/quest/list" );   
    }
}

sub decline : Local {
    my ( $self, $c ) = @_;
    
    my $quest = $c->model('DBIC::Quest')->find(
        {
            quest_id => $c->req->param('quest_id'),
            status => 'Not Started',
            kingdom_id => $c->stash->{party}->kingdom_id,
            party_id => $c->stash->{party}->party_id,
        },
    );
    
    croak "Invalid quest" unless $quest;
    
    # TODO: message player kings
    
    $quest->delete;
    
    $c->res->redirect( $c->config->{url_root} . "/quest/list" ); 
    
}

sub list : Local {
    my ( $self, $c ) = @_;

    my @quests = $c->model('DBIC::Quest')->search(
        {
            party_id => $c->stash->{party}->id,
            status   => ['Not Started', 'In Progress'],
        },
        { 
            prefetch => [ 'quest_params', { 'type' => 'quest_param_names' }, ],
            
            # Order by kingdom id to sort them by town/kingdom quests
            order_by => 'kingdom_id', 
        }
    );
     

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'quest/list.html',
                params   => { quests => \@quests, },
            }
        ]
    );
}

# Check the party's quests to see if any progress has been made for the particular action just taken
sub check_action : Private {
    my ( $self, $c, $action, @params ) = @_;

    my @messages;

    foreach my $quest ( $c->stash->{party}->quests_in_progress ) {
        if ( $quest->check_action( $c->stash->{party}, $action, @params ) ) {

            my $message = $c->forward(
                'RPG::V::TT',
                [
                    {
                        template => 'quest/action_message.html',
                        params   => {
                            quest  => $quest,
                            action => $action,
                        },
                        return_output => 1,
                    }
                ]
            );
            push @messages, $message if $message;

        }
    }

    # Check if this action affects any other quests    
    my @quests = $c->model('DBIC::Quest')->find_quests_by_interested_action($action);
    
    foreach my $quest (@quests) {
        $quest->check_action_from_another_party( $c->stash->{party}, $action, @params );
    }

    return \@messages;
}

sub complete_quest : Private {
    my ( $self, $c, $party_quest ) = @_;

	$party_quest->finish_quest;

    $party_quest->status('Complete');
    $party_quest->update;

    $c->stash->{party}->gold( $c->stash->{party}->gold + $party_quest->gold_value );
    $c->stash->{party}->update;

    my $xp_gained = $party_quest->xp_value;

    my @characters = grep { !$_->is_dead } $c->stash->{party}->characters_in_party;
    my $xp_each = int $xp_gained / scalar @characters;

    my $xp_messages = $c->forward( '/party/xp_gain', [$xp_each] );

    push @{ $c->stash->{refresh_panels} }, 'party_status', 'party';
    
    my $party_town = $c->model('Party_Town')->find_or_create(
        {
            party_id => $c->stash->{party}->id,
            town_id  => $party_quest->town->id,
        },
    );
    $party_town->prestige($party_town->prestige+3);
    $party_town->update;
    
    $party_quest->town->increase_mayor_rating(3);
    $party_quest->town->update;    
    
    my $news_message = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'quest/completed_quest_news_message.html',
                params        => { 
                    party => $c->stash->{party},
                    quest => $party_quest, 
                },
                return_output => 1,
            }
        ]
    );
    
    $c->model('DBIC::Town_History')->create(
        {
            town_id => $party_quest->town_id,
            day_id  => $c->stash->{today}->id,
            message => $news_message,
        }
    );    

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'quest/completed_quest.html',
                params        => { xp_messages => $xp_messages, },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward( '/panel/refresh', [] );
}

1;
