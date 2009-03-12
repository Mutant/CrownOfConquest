#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

open (my $log, '<', '/home/sam/RPG/log/debug.log');
my @log_lines = <$log>;
close ($log);

my $idx = 0;
my @queries;
foreach my $log_line (@log_lines) {
    if ($log_line =~ /Execution took (.+) seconds./) {
        my $time = $1;
        
        my $search_idx = $idx;
        while ($search_idx > 0) {
            $search_idx--;
            if ($log_lines[$search_idx] =~ /Executing ... (.+)$/) {
                push @queries, {
                    query => $1,
                    time => $time,
                };  
                last; 
            }
        }           
    }
    
    $idx++;
}

@queries = sort { $b->{time} <=> $a->{time} } @queries;

for my $rank (0 .. 99) {
    print $rank+1 . ". $queries[$rank]->{time} - $queries[$rank]->{query}\n";
} 

