package RPG::Schema::Skill::Medicine;

use Moose::Role;

use Games::Dice::Advanced;
use RPG::Template;

sub execute {
    my $self = shift;
    my $event = shift;
    
    return unless $event eq 'new_day';
    
    my $character = $self->char_with_skill;
    
    my $group = $character->group;

    my @group_chars;
    if ($group) {
        @group_chars = $group->members;
    }
    else {
        @group_chars = ($character);
    }
    
    my %healed;
    
    foreach my $char_to_heal (@group_chars) {
        next unless $char_to_heal->isa('RPG::Schema::Character');
        
        next if $char_to_heal->max_hit_points == $char_to_heal->hit_points;
                
        my $chance = $self->level * 3;
        
        if (Games::Dice::Advanced->roll('1d100') <= $chance) {
            my $amount_to_heal = Games::Dice::Advanced->roll('1d' . $self->level);

            my $actual_increase = $char_to_heal->change_hit_points($amount_to_heal);
            $char_to_heal->update;
            
            $healed{$char_to_heal->character_name} = $actual_increase if $actual_increase;
        }           
    }
    
    if (%healed) {
        my $message = RPG::Template->process(
            RPG::Schema->config,
            'skills/medicine.html',
            {
                character => $character,
                healed => \%healed,
            }
        );
        
        my $today = $self->result_source->schema->resultset('Day')->find_today();
        
        $character->party->add_to_day_logs(
            {
                day_id => $today->id,
                log => $message,
            }
        );
    }
    
}

1;