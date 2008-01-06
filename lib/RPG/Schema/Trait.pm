use strict;
use warnings;

package RPG::Schema::Trait;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Trait');

__PACKAGE__->add_columns(qw/trait_id trait last_used/);

1;