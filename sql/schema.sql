CREATE TABLE artist (
  id INT(11) NOT NULL auto_increment,
  name VARCHAR(255) NOT NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE name (name),
  PRIMARY KEY (id)
);

CREATE TABLE genre (
  id INT(11) NOT NULL auto_increment,
  name VARCHAR(124) NOT NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE name (name),
  PRIMARY KEY (id)
);

CREATE TABLE album (
  id INT(11) NOT NULL auto_increment,
  discid VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  year VARCHAR(4),
  comment TEXT,
  cover VARCHAR(255),
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE discid (discid),
  PRIMARY KEY (id)
);

CREATE TABLE track (
  id INT(11) NOT NULL auto_increment,
  album_id INT(11),
  artist_id INT(11),
  genre_id INT(11),
  title VARCHAR(255) NOT NULL,
  track_num SMALLINT NOT NULL,
  length_seconds INT,
  ctime timestamp,
  comment text,
  year varchar(4),
  composer varchar(255),
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE track (album_id,artist_id,title),
  PRIMARY KEY (id)
);

CREATE TABLE track_data (
  id INT(11) NOT NULL auto_increment,
  track_id INT(11),
  file_location TEXT NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_type VARCHAR(4) NOT NULL,
  bitrate SMALLINT,
  filesize INT,
  info_source VARCHAR(32),
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE track_data (track_id,file_name),
  PRIMARY KEY (id)
);

CREATE TABLE playlist (
  id INT(11) NOT NULL auto_increment,  
  name varchar(64) NOT NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  PRIMARY KEY (id)
);

--
-- track_order might be null; we can use null as a temporary 
-- order when we will be changing track order.
--  
CREATE TABLE playlist_track (
  id INT(11) NOT NULL auto_increment, 
  playlist_id INT(11) NOT NULL,
  track_id INT(11) NOT NULL,
  track_order INT NOT NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE playlist_track (playlist_id,track_id,track_order),
  PRIMARY KEY (id)
);

--
-- table where we store current "playlist", it will be working copy of
-- the real playlist, or we will just add song from menu as times go..
-- it is not temporary table because it's better to be able to access date
-- after session duration
--
CREATE TABLE playlist_current (
  id INT(11) NOT NULL auto_increment,
  zone INT(11) NOT NULL,
  track_id INT(11) NOT NULL,
  track_order INT(11) NOT NULL,
  track_played INT(11) NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE playlist_track (zone,track_id,track_order),
  PRIMARY KEY (id)
);

CREATE TABLE zone (
  id INT(11) NOT NULL auto_increment,
  name VARCHAR(124) NOT NULL,
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE name (name),
  PRIMARY KEY (id)
);

INSERT INTO zone (id,name) VALUES (1,'Lounge');

CREATE TABLE zone_mem (
  id INT(11) NOT NULL auto_increment,
  zone INT(11) NOT NULL,
  param varchar(32) NOT NULL,
  value varchar(64),
  _perm_user INT(16) DEFAULT '1',
  _perm_group INT(16) DEFAULT '1',
  _perm_access INT(16) DEFAULT '664',
  UNIQUE zone_key (zone,param),
  PRIMARY KEY (id)
);

CREATE TABLE `Session` (
  `id` varchar(24) NOT NULL default '',
  `parent_id` varchar(24) NOT NULL default '0',
  `user_id` varchar(24) NOT NULL default '0',
  `self_url` blob,
  `created` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO `genre` (id,name) VALUES (123,'A Cappella'),(34,'Acid'),(74,'Acid Jazz'),(73,'Acid Punk'),(99,'Acoustic'),(20,'Alternative'),(40,'Alt. Rock'),(26,'Ambient'),(145,'Anime'),(90,'Avantgarde'),(116,'Ballad'),(41,'Bass'),(135,'Beat'),(85,'Bebob'),(96,'Big Band'),(138,'Black Metal'),(89,'Bluegrass'),(146,'Blues'),(107,'Booty Bass'),(132,'BritPop'),(65,'Cabaret'),(88,'Celtic'),(104,'Chamber Music'),(102,'Chanson'),(97,'Chorus'),(136,'Christian Gangsta Rap'),(61,'Christian Rap'),(141,'Christian Rock'),(32,'Classical'),(1,'Classic Rock'),(112,'Club'),(128,'Club-House'),(57,'Comedy'),(140,'Contemporary Christian'),(2,'Country'),(139,'Crossover'),(58,'Cult'),(3,'Dance'),(125,'Dance Hall'),(50,'Darkwave'),(22,'Death Metal'),(4,'Disco'),(55,'Dream'),(127,'Drum & Bass'),(122,'Drum Solo'),(120,'Duet'),(98,'Easy Listening'),(52,'Electronic'),(48,'Ethnic'),(54,'Eurodance'),(124,'Euro-House'),(25,'Euro-Techno'),(84,'Fast-Fusion'),(80,'Folk'),(115,'Folklore'),(81,'Folk/Rock'),(119,'Freestyle'),(5,'Funk'),(30,'Fusion'),(36,'Game'),(59,'Gangsta Rap'),(126,'Goa'),(38,'Gospel'),(49,'Gothic'),(91,'Gothic Rock'),(6,'Grunge'),(129,'Hardcore'),(79,'Hard Rock'),(137,'Heavy Metal'),(7,'Hip-Hop'),(35,'House'),(100,'Humour'),(131,'Indie'),(19,'Industrial'),(33,'Instrumental'),(46,'Instrumental Pop'),(47,'Instrumental Rock'),(8,'Jazz'),(29,'Jazz+Funk'),(63,'Jungle'),(86,'Latin'),(71,'Lo-Fi'),(45,'Meditative'),(142,'Merengue'),(9,'Metal'),(77,'Musical'),(82,'National Folk'),(64,'Native American'),(133,'Negerpunk'),(10,'New Age'),(66,'New Wave'),(39,'Noise'),(11,'Oldies'),(103,'Opera'),(12,'Other'),(75,'Polka'),(134,'Polsk Punk'),(13,'Pop'),(53,'Pop-Folk'),(62,'Pop/Funk'),(109,'Porn Groove'),(117,'Power Ballad'),(23,'Pranks'),(108,'Primus'),(92,'Progressive Rock'),(67,'Psychedelic'),(93,'Psychedelic Rock'),(43,'Punk'),(121,'Punk Rock'),(15,'Rap'),(68,'Rave'),(14,'R&B'),(16,'Reggae'),(76,'Retro'),(87,'Revival'),(118,'Rhythmic Soul'),(17,'Rock'),(78,'Rock & Roll'),(143,'Salsa'),(114,'Samba'),(110,'Satire'),(69,'Showtunes'),(21,'Ska'),(111,'Slow Jam'),(95,'Slow Rock'),(105,'Sonata'),(42,'Soul'),(37,'Sound Clip'),(24,'Soundtrack'),(56,'Southern Rock'),(44,'Space'),(101,'Speech'),(83,'Swing'),(94,'Symphonic Rock'),(106,'Symphony'),(147,'Synthpop'),(113,'Tango'),(18,'Techno'),(51,'Techno-Industrial'),(130,'Terror'),(144,'Thrash Metal'),(60,'Top 40'),(70,'Trailer'),(31,'Trance'),(72,'Tribal'),(27,'Trip-Hop'),(28,'Vocal'),(255,'Unknown'),(256,'Misc');
