package RPG::Schema::Player_Login;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Player_Login');

__PACKAGE__->add_columns(qw/login_id player_id ip login_date screen_height screen_width/);

__PACKAGE__->add_columns(
    login_date => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key(qw/login_id/);

__PACKAGE__->belongs_to( 'player', 'RPG::Schema::Player', 'player_id' );

1;