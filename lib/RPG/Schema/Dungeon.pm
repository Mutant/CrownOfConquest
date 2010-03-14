use strict;
use warnings;

package RPG::Schema::Dungeon;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Dungeon');

__PACKAGE__->add_columns(qw/dungeon_id level land_id name/);

__PACKAGE__->set_primary_key('dungeon_id');

__PACKAGE__->has_many( 'rooms', 'RPG::Schema::Dungeon_Room', { 'foreign.dungeon_id' => 'self.dungeon_id' } );

__PACKAGE__->belongs_to( 'location', 'RPG::Schema::Land', { 'foreign.land_id' => 'self.land_id' } );

sub party_can_enter {
    my $self  = shift;
        
    my $level;
    if (ref $self && $self->isa('RPG::Schema::Dungeon')) {
        $level = $self->level;
    }
    else {
        # Called as a class method
        $level = shift;   
    }
    
    croak "Level not supplied" unless $level;
    
    my $party = shift || croak "Party not supplied";

    return ( $level - 1 ) * RPG::Schema->config->{dungeon_entrance_level_step} <= $party->level ? 1 : 0;
}

1;
