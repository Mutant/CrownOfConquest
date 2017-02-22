package RPG::Schema::Skill::Metallurgy;

use Moose::Role;

use Games::Dice::Advanced;
use Math::Round qw(round);
use RPG::Template;

sub execute {
    my $self  = shift;
    my $event = shift;

    return unless $event eq 'new_day';

    my $character = $self->char_with_skill;

    return if $character->town_id;

    my @items = $character->items;

    my @repaired;

    foreach my $item (@items) {
        my $variable_rec = $item->variable_row('Durability');

        next if !$variable_rec || !defined $variable_rec->max_value || $variable_rec->max_value == $variable_rec->item_variable_value;

        next if $variable_rec->item_variable_value == 0;

        my $chance = $self->level * 3;

        if ( Games::Dice::Advanced->roll('1d100') <= $chance ) {
            my $inc_roll = round( $self->level * 1.5 );
            my $increase = Games::Dice::Advanced->roll( '1d' . $inc_roll ) + round( $character->intelligence / 6 );

            my $new_val = $variable_rec->item_variable_value + $increase;
            $new_val = $variable_rec->max_value if $new_val > $variable_rec->max_value;

            $variable_rec->item_variable_value($new_val);
            $variable_rec->update;

            push @repaired, $item->display_name;
        }
    }

    if (@repaired) {
        my $message = RPG::Template->process(
            RPG::Schema->config,
            'skills/metallurgy.html',
            {
                character => $character,
                repaired  => \@repaired,
            }
        );

        my $today = $self->result_source->schema->resultset('Day')->find_today();

        if ( !$character->is_npc ) {
            $character->party->add_to_day_logs(
                {
                    day_id => $today->id,
                    log    => $message,
                }
            );
        }
    }
}

1;
