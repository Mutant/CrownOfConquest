package RPG::Schema::Party_Mayor_History;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Party_Mayor_History');

__PACKAGE__->add_columns(qw/history_id mayor_name got_mayoralty_day lost_mayoralty_day creature_group_id lost_mayoralty_to lost_method character_id
                            town_id party_id/);

__PACKAGE__->set_primary_key(qw/history_id/);

__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', 'town_id' );
__PACKAGE__->belongs_to( 'character', 'RPG::Schema::Character', 'character_id' );
__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', 'party_id' );

__PACKAGE__->belongs_to( 'got_mayoralty_day_rec',  'RPG::Schema::Day', { 'foreign.day_id' => 'self.got_mayoralty_day' } );
__PACKAGE__->belongs_to( 'lost_mayoralty_day_rec', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.lost_mayoralty_day' } );


1;