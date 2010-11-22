use strict;
use warnings;

package Test::RPG::NewDay::Shop;

use base qw(Test::RPG::DB);

__PACKAGE__->runtests unless caller();

use Test::MockObject;
use Test::More;

use Test::RPG::Builder::Town;
use Test::RPG::Builder::Shop;

sub startup : Test(startup => 1) {
    my $self = shift;

    use_ok 'RPG::NewDay::Action::Shop';

}

sub test_alter_statuses_of_shops : Tests(8) {
    my $mock_shop = Test::MockObject->new();
    $mock_shop->set_true('status');
    $mock_shop->set_true('update');

    my $left = RPG::NewDay::Action::Shop::_alter_statuses_of_shops(
        number_to_change => 1,
        open_or_close    => 'Open',
        shops_by_status  => { Opening => [$mock_shop], },
    );

    is( $left, 0, "No shops left to open" );
    my ( $method, $args );
    ( $method, $args ) = $mock_shop->next_call();
    is( $method,    'status', "Status called" );
    is( $args->[1], 'Open',   "Shop opened" );

    ( $method, $args ) = $mock_shop->next_call();
    is( $method, 'update', "Update called" );

    $mock_shop->clear();

    $left = RPG::NewDay::Action::Shop::_alter_statuses_of_shops(
        number_to_change => 2,
        open_or_close    => 'Close',
        shops_by_status  => { Opening => [$mock_shop], },
    );

    is( $left, 1, "One shop left to change" );
    ( $method, $args ) = $mock_shop->next_call();
    is( $method,    'status',  "Status called" );
    is( $args->[1], 'Closing', "Shop opened" );

    ( $method, $args ) = $mock_shop->next_call();
    is( $method, 'update', "Update called" );

}

sub test_adjust_number_of_shops_already_closing_shop_is_closed : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, propserity => 50 );
    my $shop1 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );
    my $shop2 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id, status => 'Closing' );
    my $shop3 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );

    $self->{config}{prosperity_per_shop} = 25;

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema', $self->{schema} );
    $mock_context->set_always( 'config', $self->{config} );
    $mock_context->set_always( 'logger', $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    my $action = RPG::NewDay::Action::Shop->new( context => $mock_context );

    # WHEN
    $action->_adjust_number_of_shops($town);

    # THEN
    $shop1->discard_changes;
    is( $shop1->status, 'Open', "shop 1 still open" );

    $shop2->discard_changes;
    is( $shop2->status, 'Closed', "shop 2 now closed" );

    $shop3->discard_changes;
    is( $shop3->status, 'Open', "shop 3 still open" );
}

sub test_adjust_number_of_shops_opening_shop_opened : Tests(2) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, propserity => 50 );
    my $shop1 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );
    my $shop2 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id, status => 'Opening' );

    $self->{config}{prosperity_per_shop} = 25;

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema', $self->{schema} );
    $mock_context->set_always( 'config', $self->{config} );
    $mock_context->set_always( 'logger', $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    my $action = RPG::NewDay::Action::Shop->new( context => $mock_context );

    # WHEN
    $action->_adjust_number_of_shops($town);

    # THEN
    $shop1->discard_changes;
    is( $shop1->status, 'Open', "shop 1 still open" );

    $shop2->discard_changes;
    is( $shop1->status, 'Open', "shop 2 now opening" );
}

sub test_adjust_number_of_shops_new_shop_created : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, propserity => 50 );
    my $shop1 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );

    $self->{config}{prosperity_per_shop} = 25;
    $self->{config}->{data_file_path} = 'data/';

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema', $self->{schema} );
    $mock_context->set_always( 'config', $self->{config} );
    $mock_context->set_always( 'logger', $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    my $action = RPG::NewDay::Action::Shop->new( context => $mock_context );

    # WHEN
    $action->_adjust_number_of_shops($town);

    # THEN
    $town->discard_changes;
    my @shops = $town->shops;

    is( scalar @shops, 2, "Now 2 shops" );

    my ($orig_shop) = grep { $_->status eq 'Open' } @shops;
    is( $orig_shop->id, $shop1->id, "Shop 1 still open" );

    my ($new_shop) = grep { $_->status eq 'Opening' } @shops;
    is( defined $new_shop, 1, "Shop 2 is opening" );

}

sub test_adjust_number_of_shops_closed_shops_deleted : Tests(3) {
    my $self = shift;

    # GIVEN
    my $town = Test::RPG::Builder::Town->build_town( $self->{schema}, propserity => 50 );
    my $shop1 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );
    my $shop2 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id, status => 'Closed' );
    my $shop3 = Test::RPG::Builder::Shop->build_shop( $self->{schema}, town_id => $town->id );

    $self->{config}{prosperity_per_shop} = 25;

    my $mock_context = Test::MockObject->new();
    $mock_context->set_always( 'schema', $self->{schema} );
    $mock_context->set_always( 'config', $self->{config} );
    $mock_context->set_always( 'logger', $self->{mock_logger} );
    $mock_context->set_isa('RPG::NewDay::Context');

    my $action = RPG::NewDay::Action::Shop->new( context => $mock_context );

    # WHEN
    $action->_adjust_number_of_shops($town);

    # THEN
    $shop1->discard_changes;
    is( $shop1->status, 'Open', "shop 1 still open" );

    $shop2->discard_changes;
    is( $shop2->in_storage, 0, "shop 2 deleted" );

    $shop3->discard_changes;
    is( $shop3->status, 'Open', "shop 3 still open" );
}
