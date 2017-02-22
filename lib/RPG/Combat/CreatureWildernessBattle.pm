package RPG::Combat::CreatureWildernessBattle;

use Moose;

with qw/
  RPG::Combat::Battle
  RPG::Combat::CreatureBattle
  RPG::Combat::InWilderness
  RPG::Combat::HasParty
  /;

after 'finish' => sub {
    my $self   = shift;
    my $losers = shift;

    if ( $losers->is( $self->creature_group ) ) {

        # Improve prestige with nearby towns
        foreach my $town ( $self->nearby_towns ) {
            my $party_town_recs = $self->schema->resultset('Party_Town')->find_or_create(
                {
                    town_id  => $town->id,
                    party_id => $self->party->id,
                }
            );

            $party_town_recs->prestige( ( $party_town_recs->prestige || 0 ) + 1 );
            $party_town_recs->update;
        }

        $self->location->creature_threat( $self->location->creature_threat - 8 );
        $self->location->update;
    }
    else {
        $self->location->creature_threat( $self->location->creature_threat + 8 );
        $self->location->update;
    }
};

__PACKAGE__->meta->make_immutable;

1;
