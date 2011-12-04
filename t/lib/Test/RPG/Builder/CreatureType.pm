use strict;
use warnings;

package Test::RPG::Builder::CreatureType;

sub build_creature_type {
    my $package = shift;
    my $schema  = shift;
    my %params  = @_;

	my $category = $schema->resultset('Creature_Category')->find_or_create( { name => $params{category_name} || 'Test' });
    my $type = $schema->resultset('CreatureType')->create( 
    	{ 
    		level => $params{creature_level} || 1, 
    		creature_category_id => $category->id,
    		hire_cost => $params{hire_cost} || 0,
    		maint_cost => $params{maint_cost} || 0,
    		creature_type => $params{type} || 'Test',
    		rare => $params{rare} || 0,
    	} 
    );

    return $type;
}

1;
