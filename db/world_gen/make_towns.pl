#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use lib "$ENV{RPG_HOME}/lib";

use DBI;
use Games::Dice::Advanced;
use RPG::Map;
use RPG::Maths;
use Math::Round qw(round);
use List::Util qw(shuffle);
use File::Slurp;
use RPG::LoadConf;
use FindBin;
use RPG::Schema::Town;

my $config = RPG::LoadConf->load( $FindBin::Bin . '/world_gen.yml' );

my $dbh = DBI->connect( @{ $config->{'Model::DBIC'}{connect_info} } );
$dbh->{RaiseError} = 1;

my $towns = $config->{towns};

my @names = shuffle read_file($config->{data_file_path} . '/town_names.txt');
chomp @names;

my $town_dist_x = $config->{town_min_distance};
my $town_dist_y = $config->{town_min_distance};

my $min_x = 1;
my $min_y = 1;
my $max_x = $config->{x_size};
my $max_y = $config->{y_size};

my %prosp_limits = RPG::Schema::Town->get_prosp_ranges();

my ($town_terrain_id) = $dbh->selectrow_array('select terrain_id from Terrain where terrain_name = "town"');

print "\nCreating $towns towns\n";

for ( 1 .. $towns ) {
    my ( $town_x, $town_y, $town_name );

    my $close_town;
    my $land_id;
    while ( ! defined $land_id ) {
        undef $close_town;

        my $x_range = $max_x - $min_x - 1;
        my $y_range = $max_y - $min_y - 1;

        $town_x = Games::Dice::Advanced->roll("1d$x_range") + $min_x - 1;
        $town_y = Games::Dice::Advanced->roll("1d$y_range") + $min_y - 1;

        my $land_allows_towns;

        warn "trying to creating town #$_ at: $town_x, $town_y\n";

        ($land_id, $land_allows_towns) = $dbh->selectrow_array("select land_id, allows_towns from Land
            JOIN Map_Tileset USING (tileset_id)
           where x=$town_x and y=$town_y");

        if (! $land_allows_towns) {
            warn "Land doesn't allow towns";
            undef $land_id;
            next;
        }

        $town_name = generate_name();

        my @surrounds = RPG::Map->surrounds( $town_x, $town_y, $town_dist_x, $town_dist_y );

        my @close_town = $dbh->selectrow_array( 'select * from Town join Land using (land_id) where x >= ' . $surrounds[0]->{x}
              . ' and x <= ' . $surrounds[1]->{x} . ' and y >= ' . $surrounds[0]->{y} . ' and y <= ' . $surrounds[1]->{y} );


        if (@close_town) {
            print "Can't create town at $town_x,$town_y .. too close to another town.\n";
            undef $land_id;
            next;
        }
    };

    $dbh->do("update Land set terrain_id = $town_terrain_id, creature_threat = 0 where land_id = $land_id");

    my $prosp = generate_prosperity();

    $dbh->do(
        'insert into Town(town_name, land_id, prosperity) values (?,?,?)',
        {},
        $town_name, $land_id, $prosp,
    );

    warn "Sucessfully created town #$_ at: $town_x, $town_y\n";
}

sub generate_name {
    my $name_to_use;

    foreach my $name (@names) {
        my @dupe_town = $dbh->selectrow_array("select * from Town where town_name = '$name'");

        unless (@dupe_town) {
            $name_to_use = $name;
            last;
        }
    }

    die "No available names" unless $name_to_use;

    return $name_to_use;
}

sub generate_prosperity {
    my $prosp;

    my @row          = $dbh->selectrow_array("select count(*) from Town");
    my $num_of_towns = shift @row;

    while ( !$prosp ) {
        $prosp = Games::Dice::Advanced->roll("1d100");

        return $prosp unless $num_of_towns;

        my $prosp_idx   = $prosp - 1;
        my $prosp_range = $prosp_idx - $prosp_idx % 5;

        my $max_percent = $prosp_limits{$prosp_range};

        my @row = $dbh->selectrow_array("select count(*) from Town where prosperity > $prosp_range+1 and prosperity <= $prosp_range+5");
        my $current_count = shift @row;

        my $current_percent = ( $current_count / $num_of_towns * 100 );

        warn "Prosp: $prosp; range: $prosp_range; max: $max_percent; current: $current_count; current_percent: $current_percent\n";

        if ( $current_percent >= $max_percent ) {
            warn "too many towns in this prosp range... ($current_count)\n";
            undef $prosp;
        }
    }

    return $prosp;
}
