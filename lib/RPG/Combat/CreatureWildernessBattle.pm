package RPG::Combat::CreatureWildernessBattle;

use Moose;

with qw/
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InWilderness
/;

after 'finish' => sub {
    my $self = shift;
    
    # Improve prestige with nearby towns   
    foreach my $town ($self->nearby_towns) {
        my $party_town_recs = $self->schema->resultset('Party_Town')->find_or_create(
            {
                town_id => $town->id,
                party_id => $self->party->id,   
            }
        );
        
        $party_town_recs->prestige(($party_town_recs->prestige || 0 )+1);
        $party_town_recs->update;
    }
    
    $self->location->creature_threat( $self->location->creature_threat - 5 );
    $self->location->update;
};    

1;