use strict;
use warnings;

package Test::RPG::Builder::CreatureType;

sub build_creature_type {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

	my $category = $schema->resultset('Creature_Category')->find_or_create( { name => $params{category_name} || 'Test' });
    my $type = $schema->resultset('CreatureType')->create( { level => $params{creature_level} || 1, creature_category_id => $category->id } );

    return $type;
}

1;
