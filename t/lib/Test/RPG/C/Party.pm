use strict;
use warnings;

package Test::RPG::C::Party;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use DateTime;

use Test::MockObject;
use Test::More;

use RPG::C::Party;

use Test::RPG::Builder::CreatureGroup;
use Test::RPG::Builder::Party;
use Test::RPG::Builder::Land;
use Test::RPG::Builder::Kingdom;
use Test::RPG::Builder::Item;

use Data::Dumper;

sub test_swap_chars : Tests(65) {
    my $self = shift;

    my @characters;
    for ( 1 .. 5 ) {
        my $character = Test::MockObject->new();
        $character->{party_order} = $_;
        $character->mock( 'party_order', sub { $_[0]->{party_order_set_to} = $_[1] if $_[1]; $_[0]->{party_order} } );
        $character->set_always( 'id', $_ );
        $character->set_true('update');
        $character->{id}          = $_;
        $character->{party_order} = $_;
        push @characters, $character;
    }

    my $party = Test::MockObject->new();
    $party->mock( 'characters_in_party', sub { @characters } );
    $party->mock( 'rank_separator_position', sub { $_[0]->{rank_sep_set_to} = $_[1] if $_[1]; $_[0]->{rank_sep} } );
    $party->set_always('update');

    $self->{stash} = {
        party => $party,
    };

    my @tests = (
        {
            moved                   => 2,
            target                  => 4,
            drop_pos                => 'before',
            rank_separator_expected => 2,
        },
        {
            moved                   => 1,
            target                  => 5,
            drop_pos                => 'after',
            rank_separator_expected => 2,
        },
        {
            moved                   => 4,
            target                  => 2,
            drop_pos                => 'after',
            rank_separator_expected => 4,
        },
        {
            moved                   => 3,
            target                  => 4,
            drop_pos                => 'before',
            rank_separator_expected => 2,
        },
        {
            moved    => 2,
            target   => 3,
            drop_pos => 'after',
        },
        {
            moved                   => 3,
            target                  => 4,
            drop_pos                => 'after',
            rank_separator_expected => 2,
        },
        {
            moved                   => 4,
            target                  => 3,
            drop_pos                => 'after',
            rank_separator_expected => 4,
        },
        {
            moved                   => 4,
            target                  => 3,
            drop_pos                => 'before',
            rank_separator_expected => 4,
        },

    );

    foreach my $test (@tests) {
        map { $_->clear; $_->{party_order_set_to} = undef; } @characters;
        $party->{rank_sep}        = 3;
        $party->{rank_sep_set_to} = undef;

        $self->{params} = $test;

        my $moved  = $test->{moved};
        my $target = $test->{target};

        my $operater = $moved > $target ? '+1' : '-1';
        my ( $upper_bound, $lower_bound ) = sort ( $moved, $target );

        my $adjusted_target = 0;
        if ( $test->{drop_pos} eq 'after' && $moved > $target ) {
            $upper_bound++;
            $target++;
            $adjusted_target = 1;
        }
        elsif ( $test->{drop_pos} eq 'before' && $moved < $target ) {
            $lower_bound--;
            $target--;
            $adjusted_target = 1;
        }

        RPG::C::Party->swap_chars( $self->{c} );

        my ( $method, $args );

        my $count = 1;
        foreach my $character (@characters) {
            if ( $count == $moved ) {
                ( $method, $args ) = $characters[ $count - 1 ]->next_call(5);

                is( $method, 'party_order', "Moved character $count has party order set" );
                is( $args->[1], $target, "Set to position of target char" );
            }
            elsif ( $count == $target ) {

                # If the target has been adjusted (due to before/after mattering), we have one less call on the target
                #  since it wasn't the original target as far as the code is concerned
                ( $method, $args ) = $characters[ $count - 1 ]->next_call( $adjusted_target ? 6 : 7 );

                is( $method, 'party_order', "party order set on target character $count" );
                is( $args->[1], $character->{id} + $operater, "Set to correct position" );
            }
            elsif ( $count > $upper_bound and $count < $lower_bound ) {
                ( $method, $args ) = $characters[ $count - 1 ]->next_call(6);

                is( $method, 'party_order', "party order set on character $count" );
                is( $args->[1], $character->{id} + $operater, "Set to correct position" );
            }
            else {
                ( $method, $args ) = $characters[ $count - 1 ]->next_call(6);

                is( $method, undef, "party order call not made on character $count" );
            }

            #warn "$count: " . $character->{party_order_set_to};

            $count++;
        }

        is( $party->{rank_sep_set_to}, $test->{rank_separator_expected}, "Rank separator in expected position" );

        #warn "rank sep: " . $party->{rank_sep_set_to};
    }
}

