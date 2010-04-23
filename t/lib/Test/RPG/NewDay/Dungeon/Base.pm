use strict;
use warnings;

package Test::RPG::NewDay::Dungeon::Base;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Data::Dumper;

use Test::MockObject;
use Test::More;
use Test::Exception;

use Test::RPG::Builder::Dungeon_Room;

sub dungeon_startup : Test(startup => 1) {
    my $self = shift;

    $self->{dice} = Test::MockObject->new();

    $self->{dice}->fake_module(
        'Games::Dice::Advanced',
        roll => sub {
            if ( $self->{rolls} ) {
                my $ret = $self->{rolls}[ $self->{counter} ];
                $self->{counter}++;
                return $ret;
            }
            else {
                return $self->{roll_result} || 0;
            }
        }
    );

    use_ok 'RPG::NewDay::Action::Dungeon';

    my $logger = Test::MockObject->new();
    $logger->set_always('debug');
    $logger->set_always('info');

    $self->{context} = Test::MockObject->new();

    $self->{config} = {
        max_x_dungeon_room_size => 6,
        max_y_dungeon_room_size => 6,
    };

    $self->{context}->set_always( 'logger', $logger );
    $self->{context}->set_always( 'schema', $self->{schema} );
    $self->{context}->set_always( 'config', $self->{config} );
    $self->{context}->set_isa('RPG::NewDay::Context');
}

sub dungeon_shutdown : Test(shutdown) {
    my $self = shift;

    $self->{dice}->unfake_module();
}

1;