#!/usr/bin/perl

use strict;
use warnings;

use lib "$ENV{RPG_HOME}/lib";

use RPG::NewDay::Context;
use RPG::Schema;
use RPG::LoadConf;

use DateTime;
use Log::Dispatch;
use FindBin;

my @actions_to_run = qw(
  Blacksmith
  CreatureOrbs
  Recruitment
  Quest
  Mayor
  Shop
  Castles
  Sewers
  Dungeon
  Dungeon_Special_Room
  Kingdom
  Majesty
  MiniMap
);

my $config = RPG::LoadConf->load( $FindBin::Bin . '/world_gen.yml' );
my $schema = RPG::Schema->connect( $config, @{ $config->{'Model::DBIC'}{connect_info} } );
my $log = Log::Dispatch->new(
    outputs => [
        [ 'Screen', min_level => 'debug', newline => 1 ],
    ],
);

my $context = RPG::NewDay::Context->new(
    config   => $config,
    schema   => $schema,
    logger   => $log,
    datetime => DateTime->now(),
);

foreach my $action (@actions_to_run) {
    my $pkg = "RPG::NewDay::Action::$action";
    eval "require $pkg";

    $log->info("Running action: $pkg");

    my $obj = $pkg->new(context => $context);
    $obj->run();
}
