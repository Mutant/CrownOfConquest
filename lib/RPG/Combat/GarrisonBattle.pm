package RPG::Combat::GarrisonBattle;

use Moose::Role;

use Data::Dumper;

requires qw/garrison/;

sub garrison_flee {
	my $self = shift;
	
	foreach my $item ($self->garrison->items) {
		$item->garrison_id(undef);
		$item->land_id($self->location->id);
		$item->update;		
	}
	$self->garrison->gold(0);
	$self->garrison->update;		
}

1;