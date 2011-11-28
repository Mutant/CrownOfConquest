use strict;
use warnings;

package Test::RPG::Schema::Building_Type;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Test::RPG::Builder::Party;

sub test_cost_to_build : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    # WHEN
    my %costs = $building_type->cost_to_build;
    
    # THEN
    my %expected = (
        Clay => 16,
        Stone => 6,
        Wood => 15,
        Iron => 8,
    );
    is_deeply(\%costs, \%expected, "Cost to build returned correctly");
    
}

sub test_cost_to_build_with_skilled_party : Tests(1) {
    my $self = shift;
    
    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 2);
    my @chars = $party->characters;
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Construction',
        }
    );
    
    my $char_skill1 = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[0]->id,
            level => 10,
        }
    );
    
    my $char_skill2 = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[1]->id,
            level => 5,
        }
    );    
    
    my $building_type = $self->{schema}->resultset('Building_Type')->find(
        {
            name => 'Tower',
        }
    );
    
    # WHEN
    my %costs = $building_type->cost_to_build([$party]);
    
    # THEN
    my %expected = (
        Clay => 11,
        Stone => 4,
        Wood => 10,
        Iron => 5,
    );
    is_deeply(\%costs, \%expected, "Cost to build returned correctly");
    
}