use strict;
use warnings;

package Test::RPG::Ticker::LandGrid;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;

sub startup : Tests(startup => 1) {
    my $self = shift;
    
    use_ok 'RPG::Ticker::LandGrid';
}

sub test_land_grid_constructer : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my @land = $self->_create_land();
    
    # WHEN
    my $land_grid = RPG::Ticker::LandGrid->new(schema => $self->{schema});
    
    # THEN
    is($land_grid->total_sectors(), 9, "Total sectors set correctly");
    is($land_grid->max_x(), 3, "Max x set correctly");
    is($land_grid->max_y(), 3, "Max y set correctly");
    
}

sub test_cg_state_recorded : Tests(3) { 
    my $self = shift;
    
    # GIVEN
    my @land = $self->_create_land();
    my $cg1 = $self->{schema}->resultset('CreatureGroup')->create( { land_id => $land[0]->id, }, );
    
    # WHEN
    my $land_grid = RPG::Ticker::LandGrid->new(schema => $self->{schema});
    
    # THEN
    my $land = $land_grid->get_land_at_location(1, 1);
    is($land->{creature_group}, 1, "Creature group found in sector");
    is($land->{ctr}, 10, "CTR loaded");
    
    $land = $land_grid->get_land_at_location(2, 1);
    is($land->{creature_group}, 0, "Creature group not found in other sector");
    
}

sub _create_land {
    my $self   = shift;
    my $x_size = shift || 3;
    my $y_size = shift || 3;

    my $non_town_terrain = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'non_town_terrain', } );

    $self->{town_terrain} = $self->{schema}->resultset('Terrain')->create( { terrain_name => 'town', } );

    my @land;
    for my $x ( 1 .. $x_size ) {
        for my $y ( 1 .. $y_size ) {
            push @land, $self->{schema}->resultset('Land')->create(
                {
                    x               => $x,
                    y               => $y,
                    terrain_id      => $non_town_terrain->id,
                    creature_threat => 10,
                }
            );
        }
    }    

    return @land;
}