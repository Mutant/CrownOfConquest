package RPG::NewDay::Action::Majesty;

use Moose;

extends 'RPG::NewDay::Base';

use DateTime;

sub cron_string {
    my $self = shift;

    return $self->context->config->{majesty_cron_string};
}

sub run {
    my $self = shift;

    my $c = $self->context;

    my @kingdoms = $c->schema->resultset('Kingdom')->search(
        {
            active => 1,
        }
    );

    my $has_crown;
    my $leader;
    foreach my $kingdom (@kingdoms) {
        my $old_majesty = $kingdom->majesty;
        my $majesty     = $kingdom->calculate_majesty_score;
        $kingdom->majesty($majesty);
        $kingdom->update;

        if ( !$leader || $leader->majesty < $kingdom->majesty ) {
            $leader = $kingdom;
        }

        $has_crown = $kingdom if $kingdom->has_crown;
    }

    # Set the majesty rank
    @kingdoms = $c->schema->resultset('Kingdom')->search(
        {
            active => 1,
        },
        {
            order_by => 'majesty desc',
        },
    );
    my $count = 1;
    foreach my $kingdom (@kingdoms) {
        $kingdom->majesty_rank($count);
        $kingdom->update;
        $count++;
    }

    # If there's a leader, possibly award them the crown
    if ($leader) {
        if ( !$leader->majesty_leader_since ) {
            my $old_leader = $c->schema->resultset('Kingdom')->find(
                {
                    majesty_leader_since => { '!=', undef },
                }
            );
            $old_leader->update( { majesty_leader_since => undef } ) if $old_leader;

            $leader->majesty_leader_since( DateTime->now() );
        }
        elsif ( !$leader->has_crown && $leader->majesty > $c->config->{crown_minimum_majesty} &&
            DateTime->compare( DateTime->now->subtract( 'days' => $c->config->{crown_majesty_wait_period} ), $leader->majesty_leader_since ) == 1 ) {

            $leader->has_crown(1);

            $leader->add_to_messages(
                {
                    day_id => $c->current_day->id,
                    message => "Our kingdom has been awarded the Crown of Conquest. We are now the greatest kingdom in the realm!",
                    type => 'message',
                }
            );

            my $king = $leader->king;
            my $title = $king->gender eq 'male' ? 'King' : 'Queen';
            $c->schema->resultset('Global_News')->create(
                {
                    day_id => $c->current_day->id,
                    message => "The Venerable High Priest bestows the Crown of Conquest upon the $title of " . $leader->name . ". They are truely the most "
                      . "majestic kingdom of the realm",
                }
            );

            $c->schema->resultset('Crown_History')->create(
                {
                    day_id => $c->current_day->id,
                    message => "The Kingdom of " . $leader->name . " was awarded the Crown of Conquest",
                },
            );

        }

        $leader->update;
    }

    # The kingdom that had the crown is no longer the leader. They lose the crown
    if ( $has_crown && $has_crown->id != $leader->id ) {
        $has_crown->has_crown(0);
        $has_crown->update;

        $has_crown->add_to_messages(
            {
                type   => 'message',
                day_id => $c->current_day->id,
                message => "We are no longer the most majestic kingdom in the realm! We've been forced to hand back the Crown of Conquest",
            }
        );

        $c->schema->resultset('Global_News')->create(
            {
                day_id => $c->current_day->id,
                message => "The Kingdom of " . $has_crown->name . " is no longer the greatest in the realm. The Venerable High Priest asks that they hand" .
                  " back the Crown of Conquest so that it may be placed upon a worthier head",
            }
        );

        $c->schema->resultset('Crown_History')->create(
            {
                day_id => $c->current_day->id,
                message => "The Kingdom of " . $has_crown->name . " no longer possesses the Crown of Conquest",
            },
        );
    }
}
