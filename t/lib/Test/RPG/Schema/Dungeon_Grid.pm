package Test::RPG::Schema::Dungeon_Grid;

use strict;
use warnings;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;
use Test::MockObject;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{mock_rpg_schema} = Test::MockObject->new();
    $self->{mock_rpg_schema}->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, );

    use_ok 'RPG::Schema::Dungeon_Grid';
}

sub dungeon_setup : Tests(setup) {
    my $self = shift;

    # Create Dungeon_Positions
    my %positions;
    foreach my $position (qw/top bottom left right/) {
        my $position_rec = $self->{schema}->resultset('Dungeon_Position')->create( { position => $position, } );
        $positions{$position} = $position_rec->id;
    }

    $self->{positions} = \%positions;
}

1;
