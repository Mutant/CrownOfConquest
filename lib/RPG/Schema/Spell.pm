package RPG::Schema::Spell;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

use RPG::Combat::SpellActionResult;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Spell');

__PACKAGE__->add_columns(qw/spell_id spell_name description points class_id combat non_combat target hidden/);

__PACKAGE__->set_primary_key('spell_id');

__PACKAGE__->belongs_to( 'class', 'RPG::Schema::Class', { 'foreign.class_id' => 'self.class_id' } );

__PACKAGE__->has_many( 'memorised_spells', 'RPG::Schema::Memorised_Spells', { 'foreign.spell_id' => 'self.spell_id' } );

# Inflate the result as a class based on spell name
sub inflate_result {
    my $self = shift;

    my $ret = $self->next::method(@_);

    $ret->_bless_into_type_class;

    return $ret;
}

sub insert {
    my ( $self, @args ) = @_;

    my $ret = $self->next::method(@args);

    $ret->_bless_into_type_class;

    return $ret;
}

sub _bless_into_type_class {
    my $self = shift;

    my $class = __PACKAGE__ . '::' . $self->spell_name;
    $class =~ s/ /_/g;

    $self->ensure_class_loaded($class);
    bless $self, $class;

    return $self;
}

sub cast {
    my $self = shift;
    my ( $character, $target ) = @_;

    confess "No target or character. ($character, $target)" unless $character && $target;

    my $memorised_spell = $self->find_related( 'memorised_spells', { character_id => $character->id, } );

    confess "Character has not memorised spell" if !$memorised_spell || $memorised_spell->casts_left_today <= 0;

    my $result_params = $self->_cast( $character, $target );

    my $result = RPG::Combat::SpellActionResult->new(
        spell_name => $self->spell_name,
        attacker   => $character,
        defender   => $target,
        %$result_params,
    );

    $memorised_spell->number_cast_today( $memorised_spell->number_cast_today + 1 );
    $memorised_spell->update;

    return $result;
}

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
    
    $self->_create_effect($search_field, $relationship_name, $joining_table, $params);
}

sub _create_effect {
    my $self = shift;
    my ($search_field, $relationship_name, $joining_table, $params) = @_;
    
    my $schema = $self->result_source->schema;

    my $effect = $schema->resultset('Effect')->find_or_new(
        {
            "$relationship_name.$search_field" => $params->{target}->id,
            effect_name                        => $params->{effect_name},
        },
        { join => $relationship_name, }
    );

    unless ( $effect->in_storage ) {
        $effect->insert;
        $schema->resultset($joining_table)->create(
            {
                $search_field => $params->{target}->id,
                effect_id     => $effect->id,
            }
        );
    }

    $effect->time_left( ( $effect->time_left || 0 ) + $params->{duration} );
    $effect->modifier( $params->{modifier} );
    $effect->modified_stat( $params->{modified_state} );
    $effect->combat( $params->{combat} );
    $effect->time_type( $params->{time_type} );
    $effect->update;   
}

sub create_party_effect {
    my ( $self, $params ) = @_;

    $self->_create_effect('party_id', 'party_effect', "Party_Effect", $params);
}

1;
