package RPG::Schema::Skill::Construction;

use Moose::Role;

sub execute {
    my $self  = shift;
    my $event = shift;

    my $character = $self->char_with_skill;

    return $self->level * 2 if $event eq 'building_cost';
}

1;
