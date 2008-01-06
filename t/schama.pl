use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;

use RPG::Schema;

ok(sub {RPG::Schema->resultset('Class')->find(1)}, "dies if there's no connection");

my $schema = RPG::Schema->connect(
    "dbi:mysql:game",
    "root",
    "",
    { AutoCommit => 1 },
);

ok($schema->resultset('Class')->find(1), "works if there's a connection");