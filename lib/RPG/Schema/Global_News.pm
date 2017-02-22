use strict;
use warnings;

package RPG::Schema::Global_News;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Global_News');

__PACKAGE__->add_columns(qw/news_id day_id message/);

__PACKAGE__->set_primary_key('news_id');

__PACKAGE__->belongs_to( 'day', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.day_id' } );

1;
