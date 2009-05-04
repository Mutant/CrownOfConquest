package RPG::Combat::CreatureBattle;

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;
use Carp;
use List::Util qw/shuffle/;
use DateTime;

requires qw/party_flee/;

has 'party'              => ( is => 'rw', isa => 'RPG::Schema::Party',         required => 1 );
has 'creature_group'     => ( is => 'rw', isa => 'RPG::Schema::CreatureGroup', required => 1 );
has 'creatures_can_flee' => ( is => 'ro', isa => 'Bool',                       default  => 1 );
has 'party_flee_attempt' => ( is => 'ro', isa => 'Bool',                       default  => 0 );

sub combatants {
    my $self = shift;

    return ( $self->party->characters, $self->creature_group->creatures );
}

sub opponents {
    my $self = shift;

    return ( $self->party, $self->creature_group );
}

sub opponents_of {
    my $self  = shift;
    my $being = shift;

    if ( $being->is_character ) {
        return $self->creature_group;
    }
    else {
        return $self->party;
    }
}

after 'execute_round' => sub {
    my $self = shift;
    
    $self->party->turns( $self->party->turns - 1 );
    $self->party->update;    
};

sub process_effects {
    my $self = shift;

    my @character_effects = $self->schema->resultset('Character_Effect')->search(
        {
            character_id    => [ map { $_->id } $self->party->characters ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    my @creature_effects = $self->schema->resultset('Creature_Effect')->search(
        {
            creature_id     => [ map { $_->id } $self->creature_group->creatures ],
            'effect.combat' => 1,
        },
        { prefetch => 'effect', },
    );

    $self->_process_effects( @character_effects, @creature_effects );

    # Refresh party / creature_group in stash if necessary
    # TODO: decide if we should be doing this here
    if (@creature_effects) {
        $self->creature_group( $self->schema->resultset('CreatureGroup')->get_by_id( $self->creature_group->id ) );
    }

    if (@character_effects) {
        $self->party( $self->schema->resultset('Party')->get_by_player_id( $self->party->player_id ) );
    }
}

sub check_for_flee {
    my $self = shift;

    if ($self->party_flee_attempt && $self->party_flee(1)) {
        return {party_fled => 1};
    }
    
    return unless $self->creatures_can_flee;
    
    # See if the creatures want to flee... check this every 3 rounds
    #  Only flee if cg level is lower than party
    if ( $self->combat_log->rounds != 0 && $self->combat_log->rounds % 3 == 0 ) {
        if ( $self->creature_group->level < $self->party->level - 2 ) {
            my $chance_of_fleeing =
                ( $self->party->level - $self->creature_group->level ) * $self->config->{chance_creatures_flee_per_level_diff};

            $self->log->debug("Chance of creatures fleeing: $chance_of_fleeing");

            my $roll = Games::Dice::Advanced->roll('1d100');
            
            $self->log->debug("Flee roll: $roll");
            
            if ( $chance_of_fleeing >= $roll) {
                # Creatures flee
                my $land = $self->get_sector_to_flee_to(1);
                
                $self->creature_group->move_to( $land );
                $self->creature_group->update;

                $self->party->in_combat_with(undef);
                $self->party->update;

                $self->combat_log->outcome('opp2_fled');
                $self->combat_log->encounter_ended( DateTime->now() );
                
                return {creatures_fled => 1};
            }
        }
    }

    return;
}

sub finish {
    my $self = shift;
    my $losers = shift;
    
    # Only do stuff if the party won
    return if $losers->isa('RPG::Schema::Party');

    my @creatures = $self->creature_group->creatures;

    my $xp;

    foreach my $creature (@creatures) {

        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $creature->type->level * $rand * $self->config->{xp_multiplier} );
    }

    my $avg_creature_level = $self->creature_group->level;

    my @characters = $self->party->characters;

    $self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );

    my $gold = scalar(@creatures) * $avg_creature_level * Games::Dice::Advanced->roll('2d6');
    $self->result->{gold} = $gold;

    $self->check_for_item_found( \@characters, $avg_creature_level );

    $self->party->in_combat_with(undef);
    $self->party->gold( $self->party->gold + $gold );
    $self->party->update;

    $self->combat_log->gold_found($gold);
    $self->combat_log->xp_awarded($xp);
    $self->combat_log->encounter_ended( DateTime->now() );

    # Don't delete creature group, since it's needed by news
    $self->creature_group->land_id(undef);
    $self->creature_group->dungeon_grid_id(undef);
    $self->creature_group->update;

    $self->end_of_combat_cleanup;
}

sub check_for_item_found {
    my $self = shift;
    my ( $characters, $avg_creature_level ) = @_;

    # See if party find an item
    if ( Games::Dice::Advanced->roll('1d100') <= $avg_creature_level * $self->config->{chance_to_find_item} ) {
        my $max_prevalence = $avg_creature_level * $self->config->{prevalence_per_creature_level_to_find};

        # Get item_types within the prevalance roll
        my @item_types = shuffle $self->schema->resultset('Item_Type')->search(
            {
                prevalence        => { '<=', $max_prevalence },
                'category.hidden' => 0,
            },
            { join => 'category', },
        );

        my $item_type = shift @item_types;

        croak "Couldn't find item to give to party under prevalence $max_prevalence\n"
            unless $item_type;

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

1;
