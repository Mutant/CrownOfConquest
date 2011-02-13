package RPG::Schema::Reward_Links;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Reward_Links');

__PACKAGE__->add_columns(qw/link_id url label turn_rewards activated/);

__PACKAGE__->set_primary_key('link_id');

1;