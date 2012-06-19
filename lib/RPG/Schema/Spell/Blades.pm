package RPG::Schema::Spell::Blades;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $modifier = $level;
    my $duration = 2 + ( int $character->level / 3 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Blades',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'damage',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'enhancing ' . $target->pronoun('posessive-subjective') . ' weapon',
    };
}

sub select_target {
    my $self = shift;
    my @targets = @_;
    
    return $self->_select_buff_target(@targets);
}

1;