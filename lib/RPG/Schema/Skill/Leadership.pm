package RPG::Schema::Skill::Leadership;

use Moose::Role;

use Math::Round;

sub execute {
    my $self  = shift;
    my $event = shift;

    my $character = $self->char_with_skill;

    if ( $event eq 'town_peasant_tax' ) {
        return $self->level * 2;
    }
    elsif ( $event eq 'kingdom_quests_allowed' ) {
        return $self->level;
    }
    elsif ( $event eq 'mayor_xp_gain' ) {
        return $self->level;
    }

}

1;
