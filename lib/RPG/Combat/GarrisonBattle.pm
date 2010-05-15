package RPG::Combat::GarrisonBattle;

use Moose::Role;

use Data::Dumper;

requires qw/garrison/;

sub garrison_flee {
	my $self = shift;
	
	$self->garrison->items->delete;
	$self->garrison->gold(0);
	$self->garrison->update;		
}

1;