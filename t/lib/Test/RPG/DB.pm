use strict;
use warnings;

package Test::RPG::DB;

use base qw(Test::RPG);

use RPG::Schema;

use Test::MockObject::Extends;

sub db_startup : Test(startup) {
    my $self = shift;

    return if $ENV{TEST_NO_DB};

	my $schema = RPG::Schema->connect( $self->{config}, @{$self->{config}->{'TestModel::DBIC'}{connect_info}}, );

    # Wrap in T::M::E so we can mock the config
    $schema = Test::MockObject::Extends->new($schema);
    $schema->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} }, 'log' => sub { $self->{mock_logger} } );

    #$schema->storage->dbh->begin_work;

    $self->{schema} = $schema;
}

sub aa_setup_context : Test(setup) {
    my $self = shift;

    $self->SUPER::aa_setup_context(@_);

    $self->{c}->mock(
        model => sub {
            my $resultset = $_[1];

            if ($resultset eq 'DBIC') {
                my $mock_model = Test::MockObject->new();
                $mock_model->set_always('schema', $self->{schema});
                return $mock_model;
            }

            $resultset =~ s/^DBIC:://;

            return $self->{mock_resultset}{$resultset} if $self->{mock_resultset}{$resultset};

            return $self->{schema}->resultset( $resultset );
        }
    );

    $self->{stash}{today} = Test::RPG::Builder::Day->build_day($self->{schema})
        unless $self->{dont_create_today};
}

sub roll_back : Test(teardown) {
    my $self = shift;

    if ($ENV{TEST_COMMIT}) {
        $self->{schema}->storage->dbh->commit;
    }
    else {
        $self->{schema}->storage->dbh->rollback;
    }
}

1;
