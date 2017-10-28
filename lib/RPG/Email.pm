use strict;
use warnings;

package RPG::Email;

use RPG::Template;

use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Transport::SMTP;
use Log::Dispatch;
use Digest::SHA1 qw(sha1_hex);

sub send {
    my $self   = shift;
    my $config = shift;
    my $params = shift;

    return if ( $config->{no_email} && !$config->{email_log_file} );

    my @emails;

    if ( $params->{email} ) {
        @emails = (
            {
                email => $params->{email}
            }
        );
    }
    else {
        foreach my $player ( @{ $params->{players} } ) {
            next unless $player->email && $player->send_email && $player->verified;

            $player->email_hash( sha1_hex rand );
            $player->update;

            push @emails, {
                email      => $player->email,
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
                config     => $config,
                email      => $email_rec->{email},
                email_hash => $email_rec->{email_hash} // '',

            }
        );
        $email_footer //= '';

        my $msg = Email::Simple->create(
          header => [
            To      => $email_rec->{email},
            From    => $config->{send_email_from},
            Subject => '[CrownOfConquest] ' . $params->{subject},
            'Content-Type' => 'text/html',
            ( $params->{reply_to} ? ( 'Reply-To' => $params->{reply_to} ) : () ),
          ],
          body => $params->{body} . $email_footer,
        );

        if ( !$config->{no_email} ) {
            my %auth_params;
            if ( $config->{email_user} ) {
                $auth_params{sasl_username} = $config->{email_user};
                $auth_params{sasl_password} = $config->{email_pass};
            }

            my $transport = Email::Sender::Transport::SMTP->new({
                host => $config->{smtp_server},
                port => 465, # TODO: config me
                ssl => 1,
                %auth_params,
                debug => 0,
            });

            sendmail($msg, { transport => $transport });

        }

        #  If debug logging of emails enabled.
        if ( $config->{email_log_file} ) {
            if ( !$config->{email_log_file_handle} ) {
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
            $config->{email_log_file_handle}->debug( "<br>===========================<br>Header:<br>" . $eheader );
            $config->{email_log_file_handle}->debug( "Body:<br>" . $msg->body_as_string );
        }
    }
}

1;
