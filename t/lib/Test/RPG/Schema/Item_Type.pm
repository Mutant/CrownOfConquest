use strict;
use warnings;

package Test::RPG::Schema::Item_Type;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests() unless caller();

use Test::More;

use Test::RPG::Builder::Item_Type;

1;