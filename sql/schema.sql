CREATE TABLE artist (
  id INT(11) NOT NULL auto_increment,
  name VARCHAR(255) NOT NULL,
  UNIQUE name (name),
  PRIMARY KEY (id)
);

CREATE TABLE genre (
  id INT(11) NOT NULL auto_increment,
  name VARCHAR(124) NOT NULL,
  UNIQUE name (name),
  PRIMARY KEY (id)
);

CREATE TABLE album (
  id INT(11) NOT NULL auto_increment,
  discid VARCHAR(255),
  name VARCHAR(255) NOT NULL,
  year VARCHAR(4),
  comment TEXT,
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
  UNIQUE track_data (track_id,file_name),
  PRIMARY KEY (id)
);

CREATE TABLE playlist (
  id INT(11) NOT NULL auto_increment,  
  name varchar(64) NOT NULL,
  PRIMARY KEY (id)
);

--
-- track_order might be null; we can use null as a temporary 
-- order when we will be changing track order.
--  
CREATE TABLE playlist_track (
  playlist_id INT(11) NOT NULL,
  track_id INT(11) NOT NULL,
  track_order INT NOT NULL
);

--
-- table where we store current "playlist", it will be working copy of
-- the real playlist, or we will just add song from menu as times go..
-- it is not temporary table because it's better to be able to access date
-- after session duration
--
CREATE TABLE playlist_current (
  zone INT(11) NOT NULL,
  track_id INT(11) NOT NULL,
  track_order INT(11) NOT NULL,
  track_played INT(11) NULL
);

CREATE TABLE zone_mem (
  zone INT(11) NOT NULL,
  `key` varchar(32) NOT NULL,
  value varchar(64),
  UNIQUE zone_key (zone,`key`)
);

