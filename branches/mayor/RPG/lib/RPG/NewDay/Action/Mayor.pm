package RPG::NewDay::Action::Mayor;
use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Town/ }

sub run {
    my $self = shift;

    my $c = $self->context;
    
    # Find towns without a mayor
    my @towns = $c->schema->resultset('Town')->search(
    	{
    		'mayor' => undef,
    	}
    );
    
    foreach my $town (@towns) {
    	my $mayor_level = int $town->prosperity / 4;
    	
    	my $character = $c->schema->resultset('Character')->generate_character(
	    	allocate_equipment => 1,
	    	level => $mayor_level,
	    );
	    
	    $town->mayor($character->id);
	    $town->update;    		
    }
    
}

1;