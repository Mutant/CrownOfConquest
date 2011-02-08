package Test::RPG::Schema::Special_Rooms::Rare_Monsters;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::CreatureType;

sub setup : Tests(setup) {
    my $self = shift;
    
    my $type1 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, category_name => 'Humanoid', type => 'Goblin Chief', creature_level => 2, rare => 1);
    my $type2 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, category_name => 'Humanoid', type => 'Orc Shaman', creature_level => 2, rare => 1);
    my $type3 = Test::RPG::Builder::CreatureType->build_creature_type($self->{schema}, category_name => 'Humanoid', type => 'Goblin');    
}

sub test_make_sepecial : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, level => 1);
  
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        dungeon_id => $dungeon->id,
        special_room_type => 'rare_monster',
        top_left => {x=>1, y=>1},
        bottom_right => {x=>5,y=>5},
    );
    
    my $special_room_type = $self->{schema}->resultset('Dungeon_Special_Room')->find(
        {
            room_type => 'rare_monster',
        }
    );
    
    # WHEN
    $room->make_special($special_room_type);
    
    # THEN
    is(defined $room->special_room_id, 1, "Special room id set");
    
    my @cg = $self->{schema}->resultset('CreatureGroup')->search();
    is(scalar @cg, 1, "1 cg generated");
    is($cg[0]->dungeon_grid->dungeon_room_id, $room->id, "CG generated in dungeon room");
    
}

sub test_remove_special : Tests(3) {
    my $self = shift;
    
    # GIVEN
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($self->{schema}, level => 1);
  
    my $room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room($self->{schema}, 
        dungeon_id => $dungeon->id,
        special_room_type => 'rare_monster',
        top_left => {x=>1, y=>1},
        bottom_right => {x=>5,y=>5},
    );
    $room->generate_special;
        
    # WHEN
    $room->remove_special;
    
    # THEN
    my @cg = $self->{schema}->resultset('CreatureGroup')->search();
    is(scalar @cg, 1, "1 cg generated");
    is($cg[0]->dungeon_grid_id, undef, "CG removed from dungeon grid");
    
    $room->discard_changes;
    is($room->special_room_id, undef, "Room no longer special");
}

1;