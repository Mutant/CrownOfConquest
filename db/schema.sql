-- MySQL dump 10.13  Distrib 5.7.17, for Linux (x86_64)
--
-- Host: localhost    Database: game
-- ------------------------------------------------------
-- Server version	5.7.17-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `Announcement`
--

DROP TABLE IF EXISTS `Announcement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Announcement` (
  `announcement_id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `announcement` text NOT NULL,
  `date` datetime NOT NULL,
  PRIMARY KEY (`announcement_id`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Announcement_Player`
--

DROP TABLE IF EXISTS `Announcement_Player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Announcement_Player` (
  `announcement_id` int(11) NOT NULL,
  `player_id` int(11) NOT NULL,
  `viewed` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`announcement_id`,`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Battle_Participant`
--

DROP TABLE IF EXISTS `Battle_Participant`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Battle_Participant` (
  `party_id` int(11) NOT NULL,
  `battle_id` int(11) NOT NULL,
  `last_submitted_round` int(11) NOT NULL,
  `online` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`party_id`,`battle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Bomb`
--

DROP TABLE IF EXISTS `Bomb`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Bomb` (
  `bomb_id` int(11) NOT NULL AUTO_INCREMENT,
  `land_id` int(11) DEFAULT NULL,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  `planted` datetime NOT NULL,
  `party_id` int(11) NOT NULL,
  `level` int(11) NOT NULL,
  `detonated` datetime DEFAULT NULL,
  PRIMARY KEY (`bomb_id`),
  KEY `land_id_idx` (`land_id`),
  KEY `d_grid_idx` (`dungeon_grid_id`),
  KEY `party_id_idx` (`party_id`),
  KEY `planted_idx` (`planted`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Building`
--

DROP TABLE IF EXISTS `Building`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Building` (
  `building_id` int(11) NOT NULL AUTO_INCREMENT,
  `land_id` int(11) NOT NULL,
  `building_type_id` int(11) NOT NULL,
  `owner_id` int(11) NOT NULL,
  `owner_type` varchar(20) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  `clay_needed` int(11) DEFAULT NULL,
  `stone_needed` int(11) DEFAULT '0',
  `wood_needed` int(11) DEFAULT '0',
  `iron_needed` int(11) DEFAULT '0',
  `labor_needed` int(11) DEFAULT '0',
  PRIMARY KEY (`building_id`),
  KEY `land_id_idx` (`land_id`),
  KEY `building_type_idx` (`building_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1233 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Building_Type`
--

DROP TABLE IF EXISTS `Building_Type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Building_Type` (
  `building_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `class` int(11) DEFAULT '0',
  `level` int(11) DEFAULT '0',
  `defense_factor` int(11) DEFAULT '0',
  `commerce_factor` int(11) DEFAULT '0',
  `clay_needed` int(11) DEFAULT NULL,
  `stone_needed` int(11) DEFAULT NULL,
  `wood_needed` int(11) DEFAULT NULL,
  `iron_needed` int(11) DEFAULT NULL,
  `labor_needed` int(11) DEFAULT NULL,
  `labor_to_raze` int(11) DEFAULT NULL,
  `visibility` int(11) NOT NULL DEFAULT '1',
  `image` varchar(255) NOT NULL,
  `constr_image` varchar(255) NOT NULL,
  `land_claim_range` int(11) NOT NULL DEFAULT '1',
  `max_upgrade_level` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`building_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Building_Upgrade`
--

DROP TABLE IF EXISTS `Building_Upgrade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Building_Upgrade` (
  `upgrade_id` int(11) NOT NULL AUTO_INCREMENT,
  `building_id` int(11) NOT NULL,
  `type_id` int(11) NOT NULL,
  `level` int(11) NOT NULL DEFAULT '0',
  `damage` int(11) NOT NULL DEFAULT '0',
  `damage_last_done` datetime DEFAULT NULL,
  PRIMARY KEY (`upgrade_id`),
  UNIQUE KEY `unique_type_building_idx` (`type_id`,`building_id`),
  KEY `building_id_idx` (`building_id`),
  KEY `type_id_idx` (`type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1983 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Building_Upgrade_Type`
--

DROP TABLE IF EXISTS `Building_Upgrade_Type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Building_Upgrade_Type` (
  `type_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) NOT NULL,
  `modifier_per_level` int(11) NOT NULL,
  `modifier_label` varchar(20) DEFAULT NULL,
  `description` varchar(2000) NOT NULL,
  `base_gold_cost` int(11) NOT NULL,
  `base_wood_cost` int(11) NOT NULL,
  `base_clay_cost` int(11) NOT NULL,
  `base_iron_cost` int(11) NOT NULL,
  `base_stone_cost` int(11) NOT NULL,
  `base_turn_cost` int(11) NOT NULL,
  PRIMARY KEY (`type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Capital_History`
--

DROP TABLE IF EXISTS `Capital_History`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Capital_History` (
  `capital_id` int(11) NOT NULL AUTO_INCREMENT,
  `kingdom_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `start_date` int(11) NOT NULL,
  `end_date` int(11) DEFAULT NULL,
  PRIMARY KEY (`capital_id`) USING BTREE,
  KEY `kingdom_id_idx` (`kingdom_id`)
) ENGINE=InnoDB AUTO_INCREMENT=98 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Character`
--

DROP TABLE IF EXISTS `Character`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Character` (
  `character_id` int(11) NOT NULL AUTO_INCREMENT,
  `character_name` varchar(255) NOT NULL,
  `xp` bigint(20) NOT NULL,
  `strength` int(11) NOT NULL,
  `intelligence` int(11) NOT NULL,
  `agility` int(11) NOT NULL,
  `divinity` int(11) NOT NULL,
  `constitution` int(11) NOT NULL,
  `hit_points` int(11) NOT NULL,
  `level` int(11) NOT NULL,
  `max_hit_points` int(11) NOT NULL,
  `party_id` int(11) DEFAULT NULL,
  `class_id` int(11) DEFAULT NULL,
  `race_id` int(11) DEFAULT NULL,
  `party_order` int(11) DEFAULT '0',
  `last_combat_action` varchar(30) NOT NULL DEFAULT 'Attack',
  `spell_points` int(11) NOT NULL DEFAULT '0',
  `stat_points` int(11) NOT NULL DEFAULT '0',
  `town_id` int(11) DEFAULT NULL,
  `last_combat_param1` varchar(255) NOT NULL,
  `last_combat_param2` varchar(255) NOT NULL,
  `gender` varchar(50) NOT NULL DEFAULT 'male',
  `garrison_id` int(11) DEFAULT NULL,
  `offline_cast_chance` int(11) NOT NULL DEFAULT '35',
  `online_cast_chance` int(11) NOT NULL DEFAULT '0',
  `creature_group_id` bigint(20) DEFAULT NULL,
  `mayor_of` bigint(20) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `status_context` bigint(20) DEFAULT NULL,
  `encumbrance` int(11) NOT NULL DEFAULT '0',
  `strength_bonus` int(11) NOT NULL DEFAULT '0',
  `intelligence_bonus` int(11) NOT NULL DEFAULT '0',
  `agility_bonus` int(11) NOT NULL DEFAULT '0',
  `divinity_bonus` int(11) NOT NULL DEFAULT '0',
  `constitution_bonus` int(11) NOT NULL DEFAULT '0',
  `movement_factor_bonus` int(11) NOT NULL DEFAULT '0',
  `attack_factor` int(11) NOT NULL DEFAULT '0',
  `defence_factor` int(11) NOT NULL DEFAULT '0',
  `back_rank_penalty` int(11) NOT NULL,
  `skill_points` int(11) NOT NULL DEFAULT '0',
  `resist_fire` int(11) NOT NULL DEFAULT '0',
  `resist_fire_bonus` int(11) NOT NULL DEFAULT '0',
  `resist_ice` int(11) NOT NULL DEFAULT '0',
  `resist_ice_bonus` int(11) NOT NULL DEFAULT '0',
  `resist_poison` int(11) NOT NULL DEFAULT '0',
  `resist_poison_bonus` int(11) NOT NULL DEFAULT '0',
  `has_usable_actions_combat` int(11) NOT NULL DEFAULT '0',
  `has_usable_actions_non_combat` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`character_id`),
  KEY `race` (`race_id`),
  KEY `class` (`class_id`),
  KEY `party_id_idx` (`party_id`),
  KEY `cg_id_idx` (`creature_group_id`),
  KEY `mayor_idx` (`mayor_of`),
  KEY `status_context_id` (`status`,`status_context`)
) ENGINE=InnoDB AUTO_INCREMENT=115679 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Character_Effect`
--

DROP TABLE IF EXISTS `Character_Effect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Character_Effect` (
  `character_id` int(11) NOT NULL,
  `effect_id` int(11) NOT NULL,
  PRIMARY KEY (`character_id`,`effect_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Character_History`
--

DROP TABLE IF EXISTS `Character_History`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Character_History` (
  `history_id` int(11) NOT NULL AUTO_INCREMENT,
  `event` varchar(4000) COLLATE latin1_general_ci DEFAULT NULL,
  `day_id` int(11) DEFAULT NULL,
  `character_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`history_id`)
) ENGINE=InnoDB AUTO_INCREMENT=323865 DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Character_Skill`
--

DROP TABLE IF EXISTS `Character_Skill`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Character_Skill` (
  `character_id` int(11) NOT NULL,
  `skill_id` int(11) NOT NULL,
  `level` int(11) NOT NULL,
  PRIMARY KEY (`character_id`,`skill_id`),
  KEY `char_id` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Class`
--

DROP TABLE IF EXISTS `Class`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Class` (
  `class_id` int(11) NOT NULL AUTO_INCREMENT,
  `class_name` varchar(255) NOT NULL,
  PRIMARY KEY (`class_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Combat_Log`
--

DROP TABLE IF EXISTS `Combat_Log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Combat_Log` (
  `combat_log_id` int(11) NOT NULL AUTO_INCREMENT,
  `encounter_started` datetime DEFAULT NULL,
  `combat_initiated_by` varchar(255) NOT NULL,
  `rounds` int(11) NOT NULL,
  `opponent_2_deaths` int(11) NOT NULL DEFAULT '0',
  `opponent_1_deaths` int(11) NOT NULL DEFAULT '0',
  `total_opponent_2_damage` int(11) NOT NULL DEFAULT '0',
  `total_opponent_1_damage` int(11) NOT NULL DEFAULT '0',
  `xp_awarded` int(11) NOT NULL,
  `spells_cast` int(11) NOT NULL,
  `gold_found` int(11) NOT NULL,
  `outcome` varchar(30) NOT NULL,
  `encounter_ended` datetime DEFAULT NULL,
  `opponent_1_id` int(11) NOT NULL,
  `opponent_2_id` int(11) NOT NULL,
  `land_id` int(11) DEFAULT NULL,
  `opponent_1_level` int(11) NOT NULL DEFAULT '0',
  `opponent_2_level` int(11) NOT NULL DEFAULT '0',
  `game_day` int(11) NOT NULL,
  `opponent_2_flee_attempts` int(11) DEFAULT NULL,
  `opponent_1_flee_attempts` int(11) DEFAULT NULL,
  `opponent_1_type` varchar(50) NOT NULL DEFAULT 'party',
  `opponent_2_type` varchar(50) NOT NULL DEFAULT 'creature_group',
  `session` text,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`combat_log_id`),
  KEY `log_count_idx` (`opponent_1_id`,`opponent_2_id`,`opponent_1_type`,`opponent_2_type`,`encounter_ended`),
  KEY `encounter_ended` (`encounter_ended`),
  KEY `opp_id_and_type` (`opponent_1_id`,`opponent_2_id`,`opponent_1_type`,`opponent_2_type`),
  KEY `encounter_started` (`encounter_started`)
) ENGINE=InnoDB AUTO_INCREMENT=1950474 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Combat_Log_Messages`
--

DROP TABLE IF EXISTS `Combat_Log_Messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Combat_Log_Messages` (
  `log_message_id` int(11) NOT NULL AUTO_INCREMENT,
  `round` int(11) DEFAULT NULL,
  `message` text,
  `combat_log_id` int(11) NOT NULL,
  `opponent_number` int(11) NOT NULL,
  PRIMARY KEY (`log_message_id`),
  KEY `fk_Combat_Log_Messages_Combat_Log1` (`combat_log_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6669021 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Conf`
--

DROP TABLE IF EXISTS `Conf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Conf` (
  `conf_name` varchar(1000) NOT NULL,
  `conf_value` varchar(1000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature`
--

DROP TABLE IF EXISTS `Creature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature` (
  `creature_id` int(11) NOT NULL AUTO_INCREMENT,
  `creature_group_id` int(11) NOT NULL,
  `creature_type_id` int(11) NOT NULL,
  `hit_points_current` int(11) NOT NULL,
  `hit_points_max` int(11) NOT NULL,
  `group_order` int(11) NOT NULL,
  `weapon` varchar(255) NOT NULL,
  PRIMARY KEY (`creature_id`),
  KEY `cg_id_idx` (`creature_group_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7836803 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Category`
--

DROP TABLE IF EXISTS `Creature_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Category` (
  `creature_category_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `dungeon_group_img` varchar(50) DEFAULT NULL,
  `standard` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`creature_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Effect`
--

DROP TABLE IF EXISTS `Creature_Effect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Effect` (
  `creature_id` int(11) NOT NULL,
  `effect_id` int(11) NOT NULL,
  PRIMARY KEY (`creature_id`,`effect_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Group`
--

DROP TABLE IF EXISTS `Creature_Group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Group` (
  `creature_group_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `land_id` int(11) DEFAULT NULL,
  `trait_id` int(11) DEFAULT NULL,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`creature_group_id`),
  KEY `land_id_idx` (`land_id`),
  KEY `d_grid_idx` (`dungeon_grid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1507777 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Orb`
--

DROP TABLE IF EXISTS `Creature_Orb`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Orb` (
  `creature_orb_id` int(11) NOT NULL AUTO_INCREMENT,
  `level` int(11) NOT NULL,
  `land_id` int(11) DEFAULT NULL,
  `name` varchar(100) COLLATE latin1_general_ci NOT NULL,
  PRIMARY KEY (`creature_orb_id`),
  KEY `land_id` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6563 DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Spell`
--

DROP TABLE IF EXISTS `Creature_Spell`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Spell` (
  `creature_spell_id` int(11) NOT NULL AUTO_INCREMENT,
  `spell_id` int(11) NOT NULL,
  `creature_type_id` int(11) NOT NULL,
  PRIMARY KEY (`creature_spell_id`),
  KEY `spell_idx` (`spell_id`),
  KEY `type_id` (`creature_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Creature_Type`
--

DROP TABLE IF EXISTS `Creature_Type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Creature_Type` (
  `creature_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `creature_type` varchar(255) NOT NULL,
  `level` int(11) NOT NULL,
  `weapon` varchar(255) NOT NULL,
  `fire` int(11) NOT NULL,
  `ice` int(11) NOT NULL,
  `poison` int(11) NOT NULL,
  `creature_category_id` int(11) NOT NULL,
  `maint_cost` int(11) DEFAULT NULL,
  `hire_cost` int(11) DEFAULT NULL,
  `image` varchar(40) DEFAULT NULL,
  `rare` tinyint(4) NOT NULL DEFAULT '0',
  `special_damage` varchar(40) DEFAULT NULL,
  PRIMARY KEY (`creature_type_id`),
  KEY `category_fk` (`creature_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Crown_History`
--

DROP TABLE IF EXISTS `Crown_History`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Crown_History` (
  `history_id` int(11) NOT NULL AUTO_INCREMENT,
  `day_id` int(11) NOT NULL,
  `message` varchar(5000) NOT NULL,
  PRIMARY KEY (`history_id`),
  KEY `day_id_idx` (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Day`
--

DROP TABLE IF EXISTS `Day`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Day` (
  `day_id` int(11) NOT NULL AUTO_INCREMENT,
  `day_number` int(11) NOT NULL,
  `game_year` int(11) NOT NULL,
  `date_started` datetime NOT NULL,
  `turns_used` bigint(20) NOT NULL DEFAULT '0',
  PRIMARY KEY (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3041 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Day_Log`
--

DROP TABLE IF EXISTS `Day_Log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Day_Log` (
  `day_log_id` int(11) NOT NULL AUTO_INCREMENT,
  `log` varchar(4000) NOT NULL,
  `party_id` int(11) DEFAULT NULL,
  `displayed` tinyint(4) NOT NULL DEFAULT '0',
  `day_id` int(11) NOT NULL,
  PRIMARY KEY (`day_log_id`),
  KEY `party_id_dx` (`party_id`),
  KEY `day_id_idx` (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1293605 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Day_Stats`
--

DROP TABLE IF EXISTS `Day_Stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Day_Stats` (
  `date` date NOT NULL,
  `visitors` int(11) NOT NULL,
  PRIMARY KEY (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Door`
--

DROP TABLE IF EXISTS `Door`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Door` (
  `door_id` int(11) NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  `position_id` int(11) NOT NULL,
  `type` varchar(255) NOT NULL DEFAULT 'standard',
  `state` varchar(255) NOT NULL DEFAULT 'closed',
  PRIMARY KEY (`door_id`),
  KEY `dungeon_grid_idx` (`dungeon_grid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=259055 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon`
--

DROP TABLE IF EXISTS `Dungeon`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon` (
  `dungeon_id` int(11) NOT NULL AUTO_INCREMENT,
  `level` int(11) NOT NULL,
  `land_id` int(11) DEFAULT NULL,
  `name` varchar(255) NOT NULL,
  `type` varchar(255) NOT NULL,
  `tileset` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`dungeon_id`),
  KEY `land_id_idx` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1482 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Grid`
--

DROP TABLE IF EXISTS `Dungeon_Grid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Grid` (
  `dungeon_grid_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `x` int(11) NOT NULL,
  `y` int(11) NOT NULL,
  `dungeon_room_id` int(11) NOT NULL,
  `stairs_up` tinyint(4) NOT NULL DEFAULT '0',
  `stairs_down` tinyint(4) NOT NULL DEFAULT '0',
  `tile` tinyint(4) NOT NULL DEFAULT '1',
  `overlay` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`dungeon_grid_id`),
  KEY `x_y_room_idx` (`x`,`y`,`dungeon_room_id`) USING BTREE,
  KEY `room_idx` (`dungeon_room_id`)
) ENGINE=InnoDB AUTO_INCREMENT=882443 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Position`
--

DROP TABLE IF EXISTS `Dungeon_Position`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Position` (
  `position_id` int(11) NOT NULL AUTO_INCREMENT,
  `position` varchar(30) NOT NULL,
  PRIMARY KEY (`position_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Room`
--

DROP TABLE IF EXISTS `Dungeon_Room`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Room` (
  `dungeon_room_id` int(11) NOT NULL AUTO_INCREMENT,
  `dungeon_id` int(11) NOT NULL,
  `floor` int(11) NOT NULL DEFAULT '1',
  `special_room_id` int(11) DEFAULT NULL,
  `tileset` varchar(100) NOT NULL,
  PRIMARY KEY (`dungeon_room_id`),
  KEY `dungeon_idx` (`dungeon_id`)
) ENGINE=InnoDB AUTO_INCREMENT=105419 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Room_Param`
--

DROP TABLE IF EXISTS `Dungeon_Room_Param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Room_Param` (
  `dungeon_room_param_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `param_name` varchar(100) NOT NULL,
  `param_value` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`dungeon_room_param_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Sector_Path`
--

DROP TABLE IF EXISTS `Dungeon_Sector_Path`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Sector_Path` (
  `sector_id` int(11) NOT NULL,
  `has_path_to` int(11) NOT NULL,
  `distance` int(11) NOT NULL,
  PRIMARY KEY (`sector_id`,`has_path_to`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Sector_Path_Door`
--

DROP TABLE IF EXISTS `Dungeon_Sector_Path_Door`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Sector_Path_Door` (
  `sector_id` int(11) NOT NULL,
  `has_path_to` int(11) NOT NULL,
  `door_id` int(11) NOT NULL,
  PRIMARY KEY (`sector_id`,`has_path_to`,`door_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Special_Room`
--

DROP TABLE IF EXISTS `Dungeon_Special_Room`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Special_Room` (
  `special_room_id` int(11) NOT NULL AUTO_INCREMENT,
  `room_type` varchar(200) NOT NULL,
  PRIMARY KEY (`special_room_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Teleporter`
--

DROP TABLE IF EXISTS `Dungeon_Teleporter`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Teleporter` (
  `teleporter_id` int(11) NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` int(11) NOT NULL,
  `destination_id` int(11) DEFAULT NULL,
  `invisible` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`teleporter_id`),
  KEY `dungeon_fk` (`dungeon_grid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16410 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Dungeon_Wall`
--

DROP TABLE IF EXISTS `Dungeon_Wall`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Dungeon_Wall` (
  `wall_id` int(11) NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  `position_id` int(11) NOT NULL,
  PRIMARY KEY (`wall_id`),
  KEY `dungeon_grid_idx` (`dungeon_grid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1570534 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Effect`
--

DROP TABLE IF EXISTS `Effect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Effect` (
  `effect_id` int(11) NOT NULL AUTO_INCREMENT,
  `effect_name` varchar(80) NOT NULL,
  `time_left` int(11) NOT NULL,
  `modifier` decimal(10,2) NOT NULL,
  `modified_stat` varchar(80) NOT NULL,
  `combat` tinyint(4) NOT NULL,
  `time_type` varchar(50) NOT NULL DEFAULT 'round',
  PRIMARY KEY (`effect_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3901240 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Election`
--

DROP TABLE IF EXISTS `Election`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Election` (
  `election_id` int(11) NOT NULL AUTO_INCREMENT,
  `town_id` int(11) NOT NULL,
  `scheduled_day` int(11) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Open',
  PRIMARY KEY (`election_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7580 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Election_Candidate`
--

DROP TABLE IF EXISTS `Election_Candidate`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Election_Candidate` (
  `election_id` int(11) NOT NULL,
  `character_id` int(11) NOT NULL,
  `campaign_spend` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Enchantment_Item_Category`
--

DROP TABLE IF EXISTS `Enchantment_Item_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Enchantment_Item_Category` (
  `enchantment_id` int(11) NOT NULL,
  `item_category_id` int(11) NOT NULL,
  PRIMARY KEY (`enchantment_id`,`item_category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Enchantments`
--

DROP TABLE IF EXISTS `Enchantments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Enchantments` (
  `enchantment_id` int(11) NOT NULL AUTO_INCREMENT,
  `enchantment_name` varchar(100) NOT NULL,
  `must_be_equipped` tinyint(4) NOT NULL DEFAULT '0',
  `one_per_item` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`enchantment_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Equip_Place_Category`
--

DROP TABLE IF EXISTS `Equip_Place_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Equip_Place_Category` (
  `equip_place_id` int(11) NOT NULL,
  `item_category_id` int(11) NOT NULL,
  PRIMARY KEY (`equip_place_id`,`item_category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Equip_Places`
--

DROP TABLE IF EXISTS `Equip_Places`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Equip_Places` (
  `equip_place_id` int(11) NOT NULL AUTO_INCREMENT,
  `equip_place_name` varchar(255) NOT NULL,
  `height` int(11) NOT NULL DEFAULT '1',
  `width` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`equip_place_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Game_Vars`
--

DROP TABLE IF EXISTS `Game_Vars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Game_Vars` (
  `game_var_id` int(11) NOT NULL AUTO_INCREMENT,
  `game_var_name` varchar(60) NOT NULL,
  `game_var_value` varchar(60) NOT NULL,
  PRIMARY KEY (`game_var_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Garrison`
--

DROP TABLE IF EXISTS `Garrison`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Garrison` (
  `garrison_id` int(11) NOT NULL AUTO_INCREMENT,
  `land_id` int(11) DEFAULT NULL,
  `party_id` int(11) NOT NULL,
  `creature_attack_mode` varchar(45) DEFAULT NULL,
  `party_attack_mode` varchar(45) DEFAULT NULL,
  `flee_threshold` int(11) DEFAULT '70',
  `in_combat_with` int(11) DEFAULT NULL,
  `gold` int(11) NOT NULL DEFAULT '0',
  `name` varchar(100) DEFAULT NULL,
  `attack_parties_from_kingdom` tinyint(4) NOT NULL DEFAULT '0',
  `attack_friendly_parties` tinyint(4) NOT NULL DEFAULT '0',
  `established` datetime NOT NULL,
  `claim_land_order` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`garrison_id`),
  KEY `fk_Garrison_Land1` (`land_id`),
  KEY `fk_Garrison_Party1` (`party_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1818 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Garrison_Messages`
--

DROP TABLE IF EXISTS `Garrison_Messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Garrison_Messages` (
  `garrison_message_id` int(11) NOT NULL AUTO_INCREMENT,
  `message` text NOT NULL,
  `garrison_id` int(11) NOT NULL,
  `day_id` int(11) NOT NULL,
  PRIMARY KEY (`garrison_message_id`),
  KEY `fk_Garrison_Messages_Garrison1` (`garrison_id`),
  KEY `fk_Garrison_Messages_Day1` (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=380145 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Global_News`
--

DROP TABLE IF EXISTS `Global_News`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Global_News` (
  `news_id` int(11) NOT NULL AUTO_INCREMENT,
  `day_id` int(11) NOT NULL,
  `message` varchar(5000) NOT NULL,
  PRIMARY KEY (`news_id`),
  KEY `day_id_idx` (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5850 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Grave`
--

DROP TABLE IF EXISTS `Grave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Grave` (
  `grave_id` int(11) NOT NULL AUTO_INCREMENT,
  `character_name` varchar(200) COLLATE latin1_general_ci NOT NULL,
  `epitaph` varchar(1000) COLLATE latin1_general_ci NOT NULL,
  `day_created` int(11) NOT NULL,
  `land_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`grave_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1980 DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Attribute`
--

DROP TABLE IF EXISTS `Item_Attribute`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Attribute` (
  `item_attribute_id` int(11) NOT NULL AUTO_INCREMENT,
  `item_attribute_value` varchar(255) NOT NULL,
  `item_type_id` int(11) NOT NULL,
  `item_attribute_name_id` int(11) NOT NULL,
  PRIMARY KEY (`item_attribute_id`),
  KEY `item_attr_name_id` (`item_attribute_name_id`),
  KEY `item_type_id` (`item_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=119 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Attribute_Name`
--

DROP TABLE IF EXISTS `Item_Attribute_Name`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Attribute_Name` (
  `item_attribute_name_id` int(11) NOT NULL AUTO_INCREMENT,
  `item_attribute_name` varchar(255) NOT NULL,
  `item_category_id` int(11) DEFAULT NULL,
  `value_type` varchar(255) NOT NULL DEFAULT 'numeric',
  `property_category_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`item_attribute_name_id`),
  KEY `item_attr` (`item_attribute_name`)
) ENGINE=InnoDB AUTO_INCREMENT=36 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Category`
--

DROP TABLE IF EXISTS `Item_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Category` (
  `item_category_id` int(11) NOT NULL AUTO_INCREMENT,
  `item_category` varchar(255) NOT NULL,
  `super_category_id` int(11) DEFAULT NULL,
  `hidden` tinyint(4) NOT NULL DEFAULT '0',
  `auto_add_to_shop` tinyint(4) NOT NULL DEFAULT '1',
  `findable` tinyint(4) NOT NULL DEFAULT '1',
  `delete_when_sold_to_shop` tinyint(4) NOT NULL DEFAULT '0',
  `always_enchanted` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`item_category_id`),
  KEY `cat_name` (`item_category`),
  KEY `super_category_id` (`super_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Enchantments`
--

DROP TABLE IF EXISTS `Item_Enchantments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Enchantments` (
  `item_enchantment_id` int(11) NOT NULL AUTO_INCREMENT,
  `enchantment_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  PRIMARY KEY (`item_enchantment_id`),
  KEY `fk_Enchantments_has_Items_Enchantments1` (`enchantment_id`),
  KEY `fk_Enchantments_has_Items_Items1` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=348704 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Grid`
--

DROP TABLE IF EXISTS `Item_Grid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Grid` (
  `item_grid_id` int(11) NOT NULL AUTO_INCREMENT,
  `owner_id` int(11) NOT NULL,
  `owner_type` varchar(50) NOT NULL,
  `item_id` int(11) DEFAULT NULL,
  `tab` varchar(100) NOT NULL DEFAULT '1',
  `x` int(11) NOT NULL,
  `y` int(11) NOT NULL,
  `start_sector` tinyint(4) DEFAULT NULL,
  `quantity` int(11) DEFAULT NULL,
  PRIMARY KEY (`item_grid_id`),
  KEY `owner_idx` (`owner_id`,`owner_type`),
  KEY `item_id_idx` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=112851934 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Property_Category`
--

DROP TABLE IF EXISTS `Item_Property_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Property_Category` (
  `property_category_id` int(11) NOT NULL AUTO_INCREMENT,
  `category_name` varchar(255) NOT NULL,
  PRIMARY KEY (`property_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Type`
--

DROP TABLE IF EXISTS `Item_Type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Type` (
  `item_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `item_type` varchar(255) NOT NULL,
  `item_category_id` int(11) DEFAULT NULL,
  `base_cost` int(11) NOT NULL,
  `prevalence` int(11) NOT NULL,
  `weight` decimal(10,2) NOT NULL,
  `image` varchar(255) DEFAULT NULL,
  `usable` tinyint(4) NOT NULL DEFAULT '0',
  `height` int(11) NOT NULL DEFAULT '1',
  `width` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`item_type_id`),
  KEY `item_category` (`item_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=73 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Variable`
--

DROP TABLE IF EXISTS `Item_Variable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Variable` (
  `item_variable_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `item_variable_value` varchar(100) NOT NULL,
  `item_id` int(11) DEFAULT NULL,
  `max_value` int(11) DEFAULT NULL,
  `item_variable_name_id` int(11) DEFAULT NULL,
  `item_enchantment_id` int(11) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`item_variable_id`),
  KEY `item_id_idx` (`item_id`),
  KEY `item_ench_idx` (`item_enchantment_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3400336 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Variable_Name`
--

DROP TABLE IF EXISTS `Item_Variable_Name`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Variable_Name` (
  `item_variable_name_id` int(11) NOT NULL AUTO_INCREMENT,
  `item_variable_name` varchar(255) NOT NULL,
  `item_category_id` int(11) DEFAULT NULL,
  `property_category_id` int(11) DEFAULT NULL,
  `create_on_insert` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (`item_variable_name_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Item_Variable_Params`
--

DROP TABLE IF EXISTS `Item_Variable_Params`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Item_Variable_Params` (
  `item_variable_param_id` int(11) NOT NULL AUTO_INCREMENT,
  `keep_max` tinyint(4) NOT NULL,
  `min_value` int(11) NOT NULL,
  `max_value` int(11) NOT NULL,
  `item_type_id` int(11) NOT NULL,
  `item_variable_name_id` int(11) NOT NULL,
  `special` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`item_variable_param_id`)
) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Items`
--

DROP TABLE IF EXISTS `Items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Items` (
  `item_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `magic_modifier` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `item_type_id` int(11) DEFAULT NULL,
  `character_id` int(11) DEFAULT NULL,
  `equip_place_id` int(11) DEFAULT NULL,
  `shop_id` int(11) DEFAULT NULL,
  `treasure_chest_id` int(11) DEFAULT NULL,
  `garrison_id` int(11) DEFAULT NULL,
  `land_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`item_id`),
  UNIQUE KEY `unique_equip_slot` (`character_id`,`equip_place_id`),
  KEY `item_type_id` (`item_type_id`),
  KEY `shop_id_index` (`shop_id`),
  KEY `character_id` (`character_id`),
  KEY `equip_place_id` (`equip_place_id`),
  KEY `land_id` (`land_id`),
  KEY `chest_id_idx` (`treasure_chest_id`),
  KEY `garrison_id_idx` (`garrison_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3478250 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom`
--

DROP TABLE IF EXISTS `Kingdom`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom` (
  `kingdom_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `colour` varchar(255) NOT NULL,
  `mayor_tax` int(11) NOT NULL DEFAULT '10',
  `gold` int(11) NOT NULL DEFAULT '0',
  `active` tinyint(4) NOT NULL DEFAULT '1',
  `inception_day_id` int(11) NOT NULL,
  `fall_day_id` int(11) DEFAULT NULL,
  `highest_land_count` int(11) NOT NULL DEFAULT '0',
  `highest_land_count_day_id` int(11) NOT NULL,
  `highest_town_count` int(11) NOT NULL DEFAULT '0',
  `highest_town_count_day_id` int(11) NOT NULL,
  `highest_party_count` int(11) NOT NULL DEFAULT '0',
  `highest_party_count_day_id` int(11) NOT NULL,
  `capital` int(11) DEFAULT NULL,
  `majesty` int(11) NOT NULL DEFAULT '0',
  `majesty_rank` int(11) DEFAULT NULL,
  `majesty_leader_since` datetime DEFAULT NULL,
  `has_crown` int(11) NOT NULL DEFAULT '0',
  `description` varchar(5000) DEFAULT NULL,
  PRIMARY KEY (`kingdom_id`),
  KEY `capital_idx` (`capital`)
) ENGINE=InnoDB AUTO_INCREMENT=52 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom_Claim`
--

DROP TABLE IF EXISTS `Kingdom_Claim`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom_Claim` (
  `claim_id` int(11) NOT NULL AUTO_INCREMENT,
  `kingdom_id` int(11) NOT NULL,
  `character_id` int(11) NOT NULL,
  `claim_made` datetime NOT NULL,
  `outcome` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`claim_id`),
  KEY `kingdom_idx` (`kingdom_id`),
  KEY `char_idx` (`character_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom_Claim_Response`
--

DROP TABLE IF EXISTS `Kingdom_Claim_Response`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom_Claim_Response` (
  `claim_id` int(11) NOT NULL,
  `party_id` int(11) NOT NULL,
  `response` varchar(50) NOT NULL,
  PRIMARY KEY (`claim_id`,`party_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom_Messages`
--

DROP TABLE IF EXISTS `Kingdom_Messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom_Messages` (
  `message_id` int(11) NOT NULL AUTO_INCREMENT,
  `kingdom_id` int(11) NOT NULL,
  `day_id` int(11) NOT NULL,
  `message` varchar(1000) NOT NULL,
  `type` varchar(50) NOT NULL DEFAULT 'message',
  `party_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`message_id`),
  KEY `kingdom_id_idx` (`kingdom_id`),
  KEY `day_id_idx` (`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=265836 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom_Relationship`
--

DROP TABLE IF EXISTS `Kingdom_Relationship`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom_Relationship` (
  `relationship_id` int(11) NOT NULL AUTO_INCREMENT,
  `kingdom_id` int(11) NOT NULL,
  `with_id` int(11) NOT NULL,
  `begun` int(11) DEFAULT NULL,
  `ended` int(11) DEFAULT NULL,
  `type` varchar(40) NOT NULL DEFAULT 'neutral',
  PRIMARY KEY (`relationship_id`),
  KEY `kingdom_id_idx` (`kingdom_id`),
  KEY `with_idx` (`with_id`),
  KEY `ended_idx` (`ended`)
) ENGINE=InnoDB AUTO_INCREMENT=236 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Kingdom_Town`
--

DROP TABLE IF EXISTS `Kingdom_Town`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Kingdom_Town` (
  `kingdom_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `loyalty` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`kingdom_id`,`town_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Land`
--

DROP TABLE IF EXISTS `Land`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Land` (
  `land_id` int(11) NOT NULL AUTO_INCREMENT,
  `x` bigint(20) NOT NULL,
  `y` bigint(20) NOT NULL,
  `terrain_id` int(11) DEFAULT NULL,
  `creature_threat` int(11) NOT NULL DEFAULT '0',
  `kingdom_id` int(11) DEFAULT NULL,
  `variation` int(11) NOT NULL DEFAULT '1',
  `claimed_by_id` int(11) DEFAULT NULL,
  `claimed_by_type` varchar(50) DEFAULT NULL,
  `tileset_id` int(11) NOT NULL,
  PRIMARY KEY (`land_id`),
  KEY `terrain_ind` (`terrain_id`),
  KEY `x_y_idx` (`x`,`y`),
  KEY `kingdom_idx` (`kingdom_id`)
) ENGINE=InnoDB AUTO_INCREMENT=78001 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Levels`
--

DROP TABLE IF EXISTS `Levels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Levels` (
  `level_number` int(11) NOT NULL,
  `xp_needed` int(11) NOT NULL,
  PRIMARY KEY (`level_number`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Map_Tileset`
--

DROP TABLE IF EXISTS `Map_Tileset`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Map_Tileset` (
  `tileset_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `prefix` varchar(50) NOT NULL,
  `allows_towns` int(11) DEFAULT '1',
  PRIMARY KEY (`tileset_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Mapped_Dungeon_Grid`
--

DROP TABLE IF EXISTS `Mapped_Dungeon_Grid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Mapped_Dungeon_Grid` (
  `mapped_grid_id` int(11) NOT NULL AUTO_INCREMENT,
  `date_mapped` datetime NOT NULL,
  `party_id` int(11) DEFAULT NULL,
  `dungeon_grid_id` int(11) NOT NULL,
  PRIMARY KEY (`mapped_grid_id`),
  KEY `d_grid_idx` (`dungeon_grid_id`,`party_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2797472 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Mapped_Sectors`
--

DROP TABLE IF EXISTS `Mapped_Sectors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Mapped_Sectors` (
  `mapped_sector_id` int(11) NOT NULL AUTO_INCREMENT,
  `storage_type` varchar(30) NOT NULL DEFAULT 'memory',
  `date_stored` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `land_id` int(11) NOT NULL,
  `party_id` int(11) NOT NULL,
  `known_dungeon` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`mapped_sector_id`),
  KEY `party_id_idx` (`party_id`),
  KEY `land_id_idx` (`land_id`),
  KEY `land_party_idx` (`land_id`,`party_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3343574 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Memorised_Spells`
--

DROP TABLE IF EXISTS `Memorised_Spells`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Memorised_Spells` (
  `mem_spell_id` int(11) NOT NULL AUTO_INCREMENT,
  `character_id` int(11) NOT NULL,
  `spell_id` int(11) NOT NULL,
  `memorise_tomorrow` tinyint(4) NOT NULL DEFAULT '1',
  `number_cast_today` int(11) NOT NULL DEFAULT '0',
  `memorised_today` tinyint(4) NOT NULL DEFAULT '0',
  `memorise_count` int(11) NOT NULL DEFAULT '0',
  `memorise_count_tomorrow` int(11) NOT NULL DEFAULT '0',
  `cast_offline` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`mem_spell_id`,`character_id`,`spell_id`),
  UNIQUE KEY `char_spell` (`character_id`,`spell_id`),
  KEY `spell_id` (`spell_id`),
  KEY `char_id` (`character_id`)
) ENGINE=InnoDB AUTO_INCREMENT=389174 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party`
--

DROP TABLE IF EXISTS `Party`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party` (
  `party_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `gold` bigint(20) NOT NULL,
  `player_id` int(11) DEFAULT NULL,
  `land_id` int(11) DEFAULT NULL,
  `turns` int(11) DEFAULT '0',
  `in_combat_with` int(11) DEFAULT NULL,
  `rank_separator_position` int(11) NOT NULL DEFAULT '3',
  `rest` int(11) NOT NULL DEFAULT '0',
  `created` datetime DEFAULT NULL,
  `turns_used` int(11) NOT NULL DEFAULT '0',
  `defunct` datetime DEFAULT NULL,
  `last_action` datetime DEFAULT NULL,
  `dungeon_grid_id` int(11) DEFAULT NULL,
  `flee_threshold` int(11) NOT NULL DEFAULT '70',
  `combat_type` varchar(255) DEFAULT NULL,
  `kingdom_id` int(11) DEFAULT NULL,
  `last_allegiance_change` int(11) DEFAULT NULL,
  `warned_for_kingdom_co_op` datetime DEFAULT NULL,
  `description` varchar(5000) DEFAULT NULL,
  `bonus_turns_today` int(11) DEFAULT '0',
  PRIMARY KEY (`party_id`),
  KEY `dungeon_idx` (`dungeon_grid_id`),
  KEY `kingdom_id_idx` (`kingdom_id`),
  KEY `player_id_idx` (`player_id`),
  KEY `in_combat_with_idx` (`in_combat_with`)
) ENGINE=InnoDB AUTO_INCREMENT=6159 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Battle`
--

DROP TABLE IF EXISTS `Party_Battle`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Battle` (
  `battle_id` int(11) NOT NULL AUTO_INCREMENT,
  `complete` datetime NOT NULL,
  PRIMARY KEY (`battle_id`)
) ENGINE=InnoDB AUTO_INCREMENT=241 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Day_Stats`
--

DROP TABLE IF EXISTS `Party_Day_Stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Day_Stats` (
  `date` date NOT NULL,
  `party_id` int(11) NOT NULL,
  `turns_used` int(11) NOT NULL,
  PRIMARY KEY (`date`,`party_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Effect`
--

DROP TABLE IF EXISTS `Party_Effect`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Effect` (
  `party_id` int(11) NOT NULL,
  `effect_id` int(11) NOT NULL,
  PRIMARY KEY (`party_id`,`effect_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Kingdom`
--

DROP TABLE IF EXISTS `Party_Kingdom`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Kingdom` (
  `party_id` int(11) NOT NULL,
  `kingdom_id` int(11) NOT NULL,
  `loyalty` int(11) NOT NULL DEFAULT '0',
  `banished_for` int(11) DEFAULT NULL,
  PRIMARY KEY (`party_id`,`kingdom_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Mayor_History`
--

DROP TABLE IF EXISTS `Party_Mayor_History`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Mayor_History` (
  `history_id` int(11) NOT NULL AUTO_INCREMENT,
  `mayor_name` varchar(255) NOT NULL,
  `got_mayoralty_day` int(11) NOT NULL,
  `lost_mayoralty_day` int(11) DEFAULT NULL,
  `creature_group_id` int(11) DEFAULT NULL,
  `lost_mayoralty_to` varchar(255) DEFAULT NULL,
  `lost_method` varchar(255) DEFAULT NULL,
  `character_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `party_id` int(11) NOT NULL,
  PRIMARY KEY (`history_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7606 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Messages`
--

DROP TABLE IF EXISTS `Party_Messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Messages` (
  `message_id` int(11) NOT NULL AUTO_INCREMENT,
  `message` varchar(4000) COLLATE latin1_general_ci NOT NULL,
  `alert_party` tinyint(4) NOT NULL DEFAULT '0',
  `day_id` int(11) DEFAULT NULL,
  `party_id` int(11) NOT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `type` varchar(20) COLLATE latin1_general_ci NOT NULL DEFAULT 'standard',
  `subject` varchar(1000) COLLATE latin1_general_ci DEFAULT NULL,
  PRIMARY KEY (`message_id`),
  KEY `type_idx` (`type`),
  KEY `day_id_idx` (`day_id`),
  KEY `sender_id_idx` (`sender_id`),
  KEY `party_id_ix` (`party_id`)
) ENGINE=InnoDB AUTO_INCREMENT=81730 DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Messages_Recipients`
--

DROP TABLE IF EXISTS `Party_Messages_Recipients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Messages_Recipients` (
  `party_id` int(11) NOT NULL,
  `message_id` int(11) NOT NULL,
  `has_read` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`party_id`,`message_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Party_Town`
--

DROP TABLE IF EXISTS `Party_Town`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Party_Town` (
  `party_id` int(11) NOT NULL,
  `town_id` int(11) NOT NULL,
  `tax_amount_paid_today` int(11) NOT NULL DEFAULT '0',
  `prestige` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`party_id`,`town_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Player`
--

DROP TABLE IF EXISTS `Player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Player` (
  `player_id` int(11) NOT NULL AUTO_INCREMENT,
  `player_name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `verified` tinyint(4) NOT NULL DEFAULT '0',
  `verification_code` varchar(255) DEFAULT NULL,
  `admin_user` tinyint(4) NOT NULL DEFAULT '0',
  `last_login` datetime NOT NULL,
  `deleted` tinyint(4) NOT NULL DEFAULT '0',
  `warned_for_deletion` tinyint(4) NOT NULL DEFAULT '0',
  `send_email` tinyint(1) NOT NULL DEFAULT '1',
  `display_tip_of_the_day` tinyint(1) NOT NULL DEFAULT '1',
  `display_announcements` tinyint(1) NOT NULL DEFAULT '1',
  `send_email_announcements` tinyint(1) NOT NULL DEFAULT '1',
  `send_daily_report` tinyint(1) NOT NULL DEFAULT '1',
  `promo_code_id` int(11) DEFAULT NULL,
  `email_hash` varchar(255) DEFAULT NULL,
  `referred_by` int(11) DEFAULT NULL,
  `refer_reward_given` tinyint(1) NOT NULL DEFAULT '0',
  `screen_width` varchar(255) NOT NULL DEFAULT 'auto',
  `screen_height` varchar(255) NOT NULL DEFAULT 'auto',
  `created` datetime NOT NULL,
  `display_town_leave_warning` tinyint(1) NOT NULL DEFAULT '1',
  `bug_manager` tinyint(1) NOT NULL DEFAULT '0',
  `contact_manager` tinyint(1) NOT NULL DEFAULT '0',
  `referer` varchar(2000) DEFAULT NULL,
  `deleted_date` datetime DEFAULT NULL,
  PRIMARY KEY (`player_id`),
  UNIQUE KEY `player_name` (`player_name`)
) ENGINE=InnoDB AUTO_INCREMENT=4575 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Player_Login`
--

DROP TABLE IF EXISTS `Player_Login`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Player_Login` (
  `login_id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) NOT NULL,
  `ip` varchar(255) NOT NULL,
  `login_date` datetime NOT NULL,
  `screen_height` int(11) DEFAULT NULL,
  `screen_width` int(11) DEFAULT NULL,
  PRIMARY KEY (`login_id`),
  KEY `player_id` (`player_id`)
) ENGINE=InnoDB AUTO_INCREMENT=67763 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Player_Reward_Links`
--

DROP TABLE IF EXISTS `Player_Reward_Links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Player_Reward_Links` (
  `player_id` int(11) NOT NULL,
  `link_id` int(11) NOT NULL,
  `last_vote_date` datetime DEFAULT NULL,
  `vote_key` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`player_id`,`link_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Player_Reward_Vote`
--

DROP TABLE IF EXISTS `Player_Reward_Vote`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Player_Reward_Vote` (
  `vote_id` int(11) NOT NULL AUTO_INCREMENT,
  `player_id` int(11) NOT NULL,
  `link_id` int(11) NOT NULL,
  `vote_date` datetime NOT NULL,
  PRIMARY KEY (`vote_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5414 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Promo_Code`
--

DROP TABLE IF EXISTS `Promo_Code`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Promo_Code` (
  `code_id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(40) NOT NULL,
  `promo_org_id` int(11) NOT NULL,
  `uses_remaining` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`code_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Promo_Org`
--

DROP TABLE IF EXISTS `Promo_Org`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Promo_Org` (
  `promo_org_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `extra_start_turns` int(11) NOT NULL,
  PRIMARY KEY (`promo_org_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Quest`
--

DROP TABLE IF EXISTS `Quest`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Quest` (
  `quest_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `party_id` int(11) DEFAULT NULL,
  `town_id` int(11) DEFAULT NULL,
  `kingdom_id` int(11) DEFAULT NULL,
  `quest_type_id` int(11) NOT NULL,
  `complete` tinyint(4) NOT NULL DEFAULT '0',
  `gold_value` int(11) NOT NULL,
  `xp_value` int(11) NOT NULL,
  `min_level` int(11) NOT NULL DEFAULT '1',
  `status` varchar(40) NOT NULL DEFAULT 'Not Started',
  `days_to_complete` int(11) NOT NULL DEFAULT '0',
  `day_offered` int(11) DEFAULT NULL,
  PRIMARY KEY (`quest_id`),
  KEY `status_idx` (`status`),
  KEY `party_id_idx` (`party_id`),
  KEY `town_id_idx` (`town_id`),
  KEY `kingdom_id_idx` (`kingdom_id`)
) ENGINE=InnoDB AUTO_INCREMENT=596622 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Quest_Param`
--

DROP TABLE IF EXISTS `Quest_Param`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Quest_Param` (
  `quest_param_id` int(11) NOT NULL AUTO_INCREMENT,
  `start_value` varchar(255) NOT NULL,
  `current_value` varchar(255) NOT NULL,
  `quest_param_name_id` int(11) DEFAULT NULL,
  `quest_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`quest_param_id`),
  KEY `quest_id_idx` (`quest_id`)
) ENGINE=InnoDB AUTO_INCREMENT=817244 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Quest_Param_Name`
--

DROP TABLE IF EXISTS `Quest_Param_Name`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Quest_Param_Name` (
  `quest_param_name_id` int(11) NOT NULL AUTO_INCREMENT,
  `quest_param_name` varchar(50) NOT NULL,
  `quest_type_id` int(11) DEFAULT NULL,
  `variable_type` varchar(50) DEFAULT NULL,
  `user_settable` tinyint(4) NOT NULL DEFAULT '0',
  `min_val` int(11) DEFAULT NULL,
  `max_val` int(11) DEFAULT NULL,
  `default_val` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`quest_param_name_id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Quest_Type`
--

DROP TABLE IF EXISTS `Quest_Type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Quest_Type` (
  `quest_type_id` int(11) NOT NULL AUTO_INCREMENT,
  `quest_type` varchar(40) NOT NULL,
  `hidden` int(11) NOT NULL DEFAULT '0',
  `prevalence` int(11) NOT NULL DEFAULT '50',
  `owner_type` varchar(40) NOT NULL DEFAULT 'town',
  `description` varchar(255) DEFAULT NULL,
  `long_desc` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`quest_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Race`
--

DROP TABLE IF EXISTS `Race`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Race` (
  `race_id` int(11) NOT NULL AUTO_INCREMENT,
  `race_name` varchar(255) NOT NULL,
  `base_int` int(11) NOT NULL,
  `base_str` int(11) NOT NULL,
  `base_agl` int(11) NOT NULL,
  `base_con` int(11) NOT NULL,
  `base_div` int(11) NOT NULL,
  PRIMARY KEY (`race_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Reward_Links`
--

DROP TABLE IF EXISTS `Reward_Links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Reward_Links` (
  `link_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `url` varchar(1000) NOT NULL,
  `label` varchar(200) NOT NULL,
  `turn_rewards` int(11) NOT NULL,
  `activated` tinyint(4) NOT NULL DEFAULT '1',
  `user_field` varchar(100) NOT NULL,
  `key_field` varchar(100) DEFAULT NULL,
  `extra_params` varchar(100) DEFAULT NULL,
  `result_field` varchar(100) DEFAULT NULL,
  `template_url` tinyint(4) NOT NULL,
  PRIMARY KEY (`link_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Road`
--

DROP TABLE IF EXISTS `Road`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Road` (
  `road_id` int(11) NOT NULL AUTO_INCREMENT,
  `position` varchar(40) NOT NULL,
  `land_id` int(11) NOT NULL,
  PRIMARY KEY (`road_id`),
  KEY `land_id_idx` (`land_id`)
) ENGINE=InnoDB AUTO_INCREMENT=417 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Shop`
--

DROP TABLE IF EXISTS `Shop`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Shop` (
  `shop_id` int(11) NOT NULL AUTO_INCREMENT,
  `town_id` int(11) NOT NULL,
  `shop_owner_name` varchar(255) NOT NULL,
  `status` varchar(20) NOT NULL,
  `shop_size` int(11) NOT NULL,
  `shop_suffix` varchar(40) NOT NULL,
  PRIMARY KEY (`shop_id`)
) ENGINE=InnoDB AUTO_INCREMENT=17883 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Skill`
--

DROP TABLE IF EXISTS `Skill`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Skill` (
  `skill_id` int(11) NOT NULL AUTO_INCREMENT,
  `skill_name` varchar(40) NOT NULL,
  `type` varchar(40) NOT NULL,
  `description` varchar(2000) NOT NULL,
  `base_stats` varchar(100) NOT NULL,
  PRIMARY KEY (`skill_id`),
  KEY `type_index` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Spell`
--

DROP TABLE IF EXISTS `Spell`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Spell` (
  `spell_id` int(11) NOT NULL AUTO_INCREMENT,
  `spell_name` varchar(40) NOT NULL,
  `description` varchar(5000) NOT NULL,
  `points` int(11) NOT NULL,
  `class_id` int(11) DEFAULT NULL,
  `combat` tinyint(4) NOT NULL,
  `non_combat` tinyint(4) NOT NULL,
  `target` varchar(30) NOT NULL,
  `hidden` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`spell_id`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Super_Category`
--

DROP TABLE IF EXISTS `Super_Category`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Super_Category` (
  `super_category_id` int(11) NOT NULL AUTO_INCREMENT,
  `super_category_name` varchar(255) NOT NULL,
  PRIMARY KEY (`super_category_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Survey_Response`
--

DROP TABLE IF EXISTS `Survey_Response`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Survey_Response` (
  `survey_response_id` int(11) NOT NULL AUTO_INCREMENT,
  `reason` varchar(255) DEFAULT NULL,
  `favourite` varchar(255) DEFAULT NULL,
  `least_favourite` varchar(255) DEFAULT NULL,
  `feedback` varchar(2000) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `party_level` int(11) DEFAULT NULL,
  `turns_used` int(11) DEFAULT NULL,
  PRIMARY KEY (`survey_response_id`)
) ENGINE=InnoDB AUTO_INCREMENT=110 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Terrain`
--

DROP TABLE IF EXISTS `Terrain`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Terrain` (
  `terrain_id` int(11) NOT NULL AUTO_INCREMENT,
  `terrain_name` varchar(255) NOT NULL,
  `modifier` int(11) NOT NULL,
  `image` varchar(255) NOT NULL,
  PRIMARY KEY (`terrain_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Tip`
--

DROP TABLE IF EXISTS `Tip`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Tip` (
  `tip_id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `tip` text NOT NULL,
  PRIMARY KEY (`tip_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Town`
--

DROP TABLE IF EXISTS `Town`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Town` (
  `town_id` int(11) NOT NULL AUTO_INCREMENT,
  `town_name` varchar(255) NOT NULL,
  `land_id` int(11) NOT NULL,
  `prosperity` int(11) NOT NULL,
  `blacksmith_age` int(11) NOT NULL DEFAULT '0',
  `blacksmith_skill` int(11) NOT NULL DEFAULT '0',
  `discount_type` varchar(50) DEFAULT NULL,
  `discount_value` int(11) NOT NULL DEFAULT '0',
  `discount_threshold` int(11) NOT NULL DEFAULT '0',
  `pending_mayor` bigint(20) DEFAULT NULL,
  `gold` int(11) NOT NULL DEFAULT '0',
  `peasant_tax` int(11) NOT NULL DEFAULT '0',
  `base_party_tax` int(11) NOT NULL DEFAULT '0',
  `party_tax_level_step` int(11) NOT NULL DEFAULT '0',
  `sales_tax` int(11) NOT NULL DEFAULT '0',
  `tax_modified_today` tinyint(4) NOT NULL DEFAULT '0',
  `mayor_rating` int(11) NOT NULL DEFAULT '0',
  `peasant_state` varchar(200) DEFAULT NULL,
  `pending_mayor_date` datetime DEFAULT NULL,
  `last_election` int(11) DEFAULT NULL,
  `advisor_fee` int(11) NOT NULL DEFAULT '0',
  `character_heal_budget` int(11) NOT NULL DEFAULT '0',
  `trap_level` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`town_id`),
  KEY `land_id_idx` (`land_id`),
  KEY `pending_mayor_idx` (`pending_mayor`)
) ENGINE=InnoDB AUTO_INCREMENT=1036 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Town_Guards`
--

DROP TABLE IF EXISTS `Town_Guards`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Town_Guards` (
  `town_id` int(11) NOT NULL,
  `creature_type_id` int(11) NOT NULL,
  `amount` int(11) NOT NULL,
  `amount_working` int(11) DEFAULT NULL,
  PRIMARY KEY (`town_id`,`creature_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Town_History`
--

DROP TABLE IF EXISTS `Town_History`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Town_History` (
  `town_history_id` int(11) NOT NULL AUTO_INCREMENT,
  `message` varchar(4000) NOT NULL,
  `town_id` int(11) NOT NULL,
  `day_id` int(11) NOT NULL,
  `date_recorded` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `type` varchar(30) NOT NULL DEFAULT 'news',
  `value` varchar(200) DEFAULT NULL,
  PRIMARY KEY (`town_history_id`),
  KEY `town_day_idx` (`town_id`,`day_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4137523 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Town_Raid`
--

DROP TABLE IF EXISTS `Town_Raid`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Town_Raid` (
  `raid_id` int(11) NOT NULL AUTO_INCREMENT,
  `town_id` int(11) NOT NULL,
  `party_id` int(11) NOT NULL,
  `day_id` int(11) NOT NULL,
  `date_started` datetime NOT NULL,
  `date_ended` datetime NOT NULL,
  `defeated_mayor` tinyint(4) NOT NULL DEFAULT '0',
  `detected` tinyint(4) NOT NULL DEFAULT '0',
  `guards_killed` int(11) NOT NULL DEFAULT '0',
  `defences` varchar(5000) DEFAULT NULL,
  `defending_party` int(11) DEFAULT NULL,
  `battle_count` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`raid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2990 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Trade`
--

DROP TABLE IF EXISTS `Trade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Trade` (
  `trade_id` int(11) NOT NULL AUTO_INCREMENT,
  `town_id` int(11) NOT NULL,
  `party_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `offered_to` int(11) DEFAULT NULL,
  `status` varchar(50) NOT NULL,
  `amount` int(11) NOT NULL,
  `item_base_value` int(11) NOT NULL,
  `item_type` varchar(100) NOT NULL,
  `purchased_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`trade_id`),
  KEY `town_id` (`town_id`),
  KEY `party_id` (`party_id`),
  KEY `item_id` (`item_id`),
  KEY `offered_to` (`offered_to`)
) ENGINE=InnoDB AUTO_INCREMENT=2616 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Trait`
--

DROP TABLE IF EXISTS `Trait`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Trait` (
  `trait_id` int(11) NOT NULL AUTO_INCREMENT,
  `trait` varchar(255) NOT NULL,
  `last_used` datetime NOT NULL,
  PRIMARY KEY (`trait_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Treasure_Chest`
--

DROP TABLE IF EXISTS `Treasure_Chest`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Treasure_Chest` (
  `treasure_chest_id` int(11) NOT NULL AUTO_INCREMENT,
  `dungeon_grid_id` int(11) NOT NULL,
  `trap` varchar(255) DEFAULT NULL,
  `gold` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`treasure_chest_id`),
  KEY `grid_id_idx` (`dungeon_grid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=109874 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sessions` (
  `id` char(72) NOT NULL,
  `session_data` text NOT NULL,
  `expires` int(11) NOT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-02-24 14:49:34
-- MySQL dump 10.13  Distrib 5.7.17, for Linux (x86_64)
--
-- Host: localhost    Database: game
-- ------------------------------------------------------
-- Server version	5.7.17-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `Equip_Places`
--

LOCK TABLES `Equip_Places` WRITE;
/*!40000 ALTER TABLE `Equip_Places` DISABLE KEYS */;
INSERT INTO `Equip_Places` VALUES (1,'Head',2,1),(2,'Torso and Legs',2,2),(3,'Right Hand',3,2),(4,'Left Hand',3,2),(5,'Left Ring Finger',1,1),(6,'Right Ring Finger',1,1),(7,'Neck',1,1);
/*!40000 ALTER TABLE `Equip_Places` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Equip_Place_Category`
--

LOCK TABLES `Equip_Place_Category` WRITE;
/*!40000 ALTER TABLE `Equip_Place_Category` DISABLE KEYS */;
INSERT INTO `Equip_Place_Category` VALUES (1,4),(2,2),(3,1),(3,6),(3,7),(4,1),(4,6),(4,7),(5,14),(6,14),(7,13);
/*!40000 ALTER TABLE `Equip_Place_Category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Class`
--

LOCK TABLES `Class` WRITE;
/*!40000 ALTER TABLE `Class` DISABLE KEYS */;
INSERT INTO `Class` VALUES (1,'Warrior'),(2,'Archer'),(3,'Priest'),(4,'Mage');
/*!40000 ALTER TABLE `Class` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Race`
--

LOCK TABLES `Race` WRITE;
/*!40000 ALTER TABLE `Race` DISABLE KEYS */;
INSERT INTO `Race` VALUES (1,'Human',5,5,5,5,5),(2,'Elf',7,4,6,3,5),(3,'Dwarf',3,5,4,7,6);
/*!40000 ALTER TABLE `Race` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Spell`
--

LOCK TABLES `Spell` WRITE;
/*!40000 ALTER TABLE `Spell` DISABLE KEYS */;
INSERT INTO `Spell` VALUES (1,'Summon','Summons an animal to fight with the party',12,3,0,1,'party',1),(2,'Shield','Gives magical shielding to a party member',2,3,1,0,'character',0),(3,'Bless','Bless a party member, making it more likely their blows will find the mark',1,3,1,0,'character',0),(4,'Locate Town','Locate the nearest town',3,3,0,1,'special',1),(5,'Locate Party','Locate a party',3,3,0,1,'special',1),(6,'Locate Creature Group','Locate a group of creatures',3,3,0,1,'special',1),(7,'Locate Item','Locate an item',2,3,0,1,'special',1),(8,'Heal','Heals a party member',1,3,1,1,'character',0),(9,'Blades','Adds invisible blades to a party member\'s weapon, increasing the damage they do with each blow',3,3,1,0,'character',0),(10,'Ward','Provides protection against attacks in the wilderness',8,3,0,1,'party',1),(11,'Haste','Speeds a party member, giving them more attacks per round',3,3,1,0,'character',0),(12,'Weaken','Saps the strength of a creature, causing them to do less damage when they hit',3,4,1,0,'creature',0),(13,'Confuse','Confuses a creature, making them move slowly, and easier to hit.',2,4,1,0,'creature',0),(14,'Raise Dead','Raises corpses as undead to fight alongside the party',12,4,0,1,'party',1),(15,'Teleport','Moves the entire party to a random sector',16,4,0,1,'party',1),(16,'Curse','Places a curse on a creature, making their attacks less likely to succeed',3,4,1,0,'creature',0),(17,'Levitate','Levitates a party member, allowing them to move quickly through the wilderness',6,4,0,1,'character',1),(18,'Light','Lights the surrounding area magically.',4,4,0,1,'party',1),(19,'Flame','Shoots a burst of flame at a creature, damaging it.',5,4,1,0,'creature',0),(20,'Entangle','Makes plant life around a creature grow, entangling it and preventing it from attacking.',8,4,1,0,'creature',0),(21,'Slow','Slows down a creature, making them attack less often.',5,4,1,0,'creature',0),(22,'Energy Beam','Shoots an energy beam at a creature, damaging it.',1,4,1,0,'creature',0),(23,'Watcher','Creates a \"Watcher\" force, that stays with the party and determines how the party will fare in combat in relation to a particular group of creatures',10,4,0,1,'party',0),(24,'Portal','Allows the party to return to the wilderness from anywhere in a dungeon',6,3,0,1,'party',0),(25,'Ice Bolt','Shoots a bolt of ice at the opponent, damaging them, and freezing them',7,4,1,0,'creature',0),(26,'Poison Blast','Sends a poisonous blast to the opponent, damaging them slowly',6,4,1,0,'creature',0),(27,'Detonate','Creates a magical bomb that will detonate after a few minutes. If detonated in a town\'s castle during a raid, or adjacent to a building in the wilderness, the building\'s upgrade runes may be damaged, temprorarily or permanently. In castles, more damage is likely to be done if bombs are planted away from the stairs. Requires 1 Vial of Dragons Blood that will be used up during casting',10,4,0,1,'party',0),(28,'Farsight','Allows the caster to see a map sector from a distance. They will see inside defences of a town or building, giving an indication of how strong they are. The presence of garrisons, dungeons, orbs and guards will also be revealed. The caster\'s level and the party\'s proximity to the sector affect the accuracy of the results.',10,3,0,1,'sector',0),(29,'Cleanse','Removes all negative effects from a character in the party',8,3,1,1,'character',0);
/*!40000 ALTER TABLE `Spell` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Quest_Type`
--

LOCK TABLES `Quest_Type` WRITE;
/*!40000 ALTER TABLE `Quest_Type` DISABLE KEYS */;
INSERT INTO `Quest_Type` VALUES (1,'msg_to_town',0,100,'town',NULL,NULL),(2,'find_jewel',0,80,'town',NULL,NULL),(3,'kill_creatures_near_town',0,100,'town',NULL,NULL),(4,'destroy_orb',0,70,'town',NULL,NULL),(5,'raid_town',0,50,'town',NULL,NULL),(6,'find_dungeon_item',0,40,'town',NULL,NULL),(7,'construct_building',0,50,'kingdom','Construct A Building','Order a party to construct a building in the sector specified'),(8,'claim_land',0,50,'kingdom','Claim Land','Request that a party claims a certain number of land for the Kingdom'),(9,'take_over_town',0,50,'kingdom','Take Over A Town','Request that a party takes over a town, installs a mayor, and changes the towns allegiance to that of the Kingdom'),(10,'create_garrison',0,50,'kingdom','Create a Garrison','Order a party to create a garrison in the sector specified, and hold the garrison for a given number of days');
/*!40000 ALTER TABLE `Quest_Type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Quest_Param_Name`
--

LOCK TABLES `Quest_Param_Name` WRITE;
/*!40000 ALTER TABLE `Quest_Param_Name` DISABLE KEYS */;
INSERT INTO `Quest_Param_Name` VALUES (1,'Range',3,NULL,0,NULL,NULL,NULL),(2,'Number Of Creatures To Kill',3,NULL,0,NULL,NULL,NULL),(3,'Town To Take Msg To',1,NULL,0,NULL,NULL,NULL),(4,'Been To Town',1,NULL,0,NULL,NULL,NULL),(5,'Sold Jewel',2,NULL,0,NULL,NULL,NULL),(6,'Jewel To Find',2,NULL,0,NULL,NULL,NULL),(7,'Destroyed Orb',4,NULL,0,NULL,NULL,NULL),(8,'Orb To Destroy',4,NULL,0,NULL,NULL,NULL),(9,'Town To Raid',5,NULL,0,NULL,NULL,NULL),(10,'Raided Town',5,NULL,0,NULL,NULL,NULL),(11,'Item',6,NULL,0,NULL,NULL,NULL),(12,'Dungeon',6,NULL,0,NULL,NULL,NULL),(13,'Item Found',6,NULL,0,NULL,NULL,NULL),(14,'Building Location',7,'Land',1,NULL,NULL,NULL),(15,'Building Type',7,'Building_Type',1,NULL,NULL,NULL),(16,'Built',7,NULL,0,NULL,NULL,'0'),(17,'Amount To Claim',8,'int',1,10,50,NULL),(18,'Amount Claimed',8,NULL,0,NULL,NULL,'0'),(19,'Town To Take Over',9,'Town',1,NULL,NULL,NULL),(20,'Location To Create',10,'Land',1,NULL,NULL,NULL),(21,'Days To Hold',10,'int',1,5,20,NULL),(22,'Created',10,NULL,0,NULL,NULL,'0');
/*!40000 ALTER TABLE `Quest_Param_Name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Levels`
--

LOCK TABLES `Levels` WRITE;
/*!40000 ALTER TABLE `Levels` DISABLE KEYS */;
INSERT INTO `Levels` VALUES (1,0),(2,250),(3,800),(4,1600),(5,3000),(6,5000),(7,7000),(8,9200),(9,11400),(10,13600),(11,16000),(12,18500),(13,21000),(14,23500),(15,26000),(16,29000),(17,32000),(18,36000),(19,40000),(20,45000),(21,50000),(22,57500),(23,65000),(24,75000),(25,100000),(26,125000),(27,150000),(28,200000),(29,400000),(30,1000000);
/*!40000 ALTER TABLE `Levels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Dungeon_Position`
--

LOCK TABLES `Dungeon_Position` WRITE;
/*!40000 ALTER TABLE `Dungeon_Position` DISABLE KEYS */;
INSERT INTO `Dungeon_Position` VALUES (5,'right'),(6,'left'),(7,'bottom'),(8,'top');
/*!40000 ALTER TABLE `Dungeon_Position` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Enchantments`
--

LOCK TABLES `Enchantments` WRITE;
/*!40000 ALTER TABLE `Enchantments` DISABLE KEYS */;
INSERT INTO `Enchantments` VALUES (1,'spell_casts_per_day',0,0),(2,'indestructible',0,1),(3,'magical_damage',0,1),(4,'daily_heal',0,1),(5,'extra_turns',0,1),(6,'bonus_against_creature_category',0,0),(7,'stat_bonus',0,0),(8,'featherweight',0,1),(9,'movement_bonus',1,1),(10,'critical_hit_bonus',1,1),(11,'resistances',1,1);
/*!40000 ALTER TABLE `Enchantments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Dungeon_Special_Room`
--

LOCK TABLES `Dungeon_Special_Room` WRITE;
/*!40000 ALTER TABLE `Dungeon_Special_Room` DISABLE KEYS */;
INSERT INTO `Dungeon_Special_Room` VALUES (1,'rare_monster'),(2,'treasure');
/*!40000 ALTER TABLE `Dungeon_Special_Room` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Building_Type`
--

LOCK TABLES `Building_Type` WRITE;
/*!40000 ALTER TABLE `Building_Type` DISABLE KEYS */;
INSERT INTO `Building_Type` VALUES (1,'Tower',1,1,4,1,16,6,15,8,150,60,1,'tower.png','fortinprog.png',2,3),(2,'Fort',1,2,6,2,22,12,18,16,200,80,2,'fort.png','fortinprog.png',3,6),(3,'Castle',1,3,8,4,28,20,26,20,250,100,3,'castle.png','fortinprog.png',4,10);
/*!40000 ALTER TABLE `Building_Type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Skill`
--

LOCK TABLES `Skill` WRITE;
/*!40000 ALTER TABLE `Skill` DISABLE KEYS */;
INSERT INTO `Skill` VALUES (1,'Recall','','Allows spell casters a chance of recalling a spell immediately after casting it, meaning they don\'t use up a cast for the day','Constitution'),(2,'Medicine','nightly','Allows the character a chance of healing their group\'s wounds over night','Divinity'),(3,'Construction','','Gives the character a bonus when constructing buildings',''),(4,'Fletching','nightly','Allows the character to produce ammunition for their equipped weapon each night','Intelligence'),(5,'Metallurgy','nightly','Gives the character the ability to repair minor damage to their weapons each night','Intelligence'),(6,'Tactics','','Allows character\'s party to prevent foes from fleeing. Also allows mayors to instruct their guards in offence','Intelligence'),(7,'Strategy','','Gives the character\'s group a greater chance of successfully fleeing from battles. Also allows mayors to instruct their guards in defence','Intelligence'),(8,'Charisma','','Mayors with good charisma will find it easier to gain approval, and win elections. Kings will gain greater popularity with the peasants in their realm','Intelligence'),(9,'Leadership','','Increases the amount of tax Mayors can collect from their towns. Increases the number of quests a King can assign.',''),(10,'Berserker Rage','combat','Gives the character a chance of going into a Beserker rage during combat, increasing the damage they inflict','Constitution'),(11,'War Cry','combat','Each round of combat, the character may sound a War Cry, giving them an increased chance of hitting their opponent','Divinity'),(12,'Shield Bash','combat','Allows the character to bash their opponent with a shield, in addition to their normal attack for the round','Strength'),(13,'Eagle Eye','','Allows the character to spot weaknesses in their opponent\'s defence, giving them an increased chance of a critical hit',''),(14,'Awareness','','Increases the character\'s chance of finding traps, secret doors, etc.','Intelligence, Divinity'),(15,'Negotiation','','Reduces the cost of entry into towns. For mayors, improves their chances of defeating a revolt','Intelligence');
/*!40000 ALTER TABLE `Skill` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Map_Tileset`
--

LOCK TABLES `Map_Tileset` WRITE;
/*!40000 ALTER TABLE `Map_Tileset` DISABLE KEYS */;
INSERT INTO `Map_Tileset` VALUES (1,'Standard','',1),(2,'Snow','snow',1),(3,'Snow Fading Bottom','snowfadingbottom',0);
/*!40000 ALTER TABLE `Map_Tileset` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Building_Upgrade_Type`
--

LOCK TABLES `Building_Upgrade_Type` WRITE;
/*!40000 ALTER TABLE `Building_Upgrade_Type` DISABLE KEYS */;
INSERT INTO `Building_Upgrade_Type` VALUES (1,'Market',0,'0','Accumulates gold on a daily basis, which goes to the owner of the building',0,6,4,2,2,5),(2,'Barracks',0,'0','Characters within the building can train here, and earn experience',0,8,3,4,4,5),(3,'Rune of Protection',5,'Resistances','Protects the inhabitants of the building from magical attacks (Fire, Ice and Poison)',1000,0,0,0,0,5),(4,'Rune of Defence',5,'DF','Gives the inhabitants of the building a defensive bonus during combat',1000,0,0,0,0,5),(5,'Rune of Attack',5,'AF','Gives the inhabitants of the building a bonus to attack during combat',1000,0,0,0,0,5);
/*!40000 ALTER TABLE `Building_Upgrade_Type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Creature_Category`
--

LOCK TABLES `Creature_Category` WRITE;
/*!40000 ALTER TABLE `Creature_Category` DISABLE KEYS */;
INSERT INTO `Creature_Category` VALUES (1,'Beast','monsters',1),(2,'Demon','demons',1),(3,'Golem','golems',1),(4,'Dragon','dragons',1),(5,'Undead','undeads',1),(6,'Humanoid','humanoid',1),(7,'Lycanthrope','lycanthropes',1),(8,'Guard','guards',0),(9,'Rodent','rodent',0);
/*!40000 ALTER TABLE `Creature_Category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Creature_Spell`
--

LOCK TABLES `Creature_Spell` WRITE;
/*!40000 ALTER TABLE `Creature_Spell` DISABLE KEYS */;
INSERT INTO `Creature_Spell` VALUES (1,1,53),(2,9,53),(3,13,53),(4,21,53),(5,22,53),(6,1,56),(7,19,56),(8,3,56),(9,13,56),(10,21,56),(11,1,50),(12,2,50),(13,3,50),(14,8,50),(15,12,50),(16,1,55),(17,11,55),(18,3,55),(19,2,55),(20,20,55);
/*!40000 ALTER TABLE `Creature_Spell` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Creature_Type`
--

LOCK TABLES `Creature_Type` WRITE;
/*!40000 ALTER TABLE `Creature_Type` DISABLE KEYS */;
INSERT INTO `Creature_Type` VALUES (1,'Troll',2,'Melee Weapon',6,6,6,6,NULL,NULL,'troll.png',0,NULL),(2,'Goblin',1,'Melee Weapon',3,3,3,6,NULL,NULL,'goblin.png',0,NULL),(3,'Orc Grunt',1,'Melee Weapon',3,3,3,6,NULL,NULL,'orc.png',0,NULL),(4,'Gorgon',9,'Fire Breath',27,27,27,1,NULL,NULL,'defaultport.png',0,NULL),(5,'Ogre',5,'Melee Weapon',15,15,15,6,NULL,NULL,'ogre.png',0,NULL),(6,'Hobgoblin',3,'Melee Weapon',9,9,9,6,NULL,NULL,'hobgoblin.png',0,NULL),(7,'Centaur',6,'Melee Weapon',18,18,18,6,NULL,NULL,'centaur.png',0,NULL),(8,'Satyr',4,'Melee Weapon',12,12,12,6,NULL,NULL,'satyr.png',0,NULL),(9,'Manticore',8,'Razor Teeth',24,24,24,1,NULL,NULL,'defaultport.png',0,NULL),(10,'Chimera',10,'Fire Breath',30,30,30,1,NULL,NULL,'defaultport.png',0,NULL),(11,'Cyclopse',9,'Melee Weapon',27,27,27,1,NULL,NULL,'cyclops.png',0,NULL),(12,'Basilisk',8,'Death Gaze',24,24,24,1,NULL,NULL,'defaultport.png',0,NULL),(13,'Dark Elf',3,'Melee Weapon',9,9,9,6,NULL,NULL,'darkelf.png',0,NULL),(14,'Werewolf',7,'Claws',21,21,21,7,NULL,NULL,'werewolf.png',0,NULL),(15,'Hell Hound',4,'Claws',12,12,12,1,NULL,NULL,'hellhound.png',0,NULL),(16,'Minotaur',4,'Melee Weapon',12,12,12,6,NULL,NULL,'minotaur.png',0,NULL),(17,'Harpy',7,'Hypnotic Song',21,21,21,6,NULL,NULL,'harpy.png',0,NULL),(18,'Bugbear',3,'Melee Weapon',9,9,9,6,NULL,NULL,'bugbear.png',0,NULL),(19,'Gargoyle',5,'Claws',15,15,15,6,NULL,NULL,'defaultport.png',0,NULL),(20,'Wraith',10,'Freezing Touch',30,30,30,5,NULL,NULL,'wraith.png',0,NULL),(21,'Spectre',8,'Melee Weapon',24,24,24,5,NULL,NULL,'spectre.png',0,NULL),(22,'Wyvern',6,'Claws',18,18,18,1,NULL,NULL,'wyvern.png',0,NULL),(23,'Skeleton',1,'Melee Weapon',3,3,3,5,NULL,NULL,'skeleton.png',0,NULL),(24,'Zombie',3,'Claws',9,9,9,5,NULL,NULL,'zombie.png',0,NULL),(25,'Ghoul',2,'Claws',6,6,6,5,NULL,NULL,'ghoul.png',0,NULL),(26,'Lesser Demon',11,'Fire Blade',33,33,33,2,NULL,NULL,'lesserdemon.png',0,NULL),(27,'Hypnotic Slime',5,'Mesmeric Acid',15,15,15,1,NULL,NULL,'hypnoslime.png',0,NULL),(28,'Revenant',13,'Melee Weapon',39,39,39,5,NULL,NULL,'revenant.png',0,NULL),(29,'Wisp',2,'Puff of Smoke',6,6,6,1,NULL,NULL,'wisp.png',0,NULL),(30,'Giant Wolf',4,'Claws',12,12,12,1,NULL,NULL,'defaultport.png',0,NULL),(31,'Succubus',12,'Melee Weapon',36,36,36,1,NULL,NULL,'defaultport.png',0,NULL),(32,'Iron Golem',13,'Melee Weapon',39,39,39,3,NULL,NULL,'irongolem.png',0,NULL),(33,'Clay Golem',11,'Melee Weapon',33,33,33,3,NULL,NULL,'claygolem.png',0,NULL),(34,'Stone Golem',15,'Melee Weapon',45,45,45,3,NULL,NULL,'stonegolem.png',0,NULL),(35,'Demon Lord',17,'Indestructible Fire Blade',51,51,51,2,NULL,NULL,'demonlord.png',0,NULL),(36,'Greater Demon',15,'Enchanted Fire Blade',45,45,45,2,NULL,NULL,'greaterdemon.png',0,NULL),(37,'Fire Elemental',14,'Fire Breath',42,42,42,1,NULL,NULL,'fireelemental.png',0,NULL),(38,'Orc Lord',12,'Melee Weapon',36,36,36,6,NULL,NULL,'defaultport.png',0,NULL),(39,'Platinum Dragon',21,'Fire Breath',78,35,63,4,0,0,'platinumdragon.png',0,NULL),(40,'Gold Dragon',20,'Fire Breath',75,50,60,4,0,0,'golddragon.png',0,NULL),(41,'Silver Dragon',19,'Fire Breath',65,40,57,4,0,0,'silverdragon.png',0,NULL),(42,'Fire Dragon',18,'Fire Breath',80,30,54,4,0,0,'firedragon.png',0,NULL),(43,'Ice Dragon',16,'Icy Breath',35,80,48,4,0,0,'icedragon.png',0,NULL),(44,'Wererat',5,'Claws',15,15,15,7,NULL,NULL,'wererat.png',0,NULL),(45,'Werebear',9,'Claws',27,27,27,7,NULL,NULL,'defaultport.png',0,NULL),(46,'Weretiger',11,'Claws',33,33,33,7,NULL,NULL,'weretiger.png',0,NULL),(47,'Rookie Town Guard',6,'Melee Weapon',18,18,18,8,10,100,'rookieguard.png',0,NULL),(48,'Seasoned Town Guard',12,'Melee Weapon',36,36,36,8,25,350,'seasonedguard.png',0,NULL),(49,'Veteran Town Guard',16,'Melee Weapon',48,48,48,8,35,1000,'veteranguard.png',0,NULL),(50,'Orc Shaman',6,'Golden Staff',25,25,25,6,NULL,NULL,'defaultport.png',1,NULL),(51,'Goblin Chief',8,'Melee Weapon',28,28,28,6,NULL,NULL,'defaultport.png',1,NULL),(52,'Bandit Leader',14,'Melee Weapon',40,40,40,6,NULL,NULL,'defaultport.png',1,'Ice'),(53,'Warlock',12,'Staff of Oden',40,40,40,6,NULL,NULL,'defaultport.png',1,NULL),(54,'Gelatinous Ooze',16,'Acidic Slime',40,40,40,1,NULL,NULL,'defaultport.png',1,'Poison'),(55,'Black Sorcerer',15,'Mace of Death',50,50,50,6,NULL,NULL,'blacksorcerer.png',1,NULL),(56,'Lich',22,'Melee Weapon',65,65,65,5,NULL,NULL,'defaultport.png',1,NULL),(57,'Demon King',24,'Melee Weapon',65,65,80,2,NULL,NULL,'demonking.png',1,'Fire'),(58,'Vampire',19,'Melee Weapon',55,55,55,5,NULL,NULL,'vampire.png',0,NULL),(59,'Devils Spawn',20,'Melee Weapon',50,50,50,2,NULL,NULL,'demonspawn.png',0,NULL),(60,'Rat',1,'Claws',3,3,3,9,NULL,NULL,'rat.png',0,NULL),(61,'Weasel',1,'Claws',3,3,3,9,NULL,NULL,'weasel.png',0,NULL),(62,'Ferret',1,'Claws',3,3,3,9,NULL,NULL,'ferret.png',0,NULL),(63,'Elite Town Guard',22,'Melee Weapon',65,65,65,8,80,7000,'eliteguard.png',0,'Fire');
/*!40000 ALTER TABLE `Creature_Type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Super_Category`
--

LOCK TABLES `Super_Category` WRITE;
/*!40000 ALTER TABLE `Super_Category` DISABLE KEYS */;
INSERT INTO `Super_Category` VALUES (1,'Armour'),(2,'Weapon');
/*!40000 ALTER TABLE `Super_Category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Terrain`
--

LOCK TABLES `Terrain` WRITE;
/*!40000 ALTER TABLE `Terrain` DISABLE KEYS */;
INSERT INTO `Terrain` VALUES (1,'medium forest',5,'medium_forest'),(2,'barren',2,'barren'),(3,'marsh',4,'marsh'),(4,'field',3,'field'),(5,'light forest',4,'light_forest'),(6,'dense forest',6,'dense_forest'),(7,'hill',7,'hill'),(8,'mountain',9,'mountain'),(9,'lake',8,'lake'),(10,'town',0,'town'),(11,'chasm',4,'chasm');
/*!40000 ALTER TABLE `Terrain` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Tip`
--

LOCK TABLES `Tip` WRITE;
/*!40000 ALTER TABLE `Tip` DISABLE KEYS */;
INSERT INTO `Tip` VALUES (1,'Find the best shops','Towns with higher prosperity tend to have better shops. Here, you\'ll find a bigger range at cheaper prices. Certain shops within each town will be even better. Make a note of the best ones, and check back often'),(2,'','Increasing your prestige rating with a town can net your party a discount at certain services in the town'),(3,'A good Blacksmith is hard to find','The skill of a town\'s blacksmith increases over time. Check the blacksmith\'s description to see how long he\'s been around'),(4,'','Upgrading your weapons and armour at the blacksmith is an excellent way of getting the most out of your equipment'),(5,'','Quests are an excellent way for new parties to increase their wealth and experience. To start a quest, head to the Town Hall of the nearest town'),(6,'Multi-tasking','You can only get one quest from each town at a time, but there\'s nothing stopping you having several quests from different towns. The maximum quests you can have at a time is determined by your party\'s level. Just make sure you have enough time to complete them all, or the town\'s council won\'t be happy!'),(7,'Finding a quest','The bigger the town (i.e. the higher it\'s prosperity) the more likely it is to have a big selection of quests. Not all quests will be offered to you though - some depend on your party level.'),(8,'Dungeons','Once you\'ve slaughtered a few easy monsters in the wilderness, and got a few easy quests under your belt, it\'s a good idea to head to a dungeon, where you\'ll find a lot of creatures, treasure and more. If you need to find a dungeon in your area, head to the Sage. The dungeons you know about are listed on the \'Map\' screen.'),(9,'Turns','You don\'t need to log into Crown of Conquest every day to make use of all your turns. Turns will accumulate for a few days, before you have to use them or lose them.'),(10,'The Watcher','New parties start with a \'Watcher\' effect, a force that gives you an indication of how tough each group of monsters is. This effect lasts for 20 days - if you need more, one of your mages will have to cast a \'Watcher\' spell.'),(11,'Prosperity','A town\'s prosperity is an indication of how big it is, and how likely it is to have a good range of services at good prices. A number of factors influence a town\'s prosperity. For instance, if a town collects a good amount of tax, and keeps the surrounding wildnerness clear of monsters, it\'s prosperity will likely go up. Your party can nurture a town\'s prosperity, and reap the benefits as its services improve.');
/*!40000 ALTER TABLE `Tip` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Attribute`
--

LOCK TABLES `Item_Attribute` WRITE;
/*!40000 ALTER TABLE `Item_Attribute` DISABLE KEYS */;
INSERT INTO `Item_Attribute` VALUES (21,'8',2,25),(22,'7',2,26),(23,'5',1,25),(24,'2',1,26),(25,'5',4,24),(26,'2',3,24),(27,'10',9,25),(28,'8',9,26),(29,'20',5,27),(30,'2',6,27),(31,'1',10,28),(32,'2',11,28),(35,'3',12,25),(36,'5',12,26),(37,'7',8,29),(38,'4',8,30),(39,'3',8,31),(40,'1',8,32),(41,'15',14,29),(42,'4',14,30),(43,'6',14,31),(44,'',14,32),(45,'1',16,34),(46,'2',17,34),(47,'4',18,28),(48,'1',9,33),(49,'10',19,25),(50,'7',19,26),(51,'1',19,33),(52,'7',20,25),(53,'5',20,26),(54,'',20,33),(55,'22',21,29),(56,'4',21,30),(57,'6',21,31),(58,'1',21,32),(59,'9',23,25),(60,'3',23,26),(61,'',23,33),(62,'6',24,25),(63,'6',24,26),(64,'1',24,33),(65,'12',25,24),(66,'5',26,28),(67,'6',27,25),(68,'9',27,26),(69,'',27,33),(70,'4',28,25),(71,'4',28,26),(72,'',28,33),(73,'8',29,25),(74,'2',29,26),(75,'',29,33),(76,'3',30,25),(77,'5',30,26),(78,'1',30,33),(79,'',12,33),(80,'',2,33),(81,'',1,33),(82,'3',23,35),(83,'3',9,35),(84,'1',12,35),(85,'4',27,35),(86,'3',20,35),(87,'4',2,35),(88,'3',28,35),(89,'2',29,35),(90,'2',30,35),(91,'3',1,35),(92,'1',24,35),(93,'2',19,35),(94,'12',31,25),(95,'10',31,26),(96,'1',31,33),(97,'0',31,35),(98,'5',32,25),(99,'7',32,26),(100,'',32,33),(101,'3',32,35),(102,'6',33,25),(103,'3',33,26),(104,'',33,33),(105,'3',33,35),(106,'7',34,29),(107,'6',34,30),(108,'4',34,31),(109,'1',34,32),(110,'8',35,24),(111,'18',36,24),(112,'4',37,34),(113,'5',38,34),(114,'3',39,34),(115,'22',72,29),(116,'8',72,30),(117,'4',72,31),(118,'1',72,32);
/*!40000 ALTER TABLE `Item_Attribute` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Attribute_Name`
--

LOCK TABLES `Item_Attribute_Name` WRITE;
/*!40000 ALTER TABLE `Item_Attribute_Name` DISABLE KEYS */;
INSERT INTO `Item_Attribute_Name` VALUES (24,'Defence Factor',2,'numeric',NULL),(25,'Damage',1,'numeric',NULL),(26,'Attack Factor',1,'numeric',NULL),(27,'Movement Bonus',3,'numeric',NULL),(28,'Defence Factor',4,'numeric',NULL),(29,'Ammunition',6,'item_type',NULL),(30,'Damage',6,'numeric',NULL),(31,'Attack Factor',6,'numeric',NULL),(32,'Two-Handed',6,'boolean',NULL),(33,'Two-Handed',1,'boolean',NULL),(34,'Defence Factor',7,'numeric',NULL),(35,'Back Rank Penalty',1,'numeric',NULL);
/*!40000 ALTER TABLE `Item_Attribute_Name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Category`
--

LOCK TABLES `Item_Category` WRITE;
/*!40000 ALTER TABLE `Item_Category` DISABLE KEYS */;
INSERT INTO `Item_Category` VALUES (1,'Melee Weapon',2,0,1,1,0,0),(2,'Armour',1,0,1,1,0,0),(3,'Movement',NULL,1,1,1,0,0),(4,'Head Gear',1,0,1,1,0,0),(5,'Ammunition',NULL,0,1,1,0,0),(6,'Ranged Weapon',2,0,1,1,0,0),(7,'Shield',1,0,1,1,0,0),(8,'Jewel',NULL,0,1,0,1,0),(9,'Special Items',NULL,0,0,0,1,0),(10,'Resource',NULL,0,1,0,0,0),(11,'Tool',NULL,1,1,0,0,0),(12,'Magical',NULL,0,0,1,0,0),(13,'Amulet',NULL,0,1,1,0,1),(14,'Ring',NULL,0,1,1,0,1);
/*!40000 ALTER TABLE `Item_Category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Property_Category`
--

LOCK TABLES `Item_Property_Category` WRITE;
/*!40000 ALTER TABLE `Item_Property_Category` DISABLE KEYS */;
INSERT INTO `Item_Property_Category` VALUES (1,'Upgrade'),(2,'Durability');
/*!40000 ALTER TABLE `Item_Property_Category` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Type`
--

LOCK TABLES `Item_Type` WRITE;
/*!40000 ALTER TABLE `Item_Type` DISABLE KEYS */;
INSERT INTO `Item_Type` VALUES (1,'Short Sword',1,10,100,10.00,'1-shortsword.PNG',0,2,1),(2,'Long Sword',1,40,60,25.00,'2-longsword.PNG',0,3,1),(3,'Leather Armour',2,20,85,23.00,'3-leatherarmour.PNG',0,2,2),(4,'Chain Mail',2,70,60,56.00,'4-chainmail.PNG',0,2,2),(5,'Flying Carpet',3,10000,3,1.00,NULL,0,1,1),(6,'Horse',3,500,30,1.00,NULL,0,1,1),(7,'Arrows',5,1,90,0.10,'7-arrows.PNG',0,1,1),(8,'Short Bow',6,55,60,12.00,'8-shortbow.PNG',0,1,1),(9,'Battle Axe',1,130,50,36.00,'9-battleaxe.PNG',0,2,1),(10,'Head Scarf',4,20,50,8.00,'10-headscarf.PNG',0,2,1),(11,'Leather Helmet',4,70,40,14.00,'11-leatherhelmet.PNG',0,2,1),(12,'Dagger',1,10,5,7.00,'12-dagger.PNG',0,1,1),(14,'Sling',6,5,70,5.00,'14-sling.PNG',0,1,1),(15,'Sling Stones',5,1,50,0.20,'15-slingstones.PNG',0,1,1),(16,'Wooden Shield',7,30,80,13.00,'16-woodenshield.PNG',0,1,1),(17,'Large Wooden Shield',7,50,65,19.00,'17-largewoodenshield.PNG',0,2,1),(18,'Bronze Head Cap',4,120,30,19.00,'18-bronzeheadcap.PNG',0,2,1),(19,'Two-Handed Sword',1,80,40,34.00,'19-twohandedsword.PNG',0,3,1),(20,'Hand Axe',1,50,70,18.00,'20-handaxe.PNG',0,2,1),(21,'Small Crossbow',6,120,40,15.00,'21-smallcrossbow.PNG',0,1,1),(22,'Crossbow Bolt',5,1,90,0.10,'22-crossbowbolt.PNG',0,1,1),(23,'Bastard Sword',1,80,20,23.00,'23-bastardsword.PNG',0,3,1),(24,'Spear',1,50,60,20.00,'24-spear.PNG',0,3,1),(25,'Splint Mail',2,300,30,63.00,'25-splintmail.PNG',0,2,2),(26,'Steel Head Cap',4,160,20,26.00,'26-steelheadcap.PNG',0,2,1),(27,'Flail',1,80,50,32.00,'27-flail.PNG',0,2,1),(28,'Mace',1,25,65,29.00,'28-mace.PNG',0,2,1),(29,'Pike',1,120,30,29.00,'29-pike.PNG',0,3,1),(30,'Quarterstaff',1,15,80,18.00,'30-quarterstaff.PNG',0,2,1),(31,'Halberd',1,150,20,38.00,'31-halberd.PNG',0,3,1),(32,'Broadsword',1,40,50,27.00,'32-broadsword.PNG',0,3,1),(33,'War hammer',1,35,30,27.00,'33-warhammer.PNG',0,2,1),(34,'Long Bow',6,90,35,16.00,'34-longbow.PNG',0,3,1),(35,'Scale Mail',2,150,40,72.00,'35-scalemail.PNG',0,2,2),(36,'Full Plate Mail',2,800,15,103.00,'36-fullplatemail.PNG',0,2,2),(37,'Medium Steel Shield',7,120,40,26.00,'37-mediumsteelshield.PNG',0,2,1),(38,'Large Steel Shield',7,180,30,34.00,'38-largesteelshield.PNG',0,2,2),(39,'Small Steel Shield',7,80,50,21.00,'39-smallsteelshield.PNG',0,1,1),(40,'Sapphire',8,50,10,1.00,'40-saphire.PNG',0,1,1),(41,'Emerald',8,60,9,1.00,'41-emerald.PNG',0,1,1),(42,'Topaz',8,70,8,1.00,'42-topaz.PNG',0,1,1),(43,'Ruby',8,90,7,1.00,'43-ruby.PNG',0,1,1),(44,'Pearl',8,40,11,1.00,'44-pearl.PNG',0,1,1),(45,'Moonstone',8,100,6,1.00,'45-moonstone.PNG',0,1,1),(46,'Jade',8,110,5,1.00,'46-jade.PNG',0,1,1),(47,'Diamond',8,120,4,1.00,'47-diamond.PNG',0,1,1),(48,'Gold Nugget',8,100,10,1.00,'48-goldnugget.PNG',0,1,1),(49,'Artifact',9,0,0,1.00,'trinket.png',0,1,1),(50,'Iron',10,70,40,10.00,'50-iron.png',0,1,1),(51,'Clay',10,25,65,7.00,'51-clay.png',0,1,1),(52,'Wood',10,12,70,6.00,'52-wood.png',0,1,1),(53,'Stone',10,35,40,12.00,'53-stone.png',0,1,1),(54,'Mallet',11,50,100,15.00,'54-mallet.png',0,2,1),(55,'Hammer',11,70,100,10.00,'55-hammer.png',0,1,1),(56,'Pickaxe',11,40,100,25.00,'56-pickaxe.png',0,2,1),(57,'Shovel',11,30,100,20.00,'57-shovel.png',0,2,1),(58,'Potion of Healing',12,100,40,5.00,'redpotion.png',1,1,1),(59,'Potion of Strength',12,1000,1,5.00,'potionstrength.png',1,1,1),(60,'Potion of Agility',12,1000,1,5.00,'potionagility.png',1,1,1),(61,'Potion of Constitution',12,1000,1,5.00,'potionconstitution.png',1,1,1),(62,'Potion of Divinity',12,1000,1,5.00,'potiondivinity.png',1,1,1),(63,'Potion of Intelligence',12,1000,1,5.00,'potionintelligence.png',1,1,1),(64,'Potion of Diffusion',12,750,15,5.00,'messypotion.png',1,1,1),(65,'Potion of Clarity',12,1000,7,5.00,'bluepotion.png',1,1,1),(66,'Vial of Dragons Blood',12,50000,1,3.00,'dbloodvial.png',0,1,1),(67,'Scroll',12,20,45,0.10,'writtenscroll1.png',1,1,1),(68,'Blank Scroll',10,20,60,0.10,'emptyscroll1.png',1,1,1),(69,'Amulet',13,100,10,1.00,'amulet.png',0,1,1),(70,'Ring',14,100,20,0.50,'ring.png',0,1,1),(71,'Book Of Past Lives',12,10000,1,10.00,'bookofpastlives.png',1,1,1),(72,'Heavy Crossbow',6,180,20,18.00,'heavycrossbow.png',0,2,1);
/*!40000 ALTER TABLE `Item_Type` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Variable_Name`
--

LOCK TABLES `Item_Variable_Name` WRITE;
/*!40000 ALTER TABLE `Item_Variable_Name` DISABLE KEYS */;
INSERT INTO `Item_Variable_Name` VALUES (1,'Quantity',5,NULL,1),(2,'Damage Upgrade',1,1,0),(3,'Attack Factor Upgrade',1,1,0),(4,'Defence Factor Upgrade',2,1,0),(5,'Attack Factor Upgrade',6,1,0),(6,'Damage Upgrade',6,1,0),(7,'Durability',1,2,1),(8,'Durability',2,2,1),(9,'Durability',6,2,1),(10,'Quantity',10,NULL,1),(11,'Quantity',12,NULL,1),(12,'Quantity',8,NULL,1),(13,'Spell',12,NULL,1),(14,'Max Level',12,NULL,1);
/*!40000 ALTER TABLE `Item_Variable_Name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `Item_Variable_Params`
--

LOCK TABLES `Item_Variable_Params` WRITE;
/*!40000 ALTER TABLE `Item_Variable_Params` DISABLE KEYS */;
INSERT INTO `Item_Variable_Params` VALUES (1,0,1,50,7,1,0),(2,0,1,20,15,1,0),(3,0,1,50,22,1,0),(4,0,0,0,23,2,0),(5,0,0,0,23,3,0),(6,1,80,100,23,7,0),(7,0,0,0,9,2,0),(8,0,0,0,9,3,0),(9,1,80,140,9,7,0),(10,0,0,0,32,2,0),(11,0,0,0,32,3,0),(12,1,60,85,32,7,0),(13,0,0,0,12,2,0),(14,0,0,0,12,3,0),(15,1,100,120,12,7,0),(16,0,0,0,27,2,0),(17,0,0,0,27,3,0),(18,1,60,60,27,7,0),(19,0,0,0,31,2,0),(20,0,0,0,31,3,0),(21,1,90,130,31,7,0),(22,0,0,0,20,2,0),(23,0,0,0,20,3,0),(24,1,70,70,20,7,0),(25,0,0,0,2,2,0),(26,0,0,0,2,3,0),(27,1,100,100,2,7,0),(28,0,0,0,28,2,0),(29,0,0,0,28,3,0),(30,1,50,50,28,7,0),(31,0,0,0,29,2,0),(32,0,0,0,29,3,0),(33,1,80,80,29,7,0),(34,0,0,0,30,2,0),(35,0,0,0,30,3,0),(36,1,50,100,30,7,0),(37,0,0,0,1,2,0),(38,0,0,0,1,3,0),(39,1,70,70,1,7,0),(40,0,0,0,24,2,0),(41,0,0,0,24,3,0),(42,1,80,80,24,7,0),(43,0,0,0,19,2,0),(44,0,0,0,19,3,0),(45,1,90,150,19,7,0),(46,0,0,0,33,2,0),(47,0,0,0,33,3,0),(48,1,70,80,33,7,0),(49,0,0,0,34,5,0),(50,0,0,0,34,6,0),(51,1,100,130,34,9,0),(52,0,0,0,8,5,0),(53,0,0,0,8,6,0),(54,1,90,140,8,9,0),(55,0,0,0,14,5,0),(56,0,0,0,14,6,0),(57,1,40,70,14,9,0),(58,0,0,0,21,5,0),(59,0,0,0,21,6,0),(60,1,60,120,21,9,0),(61,0,0,0,4,4,0),(62,1,140,200,4,8,0),(63,0,0,0,36,4,0),(64,1,160,240,36,8,0),(65,0,0,0,3,4,0),(66,1,60,130,3,8,0),(67,0,0,0,35,4,0),(68,1,80,190,35,8,0),(69,0,0,0,25,4,0),(70,1,80,170,25,8,0),(71,0,1,1000,50,10,0),(72,0,1,500,51,10,0),(73,0,1,500,52,10,0),(74,0,1,500,53,10,0),(75,0,1,1,58,11,0),(76,0,1,1,59,11,0),(77,0,1,1,60,11,0),(78,0,1,1,61,11,0),(79,0,1,1,62,11,0),(80,0,1,1,63,11,0),(81,0,1,1,64,11,0),(82,0,1,1,65,11,0),(83,0,1,1,40,12,0),(84,0,1,1,41,12,0),(85,0,1,1,42,12,0),(86,0,1,1,43,12,0),(87,0,1,1,44,12,0),(88,0,1,1,45,12,0),(89,0,1,1,46,12,0),(90,0,1,1,47,12,0),(91,0,1,1,48,12,0),(92,0,1,1,66,11,0),(93,0,1,1,67,13,1),(94,0,0,0,67,11,0),(95,0,1,40,68,10,0),(96,0,0,0,72,5,0),(97,0,0,0,72,6,0),(98,1,50,130,72,9,0),(99,0,1,1,71,14,1);
/*!40000 ALTER TABLE `Item_Variable_Params` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-02-24 14:49:34
