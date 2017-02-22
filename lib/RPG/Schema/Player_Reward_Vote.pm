package RPG::Schema::Player_Reward_Vote;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

use RPG::DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Player_Reward_Vote');

__PACKAGE__->add_columns(qw/vote_id player_id link_id/);

__PACKAGE__->add_columns(
    vote_date => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/vote_id/);

__PACKAGE__->belongs_to( 'link', 'RPG::Schema::Reward_Links', 'link_id' );

1;
