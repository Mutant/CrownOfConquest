package RPG::Schema::Kingdom;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Kingdom');

__PACKAGE__->add_columns(qw/kingdom_id name colour/);

__PACKAGE__->set_primary_key('kingdom_id');

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
    'DarkBlue',
    'Green',
    'Firebrick',
);

sub colours { @colours };

1;