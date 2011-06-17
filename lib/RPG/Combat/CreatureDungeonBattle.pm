package RPG::Combat::CreatureDungeonBattle;

use Moose;

with qw/
	RPG::Combat::HasParty
    RPG::Combat::Battle
    RPG::Combat::CreatureBattle 
    RPG::Combat::InDungeon
/;


after 'execute_round' => sub {
    my $self = shift;

    # If the creature_group contained a mayor, call auto-heal on the group
    if ($self->result->{combat_complete} && $self->creature_group->has_mayor) {
        $self->creature_group->auto_heal;   
    }
    
    return unless $self->result->{losers};
    
    # Combat is over. If this was a battle  vs. a rare monster, call remove_special() on the special room.
    # TODO: check assumes rare monster was killed by party... 
    #  This is ok, because rare cg's don't flee... but this check could make sure the rare monster was killed
    #  to be on the safe side.    
    if ($self->result->{combat_complete} && $self->session->{rare_cg} && $self->result->{losers}->id == $self->creature_group->id) {
        $self->location->dungeon_room->remove_special(rare_creature_killed => 1)
            if $self->location->dungeon_room->can('remove_special');
    }

};

__PACKAGE__->meta->make_immutable;

1;