package RPG::Schema::Memorised_Spells;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Memorised_Spells');

__PACKAGE__->add_columns(qw/mem_spell_id spell_id character_id memorise_tomorrow memorised_today number_cast_today memorise_count memorise_count_tomorrow/);

__PACKAGE__->set_primary_key('mem_spell_id');

__PACKAGE__->belongs_to(
    'character',
    'RPG::Schema::Character',
    { 'foreign.character_id' => 'self.character_id' }
);

__PACKAGE__->belongs_to(
    'spell',
    'RPG::Schema::Spell',
    { 'foreign.spell_id' => 'self.spell_id' }
);

sub casts_left_today {
    my $self = shift;
    
    return $self->memorise_count - $self->number_cast_today;
}

1;