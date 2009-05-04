package RPG::Combat::PartyBattle;

use Moose::Role;

use Data::Dumper;
use Games::Dice::Advanced;

requires 'party_flee';

has 'party_1'              => ( is => 'rw', isa => 'RPG::Schema::Party',        required => 1 );
has 'party_2'              => ( is => 'rw', isa => 'RPG::Schema::Party',        required => 1 );
has 'party_1_flee_attempt' => ( is => 'ro', isa => 'Bool',                      default  => 0 );
has 'party_2_flee_attempt' => ( is => 'ro', isa => 'Bool',                      default  => 0 );
has 'battle_record'        => ( is => 'ro', isa => 'RPG::Schema::Party_Battle', required => 1 );

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

sub finish {
    my $self   = shift;
    my $losers = shift;

    my ( $opp1, $opp2 ) = $self->opponents;
    my $winners = $losers->id == $opp1->id ? $opp2 : $opp1;

    my $xp;

    foreach my $character ( $losers->characters ) {

        # Generate random modifier between 0.6 and 1.5
        my $rand = ( Games::Dice::Advanced->roll('1d10') / 10 ) + 0.5;
        $xp += int( $character->level * $rand * $self->config->{xp_multiplier_character} );
    }

    my $avg_character_level = $losers->level;

    my @characters = $winners->characters;
    $self->result->{awarded_xp} = $self->distribute_xp( $xp, [ map { $_->is_dead ? () : $_->id } @characters ] );

    my $gold = scalar( $losers->characters ) * $avg_character_level * Games::Dice::Advanced->roll('2d6');

    $self->result->{gold} = $gold;

    $self->check_for_item_found( \@characters, $avg_character_level );

    $self->battle_record->complete(DateTime->now());
    $self->battle_record->update;
    
    $winners->gold( $winners->gold + $gold );
    $winners->update;

    $self->combat_log->gold_found($gold);
    $self->combat_log->xp_awarded($xp);
    $self->combat_log->encounter_ended( DateTime->now() );

    $self->end_of_combat_cleanup;
}

sub process_effects {
}

sub check_for_flee {
    my $self = shift;
    
    if ($self->party_1_flee_attempt && $self->party_flee(1)) {
        return {party_fled => 1};
    }
    
    if ($self->party_2_flee_attempt && $self->party_flee(2)) {
        return {party_fled => 1};
    }    
}

sub check_for_item_found {

}

1;