INSERT INTO genre VALUES (123, 'A Cappella');
INSERT INTO genre VALUES (34, 'Acid');
INSERT INTO genre VALUES (74, 'Acid Jazz');
INSERT INTO genre VALUES (73, 'Acid Punk');
INSERT INTO genre VALUES (99, 'Acoustic');
INSERT INTO genre VALUES (20, 'Alternative');
INSERT INTO genre VALUES (40, 'Alt. Rock');
INSERT INTO genre VALUES (26, 'Ambient');
INSERT INTO genre VALUES (145, 'Anime');
INSERT INTO genre VALUES (90, 'Avantgarde');
INSERT INTO genre VALUES (116, 'Ballad');
INSERT INTO genre VALUES (41, 'Bass');
INSERT INTO genre VALUES (135, 'Beat');
INSERT INTO genre VALUES (85, 'Bebob');
INSERT INTO genre VALUES (96, 'Big Band');
INSERT INTO genre VALUES (138, 'Black Metal');
INSERT INTO genre VALUES (89, 'Bluegrass');
INSERT INTO genre VALUES (0, 'Blues');
INSERT INTO genre VALUES (107, 'Booty Bass');
INSERT INTO genre VALUES (132, 'BritPop');
INSERT INTO genre VALUES (65, 'Cabaret');
INSERT INTO genre VALUES (88, 'Celtic');
INSERT INTO genre VALUES (104, 'Chamber Music');
INSERT INTO genre VALUES (102, 'Chanson');
INSERT INTO genre VALUES (97, 'Chorus');
INSERT INTO genre VALUES (136, 'Christian Gangsta Rap');
INSERT INTO genre VALUES (61, 'Christian Rap');
INSERT INTO genre VALUES (141, 'Christian Rock');
INSERT INTO genre VALUES (32, 'Classical');
INSERT INTO genre VALUES (1, 'Classic Rock');
INSERT INTO genre VALUES (112, 'Club');
INSERT INTO genre VALUES (128, 'Club-House');
INSERT INTO genre VALUES (57, 'Comedy');
INSERT INTO genre VALUES (140, 'Contemporary Christian');
INSERT INTO genre VALUES (2, 'Country');
INSERT INTO genre VALUES (139, 'Crossover');
INSERT INTO genre VALUES (58, 'Cult');
INSERT INTO genre VALUES (3, 'Dance');
INSERT INTO genre VALUES (125, 'Dance Hall');
INSERT INTO genre VALUES (50, 'Darkwave');
INSERT INTO genre VALUES (22, 'Death Metal');
INSERT INTO genre VALUES (4, 'Disco');
INSERT INTO genre VALUES (55, 'Dream');
INSERT INTO genre VALUES (127, 'Drum & Bass');
INSERT INTO genre VALUES (122, 'Drum Solo');
INSERT INTO genre VALUES (120, 'Duet');
INSERT INTO genre VALUES (98, 'Easy Listening');
INSERT INTO genre VALUES (52, 'Electronic');
INSERT INTO genre VALUES (48, 'Ethnic');
INSERT INTO genre VALUES (54, 'Eurodance');
INSERT INTO genre VALUES (124, 'Euro-House');
INSERT INTO genre VALUES (25, 'Euro-Techno');
INSERT INTO genre VALUES (84, 'Fast-Fusion');
INSERT INTO genre VALUES (80, 'Folk');
INSERT INTO genre VALUES (115, 'Folklore');
INSERT INTO genre VALUES (81, 'Folk/Rock');
INSERT INTO genre VALUES (119, 'Freestyle');
INSERT INTO genre VALUES (5, 'Funk');
INSERT INTO genre VALUES (30, 'Fusion');
INSERT INTO genre VALUES (36, 'Game');
INSERT INTO genre VALUES (59, 'Gangsta Rap');
INSERT INTO genre VALUES (126, 'Goa');
INSERT INTO genre VALUES (38, 'Gospel');
INSERT INTO genre VALUES (49, 'Gothic');
INSERT INTO genre VALUES (91, 'Gothic Rock');
INSERT INTO genre VALUES (6, 'Grunge');
INSERT INTO genre VALUES (129, 'Hardcore');
INSERT INTO genre VALUES (79, 'Hard Rock');
INSERT INTO genre VALUES (137, 'Heavy Metal');
INSERT INTO genre VALUES (7, 'Hip-Hop');
INSERT INTO genre VALUES (35, 'House');
INSERT INTO genre VALUES (100, 'Humour');
INSERT INTO genre VALUES (131, 'Indie');
INSERT INTO genre VALUES (19, 'Industrial');
INSERT INTO genre VALUES (33, 'Instrumental');
INSERT INTO genre VALUES (46, 'Instrumental Pop');
INSERT INTO genre VALUES (47, 'Instrumental Rock');
INSERT INTO genre VALUES (8, 'Jazz');
INSERT INTO genre VALUES (29, 'Jazz+Funk');
INSERT INTO genre VALUES (146, 'JPop');
INSERT INTO genre VALUES (63, 'Jungle');
INSERT INTO genre VALUES (86, 'Latin');
INSERT INTO genre VALUES (71, 'Lo-Fi');
INSERT INTO genre VALUES (45, 'Meditative');
INSERT INTO genre VALUES (142, 'Merengue');
INSERT INTO genre VALUES (9, 'Metal');
INSERT INTO genre VALUES (77, 'Musical');
INSERT INTO genre VALUES (82, 'National Folk');
INSERT INTO genre VALUES (64, 'Native American');
INSERT INTO genre VALUES (133, 'Negerpunk');
INSERT INTO genre VALUES (10, 'New Age');
INSERT INTO genre VALUES (66, 'New Wave');
INSERT INTO genre VALUES (39, 'Noise');
INSERT INTO genre VALUES (11, 'Oldies');
INSERT INTO genre VALUES (103, 'Opera');
INSERT INTO genre VALUES (12, 'Other');
INSERT INTO genre VALUES (75, 'Polka');
INSERT INTO genre VALUES (134, 'Polsk Punk');
INSERT INTO genre VALUES (13, 'Pop');
INSERT INTO genre VALUES (53, 'Pop-Folk');
INSERT INTO genre VALUES (62, 'Pop/Funk');
INSERT INTO genre VALUES (109, 'Porn Groove');
INSERT INTO genre VALUES (117, 'Power Ballad');
INSERT INTO genre VALUES (23, 'Pranks');
INSERT INTO genre VALUES (108, 'Primus');
INSERT INTO genre VALUES (92, 'Progressive Rock');
INSERT INTO genre VALUES (67, 'Psychedelic');
INSERT INTO genre VALUES (93, 'Psychedelic Rock');
INSERT INTO genre VALUES (43, 'Punk');
INSERT INTO genre VALUES (121, 'Punk Rock');
INSERT INTO genre VALUES (15, 'Rap');
INSERT INTO genre VALUES (68, 'Rave');
INSERT INTO genre VALUES (14, 'R&B');
INSERT INTO genre VALUES (16, 'Reggae');
INSERT INTO genre VALUES (76, 'Retro');
INSERT INTO genre VALUES (87, 'Revival');
INSERT INTO genre VALUES (118, 'Rhythmic Soul');
INSERT INTO genre VALUES (17, 'Rock');
INSERT INTO genre VALUES (78, 'Rock & Roll');
INSERT INTO genre VALUES (143, 'Salsa');
INSERT INTO genre VALUES (114, 'Samba');
INSERT INTO genre VALUES (110, 'Satire');
INSERT INTO genre VALUES (69, 'Showtunes');
INSERT INTO genre VALUES (21, 'Ska');
INSERT INTO genre VALUES (111, 'Slow Jam');
INSERT INTO genre VALUES (95, 'Slow Rock');
INSERT INTO genre VALUES (105, 'Sonata');
INSERT INTO genre VALUES (42, 'Soul');
INSERT INTO genre VALUES (37, 'Sound Clip');
INSERT INTO genre VALUES (24, 'Soundtrack');
INSERT INTO genre VALUES (56, 'Southern Rock');
INSERT INTO genre VALUES (44, 'Space');
INSERT INTO genre VALUES (101, 'Speech');
INSERT INTO genre VALUES (83, 'Swing');
INSERT INTO genre VALUES (94, 'Symphonic Rock');
INSERT INTO genre VALUES (106, 'Symphony');
INSERT INTO genre VALUES (147, 'Synthpop');
INSERT INTO genre VALUES (113, 'Tango');
INSERT INTO genre VALUES (18, 'Techno');
INSERT INTO genre VALUES (51, 'Techno-Industrial');
INSERT INTO genre VALUES (130, 'Terror');
INSERT INTO genre VALUES (144, 'Thrash Metal');
INSERT INTO genre VALUES (60, 'Top 40');
INSERT INTO genre VALUES (70, 'Trailer');
INSERT INTO genre VALUES (31, 'Trance');
INSERT INTO genre VALUES (72, 'Tribal');
INSERT INTO genre VALUES (27, 'Trip-Hop');
INSERT INTO genre VALUES (28, 'Vocal');
INSERT INTO genre VALUES (255, 'Unknown');
