package RPG::Schema::Announcement;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Announcement');

__PACKAGE__->add_columns(qw/announcement_id announcement title/);

__PACKAGE__->add_columns(
    date => { data_type => 'datetime' }
);

__PACKAGE__->set_primary_key(qw/announcement_id/);

__PACKAGE__->has_many( 'announcement_player', 'RPG::Schema::Announcement_Player',
    { 'foreign.announcement_id' => 'self.announcement_id' }, );

1;
