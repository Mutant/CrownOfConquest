#!/usr/bin/perl

use strict;
use warnings;

$| = 1;

use Data::Dumper;

use lib "$ENV{RPG_HOME}/lib";

use DBI;
use Games::Dice::Advanced;
use RPG::Map;
use List::Util qw(shuffle);
use RPG::LoadConf;
use FindBin;

my $config = RPG::LoadConf->load($FindBin::Bin . '/world_gen.yml');

my $dbh = DBI->connect( @{ $config->{'Model::DBIC'}{connect_info} } );
$dbh->{RaiseError} = 1;

my $min_x = 1;
my $min_y = 1;
my $max_x = $config->{x_size};
my $max_y = $config->{y_size};

my %tileset = %{ $config->{tileset_x} };

my ($town_terrain_id) = $dbh->selectrow_array('select terrain_id from Terrain where terrain_name = "town"');

my $tilesets = $dbh->selectall_arrayref('select * from Map_Tileset');

my %tileset_data = get_tileset_data($tilesets);

my $map;
my %terrain_count;
my $current_tileset = 0;

print "Creating a $max_x x $max_y world\n";

for my $y ( $min_y .. $max_y ) {
    for my $x ( $min_x .. $max_x ) {
        if ( defined $tileset{$y} && $tileset{$y} != $current_tileset ) {
            $current_tileset = $tileset{$y};
            print "\nTileset now: $current_tileset\n";
        }

        my ( $terrain_id, $variation ) = get_terrain_id( $x, $y );

        $map->[$x][$y] = $terrain_id;
        $terrain_count{$terrain_id}++;

        my $creature_threat = 50;

        $dbh->do(
            'insert into Land(x, y, terrain_id, variation, tileset_id, creature_threat) values (?,?,?,?,?,?)',
            {},
            $x, $y, $terrain_id, $variation, $current_tileset, $creature_threat,
        );
    }
    print ".";
}
print "Done!\n";

sub get_terrain_id {
    my ( $x, $y ) = @_;

    my @possible = @{ $tileset_data{$current_tileset}->{terrain} };

    my $terrain_id = ( shuffle @possible )[0];

    my $variations = $tileset_data{$current_tileset}->{variation}{$terrain_id};

    my $variation = ( shuffle( 1 .. $variations ) )[0];

    return $terrain_id, $variation;
}

sub get_tileset_data {
    my $tilesets = shift;

    my %tileset_data;

    my @terrain;
    my $sth = $dbh->prepare("select * from Terrain");
    $sth->execute;

    while ( my $rec = $sth->fetchrow_hashref ) {
        push @terrain, $rec;
    }

    foreach my $tileset (@$tilesets) {
        my ( $id, $name, $prefix ) = @$tileset;

        $prefix //= '';

        foreach my $terrain (@terrain) {
            next if $terrain->{terrain_id} == $town_terrain_id;

            my $name = $terrain->{terrain_name};
            $name =~ s/ /_/g;

            my @imgs = glob( $ENV{RPG_HOME} . "/docroot/static/images/map/$prefix$name*" );

            if (@imgs) {
                push @{ $tileset_data{$id}->{terrain} }, $terrain->{terrain_id};
                $tileset_data{$id}->{variation}{ $terrain->{terrain_id} } = scalar @imgs;
            }
        }
    }

    return %tileset_data;
}
