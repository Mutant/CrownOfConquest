package RPG::Schema::Special_Rooms::Treasure;

use Moose::Role;

with 'RPG::Schema::Special_Rooms::Interface';

use Games::Dice::Advanced;
use List::Util qw(shuffle);

sub generate_special {
    my $self = shift;
    
    my $level = $self->dungeon->level;
        
    my $schema = $self->result_source->schema;
    
    my $chests_count = Games::Dice::Advanced->roll('1d4') + 4;
    
    my $room_size = $self->sectors->count;
    
    $chests_count = $room_size if $chests_count > $room_size;
    
    my $chests_created = 0;
    my @sectors = shuffle $self->sectors;
    
    my @chests;
    foreach my $sector (@sectors) {
        next if $sector->teleporter || $sector->treasure_chest;
        
        my $gold = (Games::Dice::Advanced->roll('1d200') + 250) * $level;
		my $chest = $schema->resultset('Treasure_Chest')->create(
			{
				dungeon_grid_id => $sector->id,
				gold => $gold,
			}
		);
		$chest->add_trap;
		$chest->update;
		
		push @chests, $chest;
		
		$chests_created++;
		last if $chests_created >= $chests_count;
    }
    
    @chests = shuffle @chests;
    
    my $items = Games::Dice::Advanced->roll('1d3') - 1;

	my @item_types = shuffle $schema->resultset('Item_Type')->search(
		{
			'category.hidden'   => 0,
			'category.findable' => 1,
		},
		{ join => 'category', },
	);
	
    for (1..$items) {
        my $chest = $chests[$_-1];
        next unless $chest;

		# Find an enchantable item type
		my $item_type = shift @item_types;		
		last unless $item_type;
		
	    while ($item_type->category->enchantments_allowed->count <= 0) {
	        $item_type = shift @item_types;
	        last unless $item_type;
	    }
	    
	    my $enchantment_count = RPG::Maths->weighted_random_number(1..3);

		my $item = $schema->resultset('Items')->create_enchanted(
			{ item_type_id => $item_type->id, },
			{ 
				number_of_enchantments => $enchantment_count,
				max_value => $level * 1500,
			},
		);
		
		$item->update( { treasure_chest_id => $chest->id } );
    }    
}

sub _chests {
    my $self = shift;
    
    my $schema = $self->result_source->schema;
    
    my @chests = $schema->resultset('Treasure_Chest')->search(
        {
            'dungeon_grid.dungeon_room_id' => $self->id,
        },
        {
            join => 'dungeon_grid',
        }
    );
    
    return @chests;    
}

sub remove_special {
    my $self = shift;
    
    my @chests = $self->_chests;
    
    foreach my $chest (@chests) {
        $chest->delete;
    }
} 

sub is_active {
    my $self = shift;
    
    my @chests = $self->_chests;
    
    my $active = 0;
    foreach my $chest (@chests) {
        if (! $chest->is_empty || $chest->gold > 0) {
            $active = 1;
        }   
    }
    
    return $active;
}

1;