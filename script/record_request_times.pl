#!/usr/bin/perl

use strict;
use warnings;

use autodie;

use DBI;
use RPG::LoadConf;
use Date::Parse;

my $log_file = shift;

my $config = RPG::LoadConf->load();
my $dbh = DBI->connect(@{$config->{'Model::DBIC'}{connect_info}} );

open (my $fh, '<', $log_file);
while (my $line = <$fh>) {
    if ($line =~ /\[(.+?)\].+Request took\s+([\d\.]+)s/) {
        my $date = $1;
        my $total_time = $2;
        
        my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($date);
        $year+=1900;
        $month++;
        my $date_str = "$year-$month-$day $hh:$mm:$ss";
        
        $dbh->do("INSERT INTO Response_Time (date, action, resp_time) VALUES (?,?,?)", {}, $date_str, 'top_level', $total_time);
        
        <$fh> for 1..3; # Get rid of header;
        while (my $req_line = <$fh>) {
            last if $req_line =~ /^'---/;

            if ($req_line =~ m{\/(.+?)\s+\|\s+([\d\.]+)s}) {
                $dbh->do("INSERT INTO Response_Time (date, action, resp_time) VALUES (?,?,?)", {}, $date_str, '/'.$1, $2);
            }            
        }  
    }
}
close($fh);