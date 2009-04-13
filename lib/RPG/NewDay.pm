package RPG::NewDay;

use Mouse;

use RPG::Schema;
use RPG::NewDay::Context;

use YAML;
use DateTime;
use DateTime::Cron::Simple;
use DateTime::Format::DateParse;
use Log::Dispatch;
use Log::Dispatch::File;

use Module::Pluggable::Dependency search_path => ['RPG::NewDay::Action'], instantiate => 'new';

sub run {
    my $self = shift;
    my $date_to_run_at = shift;

    my $dt;
    
    if ($date_to_run_at) {
        $dt = DateTime::Format::DateParse->parse_datetime( $date_to_run_at );        
    }
    else {
        $dt = DateTime->now();
    }

    my $home = $ENV{RPG_HOME};

    my $config = YAML::LoadFile("$home/rpg.yml");
    if ( -f "$home/rpg_local.yml" ) {
        my $local_config = YAML::LoadFile("$home/rpg_local.yml");
        $config = { %$config, %$local_config };
    }

    my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . "] [$$] " . $_[1] . "\n" } );
    $logger->add(
        Log::Dispatch::File->new(
            name      => 'file1',
            min_level => 'debug',
            filename  => $config->{log_file_dir} . 'new_day.log',
            mode      => 'append',
            stamp_fmt => '%Y%m%d',
        ),
    );
    
    $logger->info( "Running ticker script as at: " . $dt->datetime() );

    eval { $self->do_new_day( $config, $logger, $dt ); };
    if ($@) {
        $logger->error("Error running new day script: $@");
    }
    
    $logger->info( "Successfully completed ticker script run" );

}

sub do_new_day {
    my $self = shift;
    my ( $config, $logger, $dt ) = @_;

    my $schema = RPG::Schema->connect( $config, @{ $config->{'Model::DBIC'}{connect_info} }, );

    my $context = RPG::NewDay::Context->new(
        config      => $config,
        schema      => $schema,
        logger      => $logger,
        datetime    => $dt,
    );

    foreach my $action ( $self->plugins( context => $context ) ) {
        my $cron = DateTime::Cron::Simple->new( $action->cron_string );

        if ( $cron->validate_time($dt) ) {
            $logger->info( "Running action: " . $action->meta->name );
            $action->run();
        }
    }
}

1;
