-- MySQL dump 10.9
--
-- Host: localhost    Database: game
-- ------------------------------------------------------
-- Server version	4.1.11-Debian_4sarge2-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `Class`
--

DROP TABLE IF EXISTS `Class`;
CREATE TABLE `Class` (
  `class_id` int(11) NOT NULL auto_increment,
  `class_name` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Class`
--


/*!40000 ALTER TABLE `Class` DISABLE KEYS */;
LOCK TABLES `Class` WRITE;
INSERT INTO `Class` VALUES (1,'Warrior'),(2,'Archer'),(3,'Mage'),(4,'Priest');
UNLOCK TABLES;
/*!40000 ALTER TABLE `Class` ENABLE KEYS */;

--
-- Table structure for table `Dimension`
--

DROP TABLE IF EXISTS `Dimension`;
CREATE TABLE `Dimension` (
  `group_id` int(11) NOT NULL auto_increment,
  `group_name` char(255) NOT NULL default '',
  PRIMARY KEY  (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Dimension`
--


/*!40000 ALTER TABLE `Dimension` DISABLE KEYS */;
LOCK TABLES `Dimension` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Dimension` ENABLE KEYS */;

--
-- Table structure for table `Item_Category`
--

DROP TABLE IF EXISTS `Item_Category`;
CREATE TABLE `Item_Category` (
  `category_id` int(11) NOT NULL auto_increment,
  `category_name` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Item_Category`
--


/*!40000 ALTER TABLE `Item_Category` DISABLE KEYS */;
LOCK TABLES `Item_Category` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Item_Category` ENABLE KEYS */;

--
-- Table structure for table `Item_Class`
--

DROP TABLE IF EXISTS `Item_Class`;
CREATE TABLE `Item_Class` (
  `class_id` int(11) NOT NULL auto_increment,
  `class_name` varchar(255) NOT NULL default '',
  `basic_modifier` int(11) NOT NULL default '0',
  `category_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`class_id`),
  KEY `fk_Item_Class_Item_Category` (`category_id`),
  CONSTRAINT `fk_Item_Class_Item_Category` FOREIGN KEY (`category_id`) REFERENCES `Item_Category` (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Item_Class`
--


/*!40000 ALTER TABLE `Item_Class` DISABLE KEYS */;
LOCK TABLES `Item_Class` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Item_Class` ENABLE KEYS */;

--
-- Table structure for table `Items`
--

DROP TABLE IF EXISTS `Items`;
CREATE TABLE `Items` (
  `item_id` int(11) NOT NULL auto_increment,
  `class_id` int(11) NOT NULL default '0',
  `magic_modifier` int(11) NOT NULL default '0',
  `name` varchar(255) default NULL,
  `charcter_id` int(11) default NULL,
  PRIMARY KEY  (`item_id`),
  KEY `fk_Items_Character` (`charcter_id`),
  KEY `fk_Items_Item_Class` (`class_id`),
  CONSTRAINT `fk_Items_Character` FOREIGN KEY (`charcter_id`) REFERENCES `P_Character` (`charcter_id`),
  CONSTRAINT `fk_Items_Item_Class` FOREIGN KEY (`class_id`) REFERENCES `Item_Class` (`class_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Items`
--


/*!40000 ALTER TABLE `Items` DISABLE KEYS */;
LOCK TABLES `Items` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Items` ENABLE KEYS */;

--
-- Table structure for table `Land`
--

DROP TABLE IF EXISTS `Land`;
CREATE TABLE `Land` (
  `land_id` int(11) NOT NULL auto_increment,
  `x` bigint(20) NOT NULL default '0',
  `y` int(11) NOT NULL default '0',
  `group_id` int(11) NOT NULL default '0',
  `terrain_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`land_id`),
  KEY `fk_Land_Group` (`group_id`),
  KEY `fk_Land_Terrain` (`terrain_id`),
  CONSTRAINT `fk_Land_Group` FOREIGN KEY (`group_id`) REFERENCES `Dimension` (`group_id`),
  CONSTRAINT `fk_Land_Terrain` FOREIGN KEY (`terrain_id`) REFERENCES `Terrain` (`terrain_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Land`
--


/*!40000 ALTER TABLE `Land` DISABLE KEYS */;
LOCK TABLES `Land` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Land` ENABLE KEYS */;

--
-- Table structure for table `P_Character`
--

DROP TABLE IF EXISTS `P_Character`;
CREATE TABLE `P_Character` (
  `charcter_id` int(11) NOT NULL auto_increment,
  `character_name` char(255) NOT NULL default '',
  `xp` bigint(20) NOT NULL default '0',
  `class_id` int(11) NOT NULL default '0',
  `race_id` int(11) NOT NULL default '0',
  `strength` int(11) NOT NULL default '0',
  `intelligence` int(11) NOT NULL default '0',
  `agility` int(11) NOT NULL default '0',
  `divinity` int(11) NOT NULL default '0',
  `constitution` int(11) NOT NULL default '0',
  `health` int(11) NOT NULL default '0',
  `level` int(11) NOT NULL default '1',
  PRIMARY KEY  (`charcter_id`),
  KEY `fk_Character_Class` (`class_id`),
  KEY `fk_Character_Race` (`race_id`),
  CONSTRAINT `fk_Character_Class` FOREIGN KEY (`class_id`) REFERENCES `Class` (`class_id`),
  CONSTRAINT `fk_Character_Race` FOREIGN KEY (`race_id`) REFERENCES `Race` (`race_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `P_Character`
--


/*!40000 ALTER TABLE `P_Character` DISABLE KEYS */;
LOCK TABLES `P_Character` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `P_Character` ENABLE KEYS */;

--
-- Table structure for table `Party_Character`
--

DROP TABLE IF EXISTS `Party_Character`;
CREATE TABLE `Party_Character` (
  `player_id` int(11) NOT NULL default '0',
  `charcter_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`player_id`,`charcter_id`),
  KEY `fk_Party_Character` (`charcter_id`),
  CONSTRAINT `fk_Party_Character` FOREIGN KEY (`charcter_id`) REFERENCES `P_Character` (`charcter_id`),
  CONSTRAINT `fk_Party_Player` FOREIGN KEY (`player_id`) REFERENCES `Player` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Party_Character`
--


/*!40000 ALTER TABLE `Party_Character` DISABLE KEYS */;
LOCK TABLES `Party_Character` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Party_Character` ENABLE KEYS */;

--
-- Table structure for table `Player`
--

DROP TABLE IF EXISTS `Player`;
CREATE TABLE `Player` (
  `player_id` int(11) NOT NULL auto_increment,
  `player_name` varchar(255) NOT NULL default '',
  `email` varchar(255) NOT NULL default '',
  `password` varchar(255) NOT NULL default '',
  `party_name` varchar(255) default NULL,
  `land_id` int(11) default NULL,
  `party_gold` int(11) NOT NULL default '0',
  PRIMARY KEY  (`player_id`),
  KEY `fk_Player_Land` (`land_id`),
  CONSTRAINT `fk_Player_Land` FOREIGN KEY (`land_id`) REFERENCES `Land` (`land_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Player`
--


/*!40000 ALTER TABLE `Player` DISABLE KEYS */;
LOCK TABLES `Player` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Player` ENABLE KEYS */;

--
-- Table structure for table `Race`
--

DROP TABLE IF EXISTS `Race`;
CREATE TABLE `Race` (
  `race_id` int(11) NOT NULL auto_increment,
  `race_name` varchar(255) NOT NULL default '',
  `base_str` int(11) NOT NULL default '0',
  `base_int` int(11) NOT NULL default '0',
  `base_agl` int(11) NOT NULL default '0',
  `base_div` int(11) NOT NULL default '0',
  `base_con` int(11) NOT NULL default '0',
  PRIMARY KEY  (`race_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Race`
--


/*!40000 ALTER TABLE `Race` DISABLE KEYS */;
LOCK TABLES `Race` WRITE;
INSERT INTO `Race` VALUES (1,'Human',5,5,5,5,5),(2,'Elf',4,7,6,5,3),(3,'Dwarf',5,3,4,6,7);
UNLOCK TABLES;
/*!40000 ALTER TABLE `Race` ENABLE KEYS */;

--
-- Table structure for table `Terrain`
--

DROP TABLE IF EXISTS `Terrain`;
CREATE TABLE `Terrain` (
  `terrain_id` int(11) NOT NULL auto_increment,
  `terrain_name` varchar(255) NOT NULL default '',
  `image` varchar(255) NOT NULL default '',
  `modifier` int(11) NOT NULL default '0',
  PRIMARY KEY  (`terrain_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Dumping data for table `Terrain`
--


/*!40000 ALTER TABLE `Terrain` DISABLE KEYS */;
LOCK TABLES `Terrain` WRITE;
UNLOCK TABLES;
/*!40000 ALTER TABLE `Terrain` ENABLE KEYS */;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
CREATE TABLE `sessions` (
  `id` varchar(32) NOT NULL default '',
  `a_session` text NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `sessions`
--


/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
LOCK TABLES `sessions` WRITE;
INSERT INTO `sessions` VALUES ('3c359336d2aa4ba6aeaef473e22359fc','\0\0\0\n 3c359336d2aa4ba6aeaef473e22359fc\0\0\0_session_id?\0\0\0	player_id'),('b35d65791884ed1a241df63f8ce91e20','\0\0\0\n b35d65791884ed1a241df63f8ce91e20\0\0\0_session_id?\0\0\0	player_id'),('183600c3fb98dafcc02c25595889ccb9','\0\0\0\n 183600c3fb98dafcc02c25595889ccb9\0\0\0_session_id?\0\0\0	player_id'),('97eb19f99bf59ae7d4a0fb582ff9cc0b','\0\0\0\n 97eb19f99bf59ae7d4a0fb582ff9cc0b\0\0\0_session_id?\0\0\0	player_id'),('fb0f4de6d4b512b7b02f53a82be0bc7a','\0\0\0\n fb0f4de6d4b512b7b02f53a82be0bc7a\0\0\0_session_id?\0\0\0	player_id'),('297a2dbfe4651479e8d10eab5046f49b','\0\0\0\n 297a2dbfe4651479e8d10eab5046f49b\0\0\0_session_id?\0\0\0	player_id'),('65f63520c782a7104121f68e83e28bb7','\0\0\0\n 65f63520c782a7104121f68e83e28bb7\0\0\0_session_id?\0\0\0	player_id'),('9ae8a7c095315103b16e5dbfe1278f0b','\0\0\0\n 9ae8a7c095315103b16e5dbfe1278f0b\0\0\0_session_id?\0\0\0	player_id'),('248013a55840395b7c6be116e3c52d8f','\0\0\0\n 248013a55840395b7c6be116e3c52d8f\0\0\0_session_id?\0\0\0	player_id'),('fc630da297a702b01fd2ff8cd1342c39','\0\0\0\n fc630da297a702b01fd2ff8cd1342c39\0\0\0_session_id?\0\0\0	player_id'),('48bb1cecc40c8fdf93096e864d773490','\0\0\0\n 48bb1cecc40c8fdf93096e864d773490\0\0\0_session_id?\0\0\0	player_id'),('8601cee806da4353906310b004136727','\0\0\0\n 8601cee806da4353906310b004136727\0\0\0_session_id?\0\0\0	player_id'),('5e77efcc312c42235d636d053cf2dc25','\0\0\0\n 5e77efcc312c42235d636d053cf2dc25\0\0\0_session_id?\0\0\0	player_id'),('3cecfc24b0f88e84f32688e04cbf38a2','\0\0\0\n 3cecfc24b0f88e84f32688e04cbf38a2\0\0\0_session_id?\0\0\0	player_id'),('f0aa0164f815c29a6cf1492dff16976a','\0\0\0\n f0aa0164f815c29a6cf1492dff16976a\0\0\0_session_id?\0\0\0	player_id'),('7e22ebfc43542975f0c5dde83deee2ba','\0\0\0\n 7e22ebfc43542975f0c5dde83deee2ba\0\0\0_session_id?\0\0\0	player_id'),('ff3ee9c0cab2c79c6d082d17b20b85f8','\0\0\0\n ff3ee9c0cab2c79c6d082d17b20b85f8\0\0\0_session_id?\0\0\0	player_id'),('cc8fb3297b9611135c43365fbec07ea7','\0\0\0\n cc8fb3297b9611135c43365fbec07ea7\0\0\0_session_id?\0\0\0	player_id'),('1da0a5f15f3805a138a3e64e25c9bd5b','\0\0\0\n 1da0a5f15f3805a138a3e64e25c9bd5b\0\0\0_session_id?\0\0\0	player_id'),('ef3c4cf2b203ba57e6208fea8d236314','\0\0\0\n ef3c4cf2b203ba57e6208fea8d236314\0\0\0_session_id?\0\0\0	player_id'),('4d050c90323db7b28dc56975f326c485','\0\0\0\n 4d050c90323db7b28dc56975f326c485\0\0\0_session_id?\0\0\0	player_id'),('7020df13b8995f5e57b01763593e1f51','\0\0\0\n 7020df13b8995f5e57b01763593e1f51\0\0\0_session_id?\0\0\0	player_id'),('1dd783cfb08badd20cf28a6f0e9f9820','\0\0\0\n 1dd783cfb08badd20cf28a6f0e9f9820\0\0\0_session_id?\0\0\0	player_id'),('5ada79979ab3b2f52efce2f5881d562a','\0\0\0\n 5ada79979ab3b2f52efce2f5881d562a\0\0\0_session_id?\0\0\0	player_id'),('2fb7eb85a9c4a76d59a3aea7a1435e0f','\0\0\0\n 2fb7eb85a9c4a76d59a3aea7a1435e0f\0\0\0_session_id?\0\0\0	player_id'),('3b7a40d68acfd210f4f798e9f80592de','\0\0\0\n 3b7a40d68acfd210f4f798e9f80592de\0\0\0_session_id?\0\0\0	player_id'),('b940996e3f50616b60879b82a7ba9fd4','\0\0\0\n b940996e3f50616b60879b82a7ba9fd4\0\0\0_session_id?\0\0\0	player_id'),('cbaf6dee1d6d8b3e476286e7171ba393','\0\0\0\n cbaf6dee1d6d8b3e476286e7171ba393\0\0\0_session_id?\0\0\0	player_id'),('2a8db5d9b4b31bc9c7eefdb3964571b7','\0\0\0\n 2a8db5d9b4b31bc9c7eefdb3964571b7\0\0\0_session_id?\0\0\0	player_id'),('97a048306d78aa6c5a33488994518523','\0\0\0\n 97a048306d78aa6c5a33488994518523\0\0\0_session_id?\0\0\0	player_id'),('7de1b90e02cdffe6f5c8e8493c9ff05b','\0\0\0\n 7de1b90e02cdffe6f5c8e8493c9ff05b\0\0\0_session_id?\0\0\0	player_id'),('482d1315ffbb40bc8a4705bc98462613','\0\0\0\n 482d1315ffbb40bc8a4705bc98462613\0\0\0_session_id?\0\0\0	player_id'),('0b02e8999c61928382df827366c4fe62','\0\0\0\n 0b02e8999c61928382df827366c4fe62\0\0\0_session_id?\0\0\0	player_id'),('7798b580908f745b0a8c5542811856fb','\0\0\0\n 7798b580908f745b0a8c5542811856fb\0\0\0_session_id?\0\0\0	player_id'),('db42fc9b4702660ea90eaef418a9ca2d','\0\0\0\n db42fc9b4702660ea90eaef418a9ca2d\0\0\0_session_id?\0\0\0	player_id'),('6f26f691c40c77649722184ed6b99cdc','\0\0\0\n 6f26f691c40c77649722184ed6b99cdc\0\0\0_session_id?\0\0\0	player_id'),('f06eb98cd33d2ff2fa1f643fba57d517','\0\0\0\n f06eb98cd33d2ff2fa1f643fba57d517\0\0\0_session_id?\0\0\0	player_id'),('c735584998947376a8ca0aea6b5d718a','\0\0\0\n c735584998947376a8ca0aea6b5d718a\0\0\0_session_id?\0\0\0	player_id'),('2950e09619baf92c6c49852eafc60c29','\0\0\0\n 2950e09619baf92c6c49852eafc60c29\0\0\0_session_id?\0\0\0	player_id'),('33f2a668a5cdccc71a0200a1b6f045c6','\0\0\0\n 33f2a668a5cdccc71a0200a1b6f045c6\0\0\0_session_id?\0\0\0	player_id'),('21c809ea86b3382f6004735a1a3acaa0','\0\0\0\n 21c809ea86b3382f6004735a1a3acaa0\0\0\0_session_id?\0\0\0	player_id'),('22ebf9cee27ce9ec6bc566794a692e18','\0\0\0\n 22ebf9cee27ce9ec6bc566794a692e18\0\0\0_session_id?\0\0\0	player_id'),('0c1889c0948e3a54f83399d9a5345cf2','\0\0\0\n 0c1889c0948e3a54f83399d9a5345cf2\0\0\0_session_id?\0\0\0	player_id'),('72458f63ece4b4cb5c865deca4471faf','\0\0\0\n 72458f63ece4b4cb5c865deca4471faf\0\0\0_session_id?\0\0\0	player_id'),('35ae639770f7d7e999ab5591b5b9d866','\0\0\0\n 35ae639770f7d7e999ab5591b5b9d866\0\0\0_session_id?\0\0\0	player_id'),('0be436338f2a543e34142d0e75ebc967','\0\0\0\n 0be436338f2a543e34142d0e75ebc967\0\0\0_session_id?\0\0\0	player_id'),('e6d546ebd0a2c2d2c9a7d5950b75476e','\0\0\0\n e6d546ebd0a2c2d2c9a7d5950b75476e\0\0\0_session_id?\0\0\0	player_id'),('4a7cbce34466c206bd750b0665ae291d','\0\0\0\n 4a7cbce34466c206bd750b0665ae291d\0\0\0_session_id?\0\0\0	player_id'),('1f22cd4ec273ba1d7b3d92d903dfcedd','\0\0\0\n 1f22cd4ec273ba1d7b3d92d903dfcedd\0\0\0_session_id?\0\0\0	player_id'),('f9ea15bc1d52f9ef6912d19c2156187c','\0\0\0\n f9ea15bc1d52f9ef6912d19c2156187c\0\0\0_session_id?\0\0\0	player_id'),('f5b4ed02426f517f2b2826d65f5d7e91','\0\0\0\n f5b4ed02426f517f2b2826d65f5d7e91\0\0\0_session_id?\0\0\0	player_id'),('5177c7ba66b0af89e42b805366f35cf3','\0\0\0\n 5177c7ba66b0af89e42b805366f35cf3\0\0\0_session_id?\0\0\0	player_id'),('0b006674d1278e93003de3bf36a9ffd6','\0\0\0\n 0b006674d1278e93003de3bf36a9ffd6\0\0\0_session_id?\0\0\0	player_id'),('c81b2c1fb43e84b282d669eb432d39a3','\0\0\0\n c81b2c1fb43e84b282d669eb432d39a3\0\0\0_session_id?\0\0\0	player_id'),('290b370c9b0a3d8ff02c5e184a87158c','\0\0\0\n 290b370c9b0a3d8ff02c5e184a87158c\0\0\0_session_id?\0\0\0	player_id'),('4585fb4ff9b040e6572b0a3ecd829d64','\0\0\0\n 4585fb4ff9b040e6572b0a3ecd829d64\0\0\0_session_id?\0\0\0	player_id'),('4102073163f683012b89e14cb1a2e55b','\0\0\0\n 4102073163f683012b89e14cb1a2e55b\0\0\0_session_id?\0\0\0	player_id'),('0758b7d05303b27d5c65b8cd1ef2108c','\0\0\0\n 0758b7d05303b27d5c65b8cd1ef2108c\0\0\0_session_id?\0\0\0	player_id'),('28749eb8d095b74de53b431de12c8ec8','\0\0\0\n 28749eb8d095b74de53b431de12c8ec8\0\0\0_session_id?\0\0\0	player_id'),('9f67ec3f2df14d81a90f62df33dc6fbe','\0\0\0\n 9f67ec3f2df14d81a90f62df33dc6fbe\0\0\0_session_id?\0\0\0	player_id'),('57cc30066661647a21ede04d290f0383','\0\0\0\n 57cc30066661647a21ede04d290f0383\0\0\0_session_id?\0\0\0	player_id'),('bdc372d30fb51c25abb558bf9eacc3e9','\0\0\0\n bdc372d30fb51c25abb558bf9eacc3e9\0\0\0_session_id?\0\0\0	player_id'),('3b4469c69a7810e226ddc48632969b68','\0\0\0\n 3b4469c69a7810e226ddc48632969b68\0\0\0_session_id?\0\0\0	player_id'),('62997b4997360ae690ec07ab26006d54','\0\0\0\n 62997b4997360ae690ec07ab26006d54\0\0\0_session_id?\0\0\0	player_id'),('f989017e08f1b07b15090c0ba5054d22','\0\0\0\n f989017e08f1b07b15090c0ba5054d22\0\0\0_session_id?\0\0\0	player_id'),('a529b038113de00f3cbf6b62439abc95','\0\0\0\n a529b038113de00f3cbf6b62439abc95\0\0\0_session_id?\0\0\0	player_id'),('ffc16fe0a274df09acfce9eca3003129','\0\0\0\n ffc16fe0a274df09acfce9eca3003129\0\0\0_session_id?\0\0\0	player_id'),('54f9f2ba9adafdc74a8498c5304dcc78','\0\0\0\n 54f9f2ba9adafdc74a8498c5304dcc78\0\0\0_session_id?\0\0\0	player_id'),('6d55b976b6abefe81750fd1990b5a538','\0\0\0\n 6d55b976b6abefe81750fd1990b5a538\0\0\0_session_id?\0\0\0	player_id'),('e103fbe766378eee2d2a00aac75b0db3','\0\0\0\n e103fbe766378eee2d2a00aac75b0db3\0\0\0_session_id?\0\0\0	player_id'),('73689207d2b4a5cf634d0f20e4925d43','\0\0\0\n 73689207d2b4a5cf634d0f20e4925d43\0\0\0_session_id?\0\0\0	player_id'),('26ecfda10d5cf8e4c94f5208216bd846','\0\0\0\n 26ecfda10d5cf8e4c94f5208216bd846\0\0\0_session_id?\0\0\0	player_id'),('78e4a788d78adeb5424009c1394fa304','\0\0\0\n 78e4a788d78adeb5424009c1394fa304\0\0\0_session_id?\0\0\0	player_id'),('058beccd386d8dc76e7ae96eba5bcf30','\0\0\0\n 058beccd386d8dc76e7ae96eba5bcf30\0\0\0_session_id?\0\0\0	player_id'),('6cf6fd27c69079dfd379f0e40e658f30','\0\0\0\n 6cf6fd27c69079dfd379f0e40e658f30\0\0\0_session_id?\0\0\0	player_id'),('8428c7b2d2636c3ce2747718e6104ec5','\0\0\0\n 8428c7b2d2636c3ce2747718e6104ec5\0\0\0_session_id?\0\0\0	player_id'),('b4a3489244f4f5d18b55e8f03e317c6b','\0\0\0\n b4a3489244f4f5d18b55e8f03e317c6b\0\0\0_session_id?\0\0\0	player_id'),('991bf43c35a46269765fe0cbe7e8da1a','\0\0\0\n 991bf43c35a46269765fe0cbe7e8da1a\0\0\0_session_id?\0\0\0	player_id'),('d786f58b455d4a6369c45a923190a00f','\0\0\0\n d786f58b455d4a6369c45a923190a00f\0\0\0_session_id?\0\0\0	player_id'),('e82e5db8fd6caac89d3724228837a010','\0\0\0\n e82e5db8fd6caac89d3724228837a010\0\0\0_session_id?\0\0\0	player_id'),('e98aa7c04ea9e925bd28bc005f94ddb2','\0\0\0\n e98aa7c04ea9e925bd28bc005f94ddb2\0\0\0_session_id?\0\0\0	player_id'),('04a75d991c7f2b438042761e3ed6951c','\0\0\0\n 04a75d991c7f2b438042761e3ed6951c\0\0\0_session_id?\0\0\0	player_id'),('a5f6f733c43911588aae914730593a3f','\0\0\0\n a5f6f733c43911588aae914730593a3f\0\0\0_session_id?\0\0\0	player_id'),('61d7783c620bac0fb43bcae4adca595b','\0\0\0\n 61d7783c620bac0fb43bcae4adca595b\0\0\0_session_id?\0\0\0	player_id'),('b4990d71b2824417c2fb3a9b9d3b56ca','\0\0\0\n b4990d71b2824417c2fb3a9b9d3b56ca\0\0\0_session_id?\0\0\0	player_id'),('75401394df0ae050e49e137fb07118ac','\0\0\0\n 75401394df0ae050e49e137fb07118ac\0\0\0_session_id?\0\0\0	player_id'),('27463afa4a99ed59f5a50df79a1c696c','\0\0\0\n 27463afa4a99ed59f5a50df79a1c696c\0\0\0_session_id?\0\0\0	player_id'),('0f22b10e828afa1617d565a3ba73cecf','\0\0\0\n 0f22b10e828afa1617d565a3ba73cecf\0\0\0_session_id?\0\0\0	player_id'),('ca4826e4756d86bb4611fbf42aacccea','\0\0\0\n ca4826e4756d86bb4611fbf42aacccea\0\0\0_session_id?\0\0\0	player_id'),('d2d72cf543d5a0827413a8c65c4fe357','\0\0\0\n d2d72cf543d5a0827413a8c65c4fe357\0\0\0_session_id?\0\0\0	player_id'),('cb7ad8bb27a1dda4965b27ce7b31f979','\0\0\0\n cb7ad8bb27a1dda4965b27ce7b31f979\0\0\0_session_id?\0\0\0	player_id'),('11d2c029ae838491238ae993c3719ec2','\0\0\0\n 11d2c029ae838491238ae993c3719ec2\0\0\0_session_id?\0\0\0	player_id'),('900fe9acb83939ca7b41f7bc725f57bf','\0\0\0\n 900fe9acb83939ca7b41f7bc725f57bf\0\0\0_session_id?\0\0\0	player_id'),('5dabac587ccea15b4418ac6b76cc5606','\0\0\0\n 5dabac587ccea15b4418ac6b76cc5606\0\0\0_session_id?\0\0\0	player_id'),('4f2299a4914c7a66199ce9046e11fc54','\0\0\0\n 4f2299a4914c7a66199ce9046e11fc54\0\0\0_session_id?\0\0\0	player_id'),('d1371dc6f0524b97db4c37c1a50c7790','\0\0\0\n d1371dc6f0524b97db4c37c1a50c7790\0\0\0_session_id?\0\0\0	player_id'),('0545f2299906bb0f4086c2b02d3d7ada','\0\0\0\n 0545f2299906bb0f4086c2b02d3d7ada\0\0\0_session_id?\0\0\0	player_id'),('1be06a3c00cc8a435c2866a6d9d80b93','\0\0\0\n 1be06a3c00cc8a435c2866a6d9d80b93\0\0\0_session_id?\0\0\0	player_id'),('c421059c2694912594c4f5af4aa0c1fe','\0\0\0\n c421059c2694912594c4f5af4aa0c1fe\0\0\0_session_id?\0\0\0	player_id'),('d6ba71ace18410fdec80e750ede1c4e8','\0\0\0\n d6ba71ace18410fdec80e750ede1c4e8\0\0\0_session_id?\0\0\0	player_id'),('2f93fc4b0b2624410eb3278f2ee9293c','\0\0\0\n 2f93fc4b0b2624410eb3278f2ee9293c\0\0\0_session_id?\0\0\0	player_id'),('55b9de2f6b7c470895ca305731ae3570','\0\0\0\n 55b9de2f6b7c470895ca305731ae3570\0\0\0_session_id?\0\0\0	player_id'),('42246bdad19e756741587be2d0cd646b','\0\0\0\n 42246bdad19e756741587be2d0cd646b\0\0\0_session_id?\0\0\0	player_id'),('0e0a9171f7a32da259748edd731e4dcb','\0\0\0\n 0e0a9171f7a32da259748edd731e4dcb\0\0\0_session_id?\0\0\0	player_id'),('fb98f4ff51a9d29968f7f01d14011cfa','\0\0\0\n fb98f4ff51a9d29968f7f01d14011cfa\0\0\0_session_id?\0\0\0	player_id'),('8b7743fd15087a23871bcb423cfd9f4f','\0\0\0\n 8b7743fd15087a23871bcb423cfd9f4f\0\0\0_session_id?\0\0\0	player_id'),('ead1f20ef9ea5271886cdfe673ab0072','\0\0\0\n ead1f20ef9ea5271886cdfe673ab0072\0\0\0_session_id?\0\0\0	player_id'),('bfc9ceb5923fd86d8e2061ebe35132b2','\0\0\0\n bfc9ceb5923fd86d8e2061ebe35132b2\0\0\0_session_id?\0\0\0	player_id'),('b6b9e2dec3f498b326e41e83ed0c0e7e','\0\0\0\n b6b9e2dec3f498b326e41e83ed0c0e7e\0\0\0_session_id?\0\0\0	player_id');
UNLOCK TABLES;
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

