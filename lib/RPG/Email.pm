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
        'party/email/email_footer.txt',
    	{}
    );	
    
    my $emails;
    my $to_field = 'To';
    
    if ($params->{email}) {
    	$emails = $params->{email};
    }
    else {   
    	$emails = map { $_->send_emails ? $_->email : () } @{ $params->{players} };
    	$to_field = 'Bcc';
    }
	
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