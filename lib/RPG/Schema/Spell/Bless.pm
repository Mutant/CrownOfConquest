package RPG::Schema::Spell::Bless;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    my $modifier = $character->level;
    my $duration = 1 + ( int $level / 3 + 1 );

    $self->create_effect(
        {
            target      => $target,
            effect_name    => 'Bless',
            duration       => $duration,
            modifier       => $modifier,
            combat         => 1,
            modified_state => 'attack_factor',
        }
    );

    return {
        type     => 'effect',
        duration => $duration,
        effect   => 'blessing ' . $target->pronoun('objective'),
    };
}

sub select_target {
    my $self = shift;
    my @targets = @_;
    
    return $self->_select_buff_target(@targets);
}

1;
