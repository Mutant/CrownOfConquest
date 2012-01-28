package RPG::C::Admin::Creature_Types;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Carp;

sub default : Path {
	my ($self, $c) = @_;
	
	$c->forward('list');
}

sub list : Local {
	my ($self, $c) = @_;

    my @cret_types = $c->model('DBIC::CreatureType')->search(
        {},
        {
            prefetch => 'category',
            order_by => $c->req->param('sort') // 'level',
        }
    );
    
	$c->forward('RPG::V::TT',
        [{
            template => 'admin/creature_types/list.html',
			params => {
				creature_types => \@cret_types,
			},
        }]
    );
}

sub edit : Local {
    my ($self, $c) = @_;
    
    my $creature_type = $c->model('DBIC::CreatureType')->find(
        {
            creature_type_id => $c->req->param('creature_type_id'),
        }
    );
    
    croak "Type not found!" unless $creature_type;
    
	$c->forward('RPG::V::TT',
        [{
            template => 'admin/creature_types/edit.html',
			params => {
				creature_type => $creature_type,
			},
        }]
    );
}

sub update : Local {
    my ($self, $c) = @_;
    
    my $creature_type = $c->model('DBIC::CreatureType')->find(
        {
            creature_type_id => $c->req->param('creature_type_id'),
        }
    );
    
    croak "Type not found!" unless $creature_type;
    
    $creature_type->creature_type($c->req->param('creature_type'));
    $creature_type->level($c->req->param('level'));
    $creature_type->fire($c->req->param('fire'));
    $creature_type->ice($c->req->param('ice'));
    $creature_type->hire_cost($c->req->param('hire_cost'));
    $creature_type->maint_cost($c->req->param('maint_cost'));
    $creature_type->weapon($c->req->param('weapon'));
    $creature_type->update;
    
    $c->forward('list');
}

1;