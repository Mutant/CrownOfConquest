use strict;
use warnings;

package RPG::Email;

use RPG::Template;

use MIME::Lite;
use Log::Dispatch;
use Digest::SHA1 qw(sha1_hex);

sub send {
	my $self = shift;
	my $config = shift;
	my $params = shift;
	
	return if ($config->{no_email} && ! $config->{email_log_file});
  
    my @emails;
    
    if ($params->{email}) {
    	@emails = (
    	   {
    	       email => $params->{email}
    	   }
        );
    }
    else {
        foreach my $player (@{$params->{players}}) {
            next unless $player->email && $player->send_email && $player->verified;
           
            $player->email_hash(sha1_hex rand);
            $player->update;
            
            push @emails, {
                email => $player->email,
                email_hash => $player->email_hash,
            };
        } 
        
    }
    
	return unless @emails;

    foreach my $email_rec (@emails) {
        my $email_footer = RPG::Template->process(
            $config,
            'player/email/email_footer.txt',
        	{
        		config => $config,
        		email => $email_rec->{email},
        		email_hash => $email_rec->{email_hash} // '',
        		
        	}
        );
        $email_footer //= '';

        my $msg = MIME::Lite->new(
            From    => $config->{send_email_from},
            To => $email_rec->{email},
            Subject => '[CrownOfConquest] ' . $params->{subject},
            ($params->{reply_to} ? ('Reply-To' => $params->{reply_to}) : ()),
            Data    => $params->{body} . $email_footer,
            Type    => 'text/html',
        );

        if (! $config->{no_email}) {       
            my %auth_params;
            if ($config->{email_user}) {
                $auth_params{AuthUser} = $config->{email_user};
                $auth_params{AuthPass} = $config->{email_pass};
            }   
                 
            $msg->send( 'smtp', $config->{smtp_server}, Debug => 0, %auth_params );	
        }
    
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
    }
}

1;