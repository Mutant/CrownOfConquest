package RPG::Schema::Treasure_Chest;
use base 'DBIx::Class';
use strict;
use warnings;

use List::Util qw(shuffle);
use RPG::Maths;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Treasure_Chest');

__PACKAGE__->add_columns(qw/treasure_chest_id dungeon_grid_id trap gold/);

__PACKAGE__->set_primary_key(qw/treasure_chest_id/);

__PACKAGE__->has_many( 'items', 'RPG::Schema::Items', { 'foreign.treasure_chest_id' => 'self.treasure_chest_id' } );

__PACKAGE__->belongs_to( 'dungeon_grid', 'RPG::Schema::Dungeon_Grid', { 'foreign.dungeon_grid_id' => 'self.dungeon_grid_id' } );

my @TRAPS = qw/Curse Hypnotise Detonate/;
sub add_trap {
	my $self = shift;

	my $trap = ( shuffle @TRAPS )[0];
	$self->trap($trap);	
}

# True if the chest is empty, ignoring things like quest artifacts
sub is_empty {
	my $self = shift;
	
	my @items = grep { $_->item_type->item_type ne 'Artifact' } $self->items;
	
	return @items ? 0 : 1;
}

sub fill {
	my $self = shift;
	my %item_types_by_prevalence = @_;
	
	return unless $self->dungeon_grid->dungeon_room;
	
	my $dungeon = $self->dungeon_grid->dungeon_room->dungeon;
		
	return unless $dungeon;
		
	my $number_of_items = RPG::Maths->weighted_random_number(1..3);

	for (1..$number_of_items) {
		my $min_prevalence = 15 * (5 - $dungeon->level);

        my @items = map { $_ >= $min_prevalence ? @{$item_types_by_prevalence{$_}} : () } keys %item_types_by_prevalence;

	    my $item_type = $items[ Games::Dice::Advanced->roll( '1d' . scalar @items ) - 1 ];
	    
	    # We couldn't find a suitable item. Try again
	    next unless $item_type;
	    
	    my $enchantment_chance = 5 * $dungeon->level;
	    
	    my $enchantments = 0;
	    if (Games::Dice::Advanced->roll('1d100') <= $enchantment_chance) {
	    	$enchantments = RPG::Maths->weighted_random_number(1..3);
	    }

		my $item = $self->result_source->schema->resultset('Items')->create_enchanted(
			{
				item_type_id      => $item_type->id,
			    treasure_chest_id => $self->id,
			},
			{
				number_of_enchantments => $enchantments,
				max_value => $dungeon->level * 300,
			}
	    );
	}
	
	# Add a trap
	if (Games::Dice::Advanced->roll('1d100') <= 20) {
		$self->add_trap;		
	}
	else {
		$self->trap(undef);
	}
	
    $self->update;	
}

1;
