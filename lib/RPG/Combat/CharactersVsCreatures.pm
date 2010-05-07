# Methods for battles involving charcters on one side, creatures on the other
package RPG::Combat::CharactersVsCreatures;

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;
use Carp;
use List::Util qw/shuffle/;
use DateTime;

requires qw/character_group party_flee distribute_xp/;

has 'creature_group' => ( is => 'rw', isa => 'RPG::Schema::CreatureGroup', required => 1 );
has 'creatures_initiated' => ( is => 'ro', isa => 'Bool', default  => 0 );

sub combatants {
    my $self = shift;

    return ( $self->character_group->characters, $self->creature_group->creatures );
}

sub opponents {
    my $self = shift;

    return ( $self->character_group, $self->creature_group );
}

sub opponents_of {
    my $self  = shift;
    my $being = shift;

    if ( $being->is_character ) {
        return $self->creature_group;
    }
    else {
        return $self->character_group;
    }
}

sub opponent_of_by_id {
    my $self  = shift;
    my $being = shift;
    my $id    = shift;

    my $opp_type = $self->opponents_of($being)->group_type eq 'creature_group' ? 'creature' : 'character';

    return $self->combatants_by_id->{$opp_type}{$id};
}

sub initiated_by {
    my $self = shift;

    return $self->creatures_initiated ? 'opp2' : 'opp1';
}

sub process_effects {
    my $self = shift;

    my @character_effects = $self->schema->resultset('Character_Effect')->search(
        {
            character_id    => [ map { $_->id } $self->character_group->characters ],
        },
        { prefetch => 'effect', },
    );

    my @creature_effects = map { $_->creature_effects } $self->creature_group->creatures;
    @creature_effects = grep { $_->effect->combat == 1 } @creature_effects;

    $self->_process_effects( @character_effects, @creature_effects );
}

# See if the creatures try to flee
sub creature_flee {
	my $self = shift;

    # See if the creatures want to flee... check this every 2 rounds
    #  Only flee if cg level is lower than party
    if ( $self->combat_log->rounds != 0 && $self->combat_log->rounds % 2 == 0 ) {
        if ( $self->creature_group->level < $self->character_group->level ) {
            my $chance_of_fleeing = ( $self->character_group->level - $self->creature_group->level - 2 ) * $self->config->{chance_creatures_flee_per_level_diff};

            $self->log->debug("Chance of creatures fleeing: $chance_of_fleeing");

            my $roll = Games::Dice::Advanced->roll('1d100');

            $self->log->debug("Flee roll: $roll");

            if ( $chance_of_fleeing >= $roll ) {

                # Creatures flee
                my $land = $self->get_sector_to_flee_to($self->creature_group);

                $self->creature_group->move_to($land);
                $self->creature_group->update;

                $self->_award_xp_for_creatures_killed();

                $self->combat_log->outcome('opp2_fled');
                $self->combat_log->encounter_ended( DateTime->now() );

                $self->result->{creatures_fled} = 1;
                
                $self->character_group->in_combat_with(undef);
        		$self->character_group->update;
                
                return 1;
            }
        }
    }
}

sub creatures_lost {
	my $self = shift;
	
	my @creatures = $self->creature_group->creatures;

    my $avg_creature_level = $self->creature_group->level;

    my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('2d6');
    $self->result->{gold} = $gold;
    
    $self->combat_log->gold_found($gold);

    $self->_award_xp_for_creatures_killed();

    $self->character_group->in_combat_with(undef);
    $self->character_group->update;

    $self->check_for_item_found( [$self->character_group->characters], $avg_creature_level );

    # Don't delete creature group, since it's needed by news
    $self->creature_group->land_id(undef);
    $self->creature_group->dungeon_grid_id(undef);
    $self->creature_group->update;

    $self->combat_log->encounter_ended( DateTime->now() );

    $self->end_of_combat_cleanup;	
}

sub check_for_item_found {
    my $self = shift;
    my ( $characters, $avg_creature_level ) = @_;

    # See if party find an item
    if ( Games::Dice::Advanced->roll('1d100') <= $avg_creature_level * ($self->config->{chance_to_find_item} || 0) ) {
        my $min_prevalence = 100 - ($avg_creature_level * $self->config->{prevalence_per_creature_level_to_find});

        # Get item_types within the prevalance roll
        my @item_types = shuffle $self->schema->resultset('Item_Type')->search(
            {
                prevalence        => { '>=', $min_prevalence },
                'category.hidden' => 0,
            },
            { join => 'category', },
        );

        my $item_type = shift @item_types;

        unless ($item_type) {
            $self->log->warn("Couldn't find item to give to party under prevalence $min_prevalence");
            return;
        }

        # Choose a random character to find it
        my $finder;
        foreach my $character ( shuffle @$characters ) {
            unless ( $character->is_dead ) {
                $finder = $character;
                last;
            }
        }

        # Create the item
        my $item = $self->schema->resultset('Items')->create( { item_type_id => $item_type->id, }, );

        $item->add_to_characters_inventory($finder);

        $self->result->{found_items} = [
            {
                finder => $finder,
                item   => $item,
            }
        ];
    }
}

sub _award_xp_for_creatures_killed {
    my $self = shift;

    my @creatures_killed;
    if ( $self->session->{killed}{creature} ) {
        foreach my $creature_id ( @{ $self->session->{killed}{creature} } ) {
            push @creatures_killed, $self->combatants_by_id->{creature}{$creature_id};
        }
    }

    my $xp;

    foreach my $creature (@creatures_killed) {

        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $creature->type->level * $rand * $self->config->{xp_multiplier} );
    }

    my @characters = $self->character_group->characters;

    $self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );

    $self->combat_log->xp_awarded($xp);

}

1;