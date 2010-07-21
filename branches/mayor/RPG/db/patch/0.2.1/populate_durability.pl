#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use Games::Dice::Advanced;

my $schema = RPG::Schema->connect( "dbi:mysql:game", "root", "root", { AutoCommit => 1 }, );

my %categories =
    map { $_->id => $_ }
    $schema->resultset('Item_Category')
    ->search( { 'property_category.category_name' => 'Durability', }, { prefetch => { 'item_variable_names' => ['property_category'] }, } );

my @items = $schema->resultset('Items')->search(
    { 'item_type.item_category_id' => [ keys %categories ], },
    {
        prefetch => [ 'item_type', { 'item_variables' => 'item_variable_name' }, ],
        distinct => 1,
    },
);

foreach my $item (@items) {
    unless ( $item->variable('Durability') ) {
        my $variable_param = $item->item_type->variable_param('Durability');
        
        unless ($variable_param) {
            warn "No durability param for: " . $item->item_type . "\n";
            next;
        }
        
        my $range          = $variable_param->max_value - $variable_param->min_value + 1;
        my $init_value     = Games::Dice::Advanced->roll("1d$range") + $variable_param->min_value - 1;
        $item->add_to_item_variables(
            {
                item_variable_name_id => $variable_param->item_variable_name->id,
                item_variable_value   => $init_value,
                max_value             => $variable_param->keep_max ? $init_value : undef,
            }
        );
    }
}
