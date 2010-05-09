package RPG::Combat::PartyBattle;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Data::Dumper;
use Games::Dice::Advanced;

requires qw/party_flee check_for_offline_flee finish/;

has 'party_1' => ( is => 'rw', isa => 'RPG::Schema::Party', required => 1 );
has 'party_2' => ( is => 'rw', isa => 'RPG::Schema::Party', required => 1 );
has 'party_1_flee_attempt' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'party_2_flee_attempt' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'battle_record' => ( is => 'ro', isa => 'RPG::Schema::Party_Battle', required => 1 );

with qw/RPG::Combat::CharactersVsCharacters/;

around BUILDARGS => sub {
	my $orig  = shift;
	my $class = shift;
	my %params = @_;
	
	$params{character_group_1} = $params{party_1};
	$params{character_group_2} = $params{party_2};	
	
	return $class->$orig(%params);
};

after 'finish' => sub {
	my $self = shift;

	$self->battle_record->complete( DateTime->now() );
	$self->battle_record->update;
};

sub check_for_flee {
	my $self = shift;

	# Check for only party flee
	if ( $self->party_1_flee_attempt && $self->party_flee(1) ) {
		$self->result->{party_fled} = 1;
	}
	elsif ( $self->party_2_flee_attempt && $self->party_flee(2) ) {
		$self->result->{party_fled} = 1;
	}

	if ( $self->result->{party_fled} ) {
		$self->_end_party_combat;

		return 1;
	}

	# Check for offline flee attempt
	if ( $self->check_for_offline_flee ) {
		$self->_end_party_combat;
		$self->result->{offline_party_fled} = 1;
		return 1;
	}
}

sub _end_party_combat {
	my $self = shift;

	$self->party_1->end_combat();
	$self->party_1->update();

	$self->party_2->end_combat();
	$self->party_2->update();
}

1;
