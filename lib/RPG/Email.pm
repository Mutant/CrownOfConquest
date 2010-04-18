use strict;
use warnings;

package RPG::Email;

use RPG::Template;

use MIME::Lite;

sub send {
	my $self = shift;
	my $config = shift;
	my $params = shift;
	
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
    	#$emails = map { $_->send_emails ? $_->email : () } @{ $params->{players} };
    	$emails = join ', ', (map { $_->email } @{ $params->{players} });
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

    $msg->send( 'smtp', $config->{smtp_server}, Debug => 0, );	
}

1;