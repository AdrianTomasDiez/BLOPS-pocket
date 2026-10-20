-- BO1 Zombies iOS Launcher schema (SQLite)
create table installations (
  id text primary key,
  source_path text not null,
  bookmark_data blob,
  version text,
  verified_at text,
  status text not null check (status in ('empty','importing','partial','verified','error')),
  file_count integer not null default 0,
  total_bytes integer not null default 0,
  created_at text not null default (datetime('now')),
  updated_at text not null default (datetime('now'))
);

create table file_manifest (
  id text primary key,
  installation_id text not null references installations(id) on delete cascade,
  path text not null,
  size integer not null,
  sha256 text not null,
  status text not null check (status in ('ok','missing','mismatch')),
  unique (installation_id, path)
);
create index idx_file_manifest_installation on file_manifest(installation_id);

create table maps (
  id text primary key,
  name text not null,
  zone_files text not null, -- JSON array
  iwd_files text not null,  -- JSON array
  supported integer not null default 1,
  thumbnail_asset text
);

create table profiles (
  id text primary key,
  display_name text,
  sensitivity real not null default 1.0,
  graphics_quality text not null default 'medium' check (graphics_quality in ('low','medium','high')),
  audio_master real not null default 1.0,
  audio_music real not null default 1.0,
  audio_sfx real not null default 1.0,
  control_layout text not null default 'default',
  created_at text not null default (datetime('now')),
  updated_at text not null default (datetime('now'))
);

create table saves (
  id text primary key,
  profile_id text not null references profiles(id) on delete cascade,
  map_id text not null references maps(id) on delete cascade,
  best_round integer not null default 0,
  best_score integer not null default 0,
  total_kills integer not null default 0,
  total_deaths integer not null default 0,
  updated_at text not null default (datetime('now')),
  unique (profile_id, map_id)
);
create index idx_saves_profile on saves(profile_id);

create table mods (
  id text primary key,
  name text not null,
  files text not null, -- JSON array
  enabled integer not null default 0,
  source_path text,
  created_at text not null default (datetime('now'))
);