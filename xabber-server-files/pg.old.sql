--
-- ejabberd, Copyright (C) 2002-2017   ProcessOne
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation; either version 2 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
--

CREATE TABLE users (
    username text PRIMARY KEY,
    "password" text NOT NULL,
    serverkey text NOT NULL DEFAULT '',
    salt text NOT NULL DEFAULT '',
    iterationcount integer NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Add support for SCRAM auth to a database created before ejabberd 16.03:
-- ALTER TABLE users ADD COLUMN serverkey text NOT NULL DEFAULT '';
-- ALTER TABLE users ADD COLUMN salt text NOT NULL DEFAULT '';
-- ALTER TABLE users ADD COLUMN iterationcount integer NOT NULL DEFAULT 0;

CREATE TABLE last (
    username text PRIMARY KEY,
    seconds text NOT NULL,
    state text NOT NULL
);


CREATE TABLE rosterusers (
    username text NOT NULL,
    jid text NOT NULL,
    nick text NOT NULL,
    subscription character(1) NOT NULL,
    ask character(1) NOT NULL,
    askmessage text NOT NULL,
    server character(1) NOT NULL,
    subscribe text NOT NULL,
    "type" text,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX i_rosteru_user_jid ON rosterusers USING btree (username, jid);
CREATE INDEX i_rosteru_username ON rosterusers USING btree (username);
CREATE INDEX i_rosteru_jid ON rosterusers USING btree (jid);


CREATE TABLE rostergroups (
    username text NOT NULL,
    jid text NOT NULL,
    grp text NOT NULL
);

CREATE INDEX pk_rosterg_user_jid ON rostergroups USING btree (username, jid);

CREATE TABLE sr_group (
    name text NOT NULL,
    opts text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE sr_user (
    jid text NOT NULL,
    grp text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX i_sr_user_jid_grp ON sr_user USING btree (jid, grp);
CREATE INDEX i_sr_user_jid ON sr_user USING btree (jid);
CREATE INDEX i_sr_user_grp ON sr_user USING btree (grp);

CREATE TABLE spool (
    username text NOT NULL,
    xml text NOT NULL,
    seq SERIAL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_despool ON spool USING btree (username);

CREATE TABLE archive (
    username text NOT NULL,
    timestamp BIGINT NOT NULL,
    peer text NOT NULL,
    bare_peer text NOT NULL,
    xml text NOT NULL,
    txt text,
    id SERIAL,
    kind text,
    nick text,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_username_timestamp ON archive USING btree (username, timestamp);
CREATE INDEX i_username_peer ON archive USING btree (username, peer);
CREATE INDEX i_username_bare_peer ON archive USING btree (username, bare_peer);
CREATE INDEX i_timestamp ON archive USING btree (timestamp);

CREATE TABLE archive_prefs (
    username text NOT NULL PRIMARY KEY,
    def text NOT NULL,
    always text NOT NULL,
    never text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE vcard (
    username text PRIMARY KEY,
    vcard text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE vcard_search (
    username text NOT NULL,
    lusername text PRIMARY KEY,
    fn text NOT NULL,
    lfn text NOT NULL,
    family text NOT NULL,
    lfamily text NOT NULL,
    given text NOT NULL,
    lgiven text NOT NULL,
    middle text NOT NULL,
    lmiddle text NOT NULL,
    nickname text NOT NULL,
    lnickname text NOT NULL,
    bday text NOT NULL,
    lbday text NOT NULL,
    ctry text NOT NULL,
    lctry text NOT NULL,
    locality text NOT NULL,
    llocality text NOT NULL,
    email text NOT NULL,
    lemail text NOT NULL,
    orgname text NOT NULL,
    lorgname text NOT NULL,
    orgunit text NOT NULL,
    lorgunit text NOT NULL
);

CREATE INDEX i_vcard_search_lfn       ON vcard_search(lfn);
CREATE INDEX i_vcard_search_lfamily   ON vcard_search(lfamily);
CREATE INDEX i_vcard_search_lgiven    ON vcard_search(lgiven);
CREATE INDEX i_vcard_search_lmiddle   ON vcard_search(lmiddle);
CREATE INDEX i_vcard_search_lnickname ON vcard_search(lnickname);
CREATE INDEX i_vcard_search_lbday     ON vcard_search(lbday);
CREATE INDEX i_vcard_search_lctry     ON vcard_search(lctry);
CREATE INDEX i_vcard_search_llocality ON vcard_search(llocality);
CREATE INDEX i_vcard_search_lemail    ON vcard_search(lemail);
CREATE INDEX i_vcard_search_lorgname  ON vcard_search(lorgname);
CREATE INDEX i_vcard_search_lorgunit  ON vcard_search(lorgunit);

CREATE TABLE privacy_default_list (
    username text PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE privacy_list (
    username text NOT NULL,
    name text NOT NULL,
    id SERIAL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_privacy_list_username ON privacy_list USING btree (username);
CREATE UNIQUE INDEX i_privacy_list_username_name ON privacy_list USING btree (username, name);

CREATE TABLE privacy_list_data (
    id bigint REFERENCES privacy_list(id) ON DELETE CASCADE,
    t character(1) NOT NULL,
    value text NOT NULL,
    action character(1) NOT NULL,
    ord NUMERIC NOT NULL,
    match_all boolean NOT NULL,
    match_iq boolean NOT NULL,
    match_message boolean NOT NULL,
    match_presence_in boolean NOT NULL,
    match_presence_out boolean NOT NULL
);

CREATE INDEX i_privacy_list_data_id ON privacy_list_data USING btree (id);

CREATE TABLE private_storage (
    username text NOT NULL,
    namespace text NOT NULL,
    data text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_private_storage_username ON private_storage USING btree (username);
CREATE UNIQUE INDEX i_private_storage_username_namespace ON private_storage USING btree (username, namespace);


CREATE TABLE roster_version (
    username text PRIMARY KEY,
    version text NOT NULL
);

-- To update from 0.9.8:
-- CREATE SEQUENCE spool_seq_seq;
-- ALTER TABLE spool ADD COLUMN seq integer;
-- ALTER TABLE spool ALTER COLUMN seq SET DEFAULT nextval('spool_seq_seq');
-- UPDATE spool SET seq = DEFAULT;
-- ALTER TABLE spool ALTER COLUMN seq SET NOT NULL;

-- To update from 1.x:
-- ALTER TABLE rosterusers ADD COLUMN askmessage text;
-- UPDATE rosterusers SET askmessage = '';
-- ALTER TABLE rosterusers ALTER COLUMN askmessage SET NOT NULL;

CREATE TABLE pubsub_node (
  host text NOT NULL,
  node text NOT NULL,
  parent text NOT NULL DEFAULT '',
  plugin text NOT NULL,
  nodeid SERIAL UNIQUE
);
CREATE INDEX i_pubsub_node_parent ON pubsub_node USING btree (parent);
CREATE UNIQUE INDEX i_pubsub_node_tuple ON pubsub_node USING btree (host, node);

CREATE TABLE pubsub_node_option (
  nodeid bigint REFERENCES pubsub_node(nodeid) ON DELETE CASCADE,
  name text NOT NULL,
  val text NOT NULL
);
CREATE INDEX i_pubsub_node_option_nodeid ON pubsub_node_option USING btree (nodeid);

CREATE TABLE pubsub_node_owner (
  nodeid bigint REFERENCES pubsub_node(nodeid) ON DELETE CASCADE,
  owner text NOT NULL
);
CREATE INDEX i_pubsub_node_owner_nodeid ON pubsub_node_owner USING btree (nodeid);

CREATE TABLE pubsub_state (
  nodeid bigint REFERENCES pubsub_node(nodeid) ON DELETE CASCADE,
  jid text NOT NULL,
  affiliation character(1),
  subscriptions text NOT NULL DEFAULT '',
  stateid SERIAL UNIQUE
);
CREATE INDEX i_pubsub_state_jid ON pubsub_state USING btree (jid);
CREATE UNIQUE INDEX i_pubsub_state_tuple ON pubsub_state USING btree (nodeid, jid);

CREATE TABLE pubsub_item (
  nodeid bigint REFERENCES pubsub_node(nodeid) ON DELETE CASCADE,
  itemid text NOT NULL,
  publisher text NOT NULL,
  creation text NOT NULL,
  modification text NOT NULL,
  payload text NOT NULL DEFAULT ''
);
CREATE INDEX i_pubsub_item_itemid ON pubsub_item USING btree (itemid);
CREATE UNIQUE INDEX i_pubsub_item_tuple ON pubsub_item USING btree (nodeid, itemid);

CREATE TABLE pubsub_subscription_opt (
  subid text NOT NULL,
  opt_name varchar(32),
  opt_value text NOT NULL
);
CREATE UNIQUE INDEX i_pubsub_subscription_opt ON pubsub_subscription_opt USING btree (subid, opt_name);

CREATE TABLE muc_room (
    name text NOT NULL,
    host text NOT NULL,
    opts text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX i_muc_room_name_host ON muc_room USING btree (name, host);

CREATE TABLE muc_registered (
    jid text NOT NULL,
    host text NOT NULL,
    nick text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_muc_registered_nick ON muc_registered USING btree (nick);
CREATE UNIQUE INDEX i_muc_registered_jid_host ON muc_registered USING btree (jid, host);

CREATE TABLE muc_online_room (
    name text NOT NULL,
    host text NOT NULL,
    node text NOT NULL,
    pid text NOT NULL
);

CREATE UNIQUE INDEX i_muc_online_room_name_host ON muc_online_room USING btree (name, host);

CREATE TABLE muc_online_users (
    username text NOT NULL,
    server text NOT NULL,
    resource text NOT NULL,
    name text NOT NULL,
    host text NOT NULL,
    node text NOT NULL
);

CREATE UNIQUE INDEX i_muc_online_users ON muc_online_users USING btree (username, server, resource, name, host);
CREATE INDEX i_muc_online_users_us ON muc_online_users USING btree (username, server);

CREATE TABLE muc_room_subscribers (
   room text NOT NULL,
   host text NOT NULL,
   jid text NOT NULL,
   nick text NOT NULL,
   nodes text NOT NULL,
   created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_muc_room_subscribers_host_jid ON muc_room_subscribers USING btree (host, jid);
CREATE UNIQUE INDEX i_muc_room_subscribers_host_room_jid ON muc_room_subscribers USING btree (host, room, jid);

CREATE TABLE irc_custom (
    jid text NOT NULL,
    host text NOT NULL,
    data text NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX i_irc_custom_jid_host ON irc_custom USING btree (jid, host);

CREATE TABLE motd (
    username text PRIMARY KEY,
    xml text,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE caps_features (
    node text NOT NULL,
    subnode text NOT NULL,
    feature text,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX i_caps_features_node_subnode ON caps_features USING btree (node, subnode);

CREATE TABLE sm (
    usec bigint NOT NULL,
    pid text NOT NULL,
    node text NOT NULL,
    username text NOT NULL,
    resource text NOT NULL,
    priority text NOT NULL,
    info text NOT NULL
);

CREATE UNIQUE INDEX i_sm_sid ON sm USING btree (usec, pid);
CREATE INDEX i_sm_node ON sm USING btree (node);
CREATE INDEX i_sm_username ON sm USING btree (username);

CREATE TABLE oauth_token (
    token text NOT NULL,
    jid text NOT NULL,
    scope text NOT NULL,
    expire bigint NOT NULL
);

CREATE UNIQUE INDEX i_oauth_token_token ON oauth_token USING btree (token);

CREATE TABLE route (
    domain text NOT NULL,
    server_host text NOT NULL,
    node text NOT NULL,
    pid text NOT NULL,
    local_hint text NOT NULL
);

CREATE UNIQUE INDEX i_route ON route USING btree (domain, server_host, node, pid);
CREATE INDEX i_route_domain ON route USING btree (domain);

CREATE TABLE bosh (
    sid text NOT NULL,
    node text NOT NULL,
    pid text NOT NULL
);

CREATE UNIQUE INDEX i_bosh_sid ON bosh USING btree (sid);

CREATE TABLE carboncopy (
    username text NOT NULL,
    resource text NOT NULL,
    namespace text NOT NULL,
    node text NOT NULL
);

CREATE UNIQUE INDEX i_carboncopy_ur ON carboncopy USING btree (username, resource);
CREATE INDEX i_carboncopy_user ON carboncopy USING btree (username);

CREATE TABLE proxy65 (
    sid text NOT NULL,
    pid_t text NOT NULL,
    pid_i text NOT NULL,
    node_t text NOT NULL,
    node_i text NOT NULL,
    jid_i text NOT NULL
);

CREATE UNIQUE INDEX i_proxy65_sid ON proxy65 USING btree (sid);
CREATE INDEX i_proxy65_jid ON proxy65 USING btree (jid_i);

CREATE TABLE push_session (
    username text NOT NULL,
    timestamp bigint NOT NULL,
    service text NOT NULL,
    node text NOT NULL,
    xml text NOT NULL
);

CREATE UNIQUE INDEX i_push_usn ON push_session USING btree (username, service, node);
CREATE UNIQUE INDEX i_push_ut ON push_session USING btree (username, timestamp);

ALTER TABLE archive ADD CONSTRAINT unique_timestamp UNIQUE (timestamp);

CREATE TABLE origin_id (
    id text NOT NULL,
    stanza_id BIGINT
      UNIQUE
      REFERENCES archive (timestamp) ON DELETE CASCADE
);

CREATE INDEX i_origin_id ON origin_id USING btree (id);

CREATE TABLE previous_id (
    id BIGINT
      UNIQUE
      REFERENCES archive (timestamp) ON DELETE CASCADE,
    stanza_id BIGINT
      UNIQUE
      REFERENCES archive (timestamp) ON DELETE CASCADE
);

INSERT INTO previous_id (stanza_id, id)
SELECT * FROM (
  SELECT
    current.timestamp AS stanza_id,
    (
      SELECT previous.timestamp
      FROM archive AS previous
      WHERE current.timestamp > previous.timestamp
        AND current.username = previous.username
        AND current.bare_peer = previous.bare_peer
      ORDER BY previous.timestamp DESC
      LIMIT 1
    ) AS id
  FROM archive AS current
) AS pairs
WHERE pairs.id NOTNULL;

CREATE TABLE groupchats (
    name text NOT NULL,
    localpart text NOT NULL PRIMARY KEY REFERENCES users (username) ON DELETE CASCADE,
    jid text NOT NULL UNIQUE,
    anonymous text NOT NULL,
    searchable text NOT NULL,
    model text NOT NULL,
    description text,
    owner text NOT NULL,
    avatar_id text DEFAULT '',
    message bigint DEFAULT 0,
    contacts text,
    domains text
);


CREATE TABLE groupchat_users (
    username text NOT NULL,
    role text NOT NULL,
    id text NOT NULL,
    avatar_id text,
    avatar_type text,
    avatar_url text,
    avatar_size integer not null default 0,
    nickname text default '',
    parse_vcard timestamp NOT NULL default now(),
    parse_avatar text NOT NULL default 'yes',
    badge text,
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    subscription text NOT NULL,
    last_seen timestamp NOT NULL default now(),
    user_updated_at timestamp NOT NULL default now(),
    CONSTRAINT UC_groupchat_users UNIQUE (username,chatgroup),
    CONSTRAINT UC_groupchat_users_id UNIQUE (id)
);

CREATE TABLE groupchat_present (
    username text NOT NULL,
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    resource text NOT NULL
);

CREATE TABLE groupchat_users_vcard (
    jid text PRIMARY KEY,
    givenfamily text,
    fn text,
    nickname text,
    image text,
    hash text,
    fullupdate text
);

CREATE TABLE groupchat_rights (
    name text NOT NULL UNIQUE,
    type text NOT NULL,
    description text NOT NULL
);


CREATE TABLE groupchat_policy (
    username text NOT NULL,
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    right_name text NOT NULL REFERENCES groupchat_rights(name),
    valid_from timestamp NOT NULL,
    valid_until timestamp NOT NULL,
    issued_by text NOT NULL,
    issued_at timestamp NOT NULL,
    CONSTRAINT UC_groupchat_policy UNIQUE (username,chatgroup,right_name)
);

INSERT INTO groupchat_rights (name,description,type) values
('send-messages','Send messages','restriction'),
('read-messages','Read messages','restriction'),
('owner','Owner','permission'),
('restrict-participants','Restrict participants','permission'),
('block-participants','Block participants','permission'),
('send-invitations','Send invitations','restriction'),
('send-audio','Send audio','restriction'),
('send-images','Send images','restriction'),
('administrator','Administrator','permission'),
('change-badges','Change badges','permission'),
('change-nicknames','Change nicknames','permission'),
('delete-messages','Delete messages','permission')
;

CREATE TABLE groupchat_block (
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    blocked text NOT NULL,
    type text NOT NULL,
    anonim_id text,
    issued_by text NOT NULL,
    issued_at timestamp NOT NULL,
    CONSTRAINT UC_groupchat_block UNIQUE (chatgroup,blocked)
);

CREATE TABLE groupchat_log (
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    username text NOT NULL,
    log_event text NOT NULL,
    happend_at timestamp NOT NULL,
    CONSTRAINT UC_groupchat_log UNIQUE (username,chatgroup,log_event),
    FOREIGN KEY (username,chatgroup) REFERENCES groupchat_users (username,chatgroup) ON DELETE CASCADE
);

CREATE TABLE groupchat_users_info(
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    username text NOT NULL,
    nickname text NOT NULL,
    avatar text,
    CONSTRAINT UC_groupchat_users_info UNIQUE (username,chatgroup,nickname),
    FOREIGN KEY (username,chatgroup) REFERENCES groupchat_users (username,chatgroup) ON DELETE CASCADE
);

CREATE TABLE groupchat_default_restrictions(
    chatgroup text NOT NULL REFERENCES groupchats (jid) ON DELETE CASCADE,
    right_name text NOT NULL REFERENCES groupchat_rights(name),
    action_time text NOT NULL,
    CONSTRAINT UC_groupchat_default_restrictions UNIQUE (chatgroup,right_name)
);

CREATE TABLE groupchat_retract(
    chatgroup text,
    xml text,
    version integer,
    CONSTRAINT uc_groupchat_versions UNIQUE (chatgroup,xml,version),
    FOREIGN KEY (chatgroup) REFERENCES groupchats(jid) ON DELETE CASCADE
    );

CREATE TABLE message_retract(
    username text,
    xml text,
    version bigint,
    CONSTRAINT uc_retract_message_versions UNIQUE (username,xml,version),
    FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );

CREATE TABLE foreign_message_stanza_id(
    foreign_username text,
    our_username text,
    foreign_stanza_id bigint UNIQUE,
    our_stanza_id bigint
    UNIQUE
    REFERENCES archive (timestamp) ON DELETE CASCADE
);

CREATE INDEX i_our_origin_id ON foreign_message_stanza_id USING btree (foreign_stanza_id);

CREATE TABLE xabber_token (
    token text NOT NULL,
    token_uid text NOT NULL,
    jid text NOT NULL,
    device text,
    client text,
    expire bigint NOT NULL,
    ip text DEFAULT ''::text,
    last_usage bigint NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX i_xabber_token_token ON xabber_token USING btree (token);
CREATE UNIQUE INDEX i_xabber_token_token_uid ON xabber_token USING btree (token_uid);

ALTER TABLE sm ADD COLUMN token_uid text;

CREATE TABLE conversation_metadata(
    username text,
    conversation text,
    type text NOT NULL DEFAULT 'chat',
    retract bigint NOT NULL DEFAULT 0,
    conversation_thread text NOT NULL DEFAULT '',
    read_until text NOT NULL DEFAULT '0',
    delivered_until text NOT NULL DEFAULT '0',
    displayed_until text NOT NULL DEFAULT '0',
    updated_at bigint NOT NULL,
    CONSTRAINT uc_conversation_metadata UNIQUE (username,conversation,conversation_thread),
    FOREIGN KEY (username) REFERENCES users(username) ON DELETE CASCADE
    );


