use strict;
use warnings;

package Test::RPG::Builder::Kingdom;

use Test::RPG::Builder::Character;

sub build_kingdom {
    my $package = shift;
    my $schema = shift;
    my %params = @_;
    
    my $kingdom = $schema->resultset('Kingdom')->create(
        {
            name => 'Test Kingdom',
            mayor_tax => $params{mayor_tax} // 10,
            gold => $params{gold} // 100,
            active => $params{active} // 1,
        }   
    );
    
    $params{create_king} //= 1;
    
    if ($params{create_king}) {
        my $character = Test::RPG::Builder::Character->build_character($schema);
        $character->status('king');
        $character->status_context($kingdom->id);
        $character->update;
    }
    
    return $kingdom;
}

1;