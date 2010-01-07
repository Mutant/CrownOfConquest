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
    
    my $schema = $self->result_source->schema;
    
    $schema->resultset('Effect')->create_effect($params);
}

sub create_party_effect {
    my ( $self, $params ) = @_;

    my $schema = $self->result_source->schema;
    
    $schema->resultset('Effect')->create_party_effect($params);
}

1;
