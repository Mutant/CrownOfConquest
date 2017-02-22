package RPG::Schema::Character_Skill;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Character_Skill');

__PACKAGE__->add_columns(qw/character_id skill_id level/);

__PACKAGE__->numeric_columns(qw/level/);

__PACKAGE__->set_primary_key(qw/character_id skill_id/);

__PACKAGE__->belongs_to( 'skill', 'RPG::Schema::Skill', 'skill_id' );
__PACKAGE__->belongs_to( 'char_with_skill', 'RPG::Schema::Character', 'character_id' );

sub insert {
    my ( $self, @args ) = @_;

    $self->next::method(@args);

    $self->_apply_role;
}

sub inflate_result {
    my $pkg = shift;

    my $self = $pkg->next::method(@_);

    $self->_apply_role;

    return $self;
}

sub _apply_role {
    my $self = shift;

    my $role = $self->get_role_name;
    $self->ensure_class_loaded($role);
    $role->meta->apply($self);
}

sub get_role_name {
    my $self = shift;

    my $name = $self->skill->skill_name;

    $name =~ s/ /_/g;

    return 'RPG::Schema::Skill::' . $name;
}

1;
