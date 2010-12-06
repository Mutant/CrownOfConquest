use strict;
use warnings;

package RPG::Email;

use RPG::Template;

use MIME::Lite;

sub send {
	my $self = shift;
	my $config = shift;
	my $params = shift;
	
	return if ($config->{no_email} && ! $config->{email_log_file});

    my $email_footer = RPG::Template->process(
        $config,
        'player/email/email_footer.txt',
    	{
    		config => $config,
    	}
    );	
    
    my $emails;
    my $to_field = 'To';
    
    if ($params->{email}) {
    	$emails = $params->{email};
    }
    else {   
    	$emails = join ',', (map { $_->send_email && $_->verified ? $_->email : () } @{ $params->{players} });
    	$to_field = 'Bcc';
    }
	return unless $emails;
		
    my $msg = MIME::Lite->new(
        From    => $config->{send_email_from},
        $to_field     => $emails,
        Subject => '[Kingdoms] ' . $params->{subject},
        Data    => $params->{body} . $email_footer,
        Type    => 'text/html',
    );

	#  If debug logging of emails enabled.
	if ($config->{email_log_file}) {
		if (! $config->{email_log_file_handle}) {
			$config->{email_log_file_handle} = Log::Dispatch->new(
				outputs => [
						[
							'File',
							min_level => 'debug',
							filename  => $config->{email_log_file},
							mode      => '>>',
							newline   => 1
						]
					],
				);
		}
		my $eheader = $msg->header_as_string;
		$eheader =~ s/\n/<br \/>/g;
		$config->{email_log_file_handle}->debug("<br>===========================<br>Header:<br>" . $eheader);
		$config->{email_log_file_handle}->debug("Body:<br>" . $msg->body_as_string);
	}

	return if $config->{no_email};
    
    $msg->send( 'smtp', $config->{smtp_server}, Debug => 0, );	
}

1;