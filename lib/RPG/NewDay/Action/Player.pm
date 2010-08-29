package RPG::NewDay::Action::Player;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;
use RPG::Email;
use RPG::Template;

sub run {
    my $self    = shift;
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
            $party->in_combat_with( undef );
            $party->update;
            
            # They lose any mayoralties
            $party->search_related('characters',
            	{
            		mayor_of => {'!=', undef},
            	},
            )->update(
            	{
            		mayor_of => undef,
            	}
            );
        }
    }

    my $warning_date = DateTime->now()->subtract( days => $context->config->{inactivity_warning_days} );
    my @players_to_warn =
        $context->schema->resultset('Player')->search( { last_login => { '<=', $warning_date }, warned_for_deletion => 0, deleted => 0 }, );

    my $grace = $context->config->{inactivity_deletion_days} - $context->config->{inactivity_warning_days};

    foreach my $player (@players_to_warn) {

        my $message = RPG::Template->process(
            $context->config,
            'player/email/deletion_warning.txt',
            {
                url          => $context->config->{url_root},
                warning_days => $context->config->{inactivity_warning_days},
                grace_days   => $grace,
                forum_url    => $context->config->{forum_url},
            }
        );

        RPG::Email->send(
        	$context->config,
        	{
            	players => [$player],
            	subject => 'Game Inactivity',
            	body    => $message,
        	}
        );

        $player->warned_for_deletion(1);
        $player->update;
    }

    $self->verification_reminder();

    $self->cleanup_sessions();
}

sub verification_reminder {
    my $self = shift;

    my $c = $self->context;

    my $reminder_date_end = DateTime->now()->subtract( days => $c->config->{verification_reminder_days} );
    $reminder_date_end->set(
        hour   => 23,
        minute => 59,
        second => 59,
    );

    my $reminder_date_start = $reminder_date_end->clone()->truncate(to => 'day');
    
    my @players_to_remind = $c->schema->resultset('Player')->search(
        {
            last_login          => { '>=', $reminder_date_start, '<=', $reminder_date_end },
            warned_for_deletion => 0,
            deleted             => 0,
            verified            => 0,
        },
    );

    foreach my $player (@players_to_remind) {
        my $message = RPG::Template->process(
            $c->config,
            'player/email/verification_reminder.txt',
            {
                player => $player,
                url    => $c->config->{url_root},
            }
        );

        RPG::Email->send(
        	$c->config,
        	{
            	email      => $player->email,
            	subject => 'Verification Reminder',
            	body    => $message,
        	}
        );
    }
}

sub cleanup_sessions {
    my $self = shift;

    my $c = $self->context;

    $c->schema->resultset('Session')->search( { 'expires' => { '<', time() }, } )->delete;
}

__PACKAGE__->meta->make_immutable;


1;
