use strict;
use warnings;

package Test::RPG::NewDay;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;
use Test::Resub;

use Data::Dumper;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay';

}

sub test_run_loads_normal_config : Tests(1) {
    my $self = shift;

    my $mock_config = { log_file_dir => 'bar' };
    my $mock_yaml = Test::MockObject->new();
    $mock_yaml->fake_module( 'YAML', LoadFile => sub { $mock_config }, );
    
    my $mock_logger = Test::MockObject::Extends->new( 'Log::Dispatch' );

    my $mock_new_day = Test::MockObject->new();
    $mock_new_day->set_always('do_new_day');
    
    RPG::NewDay::run($mock_new_day);

    my ($method, $args) = $mock_new_day->next_call();

    my $config_passed = $args->[1];

    is_deeply( $mock_config, $config_passed );

}

1;
