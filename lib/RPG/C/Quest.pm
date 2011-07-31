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
    
    my $party_below_min_level = $c->stash->{party}->level < $quest->min_level ? 1 :0;
    
    if ($party_below_min_level) {
        push @{$c->stash->{panel_messages}}, "Your party's level isn't high enough to accept this quest!";   
    }

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'quest/offer.html',
                params   => {
                    town  => $c->stash->{party_location}->town,
                    quest => $quest,
                    party_below_min_level => $party_below_min_level,
                },
                return_output => 1,
            }
        ]
    );
    
    $c->stash->{message_panel_size} = 'large';
    
	push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

	$c->forward('/panel/refresh');    
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
        
        croak "Accepting a quest for another party" if defined $quest->party_id;
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
        $c->forward('/quest/list');  
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
    
    my $kingdom_message = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'quest/kingdom/terminated.html',
                params   => { 
                       quest => $quest,
                       reason => 'the party declined it',  
                },
                return_output => 1,
            }
        ]
    );
    
    $quest->terminate(
        kingdom_message => $kingdom_message,
    );
    $quest->update;
    
    $c->forward('/quest/list'); 
    
}

sub list : Local {
    my ( $self, $c ) = @_;
    
    $c->stash->{message_panel_size} = 'large';

    my @quests = $c->model('DBIC::Quest')->search(
        {
            party_id => $c->stash->{party}->id,
            status   => ['Not Started', 'In Progress', 'Awaiting Reward'],
        },
        { 
            prefetch => [ 'quest_params', { 'type' => 'quest_param_names' }, ],
            
            # Order by kingdom id to sort them by town/kingdom quests
            order_by => 'kingdom_id', 
        }
    );

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'quest/list.html',
                params   => { quests => \@quests, },
                return_output => 1,
            },
            
        ]
    );
    
    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward( '/panel/refresh', [] );    
}

# Check the party's quests to see if any progress has been made for the particular action just taken
sub check_action : Private {
    my ( $self, $c, $action, @params ) = @_;

    my @messages;

    foreach my $quest ( $c->stash->{party}->quests_in_progress ) {
        if ( my $message = $quest->check_quest_action( $action, $c->stash->{party}, @params ) ) {
            push @messages, $message if $message;
        }
    }
    
    return \@messages;
}

sub complete_quest : Private {
    my ( $self, $c, $party_quest ) = @_;

    my @details = $party_quest->set_complete();

	my @messages;

	foreach my $details (@details) {
		push @messages,
			$c->forward(
    			'RPG::V::TT',
    			[
    				{
    					template      => 'party/xp_gain.html',
    					params        => $details,
    					return_output => 1,
    				}
    			]
            );
	}
	
	$c->stash->{party}->discard_changes;

    push @{ $c->stash->{refresh_panels} }, 'party_status', 'party';

    my $panel = $c->forward(
        'RPG::V::TT',
        [
            {
                template      => 'quest/completed_quest.html',
                params        => { 
                    xp_messages => \@messages,
                    quest => $party_quest,
                },
                return_output => 1,
            }
        ]
    );

    push @{ $c->stash->{refresh_panels} }, [ 'messages', $panel ];

    $c->forward( '/panel/refresh', [] );
}

1;
