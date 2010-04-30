package RPG::C::Party::Details;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Data::Dumper;

sub default : Path {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details.html',
                params   => {
                    party   => $c->stash->{party},
                    tab     => $c->req->param('tab') || '',
                    message => $c->flash->{messages},
                },
            }
        ]
    );
}

sub history : Local {
    my ( $self, $c ) = @_;

    # Check if new day message should be displayed
    my %day_logs = map { $_->day->day_number => $_ } $c->model('DBIC::DayLog')->search(
        { 'party_id' => $c->stash->{party}->id, },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
            rows     => 7,                         # TODO: config me
        },
    );

    my @messages = $c->model('DBIC::Party_Messages')->search(
        { 'party_id' => $c->stash->{party}->id, },
        {
            order_by => 'day.date_started desc',
            prefetch => 'day',
            rows     => 7,                         # TODO: config me
        },
    );

    my %message_logs;
    foreach my $message (@messages) {
        push @{ $message_logs{ $message->day->day_number } }, $message->message;
    }

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/history.html',
                params   => {
                    day_logs       => \%day_logs,
                    message_logs   => \%message_logs,
                    today          => $c->stash->{today},
                    history_length => 7,
                },
            }
        ]
    );
}

sub combat_log : Local {
    my ( $self, $c ) = @_;

    my @logs = $c->model('DBIC::Combat_Log')->get_recent_logs_for_party( $c->stash->{party}, 20 );

    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/combat_log.html',
                params   => {
                    logs  => \@logs,
                    party => $c->stash->{party},
                },
            }
        ]
    );
}

sub options : Local {
    my ( $self, $c ) = @_;

    $c->forward(
        'RPG::V::TT',
        [
            {
                template     => 'party/details/options.html',
                params       => { 
                	flee_threshold => $c->stash->{party}->flee_threshold,
                	send_daily_report => $c->stash->{party}->player->send_daily_report,
                	send_email_announcements => $c->stash->{party}->player->send_email_announcements,
                	display_tip_of_the_day => $c->stash->{party}->player->display_tip_of_the_day,
                	display_announcements => $c->stash->{party}->player->display_announcements,
                	send_email => $c->stash->{party}->player->send_email,
                },
                fill_in_form => 1,
            }
        ]
    );
}

sub update_options : Local {
    my ( $self, $c ) = @_;

    if ( $c->req->param('save') ) {
        $c->stash->{party}->flee_threshold( $c->req->param('flee_threshold') );
        $c->stash->{party}->update;
        $c->flash->{messages} = 'Changes Saved';
    }

    $c->res->redirect( $c->config->{url_root} . '/party/details?tab=options' );
}

sub update_email_options : Local {
    my ( $self, $c ) = @_;

    if ( $c->req->param('save') ) {
    	my $player = $c->stash->{party}->player;
        $player->send_daily_report($c->req->param('send_daily_report') ? 1 : 0);
        $player->send_email_announcements($c->req->param('send_email_announcements') ? 1 : 0);
        $player->display_announcements($c->req->param('display_announcements') ? 1 : 0);
        $player->display_tip_of_the_day($c->req->param('display_tip_of_the_day') ? 1 : 0);
        $player->send_email($c->req->param('send_email') ? 1 : 0);
        $player->update;
        $c->flash->{messages} = 'Changes Saved';
    }

    $c->res->redirect( $c->config->{url_root} . '/party/details?tab=options' );
}

sub garrisons : Local {
	my ($self, $c) = @_;
	
	my @garrisons = $c->stash->{party}->garrisons;
	
    $c->forward(
        'RPG::V::TT',
        [
            {
                template => 'party/details/garrisons.html',
                params   => {
                    garrisons => \@garrisons,
                },
            }
        ]
    );	
}

1;
