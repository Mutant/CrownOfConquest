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

use RPG;

RPG->run;