use strict;
use warnings;

package Test::RPG::Builder::Town;

sub build_town {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    unless ($params{land_id}) {
        my $location = $schema->resultset('Land')->create( {
            kingdom_id => $params{kingdom_id},
        } );
        $params{land_id} = $location->id;
    }
    
    my $town = $schema->resultset('Town')->create(
        {
            land_id => $params{land_id},
            prosperity => $params{prosperity} || 50,
            blacksmith_age => $params{blacksmith_age} || 0,
            gold => $params{gold} || 0,
            town_name => "Test Town",
            mayor_rating => $params{mayor_rating} || 0,
            advisor_fee => $params{advisor_fee} || 0,
            sales_tax => $params{sales_tax} || 0,
            peasant_state => '',
            peasant_tax => $params{peasant_tax} || 0,
            character_heal_budget => $params{character_heal_budget} || 0,
        }   
    );
    
    if ($params{kingdom_loyalty}) {
        foreach my $kingdom_id (keys %{ $params{kingdom_loyalty} }) {
            $schema->resultset('Kingdom_Town')->create(
                {
                    kingdom_id => $kingdom_id,
                    town_id => $town->id,
                    loyalty => $params{kingdom_loyalty}->{$kingdom_id},                              
                }   
            );
        }
    }
    
    return $town;
}

1;