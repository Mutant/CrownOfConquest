package RPG::NewDay;

use Moose;

use RPG::Schema;
use RPG::NewDay::Context;
use RPG::LoadConf;
use RPG::Email;

use YAML;
use DateTime;
use DateTime::Cron::Simple;
use DateTime::Format::DateParse;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;
use Proc::PID::File;

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

	my $config = RPG::LoadConf->load();

	my $logger = Log::Dispatch->new( callbacks => sub { return '[' . localtime() . "] [$$] " . $_[1] . "\n" } );
	$logger->add(
		Log::Dispatch::File::Stamped->new(
			name      => 'file1',
			min_level => 'debug',
			filename  => $config->{log_file_dir} . 'new_day.log',
			mode      => 'append',
			stamp_fmt => '%Y%m%d',
		),
	);

	if ( Proc::PID::File->running( dir => $home . '/var' ) ) {
		my $message = 'Another process is already running. Not executing';
		$logger->warning($message);
		exit 0;
	}
	
	my $conf_info = $config->{'Model::DBIC'}{connect_info};
	if (ref $conf_info eq 'HASH') {
	    $conf_info = [$conf_info->{dsn}, $conf_info->{user}, $conf_info->{password}];
	}
	
	my $schema = RPG::Schema->connect( $config, @$conf_info, );
	$schema->log($logger);	

	while (1) {
		my @errors = $self->do_new_day( $schema, $config, $logger, $dt, @plugins );;
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

			RPG::Email->send(
				email   => $config->{send_email_from},
				subject => 'Error running new day script',
				body    => "Error was: $error_str",
			);

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
	
	# Record the we finished successfully
	my $conf_val = $schema->resultset('Conf')->find_or_create(
	   {
	       'conf_name' => 'Last Successful Ticker Run',
	   },
	);
	$conf_val->update( { 'conf_value' => DateTime->now() } );
	
	return undef;
}

sub do_new_day {
	my $self = shift;
	my ( $schema, $config, $logger, $dt, @plugins ) = @_;

	$logger->info( "Running ticker script as at: " . $dt->datetime() );

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
