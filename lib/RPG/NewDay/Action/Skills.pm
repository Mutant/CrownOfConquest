package RPG::NewDay::Action::Skills;
use Moose;

extends 'RPG::NewDay::Base';

use Games::Dice::Advanced;

sub depends { qw/RPG::NewDay::Action::CreateDay RPG::NewDay::Action::Party/ };

sub run {
    my $self = shift;

    my $c = $self->context;
    
	my @skills = $c->schema->resultset('Character_Skill')->search(
		{
			'skill.type' => 'nightly',
			'party.defunct' => undef,
		},
		{
			prefetch => ['skill', {'char_with_skill' => 'party'}],
		}
	);
	
	foreach my $skill (@skills) {
	   $skill->execute('new_day');   
	}
}

__PACKAGE__->meta->make_immutable;


1;