use strict;
use warnings;

package Test::RPG::Builder::Quest::Find_Dungeon_Item;

use Test::RPG::Builder::Land;
use Test::RPG::Builder::Dungeon;
use Test::RPG::Builder::Dungeon_Room;
use Test::RPG::Builder::Treasure_Chest;
use Test::RPG::Builder::Item_Type;

use List::Util qw(shuffle);

sub build_quest {
    my $self   = shift;
    my $schema = shift;
    my %params = @_;

    my @land   = Test::RPG::Builder::Land->build_land($schema);

    my $town = $schema->resultset('Town')->create( { land_id => $land[4]->id, town_name => 'test town' } );
    my $dungeon = Test::RPG::Builder::Dungeon->build_dungeon($schema, land_id => $land[8]->id, level => 2);
    
    my $quest_type = $schema->resultset('Quest_Type')->find( { 'quest_type' => 'find_dungeon_item' } );
    
    my $dungeon_room = Test::RPG::Builder::Dungeon_Room->build_dungeon_room(
    	$schema, 
    	dungeon_id => $dungeon->id,
    	top_left => { x=> 1, y=> 1 },
    	bottom_right => { x=> 5, y => 5 },
    );
    
    my $chest_sector = (shuffle $dungeon_room->sectors)[0];
    
    my $chest = Test::RPG::Builder::Treasure_Chest->build_chest($schema, dungeon_grid_id => $chest_sector->id);
    
    my $item_type = Test::RPG::Builder::Item_Type->build_item_type($schema, item_type => 'Artifact');    

    my %create_params;
    if ( $params{party_id} ) {
        $create_params{party_id} = $params{party_id};
    }

    my $quest = eval {
    	$schema->resultset('Quest')->create(
	        {
	            town_id       => $town->id,
	            quest_type_id => $quest_type->id,
	            status        => $params{status} || 'Not Started',
	            %create_params,
	        }
	    );
    };
    
    my $error = $@;
    if ($error) {
    	die $error->message if $error->isa('RPG::Exception');
    	die $error;    		
    }

    return $quest;

}

1;
