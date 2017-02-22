package RPG::Schema::Spell::Detonate;

use base 'RPG::Schema::Spell';

use strict;
use warnings;

use DateTime;

sub _cast {
    my ( $self, $character, $target, $level ) = @_;

    if ( $target->location->town ) {
        return {
            type       => 'detonate',
            custom     => { in_town => 1 },
            didnt_cast => 1,
          }
    }

    # Look for an existing bomb
    my $existing_bomb_count = $self->result_source->schema->resultset('Bomb')->search(
        {
            ( $target->dungeon_grid_id ?
                  ( dungeon_grid_id => $target->dungeon_grid_id ) :
                  ( land_id         => $target->land_id ) ),
            detonated => undef,
        }
    );

    if ( $existing_bomb_count > 0 ) {
        return {
            type       => 'detonate',
            custom     => { existing_bomb => 1 },
            didnt_cast => 1,
          }
    }

    my @vials = $character->search_related(
        'items',
        {
            'item_type.item_type' => 'Vial of Dragons Blood',
        },
        {
            prefetch => { 'item_variables' => 'item_variable_name' },
            join => 'item_type',
        },
    );

    @vials = grep { $_->variable('Quantity') > 0 } @vials;

    if ( !@vials ) {
        return {
            type       => 'detonate',
            custom     => { no_vial => 1 },
            didnt_cast => 1,
          }
    }

    my $vial = shift @vials;
    if ( $vial->variable('Quantity') == 1 ) {
        $character->remove_item_from_grid($vial);
        $vial->delete;
    }
    else {
        $vial->variable( 'Quantity', $vial->variable('Quantity') - 1 );
    }

    $self->result_source->schema->resultset('Bomb')->create(
        {
            party_id => $target->id,
            level    => $level,
            ( $target->dungeon_grid_id ?
                  ( dungeon_grid_id => $target->dungeon_grid_id ) :
                  ( land_id         => $target->land_id ) ),
            planted => DateTime->now(),
        }
    );

    return {
        type => 'detonate',
        custom => { planted => 1 },
      }

}

1;
