package RPG::Schema::Skill::Strategy;

use Moose::Role;

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;

    my $character = $self->char_with_skill;
    
    if ($event eq 'flee_bonus') {
		return round $self->level + ($character->intelligence / 8);
	}
    elsif ($event eq 'guard_df') {
		return $self->level;
    }    
}

1;