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

    $self->randomly_delete_quests;

    $self->create_quests;

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
                { prevalence => { '>=', $prevalence_roll }, },
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

sub update_days_left {
    my $self = shift;

    my $c = $self->context;

    my @quests = $c->schema->resultset('Quest')->search(
        {
            party_id => { '!=', undef },
            status   => 'In Progress',
        },
        { prefetch => [ 'type', 'town' ] },
    );

    foreach my $quest (@quests) {
        next if $quest->days_to_complete == 0;

        $quest->days_to_complete( $quest->days_to_complete - 1 );

        if ( $quest->days_to_complete == 0 ) {

            # Time's up!
            $quest->status('Terminated');

            my $message = RPG::Template->process( $c->config, 'newday/quest/time_run_out.html', { quest => $quest, }, );

            $c->schema->resultset('Party_Messages')->create(
                {
                    party_id    => $quest->party_id,
                    message     => $message,
                    alert_party => 1,
                    day_id      => $c->current_day->id,
                }
            );

            my $party_town = $c->schema->resultset('Party_Town')->find_or_create(
                {
                    town_id  => $quest->town_id,
                    party_id => $quest->party_id,
                },
            );
            $party_town->prestige( $party_town->prestige - 3 );
            $party_town->update;
        }

        $quest->update;
    }
}

sub randomly_delete_quests {
    my $self = shift;

    my $c = $self->context;

    my $quest_rs = $c->schema->resultset('Quest')->search( { party_id => undef, }, { order_by => 'rand()' }, );
    
    my $number_of_quests = $quest_rs->count;
    
    my $quests_to_delete = int ($number_of_quests * 0.2);
    
    $c->logger->info("Deleting $quests_to_delete quests");
    
    for (1 .. $quests_to_delete) {
        my $quest= $quest_rs->next;
        $quest->delete;   
    }
}

1;
