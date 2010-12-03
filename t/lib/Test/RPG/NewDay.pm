use strict;
use warnings;

package Test::RPG::NewDay;

use base qw(Test::RPG);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::MockObject::Extends;
use Test::More;

use Data::Dumper;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay';

}

sub test_run_loads_normal_config : Tests(1) {
    my $self = shift;

    my $mock_config = { log_file_dir => 'bar' };
    my $mock_yaml = Test::MockObject::Extra->new();
    $mock_yaml->fake_module( 'YAML', LoadFile => sub { $mock_config }, );

    my $mock_logger = Test::MockObject::Extends->new('Log::Dispatch');

    my $mock_new_day = Test::MockObject->new();
    $mock_new_day->mock('do_new_day', sub{});

    RPG::NewDay::run($mock_new_day);

    my ( $method, $args ) = $mock_new_day->next_call();

    my $config_passed = $args->[1];

    is_deeply( $mock_config, $config_passed );
    
    $mock_yaml->unfake_module();
    require YAML;

}

sub test_do_new_day_two_plugins_run : Tests(3) {
    my $self = shift;

    # GIVEN
    my $plugin1 = Test::MockObject->new();
    $plugin1->set_always( 'cron_string', '5 4 * * *' );
    $plugin1->set_true('run');
    $plugin1->set_always('meta', $plugin1);
    $plugin1->set_always('name', 'plugin1');

    my $plugin2 = Test::MockObject->new();
    $plugin2->set_always( 'cron_string', '5 */2 * * *' );
    $plugin2->set_true('run');
    $plugin2->set_always('meta', $plugin2);
    $plugin2->set_always('name', 'plugin2');

    my $plugin3 = Test::MockObject->new();
    $plugin3->set_always( 'cron_string', '5 5 * * *' );
    $plugin3->set_true('run');

    my $new_day = RPG::NewDay->new();
    $new_day = Test::MockObject::Extends->new($new_day);
    $new_day->mock( 'plugins', sub { ( $plugin1, $plugin2, $plugin3 ) } );

    my $dt = DateTime->new(
        year   => 2000,
        month  => 5,
        day    => 28,
        hour   => 4,
        minute => 5,
        second => 59,
    );

    # WHEN
    $new_day->do_new_day($self->{config}, $self->{mock_logger}, $dt);
    
    # THEN
    $plugin1->called_ok('run', "Run called on plugin 1");
    $plugin2->called_ok('run', "Run called on plugin 2");
    is($plugin3->called('run'), 0, "Run not called on plugin 3");
}

sub test_do_new_day_dst_not_an_issue : Tests(2) {
    my $self = shift;
    
    return "Not working for some reason...";

    # GIVEN
    my $dt = DateTime->now();
    $dt->set_month(5);
    $dt->set_day(25);
    $dt->set_time_zone('Europe/London');
    warn $dt;
   
    my $cron_string1 = $dt->minute() . ' ' . $dt->hour() . ' * * *';
    my $cron_string2 = $dt->minute() . ' ' . ($dt->hour()+1) . ' * * *';
    
    warn $cron_string1;
    warn $cron_string2; 

    my $plugin1 = Test::MockObject->new();    
    $plugin1->set_always( 'cron_string', $cron_string1 );
    $plugin1->set_true('run');
    $plugin1->set_always('meta', $plugin1);
    $plugin1->set_always('name', 'plugin1');

    my $plugin2 = Test::MockObject->new();
    $plugin2->set_always( 'cron_string', $cron_string2 );
    $plugin2->set_true('run');
    $plugin2->set_always('meta', $plugin2);
    $plugin2->set_always('name', 'plugin2');

    my $new_day = RPG::NewDay->new();
    $new_day = Test::MockObject::Extends->new($new_day);
    $new_day->mock( 'plugins', sub { ( $plugin1, $plugin2 ) } );

    # WHEN
    $new_day->do_new_day($self->{config}, $self->{mock_logger}, $dt);
    
    # THEN
    $plugin1->called_ok('run', "Run called on plugin 1");
    is($plugin2->called('run'), 0, "Run not called on plugin 2");
}


1;
