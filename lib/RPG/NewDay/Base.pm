# Base class for NewDay module. Provides a method for getting/setting the new day context as class data

package RPG::NewDay::Base;

use Mouse;

has 'context' => (is => 'rw', isa => 'RPG::NewDay::Context');

1;