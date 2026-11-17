-- Supabase SQL Editor에서 한 번에 실행하세요.
create table public.profiles(id uuid primary key references auth.users on delete cascade, login text unique not null, role text not null check(role in('hq','div','reg')), div int, rid text, name text not null);
create table public.docs(col text not null, id text not null, data jsonb not null default '{}', updated_at timestamptz not null default now(), primary key(col,id));
create index docs_col on public.docs(col);
alter table public.docs replica identity full;
alter table public.profiles enable row level security;
alter table public.docs enable row level security;

create function public.my_role() returns text language sql stable security definer set search_path=public as $$select role from profiles where id=auth.uid()$$;
create function public.my_div() returns int language sql stable security definer set search_path=public as $$select div from profiles where id=auth.uid()$$;
create function public.my_rid() returns text language sql stable security definer set search_path=public as $$select rid from profiles where id=auth.uid()$$;
create function public.rid_div(r text) returns int language sql immutable as $$select case when r ~ '^r[0-9]+$' then (substr(r,2)::int-1)/18 end$$;

create policy p_self on public.profiles for select to authenticated using (id=auth.uid());

-- 계획·실적: 지역단=본인 것만 읽기/쓰기, 사업부=소속 지역단 읽기, 본부=전체
create policy plans_sel on public.docs for select to authenticated using (col='plans' and (my_role()='hq' or (my_role()='reg' and data->>'rid'=my_rid()) or (my_role()='div' and rid_div(data->>'rid')=my_div())));
create policy plans_mod on public.docs for all to authenticated using (col='plans' and (my_role()='hq' or (my_role()='reg' and data->>'rid'=my_rid()))) with check (col='plans' and (my_role()='hq' or (my_role()='reg' and data->>'rid'=my_rid())));
-- 공지: 로그인 전에도 읽기, 쓰기는 본부만
create policy notice_sel on public.docs for select to anon, authenticated using (col='notices');
create policy notice_mod on public.docs for all to authenticated using (col='notices' and my_role()='hq') with check (col='notices' and my_role()='hq');
-- 설정(마감일·최저기준): 읽기 전체, 쓰기 본부·사업부
create policy cfg_sel on public.docs for select to authenticated using (col='settings');
create policy cfg_mod on public.docs for all to authenticated using (col='settings' and my_role() in('hq','div')) with check (col='settings' and my_role() in('hq','div'));
-- 알림: 지역단은 등록만, 사업부는 소속 것만, 본부는 전체
create policy al_ins on public.docs for insert to authenticated with check (col='alerts' and (my_role()='hq' or data->>'rid'=my_rid()));
create policy al_sel on public.docs for select to authenticated using (col='alerts' and (my_role()='hq' or (my_role()='reg' and data->>'rid'=my_rid()) or (my_role()='div' and (data->>'div')::int=my_div())));
create policy al_upd on public.docs for update to authenticated using (col='alerts' and (my_role()='hq' or (my_role()='div' and (data->>'div')::int=my_div()))) with check (col='alerts');
-- 일일 집계: 읽기 본부·사업부, 쓰기 본부(및 서버 함수)
create policy dy_sel on public.docs for select to authenticated using (col='daily' and my_role() in('hq','div'));
create policy dy_mod on public.docs for all to authenticated using (col='daily' and my_role()='hq') with check (col='daily' and my_role()='hq');

alter publication supabase_realtime add table public.docs;

-- 매일 오전 9시(KST) 사업부별 자동 집계
create or replace function public.run_daily() returns void language plpgsql security definer set search_path=public as $$
declare k timestamp:=now() at time zone 'Asia/Seoul'; t text:=to_char(k,'YYYY-MM-DD'); m text; res jsonb:='{}';
begin
 foreach m in array array[to_char(k,'YYYY-MM'),to_char(k+interval '1 month','YYYY-MM')] loop
  res:=res||jsonb_build_object(m,(
   select jsonb_agg(jsonb_build_object('div',g.d,'sub',coalesce(s.sub,0),'n',coalesce(s.n,0),'done',coalesce(s.done,0),'up',coalesce(s.up,0),'cancel',coalesce(s.cancel,0),'miss',coalesce(s.miss,0),'rate',case when coalesce(s.n,0)>0 then round(100.0*s.done/s.n) else 0 end) order by g.d)
   from generate_series(0,3) g(d) left join (
    select d,count(distinct rid) sub,count(*) n,count(*) filter(where st='done') done,count(*) filter(where st='up') up,count(*) filter(where st='cancel') cancel,count(*) filter(where ms) miss from (
     select rid_div(data->>'rid') d,data->>'rid' rid,
      case when coalesce(data->>'status','')='cancel' or data->'actual'->>'done'='false' then 'cancel' when data->'actual'->>'done'='true' then 'done' else 'up' end st,
      (coalesce(data->>'status','')<>'cancel' and jsonb_typeof(data->'actual') is distinct from 'object' and data->>'date'<t) ms
     from docs where col='plans' and data->>'month'=m) q group by d) s on s.d=g.d));
 end loop;
 insert into docs(col,id,data) values('daily',t,jsonb_build_object('months',res,'time','09:00','at',now())) on conflict(col,id) do update set data=excluded.data;
end $$;
create extension if not exists pg_cron;
select cron.schedule('daily-seminar-snapshot','0 0 * * *','select public.run_daily()');
