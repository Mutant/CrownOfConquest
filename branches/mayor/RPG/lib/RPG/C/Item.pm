package RPG::C::Item;

use strict;
use warnings;
use base 'Catalyst::Controller';

sub tooltip : Local {
    my ( $self, $c, $return_res ) = @_;

    my $item_type_id;
    my $item;

    if ( $c->req->param('item_id') ) {
        $item = $c->model('DBIC::Items')->find( { item_id => $c->req->param('item_id'), }, );

        $item_type_id = $item->item_type_id;
    }
    else {
        $item_type_id = $c->req->param('item_type_id');
    }

    my $item_type = $c->model('DBIC::Item_Type')->find(
        { item_type_id => $item_type_id, },
        {
            prefetch => [
                'category',
                { 'item_attributes' => 'item_attribute_name' },
            ],
        },
    );

    my $template = 'item/tooltip.html';

    my $item_category_file_name = 'item/type/' . lc $item_type->category->item_category . '.html';
    $item_category_file_name =~ s/ /_/g;
    
    $template = $item_category_file_name if -e $c->config->{root} . '/' . $item_category_file_name;

    my $res = $c->forward(
        'RPG::V::TT',
        [
            {
                template => $template,
                params   => {
                    item      => $item,
                    item_type => $item_type,
                },
                return_output => $return_res,
            }
        ]
    );
    
    return $res;
}

1;
