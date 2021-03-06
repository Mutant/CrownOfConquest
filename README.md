### Overview

Crown of Conquest is web-based RPG. See http://crownofconquest.com/ for the 'official' installation.

This README documents how to set up your own Crown server. Note, it's not trivial. You will probably do better if you have some experience deploying web applications.

This is also a hobby project, so the docs are not comprehensive. I'm happy to answer questions if I can though (see Contact below).

Also, things might not be as "generic" as they should be (e.g. currently the name is hard-coded). These problems can fairly easily be fixed if people are interested in
running their own instance of the game. So please let me know if you are and we'll talk.

### Installation
This has been tested on Ubuntu 16.04, but should work on most flavours of Linux.

* checkout source code into some dir (e.g. '$HOME/crown')
* install some packages:
  * libgd
  * cpanminus
  * gcc
  * mysql-server
  * libdbd-mysql-perl
* Make sure STRICT_TRANS_TABLES and ONLY_FULL_GROUP_BY mysql sql modes are turned off in the mysqlconfig
  On Ubuntu, this is best done by adding a file /etc/mysql/mysql.conf.d/custom.cnf
  with the following contents:
```
[mysqld]
sql_mode = "NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
```
* From the crown directory, run:
```
  sudo cpanm --instaldeps .
```
* Create the DB:
```
  mysqladmin create database crown
  mysql crown < crown/db/schema.sql
```
* Create a config file for your instance by copying rpg_template.yml to rpg_local.yml
  Check configuration settings look correct (particularly DB settings). This file shouldn't get checked in, as it likely contains private data (e.g. DB password).
* Generate a new world (this takes a while)
```
crown/db/create_world.pl
```
  See crown/db/world_gen/README for more details
* Initialize the world:
```
crown/db/world_gen/init_world.pl
```
  Note, this will take a *long* time to run. However, you can continue with the next steps. Some parts of the world will
  just be "empty" until it's done (e.g. shops, dungeons, monsters)
* Create log and var directories (by default, crown/log & crown/var) and make sure they're writeable by appropriate user
* Set some environment variables:
```
RPG_HOME=$HOME/crown
RPG_DEV=1
```
* Start up the server (this is just a 'dev' server for now - you will need to use Plack to start up the real server, see below).
```
perl crown/rpg_server.pl
```
* You should then be able to navigate to (e.g.) http://localhost:3000 and register an account
  Make sure you set url_root in rpg_local.ymp to the appropriate base url
* To get access to the admin panel, set the 'admin' flag on the Player record in the DB to true
  You'll then be able to nagivate to http://localhost:3000/admin
* Once the init_world.pl script is done, create a cron job for the 'new_day' script, it needs to run every 5 minutes, e.g.
```
*/5 * * * * RPG_HOME=$HOME/crown/ $HOME/crown/script/new_day.pl
```
### Using Plack/Starman

Full details are beyond the scope of this README, but there is an init script called script/plack.

Running this will start up the application in Starman. By default, it runs on port 8080. You will need
a webserver to act as the frontend (e.g. apache or nginx) and proxy to Starman.

Note, if RPG_DEV is set to true, the application server will serve all static content. For the Plack
setup, you probably don't want this (you want the webserver to serve content) so make sure RPG_DEV is
not set to true.

### Technical Notes

This application makes use of the following technologies:

* Perl 5.x (5.22 and upwards recommended)
* mysql 5.x
* Catalyst framework
* DBIx::Class
* Template Toolkit
* Dojo Toolkit
* Jquery

These were mostly chosen for reasons of convenience (i.e. mostly the fact that I knew them when the project started).
They have mostly held up well over time, probably with the exception of Dojo Toolkit (which is used a lot for the UI).
My preference would also be to move to Postgres, although the effort to do so is probably not worthwhile at this stage.

Also see t/README.md for docs on the test suite.

### License

The code (including Perl, Javascript and HTML Templates) in this application is distributed under GPLv3
(see LICENSE_GPL in the top-level directory).

The artwork & assets (including .png and .jpg files) in this application are distributed under CC BY-NC-SA 4.0
license. Attribution should be given as per the 'about' page (it's sufficient just to keep this page unmodified).
See https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

For source code: https://github.com/Mutant/CrownOfConquest

### Contact

Here are a few ways you can contact me:
* via the Crown of Conquest forums: http://forum.crownofconquest.com/
* via the Crown of Conquest feedback form: http://crownofconquest.com/player/contact
* via email: support AT crownofconquest DOT com

I will try to answer any (reasonable) questions, although can't promise I will respond quickly.
