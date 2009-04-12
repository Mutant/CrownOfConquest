package RPG::NewDay::Action::Quest;
use Mouse;

extends 'RPG::NewDay::Base';

use Data::Dumper;

use RPG::Exception;
use RPG::NewDay::Template;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use Scalar::Util qw(blessed);

sub run {
    my $self = shift;

    my $c = $self->context;

    $self->create_quests;

    $self->update_days_left;
}

sub create_quests {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search();

    my @quest_types = $c->schema->resultset('Quest_Type')->search( { hidden => 0, }, );
    my @first_level_quests = grep { $_->min_level == 1 } @quest_types;

    while ( my $town = $town_rs->next ) {
        my $number_of_quests = int( $town->prosperity / $c->config->{prosperity_per_quest} );

        my @quests = $c->schema->resultset('Quest')->search(
            {
                town_id  => $town->id,
                party_id => undef,
            },
            { prefetch => 'type', },
        );

        next unless scalar @quests < $number_of_quests;

        my $number_of_first_level_quests = grep { $_->type->min_level == 1 } @quests;

        for ( scalar @quests .. $number_of_quests ) {
            my $quest_type;

            if ( $number_of_first_level_quests == 0 ) {
                shuffle @first_level_quests;
                $quest_type = $first_level_quests[0];
                $number_of_first_level_quests++;
            }
            else {
                @quest_types = shuffle @quest_types;
                $quest_type  = $quest_types[0];
            }

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
        { prefetch => 'type', 'town' },
    );

    foreach my $quest (@quests) {
        next if $quest->days_to_complete == 0;
        
        $quest->days_to_complete( $quest->days_to_complete - 1 );

        if ( $quest->days_to_complete == 0 ) {

            # Time's up!
            $quest->status('Terminated');
            
            my $message = RPG::NewDay::Template->process(
                $c,
                'newday/quest/time_run_out.html',
                {
                    quest => $quest,   
                },
            );

            $c->schema->resultset('Party_Messages')->create(
                {
                    party_id => $quest->party_id,
                    message  => $message,
                    alert_party => 1,
                    day_id      => $c->current_day->id,
                }
            );
        }
        
        $quest->update;
    }
}

1;
