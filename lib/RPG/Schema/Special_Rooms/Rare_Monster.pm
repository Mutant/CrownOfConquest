package RPG::Schema::Special_Rooms::Rare_Monster;

use Moose::Role;

with 'RPG::Schema::Special_Rooms::Interface';

use List::Util qw(shuffle);

my %RARE_MONSTERS = (
    1 => ['Orc Shaman', 'Goblin Chief'],
    2 => ['Bandit Leader', 'Warlock'],
    3 => ['Gelatinous Ooze', 'Black Sorcerer'],
    4 => ['Lich', 'Demon King'], 
);

sub generate {
    my $self = shift;
    my $dungeon_room = shift;
    
    my $level = $dungeon_room->dungeon->level;
    
    my $type_to_use = (shuffle @{$RARE_MONSTERS{$level}})[0];
    
    my $schema = $self->result_source->schema;
    
    my $creature_type = $schema->resultset('CreatureType')->find(
        {
            creature_type => $type_to_use,
        },
    );
    
    confess "Rare type $type_to_use not in db" unless $creature_type;
    
    my $sector = (shuffle $dungeon_room->sectors)[0];
    
    my $cg = $schema->resultset('CreatureGroup')->create(
        {
            dungeon_grid_id => $sector->id,            
        }
    );
    
    $cg->add_creature($creature_type);
    
    my @guard_types = $schema->resultset('CreatureType')->search(
        {
            'level' => {
                '<', $creature_type->level,
                '>', $creature_type->level-5,
            },
            'creature_category_id' => $creature_type->creature_category_id,
        },
    );
    
    my $guard_type = (shuffle @guard_types)[0];
    for my $count (1..8) {
        $cg->add_creature($guard_type, $count);   
    }
    
    $dungeon_room->special_room_id($self->id);
    $dungeon_room->update;
}

1;