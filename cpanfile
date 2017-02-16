requires 'Moose', '2.0802';
requires 'Catalyst', '5.90042';
requires 'DBIx::Class', '0.08250';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Log::Dispatch';
requires 'Catalyst::Model::DBIC::Schema';
requires 'Log::Dispatch::Config';
requires 'Catalyst::Plugin::Captcha';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::View::TT';
requires 'HTML::FillInForm';
requires 'Template::Provider::Preload';
requires 'JSON';
requires 'Math::Round';
requires 'Statistics::Basic';
requires 'DBIx::Class::Numeric';
requires 'DateTime';
requires 'Lingua::EN::Inflect';
requires 'Lingua::EN::Gender';
requires 'Games::Dice::Advanced';
requires 'AI::Pathfinding::AStar::Rectangle';
requires 'Array::Iterator::Circular';
requires 'DateTime::Format::HTTP';
requires 'Set::Object';
requires 'DateTime::Event::Cron::Quartz';
requires 'DateTime::Format::Duration';
requires 'MIME::Lite';
requires 'Digest::SHA1';
requires 'String::Random';
requires 'HTML::Strip';
requires 'DateTime::Format::MySQL';
requires 'HTML::BBCode';
requires 'Lingua::EN::Numbers::Ordinate';
requires 'Template::Plugin::Lingua::EN::Inflect';
requires 'DateTime::Cron::Simple';
requires 'DateTime::Format::DateParse';
requires 'Proc::PID::File';
requires 'Module::Pluggable::Dependency';
requires 'Tree::DAG_Node';
requires 'Text::Autoformat';
requires 'Email::Valid';
requires 'Starman';

on 'develop' => sub {
	requires 'Test::Class::Load';
	requires 'Test::MockObject::Extra';
	requires 'Sub::Override';
	requires 'Test::Resub';
	requires 'Test::MockModule';
};