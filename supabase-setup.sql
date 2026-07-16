-- ═══════════════════════════════════════════════════════════════
-- 그림판 사이트 Supabase 설정 스크립트 (보안 강화 버전)
-- 실행 위치: Supabase Dashboard → SQL Editor → 붙여넣고 Run
-- 대상 프로젝트: kzszokecpzepxotffhjl
--
-- · 이전 버전(공개 쓰기 허용)을 실행했어도 이 스크립트 1회 실행으로
--   최종 상태가 됩니다. 여러 번 실행해도 안전합니다(멱등).
-- · 쓰기 권한: 아래 관리자 UID 2개만 허용. 읽기는 공개.
-- · 소셜 로그인 Providers 설정은 필요 없습니다(댓글 기능 제거됨).
--   Authentication에는 Email 로그인 + 관리자 계정 2개만 있으면 됩니다.
-- ═══════════════════════════════════════════════════════════════

-- 0. 댓글 기능 제거 — comments 테이블은 더 이상 사용하지 않음
drop table if exists public.comments;

-- 1. 테이블 ------------------------------------------------------

create table if not exists public.categories (
  id            text primary key,
  ko            text not null,
  en            text not null,
  badge         text not null default 'b-gray',
  display_order int  not null default 0
);

create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  type       text not null default 'info',
  cat        text,
  ko_title   text not null default '',
  en_title   text not null default '',
  ko_body    text not null default '',
  en_body    text not null default '',
  date       text not null default to_char(now(), 'YYYY-MM-DD'),
  embed      text not null default '',
  is_pinned  boolean not null default false,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.post_media (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.posts(id) on delete cascade,
  storage_path  text not null,
  mime          text not null default 'image/jpeg',
  name          text not null default '',
  display_order int  not null default 0
);

-- 사이트 설정: 소개(about)·메뉴 이름(nav_names)·커스텀 페이지(custom_pages)
create table if not exists public.site_settings (
  key   text primary key,
  value jsonb not null
);

-- 2. RLS: 읽기 공개 / 쓰기는 관리자 UID만 -------------------------

alter table public.categories    enable row level security;
alter table public.posts         enable row level security;
alter table public.post_media    enable row level security;
alter table public.site_settings enable row level security;

-- 이전 버전의 허용 정책 제거
drop policy if exists "public read categories"  on public.categories;
drop policy if exists "public write categories" on public.categories;
drop policy if exists "public read posts"       on public.posts;
drop policy if exists "public write posts"      on public.posts;
drop policy if exists "public read post_media"  on public.post_media;
drop policy if exists "public write post_media" on public.post_media;
-- 재실행 대비: 이 스크립트가 만드는 정책도 먼저 제거
drop policy if exists "admin write categories" on public.categories;
drop policy if exists "admin write posts"      on public.posts;
drop policy if exists "admin write post_media" on public.post_media;
drop policy if exists "public read site_settings" on public.site_settings;
drop policy if exists "admin write site_settings" on public.site_settings;

create policy "public read categories"    on public.categories    for select using (true);
create policy "public read posts"         on public.posts         for select using (true);
create policy "public read post_media"    on public.post_media    for select using (true);
create policy "public read site_settings" on public.site_settings for select using (true);

create policy "admin write categories" on public.categories for all to authenticated
  using (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid))
  with check (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid));

create policy "admin write posts" on public.posts for all to authenticated
  using (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid))
  with check (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid));

create policy "admin write post_media" on public.post_media for all to authenticated
  using (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid))
  with check (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid));

create policy "admin write site_settings" on public.site_settings for all to authenticated
  using (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid))
  with check (auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid));

-- 3. Storage: media 버킷 — 읽기 공개, 업로드는 관리자만 ----------

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

drop policy if exists "public read media"   on storage.objects;
drop policy if exists "public upload media" on storage.objects;
drop policy if exists "admin upload media"  on storage.objects;

create policy "public read media" on storage.objects for select
  using (bucket_id = 'media');

create policy "admin upload media" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'media'
    and auth.uid() in ('6b416987-89bb-4b54-afaa-8ac1b43d0b15'::uuid,'4601b212-cf0d-4022-b989-eb41b1c48160'::uuid)
  );

-- 4. 기본 카테고리 시딩 -------------------------------------------
-- (쓰기가 잠기면 사이트의 자동 시딩이 비로그인 상태에서 동작하지
--  않으므로 여기서 직접 넣어둔다. 이미 있으면 건드리지 않음)

insert into public.categories (id, ko, en, badge, display_order) values
  ('free',   '자유그림', 'Free Draw', 'b-teal',   0),
  ('sketch', '스케치',   'Sketch',    'b-blue',   1),
  ('color',  '색칠',     'Coloring',  'b-purple', 2),
  ('daily',  '일상',     'Daily',     'b-amber',  3),
  ('etc',    '기타',     'Etc',       'b-gray',   4)
on conflict (id) do nothing;
