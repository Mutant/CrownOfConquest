package RPG::NewDay::Action::Kingdom;

use Moose;

extends 'RPG::NewDay::Base';

use List::Util qw(shuffle);
use RPG::Template;

sub run {
    my $self = shift;
    my $c = $self->context;
    
    my $schema = $c->schema;
    
    my @kingdoms = $schema->resultset('Kingdom')->search();

    foreach my $kingdom (@kingdoms) {
        my $king = $kingdom->king;

        if ($king->is_npc) {
            $self->execute_npc_kingdom_actions($kingdom, $king);
        }
    }
}

sub quest_type_map {
    my $self = shift;
    
    unless ($self->{quest_type_map}) {
        my @quest_types = $self->context->schema->resultset('Quest_Type')->search();
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
    
    if ($counts{claim_land} < 3) {
        $self->_create_quests_of_type( 'claim_land', 3 - $counts{claim_land}, $c->config->{minimum_land_claim_level}, $kingdom, \@parties );
    }    
    
    if ($counts{construct_building} < 3) {
        $self->_create_quests_of_type( 'construct_building', 3 - $counts{construct_building}, $c->config->{minimum_building_level}, $kingdom, \@parties );
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
    
    $self->context->logger->debug("Attempting to create quest of type: " . $quest_type);    
    
    for (1..$number_to_create) {
        my @eligble = $self->_find_eligible_parties($minimum_level, $quest_type, @$parties);
        
        $self->context->logger->debug("Eligible parties " . scalar @eligble);

        next unless @eligble;
            
        my $party = (shuffle @eligble)[0];
            
        my $quest = $c->schema->resultset('Quest')->create(
            {
                kingdom_id => $kingdom->id,
                party_id => $party->id,
                quest_type_id => $quest_type_rec->id,
            }
        );
        
        my $message = RPG::Template->process(
            $c->config,
            'quest/kingdom/offered.html',
            {
                king => $kingdom->king,
                quest => $quest,
            }                
        );
        
        $party->add_to_messages(
            {
                day_id => $c->current_day->id,
                message => $message,
                alert_party => 1,
            }
        );      
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
            },
            {
                join => 'type',
            }
       )->count < 1 
   } @parties;   
   
   return @eligible;
   
}