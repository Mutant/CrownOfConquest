package RPG::Schema::Spell;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Spell');


__PACKAGE__->add_columns(qw/spell_id spell_name description points class_id combat non_combat target/);

__PACKAGE__->set_primary_key('spell_id');

1;