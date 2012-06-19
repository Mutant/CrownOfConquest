use strict;
use warnings;

package Test::RPG::Schema::Building;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;
use Test::RPG::Builder::Building;

sub test_get_bonus : Tests(1) {
    my $self = shift;
    
    # GIVEN
    $self->{schema}->resultset('Building_Upgrade_Type')->search()->update( { modifier_per_level => 3 });   
    
    my $building = Test::RPG::Builder::Building->build_building($self->{schema});
    my $upgrade_type = $self->{schema}->resultset('Building_Upgrade_Type')->find(
        {
            name => 'Rune of Defence',
        }
    );
    $building->add_to_upgrades(
        {
            type_id => $upgrade_type->type_id,
            level => 2,
        }
    );
    
    # WHEN
    my $bonus = $building->get_bonus('defence_factor');
    
    # THEN
    is($bonus, 10, "DF bonus correct");
       
}  
1;