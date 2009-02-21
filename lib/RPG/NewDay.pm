package RPG::NewDay;

use Mouse;

use RPG::Schema;
use RPG::NewDay::Context;

use YAML;
use DateTime;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;

use Module::Pluggable search_path => ['RPG::NewDay::Action'], instantiate => 'new', sub_name => 'actions', only => 'RPG::NewDay::Action::Dungeon';

sub run {
    my $self = shift;

    my $home = $ENV{RPG_HOME};

    my $config = YAML::LoadFile("$home/rpg.yml");
    if ( -f "$home/rpg_local.yml" ) {
        my $local_config = YAML::LoadFile("$home/rpg_local.yml");
        $config = { %$config, %$local_config };
    }

    my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . "] [$$]" . $_[1] . "\n" } );
    $logger->add(
        Log::Dispatch::File::Stamped->new(
            name      => 'file1',
            min_level => 'debug',
            filename  => $config->{log_file_dir} . 'new_day.log',
            mode      => 'append',
            stamp_fmt => '%Y%m%d',
        ),
    );

    eval { $self->do_new_day( $config, $logger ); };
    if ($@) {
        $logger->error("Error running new day script: $@");
    }

}

sub do_new_day {
    my $self = shift;
    my ( $config, $logger ) = @_;

    my $schema = RPG::Schema->connect( $config, @{ $config->{'Model::DBIC'}{connect_info} }, );

    # Create a new day
    my $yesterday = $schema->resultset('Day')->find(
        {},
        {
            'select' => { max => 'day_number' },
            'as'     => 'day_number'
        },
        )->day_number
        || 1;

    my $new_day = $schema->resultset('Day')->create(
        {
            'day_number'   => $yesterday + 1,
            'game_year'    => 100,               # TODO: generate game year as well
            'date_started' => DateTime->now(),
        },
    );

    $logger->info( "Beginning new day script for day: " . $new_day->day_number );

    my $context = RPG::NewDay::Context->new(
        config      => $config,
        schema      => $schema,
        logger      => $logger,
        current_day => $new_day,
    );

    foreach my $action ( $self->actions(context => $context) ) {
        $logger->info("Running action: " . $action->meta->name);
        $action->run();
    }

    $schema->storage->dbh->commit unless $schema->storage->dbh->{AutoCommit};

    $logger->info( "Successfully completed new day script for day: " . $new_day->day_number );

}

1;
