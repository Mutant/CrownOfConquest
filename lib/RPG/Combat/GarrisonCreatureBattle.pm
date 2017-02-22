package RPG::Combat::GarrisonCreatureBattle;

# Battles between garrisons and creatures - always in the wilderness

use Moose;

use Data::Dumper;
use Carp;
use List::Util qw(shuffle);

has 'garrison' => ( is => 'rw', isa => 'RPG::Schema::Garrison', required => 1 );

with qw/
  RPG::Combat::CharactersVsCreatures
  RPG::Combat::Battle
  RPG::Combat::InWilderness
  RPG::Combat::GarrisonBattle
  /;

sub BUILD {
    my $self = shift;

    # We have to do this while non-garrison modules do it in the controller (etc).
    #  Maybe better here?
    $self->garrison->in_combat_with( $self->creature_group->id );
    $self->garrison->update;
}

sub character_group {
    my $self = shift;

    return $self->garrison;
}

sub check_for_flee {
    my $self = shift;

    if ( $self->garrison->is_over_flee_threshold && $self->party_flee(1) ) {
        $self->result->{party_fled} = 1;
        $self->garrison_flee;
        return 1;
    }

    if ( $self->creature_flee ) {
        return 1;
    }
}

# Modify get_sector_to_flee_to since garrisons have more restrictions on which sectors they can 'flee' to
around 'get_sector_to_flee_to' => sub {
    my $orig          = shift;
    my $self          = shift;
    my $fleeing_group = shift;

    if ( $fleeing_group->group_type eq 'garrison' ) {
        my @sectors = $fleeing_group->find_fleeable_sectors;

        @sectors = shuffle @sectors;
        return shift @sectors;
    }
    else {
        return $self->$orig($fleeing_group);
    }
};

sub finish {
    my $self   = shift;
    my $losers = shift;

    # Delete garrison if they lost
    if ( $losers->group_type eq 'garrison' ) {
        $self->wipe_out_garrison;

        $self->location->creature_threat( $self->location->creature_threat + 5 );
        $self->location->update;
    }
    else {
        $self->creatures_lost;

        $self->garrison->gold( ( $self->garrison->gold || 0 ) + $self->result->{gold} );
        $self->garrison->update;

        $self->location->creature_threat( $self->location->creature_threat - 5 );
        $self->location->update;
    }
}

sub is_online {
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;
