package RPG::NewDay;

use Moose;

use RPG::Schema;
use RPG::NewDay::Context;

use YAML;
use DateTime;
use DateTime::Cron::Simple;
use DateTime::Format::DateParse;
use Log::Dispatch;
use Log::Dispatch::File;
use Proc::PID::File;
use MIME::Lite;

use Module::Pluggable::Dependency search_path => ['RPG::NewDay::Action'], instantiate => 'new';

sub run {
	my $self           = shift;
	my $date_to_run_at = shift;
	my @plugins        = @_;

	my $dt;

	if ($date_to_run_at) {
		$dt = DateTime::Format::DateParse->parse_datetime($date_to_run_at);
	}
	else {
		$dt = DateTime->now();
	}

	$dt->set_time_zone('local');

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

	if ( Proc::PID::File->running( dir => $home . '/proc' ) ) {
		my $message = 'Another process is already running. Not executing';
		$logger->warning($message);
		exit 0;
	}

	while (1) {
		my @errors = $self->do_new_day( $config, $logger, $dt, @plugins );;
		if (@errors) {
			my $error_str;
			foreach my $error (@errors) {
				if ( ref $error && $error->isa('RPG::Exception') ) {
					$error_str .= $error->message . "\n";
				}
				else {
					$error_str .= "$error\n";
				}
			}

			my $msg = MIME::Lite->new(
				From    => $config->{send_email_from},
				To      => $config->{send_email_from},
				Subject => '[Kingdoms] Error running new day script',
				Data    => "Error was: $error_str",
			);
			$msg->send( 'smtp', $config->{smtp_server}, Debug => 0, );

			return $error_str;
		}

		# If more than a minute has elapsed, run again with an incremented time to avoid missing any actions
		unless ($date_to_run_at) {
			my $elapsed = $dt->delta_ms( DateTime->now() );
			if ( $elapsed->minutes > 0 ) {
				$dt->add( minutes => 1 );
				next;
			}
		}

		last;
	}
}

sub do_new_day {
	my $self = shift;
	my ( $config, $logger, $dt, @plugins ) = @_;

	$logger->info( "Running ticker script as at: " . $dt->datetime() );

	my $schema = RPG::Schema->connect( $config, @{ $config->{'Model::DBIC'}{connect_info} }, );
	$schema->log($logger);

	my $context = RPG::NewDay::Context->new(
		config   => $config,
		schema   => $schema,
		logger   => $logger,
		datetime => $dt,
	);
	
	my @errors;
	
	foreach my $action ( $self->plugins( context => $context ) ) {
		if (@plugins) {
			next unless grep { $action->isa($_) } @plugins;
		}

		my $cron = DateTime::Cron::Simple->new( $action->cron_string );

		if ( $cron->validate_time($dt) ) {
			$logger->info( "Running action: " . $action->meta->name );
			
			eval {
				$action->run();
			};
			if ($@) {
				push @errors, $@;
				
				$logger->error("Error occured when running " . $action->meta->name . ": $@");
				
				last unless $action->continue_on_error;
			}				
		}
	}

	$logger->info( "Successfully completed ticker script run for: " . $dt->datetime() );
	
	return @errors;
}

__PACKAGE__->meta->make_immutable;

1;
