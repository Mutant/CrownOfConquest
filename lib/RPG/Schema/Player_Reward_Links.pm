package RPG::Schema::Player_Reward_Links;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Player_Reward_Links');

__PACKAGE__->add_columns(qw/player_id link_id vote_key/);

__PACKAGE__->add_columns(
    last_vote_date => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/link_id player_id/);

__PACKAGE__->belongs_to( 'link', 'RPG::Schema::Reward_Links', 'link_id' );

1;