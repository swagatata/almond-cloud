create database if not exists thingengine_selfcontained ;
grant all on thingengine_selfcontained.* to 'thingengine'@'localhost' identified by 'thingengine';

use thingengine_selfcontained ;

drop table if exists device_class_kind cascade;
drop table if exists app_device cascade;
drop table if exists app_tag cascade;
drop table if exists device_code_version cascade;
drop table if exists device_schema_version cascade;
drop table if exists device_schema_channels cascade;
drop table if exists device_schema_arguments cascade;
drop table if exists example_utterances cascade;
drop table if exists device_schema cascade;
drop table if exists device_class_tag cascade;
drop table if exists device_class cascade;
drop table if exists app cascade;
drop table if exists oauth2_access_tokens cascade;
drop table if exists oauth2_auth_codes cascade;
drop table if exists users cascade;
drop table if exists oauth2_clients cascade;
drop table if exists category;
drop table if exists organizations cascade;

create table organizations (
    id integer auto_increment primary key,
    name varchar(255) not null collate utf8_general_ci,
    developer_key char(64) unique not null
) collate = utf8_bin ;

insert into organizations values (
    1, 'Site Administration', '0243de281cf4892575bef0477c177387fac1883ce4e7dd558eaf0e10777bd194'
);

create table users (
    id integer auto_increment primary key,
    username varchar(255) unique not null,
    human_name tinytext default null collate utf8_general_ci,
    email varchar(255) not null,
    google_id varchar(255) unique default null,
    facebook_id varchar(255) unique default null,
    omlet_id varchar(255) unique default null,
    password char(64) default null,
    salt char(64) default null,
    cloud_id char(64) unique not null,
    auth_token char(64) not null,
    developer_org int null default null,
    developer_status tinyint not null default 0,
    roles tinyint not null default 0,
    force_separate_process boolean not null default false,
    constraint password_salt check ((password is not null and salt is not null) or
                                    (password is null and salt is null)),
    constraint auth_method check (password is not null or google_id is not null or facebook_id is not null),
    foreign key (developer_org) references organizations(id) on update cascade on delete restrict
) collate = utf8_bin ;

insert into users values (
    1, 'root', 'Administrator', 'root@localhost', null, null, null,
    'a266940f93a5928c96b50c173c26cad2054c8077e1caa63584dfcfaa4881d2f1', -- password
    '00832c5af6048c2fc9713722ef0c896202e2f1b30a746394900fb0e8132d958d', -- salt
    '5f9ea96b5ce8c0b1ab675fd1cd614af7e707332ec461cb96fea7a4414202ee02', -- cloud_id
    '6311efb5e042580a3ccd95c6104af72865195fb94045104d6784533b39f77fd6', -- auth_token
    1, 3, 1, false );

create table oauth2_clients (
    id char(64) primary key,
    secret char(64) not null,
    magic_power boolean not null default false
) collate = utf8_bin ;

create table oauth2_access_tokens (
    user_id integer,
    client_id char(64),
    token char(64) not null,
    primary key (user_id, client_id),
    unique key (token),
    foreign key (user_id) references users(id) on update cascade on delete cascade,
    foreign key (client_id) references oauth2_clients(id) on update cascade on delete cascade
) collate = utf8_bin;

create table oauth2_auth_codes (
    user_id integer,
    client_id char(64),
    code char(64),
    redirectURI tinytext,
    primary key (user_id, client_id),
    key (code),
    foreign key (user_id) references users(id) on update cascade on delete cascade,
    foreign key (client_id) references oauth2_clients(id) on update cascade on delete cascade
) collate = utf8_bin;

create table app (
    id integer auto_increment primary key,
    owner integer,
    app_id varchar(255) not null,
    name varchar(255) not null collate utf8_general_ci,
    description text not null collate utf8_general_ci,
    canonical text null collate utf8_general_ci,
    code mediumtext not null,
    visible boolean not null default false,
    unique key (owner, app_id),
    foreign key (owner) references users(id) on update cascade on delete set null
) collate = utf8_bin;

create table device_class (
    id integer auto_increment primary key,
    primary_kind varchar(128) unique not null,
    global_name varchar(128) unique default null,
    owner integer not null,
    name varchar(255) not null collate utf8_general_ci,
    description text not null collate utf8_general_ci,
    fullcode boolean not null default false,
    approved_version integer(11) default null,
    developer_version integer(11) not null default 0,
    foreign key (owner) references organizations(id) on update cascade on delete cascade,
    constraint version check (approved_version is null or developer_version >= approved_version)
) collate utf8_bin;