sub test_select_action : Tests(7) {
    my $self = shift;

    # GIVEN
    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2 );
    my $char1 = ( $party->characters )[0];
    my $char2 = ( $party->characters )[1];

    $self->{params}{character_id} = $char1->id;

    $self->{stash}{party} = $party;
    $self->{params}{'action'} = 'Cast';

    my $mock_spell_action = Test::MockObject->new();
    $mock_spell_action->set_always( 'custom', {} );

    my $spell = Test::MockObject->new();
    $spell->set_always( 'cast',   $mock_spell_action );
    $spell->set_always( 'target', 'character' );
    $spell->set_always( 'spell_name' , 'spell' );

    my $spell_rs = Test::MockObject->new();
    $spell_rs->set_always( 'find', $spell );

    $self->{mock_resultset}{Spell} = $spell_rs;

    $self->{params}{action_param} = [ 'spell_id', $char2->id ];

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_; return 'spell message' };

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Party->select_action( $self->{c} );

    # THEN
    my ( $method, $args ) = $spell->next_call(2);
    is( $method, 'cast', "Cast called on spell" );

    isa_ok( $args->[1], 'RPG::Schema::Character', "Character passed as first arg to cast" );
    is( $args->[1]->id, $char1->id, "Correct char is caster of spell" );

    isa_ok( $args->[2], 'RPG::Schema::Character', "Character passed as second arg to cast" );
    is( $args->[2]->id, $char2->id, "Correct char is target of spell" );

    is( $template_args->[0][0]{params}{message}, $mock_spell_action, "Cast result passed to template" );

    is( $self->{stash}{messages}, 'spell message', "Messages set correctly" );
}

sub test_parties_in_sector_land : Tests(1) {
    my $self = shift;

    # GIVEN
    my ($land) = Test::RPG::Builder::Land->build_land( $self->{schema} );

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land->id );

    my $party1 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land->id );

    my $kingdom = Test::RPG::Builder::Kingdom->build_kingdom( $self->{schema} );
    my $party2 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land->id, kingdom_id => $kingdom->id );
    my $party3 = Test::RPG::Builder::Party->build_party( $self->{schema}, character_count => 2, land_id => $land->id, defunct => DateTime->now() );

    $self->{stash}{party_location} = $land;
    $self->{stash}{party}          = $party;

    my $template_args;
    $self->{mock_forward}->{'RPG::V::TT'} = sub { $template_args = \@_; };
    $self->{mock_forward}->{'/party/pending_mayor_check'} = sub { };

    # WHEN
    my $parties = RPG::C::Party->parties_in_sector( $self->{c}, $land->id );

    # THEN
    is( scalar @$parties, 2, "Two parties in sector" );

}

sub test_select_action_drink_potion : Tests(2) {
    my $self = shift;

    # GIVEN
    $self->mock_dice;
    $self->{roll_result} = 1;

    my $party = Test::RPG::Builder::Party->build_party( $self->{schema} );
    my $character = Test::RPG::Builder::Character->build_character( $self->{schema}, party_id => $party->id, hit_points => 9, max_hit_points => 10 );

    my $item1 = Test::RPG::Builder::Item->build_item(
        $self->{schema},
        item_type_name => 'Potion of Healing',
        variables      => [
            {
                item_variable_name  => 'Quantity',
                item_variable_value => 1,
            }
        ],
        character_id => $character->id,
    );

    $self->{stash}{party}         = $party;
    $self->{params}{character_id} = $character->id;
    $self->{params}{action_param} = $item1->id;
    $self->{params}{action}       = 'Use';

    $self->{mock_forward}->{'/panel/refresh'} = sub { };

    # WHEN
    RPG::C::Party->select_action( $self->{c} );

    # THEN
    $character->discard_changes;
    is( $character->hit_points, 10, "Character healed" );

    $item1->discard_changes;
    is( $item1->in_storage, 0, "Potion removed" );

    $self->unmock_dice;
}

1;
