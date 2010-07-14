package RPG::Combat::CreatureBattle;

# Battle between creatures and a party (not a garrison)
# TODO: Possibly needs a rename?

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;
use Carp;
use List::Util qw/shuffle/;
use DateTime;

requires qw/creature_flee creatures_lost deduct_turns/;

has 'party'               => ( is => 'rw', isa => 'RPG::Schema::Party',         required => 1 );
has 'creatures_can_flee'  => ( is => 'ro', isa => 'Bool',                       default  => 1 );
has 'party_flee_attempt'  => ( is => 'ro', isa => 'Bool',                       default  => 0 );

with qw/RPG::Combat::CharactersVsCreatures/;

sub character_group {
	my $self = shift;
	
	return $self->party;
}

after 'execute_round' => sub {
    my $self = shift;

	$self->deduct_turns($self->party);

    $self->result->{creature_battle} = 1;
};

sub check_for_flee {
    my $self = shift;

    my $attempt_to_flee = 0;
    if (! $self->party->is_online && $self->party->is_over_flee_threshold) {
        $attempt_to_flee = 1;
    }
    elsif ($self->party_flee_attempt) {
        $attempt_to_flee = 1;    
    }

    if ( $attempt_to_flee && $self->party_flee(1) ) {
        $self->result->{party_fled} = 1;
                
        return 1;
    }
    
    return unless $self->creatures_can_flee;

    return $self->creature_flee;    
}

sub finish {
    my $self   = shift;
    my $losers = shift;

    # Only do stuff if the party won
    return if $losers->group_type eq 'party';
    
    $self->creatures_lost;
    
    $self->party->gold( $self->party->gold + $self->result->{gold} );
    $self->party->update;
}

sub is_online {
	my $self = shift;
	
	return $self->party->is_online;	
}

1;
