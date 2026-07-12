-- ═══════════════════════════════════════════════════════════════
-- 그림판 사이트 전용 Supabase 프로젝트 초기 설정 스크립트
-- 실행 위치: Supabase Dashboard → SQL Editor → 새 쿼리에 붙여넣고 Run (1회)
-- 대상 프로젝트: kzszokecpzepxotffhjl
-- ═══════════════════════════════════════════════════════════════

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

create table if not exists public.comments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts(id) on delete cascade,
  provider     text not null default '',
  display_name text not null default '',
  body         text not null default '',
  created_at   timestamptz not null default now()
);

-- 2. RLS ---------------------------------------------------------
-- ⚠️ 주의: 이 사이트는 관리자 인증이 클라이언트(브라우저)에서만 이뤄지는 구조라서,
-- 아래 정책은 anon(공개) 키로 읽기·쓰기를 모두 허용합니다. 사이트가 동작하기 위한
-- "임시" 설정이며, 공개 키를 아는 누구나 데이터를 수정/삭제할 수 있습니다.
-- 향후 Supabase Auth 기반 관리자 로그인으로 전환한 뒤 쓰기 정책을
-- authenticated 사용자로 제한하는 것을 권장합니다.

alter table public.categories enable row level security;
alter table public.posts       enable row level security;
alter table public.post_media  enable row level security;
alter table public.comments    enable row level security;

create policy "public read categories"  on public.categories for select using (true);
create policy "public write categories" on public.categories for all    using (true) with check (true);

create policy "public read posts"  on public.posts for select using (true);
create policy "public write posts" on public.posts for all    using (true) with check (true);

create policy "public read post_media"  on public.post_media for select using (true);
create policy "public write post_media" on public.post_media for all    using (true) with check (true);

create policy "public read comments"  on public.comments for select using (true);
create policy "public write comments" on public.comments for all    using (true) with check (true);

-- 3. Storage (media 버킷: 이미지/동영상 업로드용, 공개 읽기) -------

insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

create policy "public read media"   on storage.objects for select using (bucket_id = 'media');
create policy "public upload media" on storage.objects for insert with check (bucket_id = 'media');

-- 4. 참고 --------------------------------------------------------
-- · 카테고리 기본값(자유그림/스케치/색칠/일상/기타)은 사이트가 첫 로드 때
--   categories 테이블이 비어 있으면 자동으로 넣으므로 여기서 시딩하지 않습니다.
-- · 소셜 로그인(댓글)을 쓰려면 Dashboard → Authentication → Providers에서
--   google / kakao / github / facebook / linkedin_oidc 활성화 후
--   Redirect URL에 https://dreamccm.github.io/fatpoby/ 를 추가하세요.
