use strict;
use warnings;

package Test::RPG::Builder::Character;

sub build_character {
    my $package = shift;
    my $schema = shift;
    my %params = @_;

    my $race = $schema->resultset('Race')->create( {} );

    my $class = $schema->resultset('Class')->create( {} );

    my $character = $schema->resultset('Character')->create(
        {
            party_id => $params{party_id},
            race_id  => $race->id,
            class_id => $class->id,
        }
    );
        
    return $character;
}

1;
