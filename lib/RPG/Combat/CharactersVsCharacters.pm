# Methods for battles involving charcters on one side, creatures on the other
package RPG::Combat::CharactersVsCharacters;

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;
use Carp;
use List::Util qw/shuffle/;
use DateTime;

requires qw/deduct_turns group_initiated/;

has 'character_group_1'       => ( is => 'rw', required => 1 );
has 'character_group_2'       => ( is => 'rw', required => 1 );
has 'initiated_by_opp_number' => ( is => 'ro', isa  => 'Maybe[Int]', default  => 0 );

has 'combatants_list' => ( 
	traits     => ['Array'],
    is         => 'ro',
    isa        => 'ArrayRef',
    handles    => {
    	'combatants'    => 'elements',
    },
    lazy => 1,
    builder => '_build_combatants',
);

sub _build_combatants {
	my $self = shift;

	return [ $self->character_group_1->members, $self->character_group_2->members ];
}

sub opponents {
	my $self = shift;

	return ( $self->character_group_1, $self->character_group_2 );
}

sub opponent_of_by_id {
	my $self  = shift;
	my $being = shift;
	my $id    = shift;

	return $self->combatants_by_id->{'character'}{$id};
}

sub initiated_by {
	my $self = shift;

	return 'opp' . $self->initiated_by_opp_number;
}

after 'execute_round' => sub {
	my $self = shift;

	foreach my $party ( $self->opponents ) {
		next unless $party->is_online;    # Only online parties use up turns

		$self->deduct_turns($party);
	}
};

sub finish {
	my $self   = shift;
	my $losers = shift;

	my ( $opp1, $opp2 ) = $self->opponents;
	my $winners = $losers->id == $opp1->id ? $opp2 : $opp1;

	my $xp;

	my $avg_character_level = $losers->level;

	$self->_award_xp_for_characters_killed( $losers, $winners );

	my $gold = scalar( $losers->members ) * $avg_character_level * Games::Dice::Advanced->roll('2d6');

	$self->result->{gold} = $gold;
	
	my @characters = $winners->members;
	$self->check_for_item_found( \@characters, $avg_character_level );

	$winners->gold( $winners->gold + $gold );
	$winners->update;

	$self->combat_log->gold_found($gold);
	$self->combat_log->xp_awarded($xp);
	$self->combat_log->encounter_ended( DateTime->now() );

	if ($losers->group_type eq 'garrison') {
    	$self->wipe_out_garrison;
	}
}

sub _award_xp_for_characters_killed {
	my $self    = shift;
	my $losers  = shift;
	my $winners = shift;

	my @characters_killed;
	if ( $self->session->{killed}{character} ) {
		foreach my $character_id ( @{ $self->session->{killed}{character} } ) {
			my $character = $self->combatants_by_id->{character}{$character_id};

			next unless $character->group_id == $losers->id && $character->group->group_type eq $losers->group_type;

			push @characters_killed, $character;
		}
	}

	my $xp = 0;

	foreach my $character (@characters_killed) {

		# Generate random modifier between 0.6 and 1.5
		my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
		$xp += int( $character->level * $rand * $self->config->{xp_multiplier_character} );
	}

	my @characters = $winners->members;
	$self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );
	$self->combat_log->xp_awarded($xp);

}

sub process_effects {
	my $self = shift;

	my @character_effects = $self->schema->resultset('Character_Effect')->search(
		{
			character_id => [ map { $_->id } $self->combatants ],
		},
		{ prefetch => 'effect', },
	);

	$self->_process_effects(@character_effects);
}

sub check_for_offline_flee {
	my $self = shift;

	my $opp;
	my @opps = $self->opponents;
	foreach my $group (@opps) {
		$opp++;

        # If the group didn't initiate, we use offline flee threshold. This is 'safer' then
        #  just an 'is_online' check, because they could have been active a few minutes ago
        #  so would appear 'online' even though they didn't. This would mean they'd never flee
        # Could result in fleeing during online combat though...
		next if $self->group_initiated($group) || !$group->is_over_flee_threshold;

		if ( $self->party_flee($opp) ) {
			my $enemy_num = $opp == 1 ? 2 : 1;
			$self->_award_xp_for_characters_killed( $group, $opps[ $enemy_num - 1 ] );
			return $group;
		}
	}
}

sub check_for_item_found {

}

sub is_online {
	my $self = shift;
	
	return $self->character_group_1->is_online || $self->character_group_1->is_online ? 1 : 0; 
}

1;
