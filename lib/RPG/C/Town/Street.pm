package RPG::C::Town::Street;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;
use HTML::Strip;

sub default : Local {
	my ($self, $c) = @_;

	$c->forward('character_list');
}

sub character_list : Private {
	my ($self, $c) = @_;

	my $current_day = $c->stash->{today}->day_number;
	
	my @graffiti = my @logs = $c->model('DBIC::Town_History')->search(
	   {
	       town_id => $c->stash->{party_location}->town->id, 
	       type => 'graffiti'
	   },
	   {
	       order_by => 'day_id desc',
	       rows => 10,
	   }
	);
	
	$c->stash->{template_params}{graffiti} = \@graffiti;     
	
	$c->forward('/town/characterhold/character_list', ['street']);
	
}

sub add_character : Local {
	my ($self, $c) = @_;

	$c->forward('/town/characterhold/add_character', ['street']);
}

sub remove_character : Local {
	my ($self, $c) = @_;
	
	$c->forward('/town/characterhold/remove_character', ['street']);
}

sub graffiti : Local {
	my ($self, $c) = @_;
	
	my $message = $c->forward(
		'RPG::V::TT',
		[
			{
				template => 'town/street/graffiti_dialog.html',
				params   => {},
				return_output => 1,
			}
		]
	);
	
	$c->forward('/panel/create_submit_dialog', 
		[
			{
				content => $message,
				submit_url => 'town/street/save_graffiti',
				dialog_title => 'Graffiti!',
			}
		],
	);
	
	$c->forward('character_list');
}

sub save_graffiti : Local {
    my ($self, $c) = @_;
    
    my $hs = HTML::Strip->new();
    
    my $clean_msg = $hs->parse( $c->req->param('message') );
        
    $c->model('DBIC::Town_History')->create(
        {
            town_id => $c->stash->{party_location}->town->id,
            day_id => $c->stash->{today}->id,
            type => 'graffiti',
            message => $clean_msg,           
        }
    );
    
    $c->forward('character_list');   
       
}

1;