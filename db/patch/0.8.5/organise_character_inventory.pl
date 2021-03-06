#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use Data::Dumper;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $char_id = shift;

$schema->resultset('Item_Grid')->search( { owner_type => 'character' } )->delete;

my @chars = $schema->resultset('Character')->search();

create_grid(@chars);

process_chars(@chars);

sub create_grid {
    my @chars = @_;
    
    open (my $file, '>', '/tmp/gen_grid') || die "Couldn't open file ($!)";
    
    foreach my $char (@chars) {
        for my $x (1..8) {
            for my $y (1..8) {
                print $file "\\N\t" . $char->id . "\tcharacter\t\\N\t1\t$x\t$y\t\\N\n";
            }
        }
    }
    
    close $file;
    
    $schema->storage->dbh->do("load data local infile '/tmp/gen_grid' into table Item_Grid");
}

sub process_chars {
    my @chars = @_;
    
    foreach my $char (@chars) {
        next if defined $char_id && $char_id != $char->id;
        warn "Processing char: " . $char->id;       
       
        $char->organise_items;
    }
}
    