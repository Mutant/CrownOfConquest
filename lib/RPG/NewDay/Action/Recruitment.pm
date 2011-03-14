package RPG::NewDay::Action::Recruitment;

use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;

use List::Util qw(max shuffle);
use Games::Dice::Advanced;

use RPG::Maths;
use File::Slurp;

sub depends { qw/RPG::NewDay::Action::CreateDay/ };

sub run {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search( {}, { prefetch => { 'characters' => 'items' }, }, );

    while ( my $town = $town_rs->next ) {
        my @characters = $town->characters;
        
        @characters = $self->randomly_delete_characters(@characters);

        my $ideal_number_of_characters = int( $town->prosperity / $c->config->{characters_per_prosperity} );
        $ideal_number_of_characters = 1 if $ideal_number_of_characters < 1;

        if ( scalar @characters < $ideal_number_of_characters ) {
            $c->logger->debug( 'Town id: ' . $town->id . " has " . scalar @characters . " characters, but should have $ideal_number_of_characters" );
            
            my $number_of_chars_to_create = $ideal_number_of_characters - scalar @characters;

            for ( 1 .. $number_of_chars_to_create ) {
                $self->generate_character($town);
            }
        }
    }
}

sub randomly_delete_characters {
	my $self = shift;
	my @characters = @_;
	
	if (Games::Dice::Advanced->roll('1d100') <= 10) {
		@characters = shuffle @characters;
		my $unlucky = shift @characters;
		$unlucky->delete if defined $unlucky;
	}
	
	return @characters;
}

sub generate_character {
    my $self = shift;
    my $town = shift;

    my $c = $self->context;

    my $character = $c->schema->resultset('Character')->generate_character(
    	allocate_equipment => 1,
    	level => Games::Dice::Advanced->roll('1d20'),
    );
    
    $character->set_default_spells;
    
    $character->town_id($town->id);
    $character->update;
    
    $c->schema->resultset('Character_History')->create(
        {
            character_id => $character->id,
            day_id       => $c->current_day->id,
            event        => $character->character_name . " arrived at the town of " . $town->town_name . " and began looking for a party to join",
        },
    );
}

__PACKAGE__->meta->make_immutable;


1;

