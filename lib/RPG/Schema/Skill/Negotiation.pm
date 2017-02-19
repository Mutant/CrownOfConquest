package RPG::Schema::Skill::Negotiation;

use Moose::Role;

use Math::Round qw(round);

sub execute {
    my $self = shift;
    my $event = shift;
    
    my $character = $self->char_with_skill;    
    
    if ($event eq 'town_entrance_tax') {
		return $self->level + round ($character->intelligence / 6);
	}
    elsif ($event eq 'mayor_overthrow_check') {
		return $self->level;
    }
    
}

1;