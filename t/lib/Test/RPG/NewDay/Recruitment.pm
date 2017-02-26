use strict;
use warnings;

package Test::RPG::NewDay::Recruitment;

use base qw(Test::RPG::Base::NewDay::ActionBase);

__PACKAGE__->runtests unless caller();

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Character;

use Test::MockObject;
use Test::More;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Recruitment';
}

sub setup : Test(setup) {
    my $self = shift;

    $self->setup_context;
}

sub test_generate_character_used_from_recruitment_hold : Tests(4) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema} );
    my $character1 = Test::RPG::Builder::Character->build_character( $self->{schema}, status => 'recruitment_hold', status_context => 1 );
    my $character2 = Test::RPG::Builder::Character->build_character( $self->{schema}, status => 'recruitment_hold', status_context => $town->id );

    my $action = RPG::NewDay::Action::Recruitment->new( context => $self->{mock_context} );

    # WHEN
    $action->generate_character($town);

    # THEN
    my @characters = $town->characters;
    is( scalar @characters, 1, "Town has 1 character" );
    is( $characters[0]->id, $character1->id, "Character 1 added to town" );

    is( $characters[0]->status, undef, "Character's status is clear" );
    is( $characters[0]->status_context, undef, "Character's status_context is clear" );

}

1;
