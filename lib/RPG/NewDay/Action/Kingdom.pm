package RPG::NewDay::Action::Kingdom;

use Moose;

extends 'RPG::NewDay::Base';

use List::Util qw(shuffle);
use RPG::Template;
use Try::Tiny;

use RPG::Schema::Quest_Type;

sub depends { qw/RPG::NewDay::Action::Mayor/ }

sub run {
    my $self = shift;
    my $c = $self->context;
    
    my $schema = $c->schema;
        
    my @kingdoms = $schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );

    foreach my $kingdom (@kingdoms) {
        return if $self->check_for_inactive($kingdom);
        
        my $king = $kingdom->king;
        
        $self->cancel_quests_awaiting_acceptance($kingdom);
        
        $self->adjust_party_loyalty($kingdom);

        if ($king->is_npc) {
            $self->execute_npc_kingdom_actions($kingdom, $king);
        }
    }
}

sub quest_type_map {
    my $self = shift;
    
    unless ($self->{quest_type_map}) {
        my @quest_types = $self->context->schema->resultset('Quest_Type')->search(
            {
                owner_type => 'kingdom',
            },
        );
        $self->{quest_type_map} = { map { $_->id => $_->quest_type } @quest_types };
    }
        
    return $self->{quest_type_map};    
}

sub execute_npc_kingdom_actions {
    my $self = shift;
    my $kingdom = shift;
    my $king = shift;
    
    $self->context->logger->info("Processing NPC Actions for Kingdom " . $kingdom->name . " id: " . $kingdom->id);
   
    my @parties = $kingdom->search_related(
        'parties',
        {
            defunct => undef,
        },  
    );
    
    $self->context->logger->debug("Kingdom has " . scalar @parties . " parties");
    
    $self->generate_kingdom_quests($kingdom, @parties);

}

