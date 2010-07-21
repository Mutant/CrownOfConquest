package RPG::Schema::Character_History;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Character_History');

__PACKAGE__->add_columns( qw/history_id character_id day_id event/ );

__PACKAGE__->set_primary_key('history_id');

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.day_id' } );

1;
