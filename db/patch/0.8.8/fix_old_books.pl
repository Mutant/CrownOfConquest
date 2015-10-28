#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @books = $schema->resultset('Items')->search(
    {
        'item_type.item_type' => 'Book of Past Lives',
    },
    {
        join => 'item_type',
    }
);

my $book_type = $schema->resultset('Item_Type')->find(
    {
        'item_type' => 'Book of Past Lives',
    }
);

my ($param) = grep { $_->item_variable_name->item_variable_name eq 'Max Level' } $book_type->item_variable_params;

foreach my $book (@books) {
    my $max_level_var = $book->variable_row('Max Level');
    if (! defined $max_level_var) {
        $book->add_to_item_variables(
            {
                item_variable_name_id => $param->item_variable_name->id,
                item_variable_value   => 30,
            }
        );           
    }   
}