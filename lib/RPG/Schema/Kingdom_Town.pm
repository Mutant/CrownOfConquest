package RPG::Schema::Kingdom_Town;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Kingdom_Town');

__PACKAGE__->add_columns(qw/kingdom_id town_id loyalty/);

__PACKAGE__->set_primary_key(qw/kingdom_id town_id/);

__PACKAGE__->belongs_to( 'kingdom', 'RPG::Schema::Kingdom', 'kingdom_id' );
__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', 'town_id' );

__PACKAGE__->numeric_columns(
	loyalty => {
		min_value => -100, 
		max_value => 100,
	},
);

1;