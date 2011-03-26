package RPG::Schema::Kingdom;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Kingdom');

__PACKAGE__->add_columns(qw/kingdom_id name colour mayor_tax gold/);

__PACKAGE__->set_primary_key('kingdom_id');

__PACKAGE__->numeric_columns(
	mayor_tax => {
		min_value => 0, 
		max_value => 100,
	},
	gold => {
		min_value => 0,
	},
);

my @colours = (
    'Silver',
    'Gray',
    'Black',
    'Maroon',
    'Olive',
    'Blue',
    'Navy',
    'Chocolate',
    'BurlyWood',
    'Crimson',
    'Green',
    'Firebrick',
    '#408080',
);

sub colours { @colours };

1;