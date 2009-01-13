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

    my $rs = Test::Resub->new(
        {
            name    => 'RPG::NewDay::do_new_day',
            code    => sub { },
            capture => 1,
        }
    );

    RPG::NewDay->run();

    my $config_passed = $rs->args->[0][0];

    is_deeply( $mock_config, $config_passed );

}

1;
