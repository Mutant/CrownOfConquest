use strict;
use warnings;

package Test::RPG::NewDay::Skills;

use base qw(Test::RPG::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::More;

use Test::RPG::Builder::Party;

sub setup : Test(setup => 1) {
    my $self = shift;

	use_ok 'RPG::NewDay::Action::Skills';

    $self->setup_context;  
    
    $self->{action} = RPG::NewDay::Action::Skills->new( context => $self->{mock_context} );
}

sub test_run : Tests(2) {
    my $self = shift;
    
    # GIVEN
    $self->mock_dice;
    
    my $party = Test::RPG::Builder::Party->build_party($self->{schema}, character_count => 3);
    my @chars = $party->characters;
    
    my $skill = $self->{schema}->resultset('Skill')->find(
        {
            skill_name => 'Medicine',
        }
    );    
    
    my $char_skill = $self->{schema}->resultset('Character_Skill')->create(
        {
            skill_id => $skill->id,
            character_id => $chars[0]->id,
            level => 1,
        }
    );
    
    $chars[1]->hit_points(2);
    $chars[1]->character_name('Victim');
    $chars[1]->update;
    
    $self->{rolls} = [1,1];
    
    # WHEN
    $self->{action}->run();
    
    # THEN
    is($party->day_logs->count, 1, "Party day logs updated");
        
    $chars[1]->discard_changes;
    is($chars[1]->hit_points, 5, "Victim was healed");    
}

1;