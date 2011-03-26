use strict;
use warnings;

package Test::RPG::Builder::Kingdom;

sub build_kingdom {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    my $town = $schema->resultset('Kingdom')->create(
        {
            name => 'Test Kingdom',
            mayor_tax => $params{mayor_tax} || 10,
            gold => $params{gold} || 100,
        }   
    );
    
    return $town;
}

1;