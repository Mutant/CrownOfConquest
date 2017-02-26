#!/usr/bin/perl

use strict;
use warnings;

my $home;
BEGIN {
    $home = $ENV{RPG_HOME} // '';
};
use lib "$home/lib";

use RPG::LoadConf;

use DBI;
use Test::Harness;

if ($ARGV[0] && $ARGV[0] eq '--refresh-schema') {
    shift @ARGV;

    print "# Refreshing schema...\n";

    my $config = RPG::LoadConf->load();

    # Connect to DBs so we can figure out the name (to pass to mysql commandline)
    my $main_dbh = DBI->connect( @{ $config->{'Model::DBIC'}{connect_info} } )     // die "Can't connect to main DB\n";
    my $test_dbh = DBI->connect( @{ $config->{'TestModel::DBIC'}{connect_info} } ) // die "Can't connect to test DB\n";

    my $main_db = $main_dbh->{Name};
    my $main_user = $main_dbh->{Username};

    my $test_db = $test_dbh->{Name};
    my $test_user = $test_dbh->{Username};

    my $dumpFile; my $rmProg;
    if ( $^O =~ /MSWin32/ ) {
        $dumpFile = $ENV{RPG_HOME} . "\\db_dump";
        $rmProg = 'del';
    } else {
        $dumpFile = '/tmp/db_dump';
        $rmProg = 'rm';
    }
    system("mysqldump -u $main_user -d $main_db > $dumpFile");
    system("mysqldump -u $main_user -t $main_db Equip_Places Class Race Spell Quest_Type Quest_Param_Name Levels Dungeon_Position Enchantments Dungeon_Special_Room Building_Type Skill Map_Tileset Building_Upgrade_Type >> $dumpFile");
    system("mysql -u $test_user $test_db < $dumpFile");
    system("$rmProg $dumpFile");
}

runtests(glob 'bin/*.t');
