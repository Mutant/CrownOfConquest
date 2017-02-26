# Tests

This directory contains tests for the game. They are mostly unit/DB integration tests.

There are a few quirks and gotchas, which I'll try to document here. Coverage is reasonable (but can always be expanded of course).

## Database

Most tests require a database. This is configured in the config file under 'TestModel::DBIC'. See rpg_dev.yml for an example.

Note, the tests (by default) do not commit anything. Instead, a rollback is done at the end of each test. More info below.


## Running

To run the tests, do:

```
t/run_tests.pl --refresh-schema
```

This will rebuild the test schema from your existing DB. You only need to do this if the schema has changed, or if your test DB needs to be cleaned for some reason. After this, you can drop the --refresh-schema option.

(TODO: it would be nice if the test schema refreshed from db/schema.sql instead of grabbing it from an existing DB. However, schema.sql has more data in it than the tests expect, so some tests would have to be tweaked to make it work).

### More fine-grained control

There are a few ways to run a subset of the tests. First, the tests are broken down into some broad categories, as per the scripts under t/bin. You can run these directly, e.g.

```
t/bin/combat.t
```

It can be useful to set TEST_VERBOSE=1 when doing this to see which tests are outputting which TAP. (This is a [Test::Class](https://metacpan.org/pod/Test::Class) parameter).

If you want to run an entire test class, you can pass it as a parameter to the test script, e.g.

```
t/bin/combat.t Test::RPG::Combat::CreatureWildernessBattle
```

More than 1 test class can be passed.

You can also run individual tests (again as per Test::Class) by setting TEST_METHOD.

## Debugging

To debug broken tests, it's usually best to run an individual test (with TEST_METHOD as above). There are then a couple of options to help you debug:

* DBIC_TRACE - set this to true to output the SQL the test/code is executing. This is usually a lot, but can help to figure out what's going on
* TEST_COMMIT - set this to true to make the test commit to the DB rather than rollback. You can then inspect what is in the DB after the test has run. The next test run will require --refresh-schema to be done. (Unfortunately this can only be done via run_tests.pl at the moment).

Logging will also go to the normal place, which can also be useful for debugging purposes. (TODO: it would be nice to have an option to make this go to STDERR).

## Mocking

The tests make extensive (arguably too much) use of mock objects. One of the more important ones is mocking of Games::Dice::Advanced, which is used throughout the code to generate random numbers. In some cases, tests need to mock these rolls to ensure consistent results.

The base test class (Test::RPG) has a mock_dice method. This replaces Game::Dice::Advanced, and returns either $self->{roll_result} for every roll, or (if set) each entry of the array ref in $self->{rolls}. There is also a unmock_dice method, although this is called after each test method, so shouldn't need to be called manually.

To help debug any issues with this, there is a MOCK_DICE_DEBUG env var, which will output some stack traces if set to true.

