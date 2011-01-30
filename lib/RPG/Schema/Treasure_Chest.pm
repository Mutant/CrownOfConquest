package RPG::Schema::Treasure_Chest;
use base 'DBIx::Class';
use strict;
use warnings;

use List::Util qw(shuffle);

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

1;
