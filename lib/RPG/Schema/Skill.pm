package RPG::Schema::Skill;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Skill');

__PACKAGE__->add_columns(qw/skill_id skill_name description type base_stats/);

__PACKAGE__->set_primary_key('skill_id');

__PACKAGE__->has_many( 'character_skills', 'RPG::Schema::Character_Skill', 'skill_id');

1;