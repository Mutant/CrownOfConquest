use strict;
use warnings;

package Test::RPG::Maths;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Data::Dumper;

use RPG::Maths;

sub startup : Test(startup) {
	my $self = shift;
	
	$self->{dice} = Test::MockObject->fake_module( 
		'Games::Dice::Advanced',
		roll => sub { $self->{roll_result} || 0 }, 
	);
}

sub shutdown : Test(shutdown) {
	my $self = shift;
	
	delete $INC{'Games/Dice/Advanced.pm'};	
	require 'Games/Dice/Advanced.pm';
}

sub test_weighted_random_number_even_number_list : Tests(no_plan) {
    my $self = shift;
    
    my @numbers = qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20);
    
    $self->{roll_result} = 1;
    is(RPG::Maths->weighted_random_number(@numbers), 1);     
}

sub test_weighted_random_number_odd_number_list : Tests(no_plan) {
    my $self = shift;
    
    my @numbers = qw(1 2 3 4 5);
    
    $self->{roll_result} = 144;
    is(RPG::Maths->weighted_random_number(@numbers), 3);     
}
1;