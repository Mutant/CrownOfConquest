use strict;
use warnings;

package RPG::Schema::Survey_Response;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Survey_Response');

__PACKAGE__->add_columns(qw/survey_response_id reason favourite least_favourite feedback email added party_level turns_used/);

__PACKAGE__->set_primary_key('survey_response_id');

1;
