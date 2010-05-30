use strict;
use warnings;

package RPG::Schema::Item_Enchantments;

use base 'DBIx::Class';

use Carp;

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Item_Enchantments');

__PACKAGE__->add_columns(qw/item_enchantment_id enchantment_id item_id/);

__PACKAGE__->set_primary_key(qw/item_enchantment_id/);

__PACKAGE__->belongs_to( 'enchantment', 'RPG::Schema::Enchantments', 'enchantment_id');

__PACKAGE__->belongs_to( 'item', 'RPG::Schema::Items', 'item_id');

__PACKAGE__->has_many( 'variables', 'RPG::Schema::Item_Variable', 'item_enchantment_id');

sub insert {
	my ( $self, @args ) = @_;
	
	$self->next::method(@args);
	
	$self->_apply_role;
	
	$self->init_enchantment;
}

sub inflate_result {
    my $pkg = shift;

    my $self = $pkg->next::method(@_);

    $self->_apply_role;

    return $self;
}

sub _apply_role {
	my $self = shift;
	
	my $role = $self->get_role_name;
	$self->ensure_class_loaded($role);	
	$role->meta->apply($self);	
}

sub get_role_name {
	my $self = shift;
	
	my $name = $self->enchantment->enchantment_name;
	
	# Camel case-ify the name
	$name =~ s/(\b|_)(\w)/$1\u$2/g;	
	
	return 'RPG::Schema::Enchantments::' . $name;
}

1;