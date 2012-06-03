use strict;
use warnings;

package Test::RPG::NewDay::Majesty;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Kingdom;

use Test::More;

sub setup : Test(startup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Action::Majesty';

    $self->setup_context;  
    
    $self->{action} = RPG::NewDay::Action::Majesty->new( context => $self->{mock_context} );
}

sub test_run_no_existing_leader : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 100, town_count => 10, building_count => 0, party_count => 5);
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 200, town_count => 5, building_count => 2, party_count => 2);
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $kingdom1->discard_changes;
    is($kingdom1->majesty, 16, "Kingdom 1's majesty calculated correctly");
    isnt($kingdom1->majesty_leader_since, undef, "Kingdom 1 is now the majesty leader"); 
    is($kingdom1->majesty_rank, 1, "Kingdom 1 is first in majesty ratings");
    
    $kingdom2->discard_changes;
    is($kingdom2->majesty, 13, "Kingdom 2's majesty calculated correctly");
    is($kingdom2->majesty_leader_since, undef, "Kingdom 2 is not the majesty leader");
    is($kingdom2->majesty_rank, 2, "Kingdom 2 is second in majesty ratings");
}

sub test_run_leader_given_crown : Tests(5) {
    my $self = shift;    
    
    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 100, town_count => 100, building_count => 0, party_count => 5,
        majesty_leader_since => DateTime->now()->subtract(days => 8, seconds => 1));
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 200, town_count => 5, building_count => 2, party_count => 2);
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $kingdom1->discard_changes;
    is($kingdom1->majesty, 106, "Kingdom 1's majesty calculated correctly");
    isnt($kingdom1->majesty_leader_since, undef, "Kingdom 1 is still the majesty leader");
    is($kingdom1->has_crown, 1, "Kingdom 1 now has the crown"); 
    
    $kingdom2->discard_changes;
    is($kingdom2->majesty, 13, "Kingdom 2's majesty calculated correctly");
    is($kingdom2->majesty_leader_since, undef, "Kingdom 2 is not the majesty leader");    
}

sub test_run_leader_change_causes_loss_of_crown : Tests(6) {
    my $self = shift;
    
    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 100, town_count => 50, building_count => 0, party_count => 5,
        majesty_leader_since => DateTime->now()->subtract(days => 8, seconds => 1), has_crown => 1);
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 200, town_count => 5, building_count => 2, party_count => 60);
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $kingdom1->discard_changes;
    is($kingdom1->majesty, 56, "Kingdom 1's majesty calculated correctly");
    is($kingdom1->majesty_leader_since, undef, "Kingdom 1 is no longer the majesty leader");
    is($kingdom1->has_crown, 0, "Kingdom 1 no longer has the crown"); 
    
    $kingdom2->discard_changes;
    is($kingdom2->majesty, 71, "Kingdom 2's majesty calculated correctly");
    isnt($kingdom2->majesty_leader_since, undef, "Kingdom 2 is now the majesty leader");
    is($kingdom2->has_crown, 0, "Kingdom 2 not awarded crown yet");        
}

sub test_run_leader_majesty_not_high_enough_for_crown : Tests(5) {
    my $self = shift;    
    
    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 100, town_count => 10, building_count => 0, party_count => 5,
        majesty_leader_since => DateTime->now()->subtract(days => 8, seconds => 1));
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 200, town_count => 5, building_count => 2, party_count => 2);
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $kingdom1->discard_changes;
    is($kingdom1->majesty, 16, "Kingdom 1's majesty calculated correctly");
    isnt($kingdom1->majesty_leader_since, undef, "Kingdom 1 is still the majesty leader");
    is($kingdom1->has_crown, 0, "Kingdom 1 not awarded crown as majesty not high enough"); 
    
    $kingdom2->discard_changes;
    is($kingdom2->majesty, 13, "Kingdom 2's majesty calculated correctly");
    is($kingdom2->majesty_leader_since, undef, "Kingdom 2 is not the majesty leader");    
}

sub test_run_leader_not_leader_long_enough_to_get_crown : Tests(5) {
    my $self = shift;    
    
    # GIVEN
    my $kingdom1 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 100, town_count => 80, building_count => 0, party_count => 5,
        majesty_leader_since => DateTime->now()->subtract(days => 7));
    my $kingdom2 = Test::RPG::Builder::Kingdom->build_kingdom($self->{schema}, land_count => 200, town_count => 5, building_count => 2, party_count => 2);
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    $kingdom1->discard_changes;
    is($kingdom1->majesty, 86, "Kingdom 1's majesty calculated correctly");
    isnt($kingdom1->majesty_leader_since, undef, "Kingdom 1 is still the majesty leader");
    is($kingdom1->has_crown, 0, "Kingdom 1 not awarded crown as majesty hasn't been leader long enough"); 
    
    $kingdom2->discard_changes;
    is($kingdom2->majesty, 13, "Kingdom 2's majesty calculated correctly");
    is($kingdom2->majesty_leader_since, undef, "Kingdom 2 is not the majesty leader");    
}

1;