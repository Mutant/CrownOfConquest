package RPG::Schema::Spell::Cleanse;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;
use List::Util qw(shuffle);

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my @effects = $target->character_effects;
    foreach my $effect (@effects) {
        if ($effect->effect->modifier < 0) {
            $effect->effect->delete;   
        }   
    }

    return {
        type   => 'cleanse',
    };

}

sub select_target {
    my $self = shift;
    my @targets = @_;
    
    my @possible_targets;
    foreach my $target (@targets) {
        next if $target->is_dead;
        
        my $debuff_count = $target->search_related('character_effects',
            {
                'effect.modifier' => {'<', 0},
            },
            {
                join => 'effect',
            },
        )->count;
        
        push @possible_targets, $target if $debuff_count > 0;
    }
    
    return unless @possible_targets;
    
    return (shuffle @possible_targets)[0];
}

1;
