package RPG::NewDay::Action::MayorsGroup;
use Moose;

extends 'RPG::NewDay::Base';

with 'RPG::NewDay::Role::CastleGuardGenerator';

# Generate the mayor's group perodically

sub cron_string {
    my $self = shift;
     
    return $self->context->config->{mayors_group_cron_string};   
}

sub run {
    my $self = shift;
    
    my $c = $self->context;
    
	my @towns = $c->schema->resultset('Town')->search(
		{},
		{
			prefetch => 'mayor',
		}
	);
	
	foreach my $town (@towns) {
	    $self->generate_mayors_group($town->castle, $town, $town->mayor);
	}
      
}

1;