package RPG::Schema::Spell::Summon;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use Games::Dice::Advanced;
use List::Util qw(shuffle);
use Lingua::EN::Inflect qw ( PL_N );

sub _cast {
    my ( $self, $caster, $group, $level ) = @_;

    my @creature_types = $self->result_source->schema->resultset('CreatureType')->search(
        {
            'level' => {
                '<=', $level,
                '>',  $level - 6,
            },
            'rare' => 0,
            'category.name' => { '!=', 'Guard' },
        },
        {
            join => 'category',
        },
    );

    my $creature_type = ( shuffle @creature_types )[0];

    my $number = Games::Dice::Advanced->roll('1d3');

    for ( 1 .. $number ) {
        $group->add_creature($creature_type);
    }

    return {
        type => 'summon',
        effect => "$number " . ( $number == 1 ? $creature_type->creature_type : PL_N( $creature_type->creature_type ) ),
    };
}

1;
