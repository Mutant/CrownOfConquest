package Foo;

use Moose::Role;

has 'a' => ( is => 'ro' );

package Bar;

use Moose::Role;;

has 'a' => ( required => 1 );

package Baz;

use Moose;

with qw/Foo Bar/;