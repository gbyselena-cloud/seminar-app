# 세미나 계획·실적 통합관리 (Vercel + Supabase)

정적 웹앱(index.html) + Supabase(DB·로그인·실시간·자동집계). 서버 코드 없음.

## 1. Supabase
1. supabase.com에서 새 프로젝트 생성
2. SQL Editor에 `schema.sql` 전체를 붙여 실행 (테이블·권한(RLS)·실시간·매일 9시 집계 포함)
   - pg_cron 오류 시: Database → Extensions에서 pg_cron 활성화 후 마지막 2줄만 다시 실행
3. Authentication → Providers → Email: **"Allow new users to sign up" 끄기**, "Confirm email" 끄기
4. Project Settings → API에서 URL, anon key, service_role key 확인

## 2. 계정 생성 (본부 1 + 사업부 4 + 지역단 72)
```
npm install
SUPABASE_URL=https://xxxx.supabase.co SERVICE_ROLE_KEY=... SAMPLE_PASSWORD='원하는비밀번호8자이상' npm run seed
```
아이디: admin / d1~d4 / r01~r72 (비밀번호는 위에서 지정한 값). 운영 시 실제 지역단명으로 profiles.name 수정.

## 3. 설정 & 배포
1. `config.js`에 URL과 anon key 입력 (service_role 키는 절대 넣지 말 것)
2. Vercel: 이 폴더를 GitHub에 올려 Import (Framework: Other, Build 없음) 또는 `npx vercel --prod`
3. 배포 URL을 카카오톡으로 공유. 첫 접속 후 admin → 데이터·엑셀 → 샘플 데이터 생성
