package RPG::Schema::Class;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Class');

__PACKAGE__->resultset_class('RPG::ResultSet::Race');

__PACKAGE__->add_columns(
    'class_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'class_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'class_name' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'class_name',
        'is_nullable'       => 0,
        'size'              => '255'
    },
);
__PACKAGE__->set_primary_key('class_id');

__PACKAGE__->has_many( 'spells', 'RPG::Schema::Spell', { 'foreign.class_id' => 'self.class_id' }, );

# Which stat is most important to this class
my %PRIMARY_STATS = (
    'Warrior' => 'strength',
    'Archer'  => 'agility',
    'Priest'  => 'divinity',
    'Mage'    => 'intelligence',
);

sub primary_stat {
    my $self = shift;
    
    return $PRIMARY_STATS{$self->class_name};
}

1;
