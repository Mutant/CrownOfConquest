package RPG::NewDay::Action::Player;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;
use MIME::Lite;

sub run {
    my $self = shift;
    my $context = $self->context;

    my $delete_date = DateTime->now()->subtract( days => $context->config->{inactivity_deletion_days} );
    my @players_to_delete = $context->schema->resultset('Player')->search( { last_login => { '<=', $delete_date }, deleted => 0 }, );

    foreach my $player (@players_to_delete) {
        $player->deleted(1);
        $player->update;

        my @parties = $player->parties;

        foreach my $party (@parties) {
            next if $party->defunct;
            $party->defunct( DateTime->now() );
            $party->update;
        }
    }

    my $warning_date = DateTime->now()->subtract( days => $context->config->{inactivity_warning_days} );
    my @players_to_warn = $context->schema->resultset('Player')->search( { last_login => { '<=', $warning_date }, warned_for_deletion => 0, deleted => 0 }, );

    my $grace = $context->config->{inactivity_deletion_days} - $context->config->{inactivity_warning_days};

    foreach my $player (@players_to_warn) {
        my $msg = MIME::Lite->new(
            From    => $context->config->{send_email_from},
            To      => $player->email,
            Subject => 'Game Inactivity',
            # TODO: template me :|
            Data    => "Hi,\n\nYou signed up to Kingdoms (" . $context->config->{url_root} . "), but you haven't logged in in over "
                . $context->config->{inactivity_warning_days}
                . " days. If you don't log in within the next $grace days, your account will be disabled.\n\nYou'll be able to re-enable your"
                . " account by logging back in, although you may lose some standing in the game in the mean time.\n\nAlso, there is a maximum"
                . " number of active players allowed, so if that number has been reached, you won't be able to re-activate your account"
                . " until some other players go inactive (or the maximum number of players is increased).\n\n"
                . " If you have any questions, or are having technical difficulties, please don't hesitate to reply to this email, or post in our forum: "
                . $context->config->{forum_url}, 
                 
        );
        $msg->send(
            'smtp',
            $context->config->{smtp_server},
            Debug    => 1,
        );

        $player->warned_for_deletion(1);
        $player->update;
    }
    
    $self->cleanup_sessions();
}

sub cleanup_sessions {
    my $self = shift;
    
    my $c = $self->context;
    
    $c->schema->resultset('Session')->search(
        {
            'expires' => { '<', time() },
        }
    )->delete;           
}

1;
