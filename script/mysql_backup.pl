#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;
use DateTime;

my $DIR = '/home/sam/mysqlbackup';
my $dt = DateTime->now();

my $backup_dir = "$DIR/" . $dt->day_abbr();

system("mkdir -p $backup_dir");

my $password = read_file('/home/sam/dumppw');
chomp $password;

system("mysqldump -u dump -p$password game > $backup_dir/game.sql");
system("gzip --force -9 $backup_dir/game.sql");