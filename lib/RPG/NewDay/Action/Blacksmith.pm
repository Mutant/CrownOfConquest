package RPG::NewDay::Action::Blacksmith;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

sub run {
    my $self = shift;

    my $c = $self->context;

    my $town_rs = $c->schema->resultset('Town')->search( {}, );

    while ( my $town = $town_rs->next ) {

        # Check if blacksmith exists
        if ( $town->blacksmith_age == 0 ) {

            # No blacksmith, see if we should create a new one
            my $new_smith_roll = Games::Dice::Advanced->roll('1d100');
            if ( $new_smith_roll < $town->prosperity ) {
                my $smith_skill = Games::Dice::Advanced->roll( '1d' . $c->config->{blacksmith_max_start_skill} );
                $town->blacksmith_skill($smith_skill);
                $town->blacksmith_age(1);
                $town->update;
                
                $town->add_to_history(
                    {
                        message => "A new blacksmith arrives in town. The townsfolk hope he has a long career ahead of him",
                        day_id => $c->current_day->day_id,
                    }
                );                
            }

            next;
        }

        # Check if blacksmith retires
        my $retirement_roll = Games::Dice::Advanced->roll('1d100');
        if ( $retirement_roll < $c->config->{blacksmith_retire_chance} ) {
             $town->add_to_history(
                {
                    message => "The town's blacksmith retires after a long " . $town->blacksmith_age . " days of service",
                    day_id => $c->current_day->day_id,
                }
             );
 
            $town->blacksmith_skill(0);
            $town->blacksmith_age(0);
            $town->update;
            
            next;
        }

        # Blacksmith exists, and hasn't retired. Update age and check for skill increase
        $town->blacksmith_age( $town->blacksmith_age + 1 );

        my $skill_increase_roll = Games::Dice::Advanced->roll('1d100');
        if ( $skill_increase_roll < $c->config->{blacksmith_skill_increase_chance} ) {
            my $old_label = $town->blacksmith_skill_label;
            $town->blacksmith_skill( $town->blacksmith_skill + 1 );
            my $new_label = $town->blacksmith_skill_label;
            
            if ($old_label ne $new_label) {
                 $town->add_to_history(
                    {
                        message => "The town blacksmith's skill level has been raised from $old_label to $new_label",
                        day_id => $c->current_day->day_id,
                    }
                 );               
            }
        }

        $town->update;
    }

}

__PACKAGE__->meta->make_immutable;


1;
