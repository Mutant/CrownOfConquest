package RPG::Combat::PartyBattle;

use Moose::Role;
use Moose::Util::TypeConstraints;

use Data::Dumper;
use Games::Dice::Advanced;

requires 'party_flee';

has 'party_1'                 => ( is => 'rw', isa => 'RPG::Schema::Party',        required => 1 );
has 'party_2'                 => ( is => 'rw', isa => 'RPG::Schema::Party',        required => 1 );
has 'party_1_flee_attempt'    => ( is => 'ro', isa => 'Bool',                      default  => 0 );
has 'party_2_flee_attempt'    => ( is => 'ro', isa => 'Bool',                      default  => 0 );
has 'battle_record'           => ( is => 'ro', isa => 'RPG::Schema::Party_Battle', required => 1 );
has 'initiated_by_opp_number' => ( is => 'ro', isa => 'Maybe[Int]', default => 0 );

sub combatants {
    my $self = shift;

    return ( $self->party_1->characters, $self->party_2->characters );
}

sub opponents {
    my $self = shift;

    return ( $self->party_1, $self->party_2 );
}

sub opponents_of {
    my $self  = shift;
    my $being = shift;

    if ( $being->party_id == $self->party_1->id ) {
        return $self->party_2;
    }
    else {
        return $self->party_1;
    }
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

        $party->turns( $party->turns - 1 );
        $party->update;
    }

    $self->result->{party_battle} = 1;
};

sub finish {
    my $self   = shift;
    my $losers = shift;

    my ( $opp1, $opp2 ) = $self->opponents;
    my $winners = $losers->id == $opp1->id ? $opp2 : $opp1;

    my $xp;

    my $avg_character_level = $losers->level;

    $self->_award_xp_for_characters_killed($losers, $winners);

    my $gold = scalar( $losers->characters ) * $avg_character_level * Games::Dice::Advanced->roll('2d6');

    $self->result->{gold} = $gold;

    my @characters = $winners->characters;
    $self->check_for_item_found( \@characters, $avg_character_level );

    $self->battle_record->complete( DateTime->now() );
    $self->battle_record->update;

    $winners->gold( $winners->gold + $gold );
    $winners->update;

    $self->combat_log->gold_found($gold);
    $self->combat_log->xp_awarded($xp);
    $self->combat_log->encounter_ended( DateTime->now() );

    $self->end_of_combat_cleanup;
}

sub _award_xp_for_characters_killed {
    my $self = shift;
    my $losers = shift;
    my $winners = shift;

    my @characters_killed;
    if ( $self->session->{killed}{character} ) {
        foreach my $character_id ( @{ $self->session->{killed}{character} } ) {
            my $character = $self->combatants_by_id->{character}{$character_id};
            
            next unless $character->party_id == $losers->id;
            
            push @characters_killed, $character;
        }
    }

    my $xp = 0;

    foreach my $character ( @characters_killed ) {
        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $character->level * $rand * $self->config->{xp_multiplier_character} );
    }

    my @characters = $winners->characters;
    $self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );
    $self->combat_log->xp_awarded($xp);

}

sub process_effects {
    my $self = shift;

    my @character_effects = $self->schema->resultset('Character_Effect')->search(
        {
            character_id    => [ map { $_->id } $self->combatants ],
        },
        { prefetch => 'effect', },
    );

    $self->_process_effects(@character_effects);
}

sub check_for_flee {
    my $self = shift;

	# Check for only party flee
    if ( $self->party_1_flee_attempt && $self->party_flee(1) ) {
        $self->result->{party_fled} = 1;
    }
    elsif ( $self->party_2_flee_attempt && $self->party_flee(2) ) {
        $self->result->{party_fled} = 1;
    }
        
    if ($self->result->{party_fled}) {
		$self->_end_party_combat;
    	
    	return 1;	
    }

    # Check for offline flee attempt
    my $opp;
    foreach my $party ( $self->opponents ) {
        $opp++;

        next if $party->is_online || !$party->is_over_flee_threshold;

        if ( $self->party_flee($opp) ) {
            $self->_award_xp_for_characters_killed($party, $self->opponents_of($party));
            $self->_end_party_combat;
            $self->result->{offline_party_fled} = 1;
            return 1;
        }
    }
}

sub _end_party_combat {
	my $self = shift;	
	
   	$self->party_1->end_combat();
   	$self->party_1->update();
    	
   	$self->party_2->end_combat();
   	$self->party_2->update();	
}

sub check_for_item_found {

}

1;
