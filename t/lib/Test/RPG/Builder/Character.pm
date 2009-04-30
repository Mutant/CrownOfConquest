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
            hit_points => $params{hit_points} // 10,
            max_hit_points => $params{max_hit_points} // 10,
            party_order => $params{party_order} || 1,
            character_name => 'test',
            agility => 5,
            level => $params{level} || 1,
        }
    );
        
    return $character;
}

1;
