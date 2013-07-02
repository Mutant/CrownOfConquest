package RPG::C::Party::Message;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

use URI::Escape;
use HTML::BBCode;
use HTML::Strip;
use Math::Round qw(round);

sub default : Path {
    my ($self, $c) = @_;
    
    $c->forward('inbox');
}

sub compose : Local {
    my ($self, $c) = @_;
    
    my $to_parties = '';
    
    my @to_party_ids = $c->req->param('to_id');
    
    croak "Too many to parties" if scalar @to_party_ids > 20;
    
    foreach my $to_party_id (@to_party_ids) {
        my $to_party = $c->model('DBIC::Party')->find(
            {
                party_id => $to_party_id,
            }
        );
        
        $to_parties .= $to_party->name . '; ' if $to_party;   
    }
            
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/compose.html',
				params => {
					party => $c->stash->{party}, 
					to_parties => $to_parties,
				},
				fill_in_form => 1,
			}
		]
	);       
}

sub reply : Local {
    my ($self, $c) = @_;
    
    my $message = $c->model('DBIC::Party_Messages')->find(
        {
            'recipients.party_id' => $c->stash->{party}->id,
            'message_id' => $c->req->param('message_id'),
        },
        {
            prefetch => 'recipients',
        }   
    );
    
    croak "Invalid message" unless $message;
    
    my $to = $message->sender->name;
    
    if ($c->req->param('all')) {
        $to .= '; ';
        my @parties = grep { $_->id != $c->stash->{party}->id } $message->recipient_parties;
        $to .= join '; ', map { $_->name } @parties;
    }
    
    my $subject = $message->subject =~ /^RE:/i ? $message->subject : 'RE: ' . $message->subject;
    
    my $message_text = '[quote="' . $message->sender->name . '"]' . $message->message . '[/quote]';
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/compose.html',
				params => {
					party => $c->stash->{party}, 
					to_parties => $to,
					subject => $subject,
					message => $message_text,
				},
				fill_in_form => 1,
			}
		]
	);    
    
}

sub send : Local {
    my ($self, $c) = @_;    
    
    if (! $c->req->param('to') || ! $c->req->param('message')) {
        $c->stash->{panel_messages} = 'Please enter a party to send to and a message';
        
        $c->forward('redisplay_compose');
    }
    
    my @parties = split /\s?;\s?/, $c->req->param('to');
    
    if (! @parties) {
        $c->stash->{panel_messages} = "Please enter a valid party name";   
        
        $c->forward('redisplay_compose');
    }
    
    if (scalar @parties > 50) {
        $c->stash->{panel_messages} = "You've exceeded the maximum number of recipients";   
        
        $c->forward('redisplay_compose');       
    }
    
    my @recip_ids;
    foreach my $party_name (@parties) {
        my $party = $c->model('DBIC::Party')->find(
            {
                name => $party_name,
                defunct => undef,
            }
        );
        
        if (! $party) {
            $c->stash->{panel_messages} = "No such party: $party_name";   
            
            $c->forward('redisplay_compose');                  
        }
        
        push @recip_ids, $party->id;
    }
    
    my $hs = HTML::Strip->new();
    
    my $clean_subject = $hs->parse( $c->req->param('subject') );    
    
    my $message = $c->model('DBIC::Party_Message')->create(
        {
            sender_id => $c->stash->{party}->id,
            day_id => $c->stash->{today}->id,
            subject => $clean_subject,
            message => $c->req->param('message'),
            type => 'message',
        }
    );
    
    foreach my $recip_id (@recip_ids) {
        $c->model('DBIC::Party_Messages_Recipients')->create(
            {
                party_id => $recip_id,
                message_id => $message->id,
            },
        );
    }
    
    $c->stash->{panel_messages} = 'Message Sent';
    $c->detach( '/panel/refresh', [[screen => 'party/message/inbox']]);
}

sub redisplay_compose : Private {
    my ($self, $c) = @_;    
    
    my $message = uri_escape($c->req->param('message'));
    my $subject = uri_escape($c->req->param('subject'));
    my $to = uri_escape($c->req->param('to') );
    
    $c->detach( '/panel/refresh', [[screen => 'party/message/compose?to=' . $to . '&subject=' . $subject . 
        '&message=' . $message]] );        
}

sub inbox : Local {
    my ($self, $c) = @_;
    
    my $rs = $c->model('DBIC::Party_Messages')->search(
        {
            'recipients.party_id' => $c->stash->{party}->id,
            type => 'message',
        },
        {
            prefetch => 'recipients',
            order_by => { -desc => [qw/day_id me.message_id/] },
            page => 1,
            rows => 20,
        }
    );
        
    my $total_pages = $rs->pager->last_page;
    
    my $page = $c->req->param('page') // 1;
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/inbox.html',
				params => {
					messages => [$rs->page($page)->all],
					current_page => $page,
					total_pages => $total_pages,
				},
			}
		]
	);        
}

sub outbox : Local {
    my ($self, $c) = @_;
    
    my $rs = $c->model('DBIC::Party_Messages')->search(
        {
            'sender_id' => $c->stash->{party}->id,
            type => 'message',
        },
        {
            prefetch => 'recipients',
            order_by =>  { -desc => [qw/day_id me.message_id/] },
            page => 1,
            rows => 20,            
        }
    );

    my $total_pages = $rs->pager->last_page;
    
    my $page = $c->req->param('page') // 1;

	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/inbox.html',
				params => {
					messages => [$rs->page($page)->all],
					current_page => $page,
					total_pages => $total_pages,
					outbox => 1,
				},
			}
		]
	);     
}

sub view : Local {
    my ($self, $c) = @_;
    
    my ($message, $recipient) = $self->read_and_check_message_can_be_viewed($c, $c->req->param('message_id'));      
    
    if ($recipient) {
        $recipient->has_read(1);
        $recipient->update;
    }
    
    $c->forward('/panel/refresh', [[screen => 'party/message/display?message_id='. $c->req->param('message_id')], 'messages_notify']);    
    
}

sub display : Local {
    my ($self, $c) = @_;    
    
    my ($message, $recipient) = $self->read_and_check_message_can_be_viewed($c, $c->req->param('message_id'));
    
    my $recip_string = join '; ', map { $_->name } $message->recipient_parties;
    
    my $bbc = HTML::BBCode->new({
        allowed_tags => [ qw/b u i quote list url/ ],
        stripscripts => 1,
        linebreaks   => 1,
    });    
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/view.html',
				params => {
					message => $message,
					recip_string => $recip_string,
					bbc => $bbc,
				},
			}
		]
	);    
}

sub read_and_check_message_can_be_viewed {
    my ($self, $c, $message_id) = @_;    
    
    my $message = $c->model('DBIC::Party_Messages')->find(
        {
            'message_id' => $message_id,
        },
        {
            prefetch => 'recipients',
        }   
    );
    
    my ($recipient) = grep { $_->party_id == $c->stash->{party}->id } $message->recipients;
    
    croak "Invalid message" if ! $message || ($message->sender_id != $c->stash->{party}->id && ! $recipient);
    
    return ($message, $recipient);  
}

sub notify : Local {
    my ($self, $c) = @_;    
    
    my $number_unread = $c->model('DBIC::Party_Messages_Recipients')->search(
        {
            'party_id' => $c->stash->{party}->id,
            'has_read' => 0, 
        },
    )->count;   
    
	$c->forward(
		'RPG::V::TT',
		[
			{
				template => 'party/message/notify.html',
				params => {
					number_unread => $number_unread,
				},
				return_output => 1,
			}
		]
	);      
}

1;