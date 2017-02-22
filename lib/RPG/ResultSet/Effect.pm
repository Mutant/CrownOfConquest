use strict;
use warnings;

package RPG::ResultSet::Effect;

use base 'DBIx::Class::ResultSet';

# Creates an effect with an associated joining table, depending on the target type. Params passed in a hashref.
# Valid keys:
#   effect_name: display name of the effect
#   target: the target, a character or creature record
#   duration: will be added to an existing effect if one exists
#   modifier: where appropriate
#   combat: true for combat effects, false for non-combat effects. Combat effects deleted at the end of combat
#   modified_state: what the effect does (TODO: need to list these?)
#   time_type: whether this is a day or round effect (default: round)
sub create_effect {
    my ( $self, $params ) = @_;

    my ( $relationship_name, $search_field, $joining_table );

    if ( $params->{target}->is_character ) {
        $search_field      = 'character_id';
        $relationship_name = 'character_effect';
        $joining_table     = 'Character_Effect';
    }
    else {
        $search_field      = 'creature_id';
        $relationship_name = 'creature_effect';
        $joining_table     = 'Creature_Effect';
    }

    $self->_create_effect( $search_field, $relationship_name, $joining_table, $params );
}

sub _create_effect {
    my $self = shift;
    my ( $search_field, $relationship_name, $joining_table, $params ) = @_;

    my $effect = $self->find_or_new(
        {
            "$relationship_name.$search_field" => $params->{target}->id,
            effect_name                        => $params->{effect_name},
        },
        { join => $relationship_name, }
    );

    unless ( $effect->in_storage ) {
        $effect->insert;
        $self->result_source->schema->resultset($joining_table)->create(
            {
                $search_field => $params->{target}->id,
                effect_id     => $effect->id,
            }
        );
    }

    $effect->time_left( ( $effect->time_left || 0 ) + $params->{duration} );
    $effect->modifier( $params->{modifier} );
    $effect->modified_stat( $params->{modified_state} ); # Yes, two different names!
    $effect->combat( $params->{combat} );
    $effect->time_type( $params->{time_type} );
    $effect->update;
}

sub create_party_effect {
    my ( $self, $params ) = @_;

    $self->_create_effect( 'party_id', 'party_effect', "Party_Effect", $params );
}

1;
