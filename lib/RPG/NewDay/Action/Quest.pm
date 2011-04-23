package RPG::NewDay::Action::Quest;
use Moose;

extends 'RPG::NewDay::Base';

use Data::Dumper;

use RPG::Exception;
use RPG::Template;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use Scalar::Util qw(blessed);

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Shop/ }

sub run {
    my $self = shift;

    my $c = $self->context;
    
    $self->run_new_day_action;
    
    $self->randomly_delete_quests;

    $self->create_quests;
    
    $self->complete_quests;

    $self->update_days_left;
}

sub create_quests {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search();

    while ( my $town = $town_rs->next ) {
        my $ideal_number_of_quests = int( $town->prosperity / $c->config->{prosperity_per_quest} );

        my $quest_count = $c->schema->resultset('Quest')->search(
            {
                town_id  => $town->id,
                party_id => undef,
            },
            { prefetch => 'type', },
        )->count;

        next unless $quest_count < $ideal_number_of_quests;

        for ( $quest_count .. $ideal_number_of_quests ) {
            my $prevalence_roll = Games::Dice::Advanced->roll('1d100');

            my $quest_type = $c->schema->resultset('Quest_Type')->find(
                { 
                    prevalence => { '>=', $prevalence_roll },
                    owner_type => 'town', 
                },
                {
                    order_by => 'rand()',
                    rows     => 1,
                },
            );

            eval { $c->schema->resultset('Quest')->create( { quest_type_id => $quest_type->id, town_id => $town->id, }, ); };
            if ( my $ev_err = $@ ) {
                if ( blessed($ev_err) && $ev_err->isa("RPG::Exception") && $ev_err->type eq 'quest_creation_error' ) {
                    $c->logger->warning( "Error creating quest: " . $ev_err->message );
                    redo;
                }
                else {
                    die $@;
                }
            }
        }
    }
}

# Complete quests that are automatically completed (i.e. not completed by going to the town hall)
#  This is mostly kingdom quests
sub complete_quests {
    my $self = shift;
    
    my $c = $self->context;
    
    my @quests = $c->schema->resultset('Quest')->search(
        {
            party_id => { '!=', undef },
            status   => 'Awaiting Reward',
        },
    );
    
    foreach my $quest (@quests) {
        my @details = $quest->set_complete;
        
        my $party = $quest->party;
        
        my @messages;
        foreach my $details (@details) {
    		push @messages,
            my $xp_info = RPG::Template->process(
                $c->config,
                'party/xp_gain.html',
                $details,
            );
        }
        
        my $template;
        my %params;
        
        if ($quest->town_id) {
            $template = 'quest/completed_quest.html';
            %params = (
                quest => $quest,
            );
        }
        else {
            $template = 'quest/kingdom/completed.html';
            %params = (
                quest => $quest,
                kingdom => $quest->kingdom,
                xp_messages => \@messages,
            );
        }   
        
        my $message = RPG::Template->process(
            $c->config,
            $template,
            \%params,
        );
        
        $party->add_to_messages(
            {
                day_id => $c->current_day->id,
                message => $message,
                alert_party => 1,
            }
        );         
    }
}

sub update_days_left {
    my $self = shift;

    my $c = $self->context;

    my @quests = $c->schema->resultset('Quest')->search(
        {
            party_id => { '!=', undef },
            status   => 'In Progress',
        },
        { prefetch => [ 'type' ] },
    );

    foreach my $quest (@quests) {
        next if $quest->days_to_complete == 0;

        $quest->days_to_complete( $quest->days_to_complete - 1 );

        if ( $quest->days_to_complete == 0 ) {

            # Time's up!
            my $message = RPG::Template->process( $c->config, 'newday/quest/time_run_out.html', { quest => $quest, }, );
            
            my $kingdom_message;
            if ($quest->kingdom_id) {
                $kingdom_message = RPG::Template->process( $c->config,
                    'quest/kingdom/terminated.html',
                    {
                        quest => $quest,
                        reason => 'the party ran out of time to complete it',
                    }
                );
            }
            
			$quest->terminate(
                party_message => $message,
                kingdom_message => $kingdom_message,
            );
        }

        $quest->update;
    }
}

sub randomly_delete_quests {
    my $self = shift;

    my $c = $self->context;

    my $quest_rs = $c->schema->resultset('Quest')->search( { party_id => undef, kingdom_id => undef }, { order_by => 'rand()' }, );
    
    my $number_of_quests = $quest_rs->count;
    
    my $quests_to_delete = int ($number_of_quests * 0.2);
    
    $c->logger->info("Deleting $quests_to_delete quests");
    
    for (1 .. $quests_to_delete) {
        my $quest= $quest_rs->next;
        $quest->delete;   
    }
}

# Run the 'new_day' action on quests
sub run_new_day_action {
    my $self = shift;
    
     my $c = $self->context;
    
    my @quests = $c->schema->resultset('Quest')->search(
        {
            status => 'In Progress',
        }
    );
    
    foreach my $quest (@quests) {
        $quest->check_quest_action( 'new_day' );   
    }
}

__PACKAGE__->meta->make_immutable;


1;
