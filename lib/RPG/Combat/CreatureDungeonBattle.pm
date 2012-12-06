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

    # If the creature_group contained a mayor, call auto-heal on the group if they didn't lose the battle
    if ($self->result->{combat_complete} && $self->creature_group->has_mayor) {
        my $mayor_lost = $self->result->{creatures_fled} || ($self->result->{losers} && $self->result->{losers}->is($self->creature_group));
        
        if (! $mayor_lost) {
            $self->creature_group->auto_heal('combat');
            
            my $dungeon = $self->location->dungeon_room->dungeon;
            my $town = $self->schema->resultset('Town')->find(
                {
                    land_id => $dungeon->land_id,
                }
            );            
            

            my $mayor = $town->mayor;
            
            # If the mayor is dead, ressurect them
            if ($mayor->is_dead) {
                $mayor->resurrect($town, 0);
                
            	$town->add_to_history(
            		{
            			type => 'mayor_news',
            			message => $mayor->character_name . ' was slain in combat. However, as the raiders ' 
                            . ($self->result->{party_fled} ? 'fled' : 'were defeated by the mayor\'s party')
                            . ' the town\'s healer resurrected ' . $mayor->pronoun('objective') . ' at no charge',
            			day_id => $self->schema->resultset('Day')->find_today->id,
            		}
            	);
                
                # Also, make sure there is no pending mayor recorded, as the raiders lost
                $town->pending_mayor(undef);
                $town->pending_mayor_date(undef);
                $town->update;
            }
        }
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
    
    my $dungeon = $self->location->dungeon_room->dungeon;
    
    if ($dungeon->type eq 'castle') {
        # If we're in a castle, any guards get an AF bonus from the mayor's Tactics skill
        #  and DF bonus from their Strategy skill
        my $town = $self->schema->resultset('Town')->find(
            {
                land_id => $dungeon->land_id,
            }
        );
        my $mayor = $town->mayor;
        
        return $combat_factors unless $mayor;
        
        my $af_bonus = $mayor->execute_skill('Tactics', 'guard_af') // 0;
        my $df_bonus = $mayor->execute_skill('Strategy', 'guard_df') // 0;
        
        return $combat_factors if $af_bonus < 0 && $df_bonus < 0;
        
        foreach my $creature ($self->creature_group->creatures) {
            next if defined $id && $id != $creature->id;
            
            if ($creature->type->category->name eq 'Guard') {
                $combat_factors->{creature}{ $creature->id }{af} += $af_bonus;
                $combat_factors->{creature}{ $creature->id }{df} += $df_bonus;
            }   
        }
    }
    
    return $combat_factors;
};

__PACKAGE__->meta->make_immutable;

1;