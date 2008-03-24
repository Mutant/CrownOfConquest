use strict;
use warnings;

package RPG::Schema::GameVars;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Game_Vars');

__PACKAGE__->add_columns(qw/game_var_id game_var_name game_var_value/);

__PACKAGE__->set_primary_key('game_var_id');
