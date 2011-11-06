package RPG::Schema::Character_Skill;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Character_Skill');

__PACKAGE__->add_columns(qw/character_id skill_id level/);

__PACKAGE__->numeric_columns(qw/level/);

__PACKAGE__->set_primary_key(qw/character_id skill_id/);

__PACKAGE__->belongs_to( 'skill', 'RPG::Schema::Skill', 'skill_id' );
__PACKAGE__->belongs_to( 'character', 'RPG::Schema::Character', 'character_id' );

1;