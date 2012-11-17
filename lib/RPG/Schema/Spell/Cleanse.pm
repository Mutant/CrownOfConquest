package RPG::Schema::Spell::Cleanse;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

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
    
    return $self->_select_buff_target(@targets);
}

1;