create table device_schema (
    id integer auto_increment primary key,
    kind varchar(128) unique not null,
    kind_type enum('primary', 'global', 'other') not null default 'other',
    owner integer not null,
    developer_version integer(11) not null default 0,
    approved_version integer(11) default null,
    foreign key (owner) references organizations(id) on update cascade on delete cascade
) collate utf8_bin;

create table device_schema_version (
    schema_id integer not null,
    version integer not null,
    types mediumtext not null,
    meta mediumtext not null,
    primary key(schema_id, version),
    foreign key (schema_id) references device_schema(id) on update cascade on delete cascade
) collate utf8_bin;

create table device_schema_channels (
    schema_id integer not null,
    version integer not null,
    name varchar(128) not null,
    channel_type enum('trigger', 'action', 'query') not null,
    canonical text null collate utf8_general_ci,
    confirmation varchar(255) collate utf8_general_ci default null,
    types mediumtext not null,
    argnames mediumtext not null,
    required mediumtext not null,
    doc mediumtext not null,
    questions mediumtext not null collate utf8_general_ci,
    primary key(schema_id, version, name),
    key canonical_btree (canonical(30)),
    foreign key (schema_id) references device_schema(id) on update cascade on delete cascade,
    fulltext key(canonical)
) collate utf8_bin;

create table device_schema_arguments (
    argname varchar(128) not null,
    argtype varchar(128) not null,
    required boolean not null,
    schema_id integer not null,
    version integer not null,
    channel_name varchar(128) not null,

    -- canonical attribute is to handle splitting "inReplyTo" to become "in reply to"
    -- or "from_channel" to be "from channel"
    canonical tinytext not null,
    primary key(argname, argtype, schema_id, version, channel_name),
    fulltext key(canonical),
    foreign key (schema_id) references device_schema(id) on update cascade on delete cascade
) collate utf8_bin;

create table example_utterances (
    id integer auto_increment primary key,
    schema_id integer null,
    is_base boolean default false,
    utterance text not null collate utf8_general_ci,
    target_json text not null,
    key(schema_id),
    fulltext key(utterance)
) collate utf8_bin;

create table device_code_version (
    device_id integer not null,
    version integer not null,
    code mediumtext not null,
    primary key(device_id, version),
    foreign key (device_id) references device_class(id) on update cascade on delete cascade
) collate utf8_bin;

create table app_device (
    app_id integer not null,
    device_id integer not null,
    primary key (app_id, device_id),
    foreign key (app_id) references app(id) on update cascade on delete cascade,
    foreign key (device_id) references device_class(id) on update cascade on delete cascade
) collate utf8_bin;

create table app_tag (
    id integer auto_increment primary key,
    app_id integer not null,
    tag varchar(255) not null collate utf8_general_ci,
    key(tag),
    foreign key (app_id) references app(id) on update cascade on delete cascade
) collate utf8_bin;

create table device_class_tag (
    tag varchar(128) not null,
    device_id integer not null,
    primary key(tag, device_id),
    foreign key (device_id) references device_class(id) on update cascade on delete restrict
) collate utf8_bin;

create table device_class_kind (
    device_id integer not null,
    kind varchar(128) not null,
    is_child boolean not null default false,
    primary key(device_id, kind),
    foreign key (device_id) references device_class(id) on update cascade on delete cascade
) collate utf8_bin;

create table category (
    id integer auto_increment primary key,
    catchphrase varchar(255) not null collate utf8_general_ci,
    name varchar(255) not null collate utf8_general_ci,
    description mediumtext not null collate utf8_general_ci,
    tag varchar(255) not null collate utf8_general_ci,
    icon varchar(255) not null,
    order_position integer not null default 0,
    key(order_position)
) collate utf8_bin;

LOCK TABLES `category` WRITE;
/*!40000 ALTER TABLE `category` DISABLE KEYS */;
INSERT INTO `category` VALUES
(3,'Play with Your Friends','Social apps','Share them with your friends!','social','thumbs-up',2),
(4,'Stay Alert','Notifications','Never miss a thing','notify','bell',-1),
(5,'Connect Your Home','IoT for the Home','Your home, everywhere','home','home',5),
(6,'Stay Healthy','Health & Fitness Apps','In Soviet gym, fat burns You!','fitness','heart',4);
/*!40000 ALTER TABLE `category` ENABLE KEYS */;
UNLOCK TABLES;

LOCK TABLES `device_class` WRITE;
/*!40000 ALTER TABLE `device_class` DISABLE KEYS */;
INSERT INTO `device_class` VALUES
(8,'org.thingpedia.builtin.omlet','omlet',1,'Omlet Account','Connect your Omlet Account to ThingEngine to enable new social network features!',0,0,0),
(22,'org.thingpedia.builtin.sabrina','sabrina',1,'Sabrina','Your magic assistant, at your service.',0,0,0);
/*!40000 ALTER TABLE `device_class` ENABLE KEYS */;
UNLOCK TABLES;

