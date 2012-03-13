package RPG::Schema::Spell::Detonate;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use DateTime;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;
    
    my @vials = $character->search_related(
        'items',
        {
            'item_type.item_type' => 'Vial of Dragons Blood',
        },
        { 
            prefetch => { 'item_variables' => 'item_variable_name' },
            join => 'item_type', 
        },
    );
    
    if (! @vials) {
        return {
            type => 'detonate',
            custom => { no_vial => 1 },   
            didnt_cast => 1,
        }
    }
    
    if ($target->location->town) {
        return {
            type => 'detonate',
            custom => { in_town => 1 },   
            didnt_cast => 1,
        }        
    }
        
    $self->result_source->schema->resultset('Bomb')->create(
        {
            party_id => $target->id,
            level => $level,
            ($target->dungeon_grid_id ?
                ( dungeon_grid_id => $target->dungeon_grid_id ) :
                ( land_id => $target->land_id )),
            planted => DateTime->now(),
        }
    );
    
    return {
        type => 'detonate',
        custom => { planted => 1 },
    }    
    
}

1;