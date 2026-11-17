import {createClient} from "@supabase/supabase-js";
const {SUPABASE_URL,SERVICE_ROLE_KEY,SAMPLE_PASSWORD}=process.env;
if(!SUPABASE_URL||!SERVICE_ROLE_KEY||!SAMPLE_PASSWORD){console.error("SUPABASE_URL, SERVICE_ROLE_KEY, SAMPLE_PASSWORD 환경변수가 필요합니다.");process.exit(1)}
const sb=createClient(SUPABASE_URL,SERVICE_ROLE_KEY,{auth:{persistSession:false}});
const DIV=["1사업부","2사업부","3사업부","4사업부"],pad=n=>String(n).padStart(2,"0");
const users=[{login:"admin",role:"hq",name:"본부 관리자"},...DIV.map((d,i)=>({login:"d"+(i+1),role:"div",div:i,name:d})),
 ...Array.from({length:72},(_,i)=>({login:"r"+pad(i+1),role:"reg",div:Math.floor(i/18),rid:"r"+pad(i+1),name:DIV[Math.floor(i/18)]+" "+(i%18+1)+"지역단"}))];
for(const u of users){
 const {data,error}=await sb.auth.admin.createUser({email:u.login+"@seminar.local",password:SAMPLE_PASSWORD,email_confirm:true});
 if(error){console.log("skip",u.login,error.message);continue}
 const r=await sb.from("profiles").insert({id:data.user.id,login:u.login,role:u.role,div:u.div??null,rid:u.rid??null,name:u.name});
 console.log(u.login,r.error?r.error.message:"ok")}
