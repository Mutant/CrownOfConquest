use strict;
use warnings;

package Test::RPG::NewDay::Recruitment;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Recruitment';
   
}

1;