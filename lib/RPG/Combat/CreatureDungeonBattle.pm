package RPG::Combat::CreatureDungeonBattle;

use Moose;

with qw/
	RPG::Combat::HasParty
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InDungeon
/;

# At the end of each round, check if combat's over. If so, and this was a battle
#  vs. a rare monster, call remove_special() on the special room.
after 'execute_round' => sub {
    my $self = shift;
    
    # TODO: check assumes rare monster was killed by party... 
    #  This is ok, because rare cg's don't flee... but this check could make sure the rare monster was killed
    #  to be on the safe side.
    return unless $self->result->{losers};
    if ($self->result->{combat_complete} && $self->session->{rare_cg} && $self->result->{losers}->id == $self->creature_group->id) {
        $self->location->dungeon_room->remove_special();
    }  
};

__PACKAGE__->meta->make_immutable;

1;