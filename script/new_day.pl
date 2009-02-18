#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    my $homedir = '/home/scrawley';
    my @user_include;
    foreach my $path (@INC) {
        if ( -d $homedir . '/perl' . $path ) {
            push @user_include, $homedir . '/perl' . $path;
        }
    }
    unshift @INC, @user_include;
    unshift @INC, $homedir . '/game/lib';
}

BEGIN {
	$ENV{DBIC_NO_WARN_BAD_PERL} = 1;
}

use RPG::NewDay;

my $new_day = RPG::NewDay->new();
$new_day->run();