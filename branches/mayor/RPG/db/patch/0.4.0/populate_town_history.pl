#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::Template;
use YAML;

my $schema = RPG::Schema->connect( "dbi:mysql:game-copy", "root", "", { AutoCommit => 1 }, );

my $home = $ENV{RPG_HOME};
die "RPG_HOME not defined\n" unless $home;
my $config = YAML::LoadFile("$home/rpg.yml");
if ( -f "$home/rpg_local.yml" ) {
    my $local_config = YAML::LoadFile("$home/rpg_local.yml");
    $config = { %$config, %$local_config };
}

my $today = $schema->resultset('Day')->find_today;

my @day_ids = ( $today->id );

for my $days_ago ( 1 .. 6 ) {
    my $previous_day = $schema->resultset('Day')->find( { day_number => $today->day_number - $days_ago, } );
    push @day_ids, $previous_day->id;
}

my @combat_logs = $schema->resultset('Combat_Log')->search( { game_day => \@day_ids, }, { prefetch => 'land', } );

foreach my $log (@combat_logs) {
    my @towns = $schema->resultset('Town')->find_in_range(
        {
            x => $log->land->x,
            y => $log->land->y,
        },
        6,
    );

    if (@towns) {

        my $message = RPG::Template->process( $config, 'combat/town_news_message.html', { log => $log, }, );

        foreach my $town (@towns) {
            $schema->resultset('Town_History')->create(
                {
                    town_id => $town->id,
                    day_id  => $today->id,
                    message => $message,
                }
            );
        }
    }
}

1;
