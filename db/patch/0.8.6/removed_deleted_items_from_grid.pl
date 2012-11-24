#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $dbh = $schema->storage->dbh;

my $sql = <<SQL;
    select Item_Grid.item_grid_id from Item_Grid left outer join Items on (Item_Grid.item_id = Items.item_id) where Items.item_id is null and Item_Grid.item_id is not null;
SQL

my $sth = $dbh->prepare($sql);
$sth->execute();

while (my ($item_grid_id) = $sth->fetchrow_array) {
    $schema->resultset('Item_Grid')->find(
        {
            item_grid_id => $item_grid_id,
        }
    )->update({item_id => undef});   
}