package RPG::Schema::Creature_Spell;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Creature_Spell');

__PACKAGE__->add_columns(qw/creature_spell_id spell_id creature_type_id/);

__PACKAGE__->set_primary_key(qw/creature_spell_id/);

__PACKAGE__->belongs_to( 'spell', 'RPG::Schema::Spell', 'spell_id' );

1;