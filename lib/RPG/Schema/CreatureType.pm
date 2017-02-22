use strict;
use warnings;

package RPG::Schema::CreatureType;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Creature_Type');

__PACKAGE__->add_columns(qw/creature_type_id creature_type level weapon fire ice poison creature_category_id hire_cost maint_cost image rare special_damage/);

__PACKAGE__->set_primary_key('creature_type_id');

__PACKAGE__->belongs_to( 'category', 'RPG::Schema::Creature_Category', 'creature_category_id' );

__PACKAGE__->has_many( 'spells', 'RPG::Schema::Creature_Spell', 'creature_type_id' );

1;
