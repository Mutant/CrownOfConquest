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

around '_build_combat_factors' => sub {
    my $orig = shift;
    my $self = shift;    
    
    my $combat_factors = $self->$orig(@_);

    my ( $refresh_type, $id ) = @_;
    
    return $combat_factors if defined $refresh_type && $refresh_type ne 'creature';    
    
    # If we're in a castle, any guards get an AF bonus from the mayor's Tactics skill
    my $dungeon = $self->location->dungeon_room->dungeon;
    
    if ($dungeon->type eq 'castle') {
        my $town = $self->schema->resultset('Town')->find(
            {
                land_id => $dungeon->land_id,
            }
        );
        my $mayor = $town->mayor;
        
        return $combat_factors unless $mayor;
        
        my $af_bonus = $mayor->execute_skill('Tactics', 'guard_af') // 0;
        
        return $combat_factors unless $af_bonus > 0;
        
        foreach my $creature ($self->creature_group->creatures) {
            next if defined $id && $id != $creature->id;
            
            if ($creature->type->category->name eq 'Guard') {
                $combat_factors->{creature}{ $creature->id }{af} += $af_bonus;    
            }   
        }
    }
    
    return $combat_factors;
};

__PACKAGE__->meta->make_immutable;

1;