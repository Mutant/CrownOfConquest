#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;

use DateTime;
use DateTime::Format::Strptime;
use File::Slurp;

my $DATA_DIR = '/var/lib/awstats/';

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, @{$config->{'Model::DBIC'}{connect_info}} );

my $date = shift;

my $dt;
if ($date) {
    my $strp = DateTime::Format::Strptime->new(
        pattern   => '%F',
    );
    $dt = $strp->parse_datetime($date);
}
else {
    $dt = DateTime->now()->subtract( hours => 1 );
}

my $file = 'awstats' . sprintf('%02d', $dt->month()) . $dt->year() . '.txt';

my @data = read_file( $DATA_DIR . $file );

my $found_day_data = 0;
my $day_string = $dt->ymd('');
my $visitor_count;
my $found_line = 0;

foreach my $line (@data) {
    next if ! $found_day_data && $line !~ /^BEGIN_DAY/;
    $found_day_data = 1;
    
    chomp $line;
    
    if ($line =~ /^$day_string/o) {
        my @stat_data = split / /,$line;
        $visitor_count = $stat_data[4];
        $found_line = 1;
        last;
    }
}

exit unless $found_line;

my $day_stat = $schema->resultset('Day_Stats')->find_or_create(
    {
        date => $dt->ymd,
    }
);
$day_stat->visitors($visitor_count // 0);
$day_stat->update;