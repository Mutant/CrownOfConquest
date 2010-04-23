package Test::RPG::Schema::Dungeon_Grid;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Data::Dumper;

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Dungeon_Grid;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Dungeon_Grid';
}

sub dungeon_setup : Tests(setup) {
    my $self = shift;

    # Query Dungeon_Positions
    my %positions = map { $_->position => $_->id} $self->{schema}->resultset('Dungeon_Position')->search();

    $self->{positions} = \%positions;
}

sub dungeon_shutdown : Tests(shutdown) {
	my $self = shift;
	$self->{mock_rpg_schema}->unfake_module();	
}

sub test_has_wall : Tests(4) {
    my $self = shift;

    # GIVEN
    my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid( $self->{schema}, walls => [ 'left', 'top' ], x=>1, y=>1 );
    
    # WHEN
    my %results;
    for my $wall (qw/left right top bottom/) {
        $results{$wall} = $sector->has_wall($wall);
    }
    
    # THEN
    is($results{left}, 1, "Has a left wall");
    is($results{right}, 0, "Doesn't have a right wall");
    is($results{top}, 1, "Has a top wall");
    is($results{bottom}, 0, "Doesn't have a bottom wall");
}

sub test_sectors_allowed_to_move_to_1 : Tests(18) {
	my $self = shift;	
	
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, dungeon_id => $dungeon->id);    
    
    my @sectors;
    for my $x ( 1 .. 4 ) {
        for my $y ( 1 .. 4 ) {
            my @walls;
            my @doors;

            if ( $x == 3 && $y == 1 ) {
                @walls = ( 'top', 'right' );
            }
            if ( $x == 1 && $y == 1 ) {
                @walls = ( 'bottom', 'right' );
                @doors = ('right');
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            push @sectors, $sector;
        }
    }
    
    $self->_build_dungeon_paths( $dungeon );
    
    my $start_sector = $sectors[5];    # 2,2
    
    my $sectors_by_coord;
    foreach my $sector (@sectors) {
    	$sectors_by_coord->[$sector->x][$sector->y] = $sector;	
    }
    
    my %expected_allowed_to_move_to;
    $expected_allowed_to_move_to{$sectors[0]->id} = 1; # 1,1
    $expected_allowed_to_move_to{$sectors[1]->id} = 1; # 1,2
    $expected_allowed_to_move_to{$sectors[2]->id} = 1; # 1,3
    $expected_allowed_to_move_to{$sectors[4]->id} = 1; # 2,1
    $expected_allowed_to_move_to{$sectors[6]->id} = 1; # 2,3 
    $expected_allowed_to_move_to{$sectors[8]->id} = 1; # 3,1
    $expected_allowed_to_move_to{$sectors[9]->id} = 1; # 3,2
    $expected_allowed_to_move_to{$sectors[10]->id} = 1;# 3,3

    # WHEN
    my $allowed_to_move_to = $start_sector->sectors_allowed_to_move_to( 1 );

    # THEN
	for my $y (1 .. 4) {
		for my $x (1 .. 4) {
			my $sector_to_check = $sectors_by_coord->[$x][$y];
    		is( $allowed_to_move_to->{$sector_to_check->id}, $expected_allowed_to_move_to{$sector_to_check->id}, "Allowed to move as expected for $x, $y" );
		}		
    }    
}

sub test_sectors_allowed_to_move_to_door_blockages : Tests(11) {
	my $self = shift;	
	
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema});
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, dungeon_id => $dungeon->id);    
    
    my @sectors;
    for my $x ( 1 .. 3 ) {
        for my $y ( 1 .. 3 ) {
            my @walls;
            my @doors;

			if ( $x == 1 && $y == 1) {
				@walls = ( 'right' );
			}
            if ( $x == 2 && $y == 1 ) {
                @walls = ( 'left', 'bottom' );
            }
            if ( $x == 2 && $y == 2 ) {
                @walls = ( 'top' );
            }
            if ( $x == 3 && $y == 1 ) {
                @walls = ( 'bottom' );
                @doors = ({
                	type => 'stuck',
                	state => 'closed',
                	position => 'bottom',	
                });
            }
            if ( $x == 3 && $y == 2 ) {
                @walls = ( 'top' );
                @doors = ({
                	type => 'stuck',
                	state => 'closed',
                	position => 'top',	
                });
            }

            my $sector = Test::RPG::Builder::Dungeon_Grid->build_dungeon_grid(
                $self->{schema},
                x     => $x,
                y     => $y,
                walls => \@walls,
                doors => \@doors,
                dungeon_room_id => $dungeon_room->id,
            );

            push @sectors, $sector;
        }
    }
    
    $self->_build_dungeon_paths( $dungeon );
    
    my $sectors_by_coord;
    foreach my $sector (@sectors) {
    	$sectors_by_coord->[$sector->x][$sector->y] = $sector;	
    }

    my $start_sector = $sectors_by_coord->[2][2];
    
    my %expected_allowed_to_move_to;
    $expected_allowed_to_move_to{$sectors_by_coord->[1][1]->id} = 1;
    $expected_allowed_to_move_to{$sectors_by_coord->[1][2]->id} = 1;
    $expected_allowed_to_move_to{$sectors_by_coord->[3][2]->id} = 1;  
    $expected_allowed_to_move_to{$sectors_by_coord->[1][3]->id} = 1;
    $expected_allowed_to_move_to{$sectors_by_coord->[2][3]->id} = 1;
    $expected_allowed_to_move_to{$sectors_by_coord->[3][3]->id} = 1;

    # WHEN
    my $allowed_to_move_to = $start_sector->sectors_allowed_to_move_to( 1 );

    # THEN
	for my $y (1 .. 3) {
		for my $x (1 .. 3) {
			my $sector_to_check = $sectors_by_coord->[$x][$y];
    		is( $allowed_to_move_to->{$sector_to_check->id}, $expected_allowed_to_move_to{$sector_to_check->id}, "Allowed to move as expected for $x, $y" );
		}		
    }    
}


sub _build_dungeon_paths {
	my $self = shift;
	my $dungeon = shift;
	
    use_ok 'RPG::NewDay::Action::Dungeon';

    my $logger = Test::MockObject->new();
    $logger->set_always('debug');
    $logger->set_always('info');

    $self->{context} = Test::MockObject->new();

    $self->{context}->set_always( 'logger', $logger );
    $self->{context}->set_always( 'schema', $self->{schema} );
    $self->{context}->set_always( 'config', $self->{config} );
    $self->{context}->set_isa('RPG::NewDay::Context');	
    
    my $dungeon_builder = RPG::NewDay::Action::Dungeon->new( context => $self->{context} );
    
    $dungeon_builder->populate_sector_paths( $dungeon );
		
}
1;
