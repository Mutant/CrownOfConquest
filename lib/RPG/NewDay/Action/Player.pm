package RPG::NewDay::Action::Player;

use Mouse;

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
            Data    => "Hi,\n\nYou signed up to the game at game.mutant.dj, but you haven't logged in in over "
                . $context->config->{inactivity_warning_days}
                . " days. If you don't log in within the next $grace days, your account will be deleted.\n\nIf you're having technical difficulties in logging"
                . " in, etc. please reply to this email. I'd love to hear about it, since we're still in alpha testing.",
        );
        $msg->send(
            'smtp',
            $context->config->{smtp_server},
            AuthUser => $context->config->{smtp_user},
            AuthPass => $context->config->{smtp_pass},
            Debug    => 1,
        );

        $player->warned_for_deletion(1);
        $player->update;
    }
}

1;
