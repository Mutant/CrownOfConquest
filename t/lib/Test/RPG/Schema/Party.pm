use strict;
use warnings;

package Test::RPG::Schema::Party;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

use Data::Dumper;

sub startup : Tests(startup=>1) {
    my $self = shift;

    my $mock_config = Test::MockObject->new();

    $self->{config} = {};

    $mock_config->fake_module( 'RPG::Config', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Party';
}

sub test_new_day : Tests(6) {
    my $self = shift;

    my $mock_party = Test::MockObject->new();
    $mock_party->set_always( 'turns', 100 );
    $mock_party->mock( 'characters', sub { () } );
    $mock_party->set_true('rest');
    $mock_party->set_true('update');
    $mock_party->set_true('add_to_day_logs');

    $self->{config} = {
        daily_turns         => 10,
        maximum_turns       => 200,
        min_heal_percentage => 10,
        max_heal_percentage => 20,
    };

    my $mock_new_day = Test::MockObject->new();
    $mock_new_day->set_always( 'id', 5 );

    RPG::Schema::Party::new_day( $mock_party, $mock_new_day );

    my ( $name, $args );

    ( $name, $args ) = $mock_party->next_call(2);
    is( $name,      'turns', "Turns method accessed" );
    is( $args->[1], 110,     "Daily turns added" );

    ( $name, $args ) = $mock_party->next_call(5);
    is( $name,      'rest', "Rest method accessed" );
    is( $args->[1], 0,      "Rest set to 0" );

    ( $name, $args ) = $mock_party->next_call();
    is( $name, 'update', "Party updated" );

}

1;
