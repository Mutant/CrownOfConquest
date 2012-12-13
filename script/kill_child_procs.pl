#!/usr/bin/perl

use strict;
use warnings;
 
use File::Slurp qw(read_file);

my ($bytes) = @ARGV;
 
my ($ppid) = read_file('/var/run/rpg/rpg.pid');
chomp $ppid;

die "Usage: $0 ram_limit_in_bytes\n" unless $ppid && $bytes;

sub loggit {
    my $msg = shift;
    print "[" . (scalar localtime) . "] " . $msg . "\n"; 
}
 
my @smem_data = split /\n/, `smem -P [p]erl-fcg -H`;

my @goners;
foreach my $smem_data (@smem_data) {
    $smem_data =~ s/^\s+//;
    
    my ($pid, $user, $proc_name, $swap, $uss, $pss, $rss) = split /\s+/,$smem_data;
    
    next if $pid == $ppid;
    
    push @goners, $pid if $uss > $bytes;
    loggit "$pid, uss: $uss, pss: $pss, swap: $swap";
}

if (@goners) {
    # kill them slowly, so that all connection serving
    # children don't suddenly die at once.
    foreach my $victim (@goners) {
        loggit "Restarting $victim";
        kill 'HUP', $victim;
        sleep 10;
    }
}