LOCK TABLES `device_class_tag` WRITE;
/*!40000 ALTER TABLE `device_class_tag` DISABLE KEYS */;
INSERT INTO `device_class_tag` VALUES ('featured',8),('featured',22);
/*!40000 ALTER TABLE `device_class_tag` ENABLE KEYS */;
UNLOCK TABLES;

LOCK TABLES `device_class_kind` WRITE;
/*!40000 ALTER TABLE `device_class_kind` DISABLE KEYS */;
INSERT INTO `device_class_kind` VALUES
(8,'messaging',false),(8,'online-account',false);
/*!40000 ALTER TABLE `device_class_kind` ENABLE KEYS */;
UNLOCK TABLES;


LOCK TABLES `device_code_version` WRITE;
/*!40000 ALTER TABLE `device_code_version` DISABLE KEYS */;
INSERT INTO `device_code_version` VALUES
(8,0,'{\n  \"auth\": {\n    \"type\": \"oauth2\"\n  },\n  \"types\": [\n    \"online-account\",\n    \"messaging\"\n  ],\n  \"params\": {},\n  \"global-name\": \"omlet\",\n  \"triggers\": {\n    \"newmessage\": {\n      \"args\": [\n        \"feed\",\n        \"type\",\n        \"message\"\n      ], \"schema\": [\"Feed\",\"String\",\"String\"],\n      \"doc\": \"trigger on any new message in the feed\"\n    },\n    \"incomingmessage\": {\n      \"args\": [\n        \"feed\",\n        \"type\",\n        \"message\"\n      ], \"schema\": [\"Feed\",\"String\",\"String\"],\n      \"doc\": \"trigger on any incoming (from other people) message in the feed\"\n    }\n  },\n  \"actions\": {\n    \"send\": {\n      \"args\": [\n        \"feed\",\n        \"type\",\n        \"message\"\n      ], \"schema\": [\"Feed\",\"String\",\"String\"],\n      \"doc\": \"send a message to the feed; type can be text or picture\"\n    }\n  }\n}'),
(22,0,'{\"auth\":{\"type\":\"builtin\"},\"triggers\":{\"listen\":{\"args\":[\"message\"],\"schema\":[\"String\"],\"doc\":\"trigger on any message to Sabrina, except those that have a built-in response\"}},\"actions\":{\"say\":{\"args\":[\"message\"],\"schema\":[\"String\"],\"doc\":\"cause Sabrina to say something\"}}}');
/*!40000 ALTER TABLE `device_code_version` ENABLE KEYS */;
UNLOCK TABLES;

LOCK TABLES `device_schema` WRITE;
/*!40000 ALTER TABLE `device_schema` DISABLE KEYS */;
INSERT INTO `device_schema` VALUES
(6,'org.thingpedia.builtin.sabrina','primary',1,0,0),
(9,'org.thingpedia.builtin.omlet','primary',1,0,0),
(18,'omlet','global',1,0,0),
(20,'sabrina','global',1,0,0),
(21,'online-account','other',1,0,0),
(24,'messaging','other',1,0,0),
(25,'data-source','other',1,0,0);
/*!40000 ALTER TABLE `device_schema` ENABLE KEYS */;
UNLOCK TABLES;

LOCK TABLES `device_schema_version` WRITE;
/*!40000 ALTER TABLE `device_schema_version` DISABLE KEYS */;
INSERT INTO `device_schema_version` VALUES
(6,0,'[{\"listen\":[\"String\"]},{\"say\":[\"String\"]}]','[{},{},{}]'),
(9,0,'[{\"newmessage\":[\"Feed\",\"String\",\"String\"],\"incomingmessage\":[\"Feed\",\"String\",\"String\"]},{\"send\":[\"Feed\",\"String\",\"String\"]}]','[{},{},{}]'),
(18,0,'[{\"newmessage\":[\"Feed\",\"String\",\"String\"],\"incomingmessage\":[\"Feed\",\"String\",\"String\"]},{\"send\":[\"Feed\",\"String\",\"String\"]}]','[{},{},{}]'),
(20,0,'[{\"listen\":[\"String\"]},{\"say\":[\"String\"]}]','[{},{},{}]'),
(21,0,'[{},{}]','[{},{},{}]'),
(24,0,'[{\"newmessage\":[\"Feed\",\"String\",\"String\"],\"incomingmessage\":[\"Feed\",\"String\",\"String\"]},{\"send\":[\"Feed\",\"String\",\"String\"]}]','[{},{},{}]'),
(25,0,'[{},{}]','[{},{},{}]');
/*!40000 ALTER TABLE `device_schema_version` ENABLE KEYS */;
UNLOCK TABLES;