sub generate_kingdom_quests {
    my $self = shift;
    my $kingdom = shift;
    my @parties = @_;   

    return unless @parties;
    
    my $c = $self->context;
    
    my @quest_count = $c->schema->resultset('Quest')->search(
        {
            kingdom_id => $kingdom->id,
            status => ['Not Started', 'In Progress'],
        },
        {
            'select' => [ 'quest_type_id', { 'count' => '*' } ],
            'as' => [ 'quest_type_id', 'count' ],
            'group_by' => 'quest_type_id',
        } 
    );
   
    my %counts;
    foreach my $count_rec (@quest_count) {
        $counts{$self->quest_type_map->{$count_rec->quest_type_id}} = $count_rec->get_column('count') // 0;   
    }

    my $quests_allowed = $kingdom->quests_allowed;
    my $total_current_quests = $kingdom->search_related(
        'quests',
        {
            status => {'!=', ['Complete', 'Terminated']},
        }
    )->count;
    
    $c->logger->debug("Has $total_current_quests quests, allowed $quests_allowed");
    
    my $quests_to_create = $quests_allowed - $total_current_quests;    
    
    for my $quest_type (values %{ $self->quest_type_map }) {
        # TODO: currently create 3 of each quest type. Should change this
        my $base_number = 3;
        my $number_to_create = $base_number - ($counts{$quest_type} // 0);
        
        $number_to_create = $quests_to_create if $quests_to_create < $number_to_create;
        
        next if $number_to_create <= 0; 
        
        my $min_level = RPG::Schema::Quest_Type->min_level( $quest_type );
            
        $self->_create_quests_of_type( $quest_type, $number_to_create, $min_level, $kingdom, \@parties );    
    }      
}

sub _create_quests_of_type {
    my $self = shift;
    my $quest_type = shift;
    my $number_to_create = shift;
    my $minimum_level = shift;
    my $kingdom = shift;
    my $parties = shift;
    
    my $c = $self->context;
    
    my $quest_type_rec = $c->schema->resultset('Quest_Type')->find(
        {
            quest_type => $quest_type,
        },
    );
    
    confess "No such quest type: $quest_type\n" unless $quest_type_rec;
    
    $self->context->logger->debug("Attempting to create $number_to_create quests of type: " . $quest_type);    
    
    for (1..$number_to_create) {
        my @eligble = $self->_find_eligible_parties($minimum_level, $quest_type, @$parties);
        
        next unless @eligble;
            
        my $party = (shuffle @eligble)[0];
            
        my $quest = try {
            $c->schema->resultset('Quest')->create(
                {
                    kingdom_id => $kingdom->id,
                    party_id => $party->id,
                    quest_type_id => $quest_type_rec->id,
                    day_offered => $c->current_day->id,
                }
            );
        }
        catch {
            if (ref $_ && $_->isa('RPG::Exception')) {
                if ($_->type eq 'quest_creation_error') {
                    $c->logger->debug("Couldn't create quest: " . $_->message);
                    next;
                }
                die $_->message;
            } 
            
            die $_;
        };
        
        if ($quest->gold_value > $kingdom->gold) {
            # Not enough gold to create this quest, skip it
            $self->context->logger->debug("No enough gold to fund this quest, deleting (have: " . $kingdom->gold . ", need: " . $quest->gold_value . ')');
            $quest->delete;
            next;
        }
        
        $kingdom->decrease_gold($quest->gold_value);
   
    } 
}

# Given a list of parties, return parties above a certain level, and without a particular quest type
sub _find_eligible_parties {
    my $self = shift;
    my $min_level = shift;
    my $quest_type = shift;
    my @parties = @_;
    
    my @eligible = grep { 
        $_->level >= $min_level && 
        $_->search_related(
            'quests', 
            { 
                'type.quest_type' => $quest_type,
                'status' => ['In Progress','Not Started'],
            },
            {
                join => 'type',
            }
       )->count < 1 
   } @parties;   
   
   return @eligible;   
}

# Cancel any quests that have been awaiting acceptance by the party for too long
sub cancel_quests_awaiting_acceptance {
    my $self = shift;
    my $kingdom = shift;
    
    my $expired_day_number = $self->context->current_day->day_number - $self->context->config->{kingdom_quest_offer_time_limit};
    my $day_rec = $self->context->schema->resultset('Day')->find(
        {
            day_number => $expired_day_number,
        }
    );
    
    my @quests_to_cancel = $self->context->schema->resultset('Quest')->search(
        {
            kingdom_id => $kingdom->id,
            status => 'Not Started',
            day_offered => {'<=', $day_rec->day_number},
        }
    );

    foreach my $quest (@quests_to_cancel) {
        my $message = RPG::Template->process(
            $self->context->config,
            'quest/kingdom/offer_expired.html',
            {
                quest => $quest,
            }
        );
        
        my $kingdom_message = RPG::Template->process(
            RPG::Schema->config,
            'quest/kingdom/terminated.html',
            {
                quest => $quest,
                reason => 'the party took too long to accept it',
            },
        );        
        
        $quest->terminate(
            party_message => $message,
            kingdom_message => $kingdom_message,
        );        
        $quest->update;
        
    }       
}

# Mark any kingdoms with 0 towns as inactive.
#  All land becomes neutral, King removed, and party become free citizens
sub check_for_inactive {
    my $self = shift;
    my $kingdom = shift;
    
    my $c = $self->context;
    
    my $town_count = $c->schema->resultset('Town')->search(
        {
            'location.kingdom_id' => $kingdom->id
        },
        {
            'join' => 'location',
        }
    )->count;
    
    return 0 if $town_count > 0;
    
    $kingdom->active(0);
    $kingdom->update;
    
    $kingdom->search_related('sectors')->update( { kingdom_id => undef } );
    
    my $king = $kingdom->king;
    $king->status(undef);
    $king->status_context(undef);
    $king->update;
    
    if (! $king->is_npc) {
        my $party = $king->party;
        $party->add_to_messages(
            {
                day_id => $c->current_day->id,
                alert_party => 1,
                message => "Our mighty Kingdom of " . $kingdom->name . " has fallen, as we no longer own any towns. A sad day indeed.",
            },
        );
    } 
    
    return 1;
}

# Adjust loyalty of parties
sub adjust_party_loyalty {
    my $self = shift;
    my $kingdom = shift;
    
    my $c = $self->context;
    
    my @parties = $kingdom->parties;
    foreach my $party (@parties) {
        # Adjust loyalty based on number of towns owned by party that are loyal to kingdom
        my $loyal_town_count = $c->schema->resultset('Town')->search(
            {
                'mayor.party_id' => $party->id,
                'location.kingdom_id' => $kingdom->id,
            },
            {
                join => ['mayor', 'location'],
            }
        )->count;
        
        my $disloyal_town_count = $c->schema->resultset('Town')->search(
            {
                'mayor.party_id' => $party->id,
                'location.kingdom_id' => [{'!=', $kingdom->id}, undef],
            },
            {
                join => ['mayor', 'location'],
            }
        )->count;
        
        my $party_kingdom = $c->schema->resultset('Party_Kingdom')->find_or_create(
            {
                'party_id' => $party->id,
                'kingdom_id' => $kingdom->id,
            }
        );
        $party_kingdom->adjust_loyalty($loyal_town_count - $disloyal_town_count);
        $party_kingdom->update;
    }
}

1;