#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use List::Util qw(shuffle);

my $config = RPG::LoadConf->load();
my $schema = RPG::Schema->connect( @{$config->{'Model::DBIC'}{connect_info}} );

my @kingdoms = $schema->resultset('Kingdom')->search();

my @parties = $schema->resultset('Party')->search(
    {
        defunct => undef,
    }
);

my $today = $schema->resultset('Day')->find_today;

foreach my $party (@parties) {
    if ($party->location and my $kingdom_id = $party->location->kingdom_id) {
        $party->kingdom_id($kingdom_id);
    }
    else {
        my $kingdom = (shuffle @kingdoms)[0];
        $party->kingdom_id($kingdom->id);   
    }
    
    $party->update;
    
    my $new_kingdom = $party->kingdom;
    $new_kingdom->increment_highest_party_count;
    $new_kingdom->highest_party_count_day_id($today->id);
    $new_kingdom->update;
}
