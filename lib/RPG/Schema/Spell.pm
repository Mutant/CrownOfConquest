package RPG::Schema::Spell;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Spell');


__PACKAGE__->add_columns(qw/spell_id spell_name description points class_id combat non_combat target hidden/);

__PACKAGE__->set_primary_key('spell_id');

__PACKAGE__->has_many(
    'memorised_by_characters',
    'RPG::Schema::Memorised_Spells',
    { 'foreign.spell_id' => 'self.spell_id' },
);

__PACKAGE__->belongs_to(
    'class',
    'RPG::Schema::Class',
    { 'foreign.class_id' => 'self.class_id' }
);

1;