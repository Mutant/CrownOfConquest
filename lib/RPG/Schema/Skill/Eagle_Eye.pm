package RPG::Schema::Skill::Eagle_Eye;

use Moose::Role;

sub execute {
    my $self  = shift;
    my $event = shift;

    return $self->level if $event eq 'critical_hit_chance';
}

1;
