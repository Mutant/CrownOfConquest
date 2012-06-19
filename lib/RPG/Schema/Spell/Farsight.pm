package RPG::Schema::Spell::Farsight;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;
use RPG::Map;
use Carp;

sub _cast {
    my ( $self, $character, $sector, $level ) = @_;
    
    croak "Invalid sector!\n" unless $sector;
    
    my $party = $character->party;
    my $party_location = $party->location;
    
    my $distance_to_sector = RPG::Map->get_distance_between_points(
        {
            x => $party_location->x,
            y => $party_location->y,
        },
        {
            x => $sector->x,
            y => $sector->y,
        }
    );
    
    my $schema = $self->result_source->schema;
    
    my $chance = ($level*3)-$distance_to_sector;
    
    my %discoveries;
          
    my $building_roll = Games::Dice::Advanced->roll('1d100');
    if ($building_roll <= $chance) {
        # Building discovered
        my $building = $sector->building;
        
        $discoveries{building} = $building && $building->building_type->name // 'none';
        
        if ($building and my @upgrades = $building->upgrades) {
            my @upgrade_types = $schema->resultset('Building_Upgrade_Type')->search;
            foreach my $type (@upgrade_types) {
                my $upgrade_roll = Games::Dice::Advanced->roll('1d100');
                if ($upgrade_roll <= $chance) {
                    # Upgrade discovered
                    if (my ($upgrade) = grep { $_->type_id == $type->id } @upgrades) {
                        $discoveries{building_upgrade}{$type->name} = $upgrade->level; 
                    }
                    else {
                        $discoveries{building_upgrade}{$type->name} = 'none';
                    }
                }
            }
        }
        else {
            $discoveries{building_upgrade} = 'none';
        }
    }
    
    my $town = $sector->town;
    if ($town) {
        $discoveries{town} = $town;
        
        my $mayor_roll = Games::Dice::Advanced->roll('1d100');
        if ($mayor_roll <= $chance) {
            $discoveries{mayor} = $town->mayor // 'none';   
        }
        
        my $town_garrison_roll = Games::Dice::Advanced->roll('1d100');
        if ($town_garrison_roll <= $chance) {
            my $garrison_char_count = $schema->resultset('Character')->search(
                {
                    status => 'mayor_garrison',
                    status_context => $town->id,
                }
            )->count;
            $discoveries{town_garrison} = $garrison_char_count;
        }   
        
        my $guards_roll = Games::Dice::Advanced->roll('1d100');
        if ($guards_roll <= $chance) {        
            my $castle = $town->castle;

        	my @crets = $schema->resultset('Creature')->search(
        		{
        			'dungeon_room.dungeon_id' => $castle->id,
        		},
        		{
        			join => {'creature_group' => {'dungeon_grid' => 'dungeon_room'}},
        		}
        	);            
            
            if (@crets) {
            	my @creatures = $schema->resultset('Creature')->search(
            		{
            			'creature_id' => [map { $_->id } @crets],
            		},
            		{
            		    select => [{'count' => '*'}, 'type.creature_type'],
            		    as => ['count', 'type'],
            			join => 'type',
            			order_by => 'level',
            			group_by => 'type.creature_type',
            		}
            	);
            	
            	$discoveries{town_guards} = \@creatures;
            }
            else {
                $discoveries{town_guards} = 'none';
            }
        }
    }
    else {
        for my $item (qw/garrison orb dungeon/) {
            my $roll = Games::Dice::Advanced->roll('1d100');
            if ($roll <= $chance) {
                $discoveries{$item} = $sector->$item // 'none';
            }    
        }
    }
            
    return {
        type => 'farsight',
        defender => $sector,
        custom => \%discoveries,
    }
}

1;