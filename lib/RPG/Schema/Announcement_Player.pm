package RPG::Schema::Announcement_Player;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Announcement_Player');

__PACKAGE__->add_columns(qw/announcement_id player_id viewed/);

__PACKAGE__->set_primary_key(qw/announcement_id player_id/);

1;
