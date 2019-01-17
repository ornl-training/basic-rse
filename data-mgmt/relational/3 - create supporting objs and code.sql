-- **********
-- 2018-09-24 - auditing setup
-- **********

-- typ
create or replace type typ_colVarchar as table of varchar2(4000);
create or replace type typ_colMaxVarchar2 as table of varchar2(32767);

-- in_list
create or replace procedure prc_set_in_list_ctx(p_vcinlist in varchar2) is
begin
   dbms_session.set_context('ctx_in_list', 'in_list', p_vcInList);
end;
/

create or replace context ctx_in_list using prc_set_in_list_ctx
/
 
create or replace force view vu_in_list
bequeath definer
as 
select trim(substr(in_list,instr(in_list,',',1,level) + 1, instr(in_list,',',1,level+1) - instr(in_list,',',1,level) - 1)) as token
from (select ',' || sys_context('ctx_in_list','in_list',4000) || ',' in_list from dual)
connect by level <=
   length(sys_context('ctx_in_list','in_list',4000)) - length(replace(sys_context('ctx_in_list','in_list',4000),',','')) + 1;
/

---- op_log
--create table t_op_log(
--   op_log_id  integer,
--   cat        varchar2(5),
--   descr      varchar2(4000),
--   err_code   integer,
--   err_msg    varchar2(512),
--   module     varchar2(4000),
--   sess_id    varchar2(256),
--   ts         timestamp(4) with local time zone,
--   usr        varchar2(30))
--/

create or replace package pkg_op_log is
/**
DB logging mechanism.
*/

-- **********
-- subs
-- **********
-- fcns
-- **********

function fcn_calc_duration(
   p_numStartTime in number)
   return varchar2;

function fcn_calc_sect_duration return varchar2;

function fcn_convert_interval_to_secs(
   p_itvInterval in interval day to second)
   return number;

function fcn_get_assert_level return varchar2;

function fcn_get_level(
   p_intLevel in pls_integer := null)
   return varchar2;

function fcn_get_log_dbms_output_stat return varchar2;

function fcn_get_log_tbl_stat return boolean;

function fcn_get_sect return varchar2;

function fcn_is_all_enabled return boolean;

function fcn_is_trace_enabled return boolean;

function fcn_is_trace_only_enabled return boolean;

function fcn_is_debug_enabled return boolean;

function fcn_is_debug_only_enabled return boolean;

function fcn_is_info_enabled return boolean;

function fcn_is_info_only_enabled return boolean;

function fcn_is_warn_enabled return boolean;

function fcn_is_warn_only_enabled return boolean;

function fcn_is_error_enabled return boolean;

function fcn_is_error_only_enabled return boolean;

function fcn_is_fatal_enabled return boolean;

function fcn_is_fatal_only_enabled return boolean;

-- **********
-- prcs
-- **********

procedure prc_assert(
   p_blnCondition in boolean,
   p_vcTrueResult in varchar2 := 'assertion evaluated to ''true''',
   p_vcFalseResult in varchar2 := 'assertion evaluated to ''false''');

procedure prc_begin_sect_timing;

procedure prc_begin_module(
   p_vcSect in varchar2);

procedure prc_debug(
   p_fldDesc in t_op_log.descr%type);

procedure prc_end_module(
   p_vcSect in varchar2,
   p_vcOption in varchar2 := 'norm');

procedure prc_error(
   p_fldDesc in t_op_log.descr%type);

procedure prc_fatal(
   p_fldDesc in t_op_log.descr%type);

procedure prc_info(
   p_fldDesc in t_op_log.descr%type);

procedure prc_ins(
   p_fldCat in t_op_log.cat%type,
   --p_fldOpCentisecs in t_op_log.op_centisecs%type := null,
   p_fldTS in t_op_log.ts%type := systimestamp,
   p_fldDescr in t_op_log.descr%type,
   p_fldErrCode in t_op_log.err_code%type := null,
   p_fldErrMsg in t_op_log.err_msg%type := null,
   p_fldModule in t_op_log.module%type,
   p_fldSessID in t_op_log.sess_id%type := null,
   p_fldUsr in t_op_log.usr%type := user);

procedure prc_log(
   p_fldCat in t_op_log.cat%type,
   p_fldDescr in t_op_log.descr%type);

procedure prc_purge(
   p_datPurgePriorToDT in date := null);

procedure prc_reset_sect;

procedure prc_reset_sess_log_vbls;

procedure prc_set_assert_level(
   p_vcLevel in varchar2 := 'none');

procedure prc_set_begin_sect(
   p_vcSect in varchar2 := null);

procedure prc_set_end_sect(
   p_vcSect in varchar2);

procedure prc_set_level(
   p_vcLevel in varchar2 := 'none');

procedure prc_set_log_dbms_output_stat(
   p_vcLogDBMSOutput in varchar2 := 'abbrev');

procedure prc_set_log_tbl_stat(
   p_blnLogTbl in boolean := true);

procedure prc_set_sess_log_vbls(
   p_blnLogTblStat in boolean := null,
   p_vcLevel in varchar2 := null,
   p_vcLogDBMSOutputStat in varchar2 := null);

procedure prc_trace(
   p_fldDesc in t_op_log.descr%type);

procedure prc_warn(
   p_fldDesc in t_op_log.descr%type);

-- testing
function fcn_is_level_enabled(
   p_intLevel in pls_integer)
   return boolean;

end pkg_op_log;
/

create or replace package body pkg_op_log is

-- **********
-- constants
-- **********
c_vcPkgName             constant varchar2(30) := 'pkg_op_log';

-- bit flags
c_intLevelNone          constant pls_integer := 0;      -- 0000 0000
c_intLevelFatalOnly     constant pls_integer := 1;      -- 0000 0001
c_intLevelFatal         constant pls_integer := 1;      -- 0000 0001
c_intLevelErrorOnly     constant pls_integer := 2;      -- 0000 0010
c_intLevelError         constant pls_integer := 3;      -- 0000 0011
c_intLevelWarnOnly      constant pls_integer := 4;      -- 0000 0100
c_intLevelWarn          constant pls_integer := 7;      -- 0000 0111
c_intLevelInfoOnly      constant pls_integer := 8;      -- 0000 1000
c_intLevelInfo          constant pls_integer := 15;   -- 0000 1111
c_intLevelDebugOnly     constant pls_integer := 16;   -- 0001 0000
c_intLevelDebug         constant pls_integer := 31;   -- 0001 1111
c_intLevelTraceOnly     constant pls_integer := 32;   -- 0010 0000
c_intLevelTrace         constant pls_integer := 63;   -- 0011 1111
c_intLevelAll           constant pls_integer := 127;   -- 0111 1111

-- level names
c_vcLevelNone           constant varchar2(15) := 'none';
c_vcLevelFatalOnly      constant varchar2(15) := 'fatal only';
c_vcLevelFatal          constant varchar2(15) := 'fatal';
c_vcLevelErrorOnly      constant varchar2(15) := 'error only';
c_vcLevelError          constant varchar2(15) := 'error';
c_vcLevelWarnOnly       constant varchar2(15) := 'warn only';
c_vcLevelWarn           constant varchar2(15) := 'warn';
c_vcLevelInfoOnly       constant varchar2(15) := 'info only';
c_vcLevelInfo           constant varchar2(15) := 'info';
c_vcLevelDebugOnly      constant varchar2(15) := 'debug only';
c_vcLevelDebug          constant varchar2(15) := 'debug';
c_vcLevelTraceOnly      constant varchar2(15) := 'trace only';
c_vcLevelTrace          constant varchar2(15) := 'trace';
c_vcLevelAll            constant varchar2(15) := 'all';

-- **********
-- types
-- **********
type typ_colSectBeginTimestamp is table of timestamp with time zone index by varchar2(500);

-- **********
-- vbls
-- **********
g_blnCurrLogTblStat        boolean;
g_blnLogTblStat            boolean := true;
g_colSectBeginTimestamp    pkg_op_log.typ_colSectBeginTimestamp;
g_intAssertLevel           pls_integer := pkg_op_log.c_intLevelAll;
g_intLevel                 pls_integer := pkg_op_log.c_intLevelInfo;
g_vcCurrLevel              varchar2(15);
g_vcCurrLogDBMSOutputStat  varchar2(6);
g_vcLogDBMSOutputStat      varchar2(6) := 'none';
g_vcSect                   varchar2(2000);

-- **********
-- subs: private fcns
-- **********
-- private: fcn_convert_level
-- **********
function fcn_convert_level(
   p_vcLevel in varchar2)
   return pls_integer is

   v_intLevel      pls_integer := 0;

begin

   if lower(p_vcLevel) = 'none' then
      v_intLevel := pkg_op_log.c_intLevelNone;
   elsif lower(p_vcLevel) = 'fatal' then
      v_intLevel := pkg_op_log.c_intLevelFatal;
   elsif lower(p_vcLevel) = 'error' then
      v_intLevel := pkg_op_log.c_intLevelError;
   elsif lower(p_vcLevel) = 'warn' then
      v_intLevel := pkg_op_log.c_intLevelWarn;
   elsif lower(p_vcLevel) = 'info' then
      v_intLevel := pkg_op_log.c_intLevelInfo;
   elsif lower(p_vcLevel) = 'debug' then
      v_intLevel := pkg_op_log.c_intLevelDebug;
   elsif lower(p_vcLevel) = 'trace' then
      v_intLevel := pkg_op_log.c_intLevelTrace;
   elsif lower(p_vcLevel) = 'all' then
      v_intLevel := pkg_op_log.c_intLevelAll;
   else
      if lower(p_vcLevel) like '%fatalonly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelFatalOnly;
      end if;
      if lower(p_vcLevel) like '%erroronly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelErrorOnly;
      end if;
      if lower(p_vcLevel) like '%warnonly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelWarnOnly;
      end if;
      if lower(p_vcLevel) like '%infoonly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelInfoOnly;
      end if;
      if lower(p_vcLevel) like '%debugonly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelDebugOnly;
      end if;
      if lower(p_vcLevel) like '%traceonly%' then
         v_intLevel := v_intLevel + pkg_op_log.c_intLevelTraceOnly;
      end if;
   end if;

   return v_intLevel;

exception
   when others then
      raise_application_error(-20000,sqlerrm);
end fcn_convert_level;

-- **********
-- private: fcn_get_assert_level
-- **********
/*
function fcn_get_assert_level return pls_integer is
begin
   return pkg_op_log.g_intAssertLevel;
end fcn_get_assert_level;
*/

-- **********
-- private: fcn_is_level_enabled
-- **********
function fcn_is_level_enabled(
   p_intLevel in pls_integer)
   return boolean is
begin
   if (pkg_op_log.g_intLevel = 0) or (p_intLevel = 0) then
      return false;
   elsif bitand(pkg_op_log.g_intLevel,p_intLevel) = p_intLevel then
      return true;
   else
      return false;
   end if;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end fcn_is_level_enabled;

-- **********
-- private: prc_put_line
-- **********
procedure prc_put_line(
   p_string in varchar2,
   p_compress in boolean := false) is

   v_curr_pos     integer;
   v_length       integer;
   v_printed_to   integer;
   v_last_ws      integer;
   skipping_ws    boolean;
   c_len          constant integer := 140;
   ------------------------------------------------------
   -- all 3 variables must be modified at the same time.
   c_max_len      constant integer := 10000;
   v_string       varchar2 (10002);
   ------------------------------------------------------
   nl             constant varchar2 (3)     := chr (10);
   cr             constant varchar2 (3)     := chr (13);
   v_len_total    integer;

begin
   -------------------------------------------------------------------------
   -- case 1: null string.
   -------------------------------------------------------------------------
   if (p_string is null) then
      dbms_output.new_line;
      return;
   end if;

   -------------------------------------------------------------------------
   -- case 2: recursive calls for very long strings! (hard line breaks)
   -------------------------------------------------------------------------
   v_len_total:=length (p_string);

   if (v_len_total > c_max_len) then
      prc_put_line(substr (p_string, 1, c_max_len),p_compress);
      prc_put_line(substr (p_string, c_max_len+1, v_len_total-c_max_len),p_compress);
      return;
   end if;

   -------------------------------------------------------------------------
   -- case 3: regular start here.
   -------------------------------------------------------------------------
   v_string := p_string;

   -------------------------------------------------------------------------
   -- remove eol characters!
   -------------------------------------------------------------------------
   if (p_compress) then
      --
      -- strip all linefeed characters
      --
      v_string := replace (v_string, chr (10), ' ');              --new line
      v_string := replace (v_string, chr (13), ' ');       --carriage return
   else
      --
      -- strip only last linefeed characters
      --
      v_string := rtrim (v_string, chr (10));                     --new line
      v_string := rtrim (v_string, chr (13));              --carriage return
   end if;

   --------------------------------------------------------------------------
   -- main algorithm
   --------------------------------------------------------------------------
   v_length     := length (v_string);
   v_curr_pos   :=  1;                 -- current position (start with 1.ch.)
   v_printed_to :=  0;                 -- string was printed to this mark
   v_last_ws    :=  0;                 -- position of last blank
   skipping_ws  := true;               -- remember if blanks may be skipped

   while v_curr_pos <= v_length loop
      if substr (v_string, v_curr_pos, 1) = ' ' then
         -- blank found
         v_last_ws := v_curr_pos;

         ----------------------------------------
         -- if in compress mode, skip any blanks
         ----------------------------------------
         if (p_compress and skipping_ws) then
            v_printed_to := v_curr_pos;
         end if;
      else
         skipping_ws := false;
      end if;

      if (v_curr_pos >= (v_printed_to + c_len)) then
         -- 1) no blank found
         -- 2) next char is blank (ignore last blank)
         -- 3) end of string
         if ((v_last_ws <= v_printed_to) or
            ((v_curr_pos < v_length) and (substr(v_string,v_curr_pos+1,1) = ' ')) or
             (v_curr_pos = v_length)) then
            -------------------------------------
            -- hard break (no blank found)
            -------------------------------------
            dbms_output.put_line(substr(v_string, v_printed_to + 1, v_curr_pos - v_printed_to));
            v_printed_to := v_curr_pos;
            skipping_ws  := true;
         else
            ----------------------------------
            -- line break on last blank
            ----------------------------------
            dbms_output.put_line(substr(v_string, v_printed_to + 1, v_last_ws - v_printed_to));
            v_printed_to := v_last_ws;

            if (v_last_ws = v_curr_pos) then
               skipping_ws := true;
            end if;
         end if;
      end if;
      v_curr_pos := v_curr_pos + 1;
   end loop;

   dbms_output.put_line (substr (v_string, v_printed_to + 1));

end prc_put_line;

-- **********
-- subs: public fcns
-- **********
-- fcn_calc_duration
-- **********
function fcn_calc_duration(
   p_numStartTime in number)
   return varchar2 is
begin

   if p_numStartTime is null then
      return 'unk';
   else
      return to_char((dbms_utility.get_time-p_numStartTime)/100,'fm9,999,990.90');
   end if;

exception
   when others then
      return 'err';
end fcn_calc_duration;

-- **********
-- public: fcn_convert_interval_to_secs
-- **********
function fcn_convert_interval_to_secs(
   p_itvInterval in interval day to second)
   return number is
begin
   return
      extract(day from p_itvInterval)*24*60*60 +
      extract(hour from p_itvInterval)*60*60 +
      extract(minute from p_itvInterval)*60 +
      extract(second from p_itvInterval);
exception
   when others then
      return -1;
end fcn_convert_interval_to_secs;

-- **********
-- public: fcn_calc_sect_duration
-- **********
function fcn_calc_sect_duration return varchar2 is

begin

   return
      to_char
         (
         pkg_op_log.fcn_convert_interval_to_secs(systimestamp - pkg_op_log.g_colSectBeginTimestamp(pkg_op_log.fcn_get_sect)),
         'fm99,990.990'
         );

exception
   when no_data_found then
      -- possibly thrown if pkg_op_log.g_colSectBeginTimestamp(pkg_op_log.fcn_get_sect) has not been previously set
      return 'unknown';

   when others then
      return 'timing err';

end fcn_calc_sect_duration;

-- **********
-- public: fcn_get_assert_level
-- **********
function fcn_get_assert_level return varchar2 is
begin
   return pkg_op_log.fcn_get_level(pkg_op_log.g_intAssertLevel);
end fcn_get_assert_level;

-- **********
-- public: fcn_get_level
-- **********
function fcn_get_level(
   p_intLevel in pls_integer := null)
   return varchar2 is

   v_intLevel      pls_integer := nvl(p_intLevel,pkg_op_log.g_intLevel);
   v_vcLevel      varchar2(100);

begin

   case v_intLevel
      when pkg_op_log.c_intLevelAll then v_vcLevel := c_vcLevelAll;
      when pkg_op_log.c_intLevelTrace then v_vcLevel := c_vcLevelTrace;
      when pkg_op_log.c_intLevelTraceOnly then v_vcLevel := c_vcLevelTraceOnly;
      when pkg_op_log.c_intLevelDebug then v_vcLevel := c_vcLevelDebug;
      when pkg_op_log.c_intLevelDebugOnly then v_vcLevel := c_vcLevelDebugOnly;
      when pkg_op_log.c_intLevelInfo then v_vcLevel := c_vcLevelInfo;
      when pkg_op_log.c_intLevelInfoOnly then v_vcLevel := c_vcLevelInfoOnly;
      when pkg_op_log.c_intLevelWarn then v_vcLevel := c_vcLevelWarn;
      when pkg_op_log.c_intLevelWarnOnly then v_vcLevel := c_vcLevelWarnOnly;
      when pkg_op_log.c_intLevelError then v_vcLevel := c_vcLevelError;
      when pkg_op_log.c_intLevelErrorOnly then v_vcLevel := c_vcLevelErrorOnly;
      when pkg_op_log.c_intLevelFatal then v_vcLevel := c_vcLevelFatal;
      when pkg_op_log.c_intLevelNone then v_vcLevel := c_vcLevelNone;
      else
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelFatalOnly) = pkg_op_log.c_intLevelFatalOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelFatalOnly;
         end if;
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelErrorOnly) = pkg_op_log.c_intLevelErrorOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelErrorOnly;
         end if;
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelWarnOnly) = pkg_op_log.c_intLevelWarnOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelWarnOnly;
         end if;
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelInfoOnly) = pkg_op_log.c_intLevelInfoOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelInfoOnly;
         end if;
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelDebugOnly) = pkg_op_log.c_intLevelDebugOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelDebugOnly;
         end if;
         if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelTraceOnly) = pkg_op_log.c_intLevelTRaceOnly then
            v_vcLevel := case when v_vcLevel is not null then v_vcLevel || '+' end || c_vcLevelTraceOnly;
         end if;
   end case;
   v_vcLevel := nvl(v_vcLevel,'unknown');

   return v_vcLevel;

exception
   when others then
      raise_application_error(-20000,sqlerrm);

end fcn_get_level;

-- **********
-- public: fcn_get_log_dbms_output_stat
-- **********
function fcn_get_log_dbms_output_stat return varchar2 is
begin
   return lower(pkg_op_log.g_vcLogDBMSOutputStat);
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end fcn_get_log_dbms_output_stat;

-- **********
-- public: fcn_get_log_tbl_stat
-- **********
function fcn_get_log_tbl_stat return boolean is
begin
   return pkg_op_log.g_blnLogTblStat;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end fcn_get_log_tbl_stat;

-- **********
-- public: fcn_get_sect
-- **********
function fcn_get_sect return varchar2 is
begin
   return nvl(pkg_op_log.g_vcSect,'none');
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end fcn_get_sect;

-- **********
-- public: fcn_is_all_enabled
-- **********
function fcn_is_all_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelAll);
end fcn_is_all_enabled;

-- **********
-- public: fcn_is_trace_enabled
-- **********
function fcn_is_trace_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelTrace);
end fcn_is_trace_enabled;

-- **********
-- public: fcn_is_trace_only_enabled
-- **********
function fcn_is_trace_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelTraceOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_trace_only_enabled;

-- **********
-- public: fcn_is_debug_enabled
-- **********
function fcn_is_debug_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelDebug);
end fcn_is_debug_enabled;

-- **********
-- public: fcn_is_debug_only_enabled
-- **********
function fcn_is_debug_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelDebugOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_debug_only_enabled;

-- **********
-- public: fcn_is_info_enabled
-- **********
function fcn_is_info_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelInfo);
end fcn_is_info_enabled;

-- **********
-- public: fcn_is_info_only_enabled
-- **********
function fcn_is_info_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelInfoOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_info_only_enabled;

-- **********
-- public: fcn_is_warn_enabled
-- **********
function fcn_is_warn_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelWarn);
end fcn_is_warn_enabled;

-- **********
-- public: fcn_is_warn_only_enabled
-- **********
function fcn_is_warn_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelWarnOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_warn_only_enabled;

-- **********
-- public: fcn_is_error_enabled
-- **********
function fcn_is_error_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelError);
end fcn_is_error_enabled;

-- **********
-- public: fcn_is_error_only_enabled
-- **********
function fcn_is_error_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelErrorOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_error_only_enabled;

-- **********
-- public: fcn_is_fatal_enabled
-- **********
function fcn_is_fatal_enabled return boolean is
begin
   return pkg_op_log.fcn_is_level_enabled(pkg_op_log.c_intLevelFatal);
end fcn_is_fatal_enabled;

-- **********
-- public: fcn_is_fatal_only_enabled
-- **********
function fcn_is_fatal_only_enabled return boolean is
begin
   if pkg_op_log.g_intLevel = pkg_op_log.c_intLevelFatalOnly then
      return true;
   else
      return false;
   end if;
end fcn_is_fatal_only_enabled;

-- **********
-- subs: prcs
-- **********
-- public: prc_assert
-- **********
procedure prc_assert(
   p_blnCondition in boolean,
   p_vcTrueResult in varchar2 := 'assertion evaluated to ''true''',
   p_vcFalseResult in varchar2 := 'assertion evaluated to ''false''') is
begin
   if pkg_op_log.fcn_is_level_enabled(pkg_op_log.fcn_convert_level(pkg_op_log.fcn_get_assert_level)) then
      pkg_op_log.prc_log
         (
         p_fldCat => pkg_op_log.fcn_get_assert_level,
         p_fldDescr => case p_blnCondition
                           when true then p_vcTrueResult
                           else p_vcFalseResult
                        end
         );
   end if;
end prc_assert;

-- **********
-- public: prc_begin_module
-- **********
procedure prc_begin_module(
   p_vcSect in varchar2) is
begin
   pkg_op_log.prc_set_begin_sect(p_vcSect);
   pkg_op_log.prc_begin_sect_timing;
   pkg_op_log.prc_debug('begin');
end prc_begin_module;

-- **********
-- public: prc_begin_sect_timing
-- **********
procedure prc_begin_sect_timing is
begin
   pkg_op_log.g_colSectBeginTimestamp(pkg_op_log.fcn_get_sect) := systimestamp;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_begin_sect_timing;

-- **********
-- public: prc_debug
-- **********
procedure prc_debug(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelDebugOnly) = pkg_op_log.c_intLevelDebugOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelDebug,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_debug;

-- **********
-- public: prc_end_module
-- **********
procedure prc_end_module
   (
   p_vcSect in varchar2,
   p_vcOption in varchar2 := 'norm'
   )
is

begin
   if lower(p_vcOption) != 'exc' then
      pkg_op_log.prc_debug('elapsed: ' || pkg_op_log.fcn_calc_sect_duration || ' sec(s)');
   end if;
   pkg_op_log.prc_debug('end');
   pkg_op_log.prc_set_end_sect(p_vcSect => p_vcSect);
end prc_end_module;

-- **********
-- public: prc_error
-- **********
procedure prc_error(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelErrorOnly) = pkg_op_log.c_intLevelErrorOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelError,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_error;

-- **********
-- public: prc_fatal
-- **********
procedure prc_fatal(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelFatalOnly) = pkg_op_log.c_intLevelFatalOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelFatal,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_fatal;

-- **********
-- public: prc_info
-- **********
procedure prc_info(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelInfoOnly) = pkg_op_log.c_intLevelInfoOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelInfo,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_info;

-- **********
-- public: prc_ins
-- **********
procedure prc_ins(
   p_fldCat in t_op_log.cat%type,
   --p_fldOpCentisecs in t_op_log.op_centisecs%type := null,
   p_fldTS in t_op_log.ts%type := systimestamp,
   p_fldDescr in t_op_log.descr%type,
   p_fldErrCode in t_op_log.err_code%type := null,
   p_fldErrMsg in t_op_log.err_msg%type := null,
   p_fldModule in t_op_log.module%type,
   p_fldSessID in t_op_log.sess_id%type := null,
   p_fldUsr in t_op_log.usr%type := user) is

   pragma autonomous_transaction;

   v_recTOpLog      t_op_log%rowtype;

begin

   v_recTOpLog.cat := p_fldCat;
   --v_recTOpLog.op_centisecs := p_fldOpCentisecs;
   v_recTOpLog.ts := p_fldTS;
   v_recTOpLog.descr := p_fldDescr;
   v_recTOpLog.err_code := p_fldErrCode;
   v_recTOpLog.err_msg := p_fldErrMsg;
   v_recTOpLog.module := p_fldModule;
   v_recTOpLog.sess_id := p_fldSessID;
   v_recTOpLog.usr := p_fldUsr;

   select
      sq_op_log.nextval
   into
      v_recTOpLog.op_log_id
   from
      dual;

   insert into
      t_op_log
   values
      v_recTOpLog;

   commit;

exception
   when others then
      raise_application_error(-20000,sqlerrm);

end prc_ins;

-- **********
-- public: prc_log
-- **********
procedure prc_log(
   p_fldCat in t_op_log.cat%type,
   p_fldDescr in t_op_log.descr%type) is

   v_recTOpLog      t_op_log%rowtype;

begin

   if (pkg_op_log.fcn_get_log_dbms_output_stat != 'none') or
      (pkg_op_log.fcn_get_log_tbl_stat)
   then

      v_recTOpLog.cat := p_fldCat;
      --v_recTOpLog.op_centisecs := mod(dbms_utility.get_time,100);
      v_recTOpLog.ts := systimestamp;
      v_recTOpLog.descr := p_fldDescr;
      if (sqlcode != 0) and
         (p_fldCat in (pkg_op_log.c_vcLevelFatal,
                         pkg_op_log.c_vcLevelFatalOnly,
                         pkg_op_log.c_vcLevelError,
                         pkg_op_log.c_vcLevelErrorOnly))
      then
         v_recTOpLog.err_code := sqlcode;
         v_recTOpLog.err_msg := sqlerrm;
      else
         v_recTOpLog.err_code := null;
      end if;
      -- case sqlcode when 0 then null else sqlcode end;
      --v_recTOpLog.err_msg :=
         -- case sqlcode when 0 then null else sqlerrm end;
      v_recTOpLog.module := pkg_op_log.fcn_get_sect;
      v_recTOpLog.sess_id := sys_context('userenv','sessionid');
      v_recTOpLog.usr := user;

      if pkg_op_log.fcn_get_log_dbms_output_stat = 'full' then
         pkg_op_log.prc_put_line(
            '[' ||
            to_char(v_recTOpLog.ts,'yyyymmdd-hh24miss.ff2') || --'.' || to_char(v_recTOpLog.op_centisecs,'FM09') ||
            ']' ||
            '[' ||
            v_recTOpLog.sess_id ||
            ']' ||
            '[' ||
            v_recTOpLog.usr ||
            ']' ||
            '[' ||
            v_recTOpLog.module ||
            ']' ||
            '[' ||
            v_recTOpLog.cat ||
            ']' ||
            '[' ||
            v_recTOpLog.descr ||
            ']' ||
            case
               when v_recTOpLog.err_code is null then
                  null
               else
                  '[' ||
                  v_recTOpLog.err_code ||
                  ']' ||
                  '[' ||
                  v_recTOpLog.err_msg ||
                  ']'
            end);
      elsif pkg_op_log.fcn_get_log_dbms_output_stat = 'abbrev' then
         pkg_op_log.prc_put_line(
            '[' ||
            to_char(v_recTOpLog.ts,'hh24miss.ff2') || --'.' || to_char(v_recTOpLog.op_centisecs,'FM09') ||
            ']' ||
            '[' ||
            v_recTOpLog.cat ||
            ']' ||
            '[' ||
            --case when instr(v_recTOpLog.module,'/',1) != 0 then '.' end ||
            replace(translate(substr(v_recTOpLog.module,1,instr(v_recTOpLog.module,'/',-1)),'.0123456789abcdefghijklmnopqrstuvwxyz_()','.'),'//','/./') ||
               substr(v_recTOpLog.module,instr(v_recTOpLog.module,'/',-1)+1) ||
            --v_recTOpLog.module ||
            ']' ||
            '[' ||
            v_recTOpLog.descr ||
            ']' ||
            case
               when v_recTOpLog.err_code is null then
                  null
               else
                  '[' ||
                  v_recTOpLog.err_code ||
                  ']' ||
                  '[' ||
                  v_recTOpLog.err_msg ||
                  ']'
            end);
      end if;

      if pkg_op_log.fcn_get_log_tbl_stat then
         pkg_op_log.prc_ins(
            p_fldCat => v_recTOpLog.cat,
            p_fldTS => v_recTOpLog.ts,
            p_fldDescr => v_recTOpLog.descr,
            p_fldErrCode => v_recTOpLog.err_code,
            p_fldErrMsg => v_recTOpLog.err_msg,
            p_fldModule => v_recTOpLog.module,
            p_fldSessID => v_recTOpLog.sess_id,
            p_fldUsr => v_recTOpLog.usr);
      end if;
   end if;

exception
   when pkg_exception.exc_Subroutine then
      raise;

   when others then
      raise_application_error(-20000,sqlerrm);

end prc_log;

-- **********
-- public: prc_purge
-- **********
procedure prc_purge(
   p_datPurgePriorToDT in date := null) is

   c_vcSubName          constant varchar2(30) := 'prc_purge';
   c_vcModuleName       constant varchar2(61) := c_vcPkgName || '.' || c_vcSubName;

   v_intRecDelCount      pls_integer;
   v_intRecRemainCount   pls_integer;
   v_numStartTime       number := dbms_utility.get_time;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_datPurgePriorToDT = ''' ||
      nvl(to_char(p_datPurgePriorToDT,'mm/dd/yyyy hh24:mi:ss'),'null') || '''');

   -- del
   delete
      t_op_log
   where
      ts < p_datPurgePriorToDT;

   v_intRecDelCount := sql%rowcount;

   -- remaining recs
   select
      count(*)
   into
      v_intRecRemainCount
   from
      t_op_log;

   -- log
   pkg_op_log.prc_info('t_op_log recs del = ''' || v_intRecDelCount || ''', recs remain = ''' ||
      v_intRecRemainCount || '''.');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred. ' ||
         'Param: ' ||
         'p_datPurgePriorToDT = ''' || nvl(to_char(p_datPurgePriorToDT,'mm/dd/yyyy hh24:mi:ss'),'null') ||
         '''.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_purge;

-- **********
-- public: prc_reset_sect
-- **********
procedure prc_reset_sect is
begin
   pkg_op_log.g_vcSect := null;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_reset_sect;

-- **********
-- public: prc_reset_sess_log_vbls
-- **********
procedure prc_reset_sess_log_vbls is

begin
   pkg_op_log.prc_reset_sect;
   pkg_op_log.prc_set_log_tbl_stat(nvl(pkg_op_log.g_blnCurrLogTblStat,pkg_op_log.g_blnLogTblStat));
   pkg_op_log.prc_set_level(nvl(pkg_op_log.g_vcCurrLevel,pkg_op_log.fcn_get_level(pkg_op_log.g_intLevel)));
   pkg_op_log.prc_set_log_dbms_output_stat(nvl(pkg_op_log.g_vcCurrLogDBMSOutputStat,pkg_op_log.g_vcLogDBMSOutputStat));
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_reset_sess_log_vbls;

-- **********
-- public: prc_set_begin_sect
-- **********
procedure prc_set_begin_sect(
   p_vcSect in varchar2 := null) is
begin
   pkg_op_log.g_vcSect :=
      pkg_op_log.g_vcSect ||
      case
         when pkg_op_log.g_vcSect is null then null
         else '/'
      end ||
      p_vcSect;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_begin_sect;

-- **********
-- public: prc_set_end_sect
-- **********
procedure prc_set_end_sect(
   p_vcSect in varchar2) is
begin
   pkg_op_log.g_vcSect := substr(pkg_op_log.g_vcSect,1,instr(pkg_op_log.g_vcSect,p_vcSect,-1)-2);
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_end_sect;

-- **********
-- public: prc_set_assert_level
-- **********
procedure prc_set_assert_level(
   p_vcLevel in varchar2 := 'none') is
begin
   pkg_op_log.g_intAssertLevel := pkg_op_log.fcn_convert_level(p_vcLevel);
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_assert_level;

-- **********
-- public: prc_set_level
-- **********
procedure prc_set_level(
   p_vcLevel in varchar2 := 'none') is

begin

   pkg_op_log.g_intLevel := pkg_op_log.fcn_convert_level(p_vcLevel);

/*
   pkg_op_log.g_intLevel := 0;

   if lower(p_vcLevel) = 'none' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelNone;
   elsif lower(p_vcLevel) = 'fatal' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelFatal;
   elsif lower(p_vcLevel) = 'error' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelError;
   elsif lower(p_vcLevel) = 'warn' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelWarn;
   elsif lower(p_vcLevel) = 'info' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelInfo;
   elsif lower(p_vcLevel) = 'debug' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelDebug;
   elsif lower(p_vcLevel) = 'trace' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelTrace;
   elsif lower(p_vcLevel) = 'all' then
      pkg_op_log.g_intLevel := pkg_op_log.c_intLevelAll;
   else
      if lower(p_vcLevel) like '%fatalonly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelFatalOnly;
      end if;
      if lower(p_vcLevel) like '%erroronly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelErrorOnly;
      end if;
      if lower(p_vcLevel) like '%warnonly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelWarnOnly;
      end if;
      if lower(p_vcLevel) like '%infoonly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelInfoOnly;
      end if;
      if lower(p_vcLevel) like '%debugonly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelDebugOnly;
      end if;
      if lower(p_vcLevel) like '%traceonly%' then
         pkg_op_log.g_intLevel := pkg_op_log.g_intLevel + pkg_op_log.c_intLevelTraceOnly;
      end if;
   end if;
*/

exception
   when others then
      raise_application_error(-20000,sqlerrm);

end prc_set_level;

-- **********
-- public: prc_set_log_dbms_output_stat
-- **********
procedure prc_set_log_dbms_output_stat(
   p_vcLogDBMSOutput in varchar2 := 'abbrev') is
begin
   pkg_op_log.g_vcLogDBMSOutputStat := lower(p_vcLogDBMSOutput);
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_log_dbms_output_stat;

-- **********
-- public: prc_set_log_tbl_stat
-- **********
procedure prc_set_log_tbl_stat(
   p_blnLogTbl in boolean := true) is
begin
   pkg_op_log.g_blnLogTblStat := p_blnLogTbl;
exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_log_tbl_stat;

-- **********
-- public: prc_set_sess_log_vbls
-- **********
procedure prc_set_sess_log_vbls(
   p_blnLogTblStat in boolean,
   p_vcLevel in varchar2,
   p_vcLogDBMSOutputStat in varchar2) is

begin

   if
      p_blnLogTblStat is not null
      and
      p_vcLevel is not null
      and
      p_vcLogDBMSOutputStat is not null
   then
      -- save current
      pkg_op_log.g_blnCurrLogTblStat := pkg_op_log.fcn_get_log_tbl_stat;
      pkg_op_log.g_vcCurrLevel := pkg_op_log.fcn_get_level;
      pkg_op_log.g_vcCurrLogDBMSOutputStat := pkg_op_log.fcn_get_log_dbms_output_stat;
      -- set
      pkg_op_log.prc_reset_sect;
      pkg_op_log.prc_set_log_tbl_stat(p_blnLogTblStat);
      pkg_op_log.prc_set_level(p_vcLevel);
      pkg_op_log.prc_set_log_dbms_output_stat(p_vcLogDBMSOutputStat);
   else
      raise_application_error(-20000,'Invalid input parameters.');
   end if;

exception
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_set_sess_log_vbls;

-- **********
-- public: prc_trace
-- **********
procedure prc_trace(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelTraceOnly) = pkg_op_log.c_intLevelTraceOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelTrace,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_trace;

-- **********
-- public: prc_warn
-- **********
procedure prc_warn(
   p_fldDesc in t_op_log.descr%type) is
begin
   if bitand(pkg_op_log.g_intLevel,pkg_op_log.c_intLevelWarnOnly) = pkg_op_log.c_intLevelWarnOnly then
      pkg_op_log.prc_log(
         p_fldCat => c_vcLevelWarn,
         p_fldDescr => p_fldDesc);
   end if;
exception
   when pkg_exception.exc_Subroutine then
      raise;
   when others then
      raise_application_error(-20000,sqlerrm);
end prc_warn;

-- **********
-- end
-- **********

end pkg_op_log;
/

-- pkg_exception
create or replace package pkg_exception as
/**
Named exceptions for use throughout the app.
*/

   exc_ArgOutOfRange          exception;
      pragma                  exception_init(exc_ArgOutOfRange,-1428);

   exc_DeletedRecord          exception;

   exc_FailedDelete           exception;
   exc_FailedInsert           exception;
   exc_FailedUpdate           exception;

   exc_InvalidDatatype        exception;
   exc_InvalidDest            exception;
   exc_InvalidParam           exception;
   exc_InvalidParameter       exception;
   exc_InvalidProxy           exception;
   exc_InvalidRec             exception;
   exc_InvalidSync            exception;

   exc_MissingSequence        exception;
      pragma                  exception_init(exc_MissingSequence,-2289);
   exc_MissingSubtype         exception;
   exc_MissingValue           exception;

   exc_NameInUse              exception;
      pragma                  exception_init(exc_NameInUse,-955);
   exc_NoRecordFound          exception;

   exc_RaiseOnly              exception;

   exc_Subroutine             exception;
      pragma                  exception_init(exc_Subroutine,-20000);

   exc_TooManyRows            exception;

   exc_Unauthorized           exception;
   exc_UndefinedSeq           exception;
      pragma                  exception_init(exc_UndefinedSeq,-8002);
   exc_UnequalChksum          exception;
   exc_UnequalChecksum        exception;
   exc_UniqueConstraint       exception;
      pragma                  exception_init(exc_UniqueConstraint,-1);
   exc_UnknownClmn            exception;
   exc_UnknownColumn          exception;
   exc_UnsuccessfulAction     exception;

end pkg_Exception;
/

-- pkg_global
create or replace package pkg_global is
/*
Description
*/

   c_blnAudit              constant boolean := true;
   c_blnTest               constant boolean := true;
   c_intCCProd             constant pls_integer := 1;
   c_intCCTest             constant pls_integer := 2;
   c_numDaysToHrs          constant number := 1/24;
   c_numDaysToMins         constant number := 1/1440;
   c_numDaysToSecs         constant number := 1/86400;
   c_vcDateFormat          constant varchar2(21) := 'mm/dd/yyyy hh24:mi:ss';
   c_vcSchemaName          constant varchar2(30) := upper('vwr');

   -- pop_4_test constants
   c_intAmtOffset          constant pls_integer := 25;
   c_intCsatIdOffset       constant pls_integer := 500;
   c_intIdOffset           constant pls_integer := 10;

   v_colNullColumn         pkg_composite_type.t_colClmn;
   v_colNullClmn           pkg_composite_type.t_colClmn;
   v_colNullColumnName     pkg_composite_type.t_colColumnName;
   v_colNullColumnValue    pkg_composite_type.t_colColumnValue;

end pkg_global;
/

-- pkg_composite_type
create or replace package pkg_composite_type is
/**
Complex PL/SQL types used throughout the application.
*/

-- **********
-- types
-- **********
-- collections
type t_colClmn is table of pkg_composite_type.t_recClmn index by pls_integer;
type t_colColumn is table of pkg_composite_type.t_recColumn index by pls_integer;
type t_colColumnName is table of varchar2(4000) index by pls_integer;
type t_colColumnValue is table of varchar2(4000) index by pls_integer;
type t_colIntArray is table of integer index by pls_integer;
type t_colOracleName is table of varchar2(30) index by pls_integer;
type t_colPredicate is table of pkg_composite_type.t_recPredicate index by pls_integer;
type t_colRole is table of varchar2(30) index by pls_integer;

-- cursors
type t_curRef is ref cursor;

-- records
type t_recClause is record
   (
   OrderBy     pkg_composite_type.t_colOracleName,
   SetPred     pkg_composite_type.t_colPredicate,
   WherePred   pkg_composite_type.t_colPredicate
   );
type t_recClmn is record(
   Name          varchar2(4000),
   Value         varchar2(4000));
type t_recColumn is record(
   Name          varchar2(4000),
   Value         varchar2(4000));
type t_recPredicate is record
   (
   Clmn        varchar2(30),
   Value       varchar2(2000)
   );

-- **********
-- subs
-- **********
function fcn_convert_list_to_collection(p_clbList in clob, p_vcPrefix in varchar2) return typ_colMaxVarchar2;
/**
Convert a comma-delimited list of strings to a SQL collection.
@param p_clbList (mode: in, default: null) Comma-delimited list of strings.
@return typ_colMaxVarchar2 - Def.
@throws exc_Subroutine Propogated exception from subroutine.
@throws others Unexpected error.
*/

function fcn_convert_list_to_collection(p_vcList in varchar2) return typ_colVarchar;
/**
Convert a comma-delimited list of strings to a SQL collection. Strings will be lowercased.
@param p_vcList (mode: in, default: null) Comma-delimited list of strings.
@return typ_colVarchar - Def.
@throws exc_Subroutine Propogated exception from subroutine.
@throws others Unexpected error.
*/

-- **********
-- end
-- **********

end pkg_composite_type;
/

create or replace package body pkg_composite_type is

-- **********
-- constants
-- **********
c_vcPkgName constant varchar2(30) := 'pkg_composite_type';

-- **********
-- subs: public
-- **********
-- public: fcn_convert_list_to_collection(clb)
-- **********
function fcn_convert_list_to_collection(p_clbList in clob, p_vcPrefix in varchar2) return typ_colMaxVarchar2 is

   c_vcSubName       constant varchar2(40) := 'fcn_convert_list_to_collection(clb)';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colMaxVarchar2  typ_colMaxVarchar2;
   v_fldDescr        t_op_log.descr%type;
   v_clbList         clob;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_clbList = ''' || nvl(substr(p_clbList,1,3950),'null') || '''');

   if p_clbList is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   -- remove any spaces
   v_clbList := replace(p_clbList,' ','');

   -- if needed, strip the last comma from the clob
   v_clbList := case when substr(p_clbList,length(p_clbList)) = ',' then substr(v_clbList,1,length(v_clbList)-1) else v_clbList end;

   select
      p_vcPrefix ||
      substr
         (
         comma_delimit_list,
         instr(comma_delimit_list,',',1,level)+1,
         instr(comma_delimit_list,',',1,level+1)-instr(comma_delimit_list,',',1,level)-1
         ) as token
   bulk collect into v_colMaxVarchar2
   from
      (
      select ',' || v_clbList || ',' comma_delimit_list
      from dual
      )
   connect by level <= length(v_clbList)-length(replace(v_clbList,',',''))+1;

   for i in 1 .. v_colMaxVarchar2.count loop
      pkg_op_log.prc_trace('out: (' || i || ') = ''' || v_colMaxVarchar2(i) || '''');
   end loop;

   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colMaxVarchar2;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'Input parameter list contains no elements.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_convert_list_to_collection;

-- **********
-- public: fcn_convert_list_to_collection(vc)
-- **********
function fcn_convert_list_to_collection(p_vcList in varchar2) return typ_colVarchar is

   c_vcSubName       constant varchar2(34) := 'fcn_convert_list_to_collection(vc)';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colVarchar      typ_colVarchar;
   v_fldDescr        t_op_log.descr%type;
   v_vcList          varchar2(4000);

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcList = ''' || nvl(p_vcList,'null') || '''');

   if p_vcList is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   v_vcList := lower(replace(p_vcList,' ',''));

   select
      substr
         (
         comma_delimit_list,
         instr(comma_delimit_list,',',1,level)+1,
         instr(comma_delimit_list,',',1,level+1)-instr(comma_delimit_list,',',1,level)-1
         ) as token
   bulk collect into v_colVarchar
   from
      (
      select ',' || v_vcList || ',' comma_delimit_list
      from dual
      )
   connect by level <= length(v_vcList)-length(replace(v_vcList,',',''))+1;

   for i in 1 .. v_colVarchar.count loop
      pkg_op_log.prc_trace('out: (' || i || ') = ''' || v_colVarchar(i) || '''');
   end loop;

   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colVarchar;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'Input parameter list contains no elements.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_convert_list_to_collection;

-- **********
-- end
-- **********

end pkg_composite_type;
/

--create table t_audit_tbl
--(
--   audit_tbl_id   integer        constraint pk_audittbl primary key,
--   action         varchar2(3)    constraint nn_audittbl_action not null ,
--   dt             date           constraint nn_audittbl_dt not null ,
--   rec_id         number         constraint nn_audittbl_recid not null ,
--   tbl_name       varchar2(30)   constraint nn_audittbl_tblname not null ,
--   usr            varchar2(30)   constraint nn_audittbl_usr not null,
--   prev_hash      binary_float   null,
--   hash           binary_float   constraint nn_audittbl_hash not null
--);

--create table t_audit_clmn
--(
--   audit_clmn_id        integer        constraint pk_auditclmn primary key,
--   audit_tbl_id         number         constraint nn_auditclmn_audittblid not null references t_audit_tbl (audit_tbl_id),
--   name                 varchar2(30)   constraint nn_auditclmn_name not null,
--   new_value            varchar2(4000) null,
--   old_value            varchar2(4000) null,
--   prev_hash            binary_float   null,
--   hash                 binary_float   constraint nn_auditclmn_hash not null
--);


create or replace package pkg_audit is
/**
Audit object.  Supports table-level auditing implemented via triggers.
</br>
</br>
<table border="1">
   <caption align="left"><b>Revision History</b></caption>
   <tr><th><i>Ver</i></th><th><i>Date</i></th><th><i>Author</i></th><th><i>Sub</i></th><th><i>Description</i></th></tr>
   <tr><td>v01.00</td><td>01/01/2008</td><td>WB Ray</td><td>;</td><td>Created</td></tr>
   <tr><td>v01.01</td><td>01/22/2010</td><td>WB Ray</td><td>;</td><td>Modified to support different naming convention.</td></tr>
</table>
@headcom
*/

-- **********
-- types
-- **********
type typ_recAuditClmn is record
   (
   Name        varchar2(4000),
   OldValue    varchar2(4000),
   NewValue    varchar2(4000)
   );

type typ_colAuditClmn is table of typ_recAuditClmn index by pls_integer;

-- **********
-- subs: fcns
-- **********
/**
Returns status of audit flag.
@return boolean - TRUE - Auditing is enabled.  FALSE - Auditing is disabled.
@throws others Unexpected error.
*/
function fcn_get_audit_flag
   return boolean;

/**
Insert audit table record.
@param p_fldAction (mode: in, default: n/a) DML action executed.  Valid: del, ins, or upd.
@param p_fldRecID (mode: in, default: n/a) Unique ID of the record affected.
@param p_fldTblName (mode: in, default: n/a) Table on which the DML was performed.
@return t_audit_tbl.audit_tbl_id%type - The audit record id.
@throws exc_Subroutine Propogated exception from subroutine.
@throws others Unexpected error.
*/
function fcn_ins_audit_tbl(
   p_fldAction in t_audit_tbl.action%type,
   p_fldRecID in t_audit_tbl.rec_id%type,
   p_fldTblName in t_audit_tbl.tbl_name%type)
   return t_audit_tbl.audit_tbl_id%type;

function fcn_updated(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_blbOldValue in blob,
   p_blbNewValue in blob)
   return boolean;

function fcn_updated(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_clbOldValue in clob,
   p_clbNewValue in clob)
   return boolean;

function fcn_updated(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_datOldValue in date,
   p_datNewValue in date)
   return boolean;

function fcn_updated(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_numOldValue in number,
   p_numNewValue in number)
   return boolean;

function fcn_updated(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_vcOldValue in varchar2,
   p_vcNewValue in varchar2)
   return boolean;

-- **********
-- subs: prcs
-- **********
/**
Insert record into the AuditClmn table.
@param p_fldAuditTblID (mode: in, default: n/a) The parent AuditTbl ID.
@param p_colAuditClmn (mode: in, default: n/a) The record to be inserted into the AuditClmn table.
@throws exc_Subroutine Propagated exception from subroutine.
@throws others Unexpected error.
*/
procedure prc_ins_audit_clmn(
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_colAuditClmn in pkg_audit.typ_colAuditClmn);

procedure prc_purge(
   p_datPurgePriorToDT in date := null);
   
procedure prc_set_audit_flag(
   p_blnAuditFlag in boolean := true);

-- **********
-- end
-- **********

end pkg_audit;
/

create or replace package body pkg_audit is

-- **********
-- constants
-- **********
c_intEquivalent   constant pls_integer := 0;
c_vcPkgName       constant varchar2(30) := 'pkg_audit';

-- **********
-- vbls
-- **********
g_blnAuditFlag    boolean := true;

-- **********
-- subs: public
-- **********
-- public: fcn_get_audit_flag
-- **********
function fcn_get_audit_flag return boolean is

   c_vcSubName         constant varchar2(33) := 'fcn_get_audit_flag';
   c_vcModuleName      constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   return pkg_audit.g_blnAuditFlag;

exception
   when others then
      pkg_op_log.prc_set_begin_sect(c_vcModuleName);
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);
      
end fcn_get_audit_flag;

-- **********
-- public: fcn_ins_audit_tbl
-- **********
function fcn_ins_audit_tbl
   (
   p_fldAction in t_audit_tbl.action%type,
   p_fldRecID in t_audit_tbl.rec_id%type,
   p_fldTblName in t_audit_tbl.tbl_name%type
   )
   return t_audit_tbl.audit_tbl_id%type
is

   c_vcSubName         constant varchar2(33) := 'fcn_ins_audit_tbl';
   c_vcModuleName      constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_fldAuditTblID      t_audit_tbl.audit_tbl_id%type;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);
   
   insert into t_audit_tbl
      (
      audit_tbl_id,
      action,
      dt, 
      rec_id,
      tbl_name,
      usr
      ) 
   values
      (
      sq_audit_tbl.nextval,
      p_fldAction,
      sysdate,
      p_fldRecID,
      p_fldTblName,
      (select case when apex_custom_auth.get_username() is null then user else apex_custom_auth.get_username() end usr from dual)
      )
   returning audit_tbl_id
   into v_fldAuditTblID;
    
   pkg_op_log.prc_set_end_sect(c_vcModuleName);
   
   return v_fldAuditTblID;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_ins_audit_tbl;

-- **********
-- public: fcn_updated(1)
-- **********
function fcn_updated
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_blbOldValue in blob,
   p_blbNewValue in blob
   )
   return boolean
is

   c_vcSubName       constant varchar2(33) := 'fcn_updated(1)';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_blnReturnValue  boolean;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   if
      (dbms_lob.compare(p_blbOldValue,p_blbNewValue) != c_intEquivalent)
      or
      (p_blbOldValue is null and p_blbNewValue is not null)
      or
      (p_blbOldValue is not null and p_blbNewValue is null)
   then
      insert into t_audit_clmn
         (
         audit_clmn_id,
         clmn_name,
         audit_tbl_id,
         new_value, 
         old_value
         ) 
      values
         (
         sq_audit_clmn.nextval,
         p_fldClmnName,
         p_fldAuditTblID,
         case when p_blbNewValue is not null then 'New BLOB' else null end,
         case when p_blbOldValue is not null then 'Old BLOB' else null end
         )
      ;
      v_blnReturnValue := true;
   else
      v_blnReturnValue := false;
   end if;
   
   pkg_op_log.prc_set_end_sect(c_vcModuleName);

   return v_blnReturnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_updated;

-- **********
-- public: fcn_updated(2)
-- **********
function fcn_updated
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_clbOldValue in clob,
   p_clbNewValue in clob
   )
   return boolean
is

   c_vcSubName       constant varchar2(33) := 'fcn_updated(2)';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_blnReturnValue  boolean;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   if
      (dbms_lob.compare(p_clbOldValue,p_clbNewValue) != c_intEquivalent)
      or
      (p_clbOldValue is null and p_clbNewValue is not null)
      or
      (p_clbOldValue is not null and p_clbNewValue is null)
   then
      insert into t_audit_clmn
         (
         audit_clmn_id,
         clmn_name,
         audit_tbl_id,
         new_value, 
         old_value
         ) 
      values
         (
         sq_audit_clmn.nextval,
         p_fldClmnName,
         p_fldAuditTblID,
         case when p_clbNewValue is not null then 'New CLOB' else null end,
         case when p_clbOldValue is not null then 'Old CLOB' else null end
         )
      ;
      v_blnReturnValue := true;
   else
      v_blnReturnValue := false;
   end if;
   
   pkg_op_log.prc_set_end_sect(c_vcModuleName);
   
   return v_blnReturnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_updated;

-- **********
-- public: fcn_updated(3)
-- **********
function fcn_updated
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_datOldValue in date,
   p_datNewValue in date
   )
   return boolean
is

   c_vcSubName         constant varchar2(33) := 'fcn_updated(3)';
   c_vcModuleName      constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_blnReturnValue   boolean;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   if
      (p_datOldValue <> p_datNewValue)
      or
      (p_datOldValue is null and p_datNewValue is not null)
      or
      (p_datOldValue is not null and p_datNewValue is null)
   then
      insert into t_audit_clmn
         (
         audit_clmn_id,
         clmn_name,
         audit_tbl_id,
         new_value, 
         old_value
         ) 
      values
         (
         sq_audit_clmn.nextval,
         p_fldClmnName,
         p_fldAuditTblID,
         to_char(p_datNewValue,pkg_global.c_vcDateFormat),
         to_char(p_datOldValue,pkg_global.c_vcDateFormat)
         )
      ;
      v_blnReturnValue := true;
   else
      v_blnReturnValue := false;
   end if;
   
   pkg_op_log.prc_set_end_sect(c_vcModuleName);
   
   return v_blnReturnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_updated;

-- **********
-- public: fcn_updated(4)
-- **********
function fcn_updated
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_numOldValue in number,
   p_numNewValue in number
   )
   return boolean
is

   c_vcSubName          constant varchar2(33) := 'fcn_updated(4)';
   c_vcModuleName       constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_blnReturnValue     boolean;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   if
      (p_numOldValue <> p_numNewValue)
      or
      (p_numOldValue is null and p_numNewValue is not null)
      or
      (p_numOldValue is not null and p_numNewValue is null)
   then
      insert into t_audit_clmn
         (
         audit_clmn_id,
         clmn_name,
         audit_tbl_id,
         new_value, 
         old_value
         ) 
      values
         (
         sq_audit_clmn.nextval,
         p_fldClmnName,
         p_fldAuditTblID,
         to_char(p_numNewValue),
         to_char(p_numOldValue)
         )
      ;
      v_blnReturnValue := true;
   else
      v_blnReturnValue := false;
   end if;

   pkg_op_log.prc_set_end_sect(c_vcModuleName);
   
   return v_blnReturnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_updated;

-- **********
-- public: fcn_updated(5)
-- **********
function fcn_updated
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_fldClmnName in t_audit_clmn.clmn_name%type,
   p_vcOldValue in varchar2,
   p_vcNewValue in varchar2
   )
   return boolean
is

   c_vcSubName       constant varchar2(33) := 'fcn_updated(5)';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_blnReturnValue  boolean;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   if
      (p_vcOldValue <> p_vcNewValue)
      or
      (p_vcOldValue is null and p_vcNewValue is not null)
      or
      (p_vcOldValue is not null and p_vcNewValue is null)
   then
      insert into t_audit_clmn
         (
         audit_clmn_id,
         clmn_name,
         audit_tbl_id,
         new_value, 
         old_value
         ) 
      values
         (
         sq_audit_clmn.nextval,
         p_fldClmnName,
         p_fldAuditTblID,
         p_vcNewValue,
         p_vcOldValue
         )
      ;
      v_blnReturnValue := true;
   else
      v_blnReturnValue := false;
   end if;

   pkg_op_log.prc_set_end_sect(c_vcModuleName);

   return v_blnReturnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end fcn_updated;

-- **********
-- public: prc_ins_audit_clmn
-- **********
procedure prc_ins_audit_clmn
   (
   p_fldAuditTblID in t_audit_tbl.audit_tbl_id%type,
   p_colAuditClmn in pkg_audit.typ_colAuditClmn
   )
is

   c_vcSubName         constant varchar2(33) := 'prc_ins_audit_clmn';
   c_vcModuleName      constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;
   
   type typ_colEAuditClmn is table of t_audit_clmn%rowtype index by pls_integer;

   v_colEAuditClmn   typ_colEAuditClmn;

begin

   pkg_op_log.prc_set_begin_sect(c_vcModuleName);

   for i in 1 .. p_colAuditClmn.count loop
      select sq_audit_clmn.nextval into v_colEAuditClmn(i).audit_clmn_id from dual;
      v_colEAuditClmn(i).clmn_name := p_colAuditClmn(i).Name;
      v_colEAuditClmn(i).audit_tbl_id := p_fldAuditTblID;
      v_colEAuditClmn(i).old_value := p_colAuditClmn(i).OldValue;
      v_colEAuditClmn(i).new_value := p_colAuditClmn(i).NewValue;
   end loop;
   
   forall i in v_colEAuditClmn.first .. v_colEAuditClmn.last
      insert into t_audit_clmn values v_colEAuditClmn(i);

   pkg_op_log.prc_set_end_sect(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end prc_ins_audit_clmn;

-- **********
-- prc_purge
-- **********
procedure prc_purge(p_datPurgePriorToDT in date := null) is

   c_vcSubName            constant varchar2(33) := 'prc_purge';
   c_vcModuleName         constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_intRecDelCount      pls_integer;
   v_intRecRemainCount   pls_integer;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_datPurgePriorToDT = ''' ||
      nvl(to_char(p_datPurgePriorToDT,pkg_global.c_vcDateFormat),'null') || '''');

   -- del
   delete
      t_audit_tbl
   where
      dt < p_datPurgePriorToDT;

   v_intRecDelCount := sql%rowcount;

   -- remaining recs
   select
      count(*)
   into
      v_intRecRemainCount
   from
      t_audit_tbl;

   -- log
   pkg_op_log.prc_info('t_audit_tbl recs del = ''' || v_intRecDelCount || ''', recs remain = ''' ||
      v_intRecRemainCount || '''.');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred. ' ||
         'Param: ' ||
         'p_datPurgePriorToDT = ''' || nvl(to_char(p_datPurgePriorToDT,pkg_global.c_vcDateFormat),'null') ||
         '''.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_purge;

-- **********
-- public: prc_set_audit_flag
-- **********
procedure prc_set_audit_flag(p_blnAuditFlag in boolean := true) is

   c_vcSubName         constant varchar2(33) := 'prc_set_audit_flag';
   c_vcModuleName      constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_audit.g_blnAuditFlag := p_blnAuditFlag;

exception
   when others then
      pkg_op_log.prc_set_begin_sect(c_vcModuleName);
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_set_end_sect(c_vcModuleName);
      raise_application_error(-20000,sqlerrm);

end prc_set_audit_flag;

-- **********
-- end
-- **********

end pkg_audit;
/

create or replace package pkg_code_gen authid current_user is
/**
Objects and methods used for code generation.
</br>
</br>
<table border="1">
   <caption align="left"><b>Revision History</b></caption>
   <tr><th><i>Ver</i></th><th><i>Date</i></th><th><i>Author</i></th><th><i>Sub</i></th><th><i>Description</i></th></tr>
   <tr><td>v01.00</td><td>04/17/2007</td><td>WB Ray</td><td>nbsp;</td><td>Created</td></tr>
   <tr><td>v01.01</td><td>01/27/2010</td><td>WB Ray</td><td>fcn_get_default_datatype</br>fcn_assign_default_value</td>
      <td>Added</td>
   </tr>
   <tr><td>v01.01</td><td>01/29/2010</td><td>WB Ray</td><td>cur_SysTbls</td><td>Added</td></tr>
</table>
@headcom
*/

-- **********
-- forward declaration
-- **********
/**
Get the prefix of the schema table names..
@return varchar2 - Table name prefix.
@throws others Unexpected error.
*/
function fcn_get_tbl_prefix return varchar2;

-- **********
-- constants
-- **********
-- none

-- **********
-- types
-- **********
type t_colObjHier is table of varchar2(30);

type t_colObjHierRec is table of pkg_code_gen.t_recObjHier index by pls_integer;

type t_recClmn is record
   (
   clmn           user_tab_columns.column_name%type,
   data_type      user_tab_columns.data_type%type,
   tbl_dot_clmn   varchar2(61)
   );

type t_recNonSupSubObj is record (obj_name varchar2(30));

type t_recObjAndTbl is record
   (
   obj_name       varchar2(30),
   tbl_name       varchar2(30)
   );

type t_recObjHier is record
   (
   id             varchar2(30),
   base_pkg       varchar2(30),
   tbl            varchar2(30),
   vbl            varchar2(30)
   );

type t_recSrcCode is record(Code_text varchar2(500));

type t_recUserTbls is record(tbl_name user_tables.table_name%type);

-- **********
-- curs
-- **********
cursor cur_ClmnByTblList(p_vcTblList varchar2) return pkg_code_gen.t_recClmn is
   with tbl_list as
      (
      select
         substr
            (
            comma_delimit_list,
            instr(comma_delimit_list,',',1,level)+1,
            instr(comma_delimit_list,',',1,level+1)-instr(comma_delimit_list,',',1,level)-1
            ) as token
      from
         (
         select ',' || upper(p_vcTblList) || ',' comma_delimit_list
         from dual
         )
      connect by level <= length(p_vcTblList)-length(replace(p_vcTblList,',',''))+1
      )
   select
      lower(col.column_name) as clmn,
      null as data_type,
      lower(col.table_name || '.' || col.column_name) as tbl_dot_clmn
   from user_tab_columns col
   where col.table_name in (select * from tbl_list)
   order by col.column_name;

-- tables that are not a subtype of another table
cursor cur_NonSubtype return pkg_code_gen.t_recObjAndTbl is
   select
      lower(substr(table_name,3)) as obj_name,
      lower(table_name) as tbl_name
   from user_tables ut
   where
      regexp_like(ut.table_name,'^' || pkg_code_gen.fcn_get_tbl_prefix || '.*','i')
      and
      not exists (select null from vu_in_list inlist where inlist.token = lower(ut.table_name))
      and
      table_name not in
         (
         with pk as
            (
            select
               ucc.column_name,
               uc.table_name
            from
               user_constraints uc
               join user_cons_columns ucc using (constraint_name)
            where constraint_type = 'P'
            ),
         fk as
            (
            select
               ucc.column_name,
               uc.table_name
            from
               user_constraints uc
               join user_cons_columns ucc using (constraint_name)
            where constraint_type = 'R'
            )
         select pk.table_name
         from
            pk
            join fk on (pk.column_name = fk.column_name and pk.table_name = fk.table_name)
         )
   order by tbl_name;

/*
cursor cur_NonSupSubObj return t_recNonSupSubObj is
   select lower(substr(table_name,3)) as obj_name
   from user_tables
   where
      table_name like 'T@_%' escape '@'
      and
      table_name != 'T_OP_LOG'
      and
      table_name not in
         (
         with pk as
            (
            select
               ucc.column_name,
               uc.table_name
            from
               user_constraints uc
               join user_cons_columns ucc using (constraint_name)
            where constraint_type = 'P'
            ),
         fk as
            (
            select
               ucc.column_name,
               uc.table_name
            from
               user_constraints uc
               join user_cons_columns ucc using (constraint_name)
            where constraint_type = 'R'
            )
         select pk.table_name
         from
            pk
            join fk on (pk.column_name = fk.column_name and pk.table_name = fk.table_name)
         )
   order by table_name;
*/

cursor cur_SrcCode(p_vcPkgName varchar2,p_vcPkgType varchar2) return pkg_code_gen.t_recSrcCode is
   select
      --nvl(replace(text,chr(10),null),chr(9)) as code_text
      replace(text,chr(10),null) as code_text
   from user_source
   where
      name = upper(p_vcPkgName)
      and
      type = 'PACKAGE' || case when lower(p_vcPkgType)='body' then ' BODY' else null end
      and
      line >=
         (
         select
            --line + case when lower(p_vcPkgType)='body' then 1 else 2 end as line_num
            line - 1
         from user_source
         where
            name = upper(p_vcPkgName)
            and
            type = 'PACKAGE' || case when lower(p_vcPkgType)='body' then ' BODY' else null end
            and
            text like '-- subs: man%'
         )
      and
      line <=
         (
         select
            --line - 2 as line_num
            line - 1 as line_num
         from user_source
         where
            name = upper(p_vcPkgName)
            and
            type = 'PACKAGE' || case when lower(p_vcPkgType)='body' then ' BODY' else null end
            and
            --text = '-- end' || chr(10)
            text like 'end ' || lower(p_vcPkgName) || ';%'
         )
   order by line;

cursor cur_Subtype return t_recObjAndTbl is
   with pk as
      (
      select
         ucc.column_name,
         uc.table_name
      from
         user_constraints uc
         join user_cons_columns ucc using (constraint_name)
      where constraint_type = 'P'
      ),
   fk as
      (
      select
         ucc.column_name,
         uc.table_name
      from
         user_constraints uc
         join user_cons_columns ucc using (constraint_name)
      where constraint_type = 'R'
      )
   select
      lower(substr(pk.table_name,3)) as obj_name,
      lower(pk.table_name) as tbl_name
   from
      pk
      join fk on (pk.column_name = fk.column_name and pk.table_name = fk.table_name)
   order by tbl_name;

cursor cur_SysTbls return pkg_code_gen.t_recObjAndTbl is
   select
      lower(substr(table_name,instr(table_name,'_')+1)) as obj_name,
      lower(table_name) as tbl_name
   from user_tables
   -- where table_name in ('T_AUDIT_CLMN', 'T_AUDIT_TBL', 'T_OP_LOG', 'T_VALID_VALUE')
   where lower(table_name) in (select * from vu_in_list)
   order by table_name;

/*
cursor cur_UserTbls return pkg_code_gen.t_recUserTbls is
   select lower(table_name) as tbl_name
   from user_tables
   where
      table_name like 'T@_%' escape '@'
      and
      table_name != 'T_OP_LOG'
   order by table_name;
*/

-- **********
-- vbls
-- **********
-- none

-- **********
-- subs: fcns
-- **********
/**
Assign a default value based on datatype.
@param p_vcDataType (mode: in, default: null) Datatype of interest.
@return varchar2 - The default value for the specified datatype.
@throws exc_InvalidParam Encountered a null parameter.
@throws exc_Subroutine Propogated exception from subroutine.
@throws others Unexpected error.
*/
function fcn_assign_default_value(p_vcDataType in varchar2) return varchar2;

function fcn_create_dyn_list(p_colObjHierRec in pkg_code_gen.t_colObjHierRec) return varchar2;

function fcn_create_obj_hier_rec(p_colObjHier in pkg_code_gen.t_colObjHier) return pkg_code_gen.t_colObjHierRec;

/**
Return the default value for table/column name pair.
@param p_vcTblName (mode: in, default: null) The name of the table.
@param p_vcClmnName (mode: in, default: null) The name of the column.
@return varchar2 - The first 4000 characters of the default datatype.
@throws exc_InvalidParam Encountered at least one null parameter.
@throws exc_Subroutine Propogated exception from subroutine.
@throws others Unexpected error.
*/
function fcn_get_default_value
   (
   p_vcTblName in varchar2,
   p_vcClmnName in varchar2
   )
   return varchar2;

function fcn_get_sys_tbl_list return varchar2;

function fcn_get_tbl_excl_list return varchar2;

function fcn_get_obj_hier(p_vcTblName in varchar2) return pkg_code_gen.t_colObjHier;

/**
Gets the output destination for generated code.
@return varchar2 - Output destination. Returns 'screen' if global variable is null.
@throws exc_Subroutine Propagated exception from subroutine.
@throws others Unexpected error.
*/
function fcn_get_output_dest return varchar2;

function fcn_get_parent_tbl(p_vcTblName in varchar2) return varchar2;

function fcn_get_schema_abbrev return varchar2;

function fcn_get_sql_col return dbms_sql.varchar2a;

function fcn_get_sql_idx return pls_integer;

-- requires forward declaration, see above
-- function fcn_get_tbl_prefix return varchar2;

function fcn_parse_list(p_vcList in varchar2) return pkg_code_gen.t_colObjHier;

function fcn_tab(p_intNum in pls_integer) return varchar2;

-- **********
-- subs: prcs
-- **********
procedure prc_append_sql_col
   (
   p_blnNewLine in boolean,
   p_vcText in varchar2
   );

procedure prc_close_file;

procedure prc_execute_sql;

procedure prc_execute_sql_col;

procedure prc_get_param_col(
   p_vcPkg in varchar2,
   p_colErrParam out dbms_sql.varchar2a,
   p_colTraceParam out dbms_sql.varchar2a);

procedure prc_incr_sql_idx(p_intIncrAmt in pls_integer := 1);

procedure prc_open_file(p_vcFilename in varchar2 := null);

procedure prc_output_put(p_vcText in varchar2);

procedure prc_output_put_line(p_vcText in varchar2);

procedure prc_reset_sql;

procedure prc_reset_sql_col;

procedure prc_reset_sql_idx;

procedure prc_set_schema_abbrev(p_vcSchemaAbbrev in varchar2);

procedure prc_set_sys_tbl_list(p_vcSysTblList in varchar2 := 't_audit_tbl,t_audit_clmn,t_op_log');

procedure prc_set_tbl_excl_list(p_vcTblExclList in varchar2 := 't_audit_tbl,t_audit_clmn,t_op_log');

/**
Sets the output destination for generated code.
@param p_vcDest (mode: in, default: 'screen') Destination for generated code.  Valid: execute, file, screen.
@throws exc_InvalidParameter Writes error message and leaves variable unchanged.
@throws exc_Subroutine Propagated exception from subroutine.
@throws others Unexpected error.
*/
procedure prc_set_output_dest(
   p_vcDest in varchar2 := 'screen',
   p_vcFilename in varchar2 := null);

/**
Define the prefix of the schema table names.
@param p_vcPrefix (mode: in, default: 'e_') Prefix of the schema table names.
@throws others Unexpected error.
*/
procedure prc_set_tbl_prefix(
   p_vcPrefix in varchar2 := 't_');

-- **********
-- end
-- **********

end pkg_code_gen;
/

show errors;

create or replace package pkg_code_gen_audit_trg authid current_user is
/**
Generate triggers for one or more tables that will log audit
information for any DML that occurs on the table(s).
</br>
</br>
<table border="1">
   <caption align="left"><b>Revision History</b></caption>
   <tr><th><i>Ver</i></th><th><i>Date</i></th><th><i>Author</i></th><th><i>Sub</i></th><th><i>Description</i></th></tr>
   <tr><td>v01.00</td><td>05/31/2007</td><td>WB Ray</td><td>;</td><td>Created</td></tr>
   <tr><td>v01.01</td><td>01/22/2010</td><td>WB Ray</td><td>prc_create_tbl_trg</td><td>Modified naming standard</td></tr>
</table>
@headcom
*/

-- **********
-- subs: prcs
-- **********
/**
Create auditing triggers for one or more tables.
@param p_colObjHier (mode: in, default: n/a) List of table names or 'all'.
@throws exc_Subroutine Propagated exception from subroutine.
@throws others Unexpected error.
*/
procedure prc_create(p_colObjHier in pkg_code_gen.t_colObjHier);

-- **********
-- end
-- **********

end pkg_code_gen_audit_trg;
/

create or replace package body pkg_code_gen AS

-- **********
-- constants
-- **********
c_vcDefaultFilename     constant varchar2(60) := 'code_gen.sql';
c_vcPkgName             constant varchar2(30) := 'pkg_code_gen';

-- **********
-- types
-- **********
-- none

-- **********
-- curs
-- **********
-- none

-- **********
-- vbls
-- **********
g_colSQL                dbms_sql.varchar2a;
g_intSQLIdx             pls_integer := 1;
g_recFileType           utl_file.file_type;
g_vcSysTblList          varchar2(1000) := 't_audit_tbl,t_audit_clmn,t_op_log';
g_vcTblExclList         varchar2(4000) := 't_audit_tbl,t_audit_clmn,t_op_log';
g_vcOutputDest          varchar2(7) := 'screen';
g_vcSchemaAbbrev        varchar2(5) := 'star';
g_vcTblPrefix           varchar2(10) := 't_';

-- **********
-- subs: private
-- **********
-- none

-- **********
-- subs: public
-- **********
-- public: fcn_assign_default_value
-- **********
function fcn_assign_default_value(p_vcDataType in varchar2) return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_create_dyn_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_fldDescr        t_op_log.descr%type;
   v_vcDefaultValue  varchar2(25);

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcDataType = ''' || nvl(p_vcDataType,'null') || '''');

   if p_vcDataType is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   v_vcDefaultValue :=
      case substr(p_vcDataType,1,9)
         when 'DATE' then 'sysdate'
         when 'NUMBER' then '0'
         when 'TIMESTAMP' then 'systimestamp'
         when 'VARCHAR2' then '''*'''
         else '**unsupported datatype**'
      end;

   pkg_op_log.prc_trace('out: v_vcDefaultValue = ''' || nvl(v_vcDefaultValue,'null') || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcDefaultValue;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr :=
         'Missing table or column name. ' ||
         'Param: ' ||
         'p_vcDataType = ''' || nvl(p_vcDataType,'null') ||
         '''.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_assign_default_value;

-- **********
-- public: fcn_create_dyn_list
-- **********
function fcn_create_dyn_list(p_colObjHierRec in pkg_code_gen.t_colObjHierRec) return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_create_dyn_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcDynList       varchar2(310);

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   if p_colObjHierRec.count > 0 then
      for i in 1..p_colObjHierRec.count loop
         v_vcDynList :=
            case when v_vcDynList is not null then v_vcDynList || ',' end ||
            p_colObjHierRec(i).tbl;
      end loop;
   end if;

   pkg_op_log.prc_trace('out: ''' || nvl(v_vcDynList,'none') || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return nvl(v_vcDynList,'none');

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_create_dyn_list;

-- **********
-- public: fcn_create_obj_hier_rec
-- **********
function fcn_create_obj_hier_rec(p_colObjHier in pkg_code_gen.t_colObjHier) return pkg_code_gen.t_colObjHierRec is

   c_vcSubName       constant varchar2(33) := 'fcn_create_obj_hier_rec';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colObjHierRec   pkg_code_gen.t_colObjHierRec;
   v_fldDescr        t_op_log.descr%type;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   if p_colObjHier.exists(1) then
      for i in 1..p_colObjHier.count loop
         pkg_op_log.prc_trace('in: p_colObjHier(' || i || ') = ''' || nvl(p_colObjHier(i),'null') || '''');
      end loop;
   else
      raise pkg_exception.exc_InvalidParam;
   end if;

   for i in 1..p_colObjHier.count loop
      v_colObjHierRec(i).id := lower(p_colObjHier(i)) || '_id';
      v_colObjHierRec(i).tbl := pkg_code_gen.fcn_get_tbl_prefix || lower(p_colObjHier(i));
   end loop;

   for i in 1..p_colObjHier.count loop
      pkg_op_log.prc_trace('out: v_colObjHierRec(' || i || ').id = ''' || nvl(v_colObjHierRec(i).id,'null') || '''');
      pkg_op_log.prc_trace('out: v_colObjHierRec(' || i || ').tbl = ''' || nvl(v_colObjHierRec(i).tbl,'null') || '''');
   end loop;

   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colObjHierRec;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'An empty collection was passed to the subroutine.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_create_obj_hier_rec;

-- **********
-- public: fcn_get_default_value
-- **********
function fcn_get_default_value
   (
   p_vcTblName in varchar2,
   p_vcClmnName in varchar2
   )
   return varchar2
is

   c_vcSubName       constant varchar2(33) := 'fcn_get_default_value';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_fldDescr        t_op_log.descr%type;
   v_lngDataDefault  long;
   v_vcDataDefault   varchar2(4000);

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcTblName = ''' || nvl(p_vcTblName,'null') || '''');
   pkg_op_log.prc_trace('in: p_vcClmnName = ''' || nvl(p_vcClmnName,'null') || '''');

   if p_vcTblName is null or p_vcClmnName is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   select data_default
   into v_lngDataDefault
   from user_tab_columns
   where
      table_name = p_vcTblName
      and
      column_name = p_vcClmnName
   ;

   v_vcDataDefault := substr(v_lngDataDefault,1,4000);

   pkg_op_log.prc_trace('out: v_vcDataDefault = ''' || nvl(v_vcDataDefault,'null') || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcDataDefault;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr :=
         'Missing table or column name. ' ||
         'Param: ' ||
         'p_vcTblName = ''' || nvl(p_vcTblName,'null') || ''', ' ||
         'p_vcClmnName = ''' || nvl(p_vcClmnName,'null') ||
         '''.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_default_value;

-- **********
-- public: fcn_get_obj_hier
-- **********
function fcn_get_obj_hier(p_vcTblName in varchar2) return pkg_code_gen.t_colObjHier is

   c_vcSubName       constant varchar2(33) := 'fcn_get_obj_hier';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colObjHier      pkg_code_gen.t_colObjHier;
   v_fldDescr        t_op_log.descr%type;
   v_vcObjList       varchar2(600) := substr(p_vcTblName,3);
   v_vcTblName       varchar2(30) := p_vcTblName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcTblName = ''' || nvl(p_vcTblName,'null') || '''');

   if p_vcTblName is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   while v_vcTblName is not null loop
      v_vcTblName := pkg_code_gen.fcn_get_parent_tbl(v_vcTblName);
      v_vcObjList := case when v_vcTblName is not null then substr(v_vcTblName,3) || ',' else null end || v_vcObjList;
   end loop;
   v_colObjHier := pkg_code_gen.fcn_parse_list(v_vcObjList);

   for i in 1 .. v_colObjHier.count loop
      pkg_op_log.prc_trace('out: (' || i || ') = ''' || v_colObjHier(i) || '''');
   end loop;
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colObjHier;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'Missing table name.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_obj_hier;

-- **********
-- public: fcn_get_output_dest
-- **********
function fcn_get_output_dest return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_get_output_dest';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcRtnValue      varchar2(7) := nvl(pkg_code_gen.g_vcOutputDest,'screen');

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || v_vcRtnValue || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcRtnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_output_dest;

-- **********
-- public: fcn_get_parent_tbl
-- **********
function fcn_get_parent_tbl(p_vcTblName in varchar2) return varchar2 is

   c_vcSubName          constant varchar2(33) := 'fcn_get_parent_tbl';
   c_vcModuleName       constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_fldDescr           t_op_log.descr%type;
   v_vcParentTblName    varchar2(30);

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcTblName = ''' || nvl(p_vcTblName,'null') || '''');

   if p_vcTblName is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   begin
      select lower(table_name)
      into v_vcParentTblName
      from user_constraints
      where
         constraint_name =
            (
            -- pk for parent tbl
            select uc.r_constraint_name
            from user_constraints uc
            inner join user_cons_columns ucc
            using (constraint_name)
            where
               constraint_name in
                  (
                  -- fks for base tbl
                  select constraint_name
                  from user_constraints
                  where
                     table_name = upper(p_vcTblName)
                     and
                     constraint_type = 'R'
                  )
               and
               ucc.column_name in
                  (
                  -- pk for base tbl
                  select ucc.column_name
                  from user_constraints uc
                  inner join user_cons_columns ucc
                  using (constraint_name)
                  where
                     ucc.table_name = upper(p_vcTblName)
                     and
                     constraint_type = 'P'
                  )
            );

   exception
      when no_data_found then
         null;

      when others then
         raise;
   end;

   pkg_op_log.prc_trace('out: ''' || nvl(v_vcParentTblName,'null') || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcParentTblName;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'Missing table name.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_parent_tbl;

-- **********
-- public: fcn_get_schema_abbrev
-- **********
function fcn_get_schema_abbrev return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_get_schema_abbrev';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcRtnValue      varchar2(4000) := pkg_code_gen.g_vcSchemaAbbrev;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || v_vcRtnValue || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcRtnValue;

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_schema_abbrev;

-- **********
-- public: fcn_get_sql_col
-- **********
function fcn_get_sql_col return dbms_sql.varchar2a is

   c_vcSubName       constant varchar2(33) := 'fcn_get_sql_col';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colRtnValue     dbms_sql.varchar2a := pkg_code_gen.g_colSQL;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   for i in 1 .. pkg_code_gen.g_colSQL.count loop
      pkg_op_log.prc_trace('out: (' || i || ') = ''' || nvl(v_colRtnValue(i),'null') || '''');
   end loop;
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colRtnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_sql_col;

-- **********
-- public: fcn_get_sql_idx
-- **********
function fcn_get_sql_idx return pls_integer is

   c_vcSubName       constant varchar2(33) := 'fcn_get_sql_idx';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_intRtnValue     pls_integer := pkg_code_gen.g_intSQLIdx;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || nvl(to_char(v_intRtnValue),'null') || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_intRtnValue;

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_sql_idx;

-- **********
-- public: fcn_get_sys_tbl_list
-- **********
function fcn_get_sys_tbl_list return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_get_sys_tbl_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcRtnValue      varchar2(1000) := nvl(pkg_code_gen.g_vcSysTblList,'t_audit_tbl,t_audit_clmn,t_op_log');

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || v_vcRtnValue || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcRtnValue;

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_sys_tbl_list;

-- **********
-- public: fcn_get_tbl_excl_list
-- **********
function fcn_get_tbl_excl_list return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_get_tbl_excl_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcRtnValue      varchar2(4000) := nvl(pkg_code_gen.g_vcTblExclList,'t_audit_tbl,t_audit_clmn,t_op_log');

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || v_vcRtnValue || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcRtnValue;

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_tbl_excl_list;

-- **********
-- public: fcn_get_tbl_prefix
-- **********
function fcn_get_tbl_prefix return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_get_tbl_prefix';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcRtnValue      varchar2(10) := nvl(pkg_code_gen.g_vcTblPrefix,'t_');

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_op_log.prc_trace('out: ''' || v_vcRtnValue || '''');
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_vcRtnValue;

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_get_tbl_prefix;

-- **********
-- public: fcn_parse_list
-- **********
function fcn_parse_list(p_vcList in varchar2) return pkg_code_gen.t_colObjHier is

   c_vcSubName       constant varchar2(33) := 'fcn_parse_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colRtnValue     pkg_code_gen.t_colObjHier;
   v_fldDescr        t_op_log.descr%type;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcList = ''' || nvl(p_vcList,'null') || '''');

   if p_vcList is null then
      raise pkg_exception.exc_InvalidParam;
   end if;

   select
      substr
         (
         comma_delimit_list,
         instr(comma_delimit_list,',',1,level)+1,
         instr(comma_delimit_list,',',1,level+1)-instr(comma_delimit_list,',',1,level)-1
         ) as token
   bulk collect into v_colRtnValue
   from
      (
      select ',' || p_vcList || ',' comma_delimit_list
      from dual
      )
   connect by level <= length(p_vcList)-length(replace(p_vcList,',',''))+1;

   for i in 1 .. v_colRtnValue.count loop
      pkg_op_log.prc_trace('out: (' || i || ') = ''' || v_colRtnValue(i) || '''');
   end loop;
   pkg_op_log.prc_end_module(c_vcModuleName);

   return v_colRtnValue;

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'Missing table name.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,v_fldDescr);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_parse_list;

-- **********
-- public: fcn_tab
-- **********
function fcn_tab(p_intNum in pls_integer) return varchar2 is

   c_vcSubName       constant varchar2(33) := 'fcn_tab';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   c_chrTab          constant char(1) := chr(9);

begin

   return lpad(c_chrTab,p_intNum,c_chrTab);

exception
   when others then
      pkg_op_log.prc_set_begin_sect(c_vcModuleName);
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end fcn_tab;

-- **********
-- public: prc_append_sql_col
-- **********
procedure prc_append_sql_col
   (
   p_blnNewLine in boolean,
   p_vcText in varchar2
   )
is

   c_vcSubName       constant varchar2(33) := 'prc_append_sql_col';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace
      (
      'in: p_blnNewLine = ''' ||
      case p_blnNewLine when true then 'true' when false then 'false' else 'null' end ||
      ''''
      );
   pkg_op_log.prc_trace('in: p_vcText = ''' || nvl(p_vcText,'null') || '''');

   pkg_code_gen.g_colSQL(pkg_code_gen.g_intSQLIdx) :=
      case
         when pkg_code_gen.g_colSQL.exists(pkg_code_gen.g_intSQLIdx) then
            pkg_code_gen.g_colSQL(pkg_code_gen.g_intSQLIdx) || p_vcText
         else
            nvl(p_vcText,chr(9))
      end;
   if p_blnNewLine then
      pkg_code_gen.g_intSQLIdx := pkg_code_gen.g_intSQLIdx + 1;
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_append_sql_col;

-- **********
-- public: prc_close_file
-- **********
procedure prc_close_file is

   c_vcSubName       constant varchar2(33) := 'prc_close_file';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   if utl_file.is_open(pkg_code_gen.g_recFileType) then
      utl_file.fclose(pkg_code_gen.g_recFileType);
      pkg_op_log.prc_trace('bdy: file closed');
   else
      pkg_op_log.prc_trace('bdy: file is not open, no need to close');
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_close_file;

-- **********
-- public: prc_execute_sql
-- **********
procedure prc_execute_sql is

   c_vcSubName       constant varchar2(33) := 'prc_execute_sql';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   if pkg_code_gen.g_colSQL.count != 0 then
      pkg_code_gen.prc_execute_sql_col;
      pkg_code_gen.prc_reset_sql;
      pkg_op_log.prc_info('Execution complete.');
   else
      pkg_op_log.prc_trace('bdy: nothing to execute');
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_execute_sql;

-- **********
-- public: prc_execute_sql_col
-- **********
procedure prc_execute_sql_col is

   c_vcSubName       constant varchar2(33) := 'prc_execute_sql_col';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_intCur          pls_integer;
   v_intNumRows      pls_integer;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   v_intCur := dbms_sql.open_cursor;
   pkg_op_log.prc_trace('bdy: opened v_intCur = ''' || v_intCur || '''');

   pkg_op_log.prc_trace('bdy: ub = ''' || to_char(pkg_code_gen.g_intSQLIdx-1) || '''');

   begin
      dbms_sql.parse
         (
         c => v_intCur,
         statement => pkg_code_gen.fcn_get_sql_col,
         lb => 1,
         ub => pkg_code_gen.g_intSQLIdx-1,
         lfflg => true,
         language_flag => dbms_sql.native
         );
      pkg_op_log.prc_trace('bdy: parsed cur');

      v_intNumRows := dbms_sql.execute(v_intCur);
      pkg_op_log.prc_trace('bdy: executed cur, v_intNumRows = ''' || v_intNumRows || '''');
   exception
      when pkg_exception.exc_NameInUse then
         pkg_op_log.prc_error('Package has manually-coded subroutines.  Code must be copied to package specification and body.');

      when others then
         raise;
   end;

   dbms_sql.close_cursor(v_intCur);
   pkg_op_log.prc_trace('bdy: closed cur');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      if dbms_sql.is_open(v_intCur) then
         dbms_sql.close_cursor(v_intCur);
         pkg_op_log.prc_trace('bdy: closed cur');
      end if;
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      if dbms_sql.is_open(v_intCur) then
         dbms_sql.close_cursor(v_intCur);
         pkg_op_log.prc_trace('bdy: closed cur');
      end if;
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_execute_sql_col;

-- **********
-- public: prc_get_param_col
-- **********
-- p_vcPkg - pkg name
procedure prc_get_param_col(
   p_vcPkg in varchar2,
   p_colErrParam out dbms_sql.varchar2a,
   p_colTraceParam out dbms_sql.varchar2a) is

   c_vcSubName          constant varchar2(33) := 'prc_get_param_col';
   c_vcModuleName       constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_intErrIdx          pls_integer := 1;
   v_intTraceIdx        pls_integer := 1;
   v_vcParamStr1        varchar2(250);
   v_vcParamStr2        varchar2(250);
   v_vcSubName          varchar2(60) := 'XX';

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcPkg = ''' || nvl(p_vcPkg,'null') || '''');

   for cur_Arg in (
      select
         case when ua.overload is not null then ua.object_name || '(' || ua.overload || ')' else ua.object_name end sub_name,
         nvl(ua.argument_name,'none') param,
         ua.data_type
      from user_arguments ua
      where
         ua.package_name = upper(p_vcPkg)
         and ua.data_level = 0
         and in_out != 'OUT'
      order by
         object_name,
         overload,
         position) loop

      pkg_op_log.prc_trace('bdy: cur_Arg.sub_name = ''' || cur_Arg.sub_name || '''');
      if v_vcSubName != cur_Arg.sub_name and v_intErrIdx > 3 then
         p_colErrParam(v_intErrIdx-1) := substr(p_colErrParam(v_intErrIdx-1),1,length(p_colErrParam(v_intErrIdx-1))-10);
         p_colErrParam(v_intErrIdx) := q'[   '''.');]';
         v_intErrIdx := v_intErrIdx + 1;
      end if;

      if v_vcSubName != cur_Arg.sub_name then
         p_colTraceParam(v_intTraceIdx) := p_vcPkg || '.' || cur_Arg.sub_name || ':';
         v_intTraceIdx := v_intTraceIdx + 1;

         p_colErrParam(v_intErrIdx) := p_vcPkg || '.' || cur_Arg.sub_name || ':';
         v_intErrIdx := v_intErrIdx + 1;

         p_colErrParam(v_intErrIdx) := q'[pkg_op_log.prc_error(]';
         v_intErrIdx := v_intErrIdx + 1;

         p_colErrParam(v_intErrIdx) := q'['An unexpected error occurred. Param: ' ||]';
         v_intErrIdx := v_intErrIdx + 1;
      end if;

      v_vcSubName := cur_Arg.sub_name;

      -- trace
      pkg_op_log.prc_trace('bdy: cur_Arg.data_type = ''' || cur_Arg.data_type || '''');
      case
         when cur_Arg.data_type is null then
            v_vcParamStr1 := null;
            v_vcParamStr2 := q'[');]';
         when cur_Arg.data_type in ('CHAR', 'VARCHAR2') then
            v_vcParamStr1 := q'[ = ''' || nvl(]';
            v_vcParamStr2 := q'[,'null') || '''');]';
         when cur_Arg.data_type in ('BINARY_INTEGER', 'NUMBER') then
            v_vcParamStr1 := q'[ = ''' || nvl(to_char(]';
            v_vcParamStr2 := q'[),'null') || '''');]';
         when cur_Arg.data_type in ('DATE') then
            v_vcParamStr1 := q'[= ''' || nvl(to_char(]';
            v_vcParamStr2 := q'[,'mm/dd/yyyy hh24:mi:ss'),'null') || '''');]';
         else
            v_vcParamStr1 := q'[ = '']';
            v_vcParamStr2 := q'[(]' || lower(cur_Arg.data_type) || q'[)' || '''');]';
      end case;

      p_colTraceParam(v_intTraceIdx) :=
         q'[pkg_op_log.prc_trace('in: ]' ||
         lower(cur_Arg.param) ||
         v_vcParamStr1 ||
         case when cur_Arg.param = 'none' then null else lower(cur_Arg.param) end ||
         v_vcParamStr2;
      v_intTraceIdx := v_intTraceIdx + 1;

      -- err
      case
         when cur_Arg.data_type is null then
            v_vcParamStr1 := null;
            v_vcParamStr2 := q'[' || ''', ' ||]';
         when cur_Arg.data_type in ('CHAR', 'VARCHAR2') then
            v_vcParamStr1 := q'[ = ''' || nvl(]';
            v_vcParamStr2 := q'[,'null') || ''', ' ||]';
         when cur_Arg.data_type in ('BINARY_INTEGER', 'NUMBER') then
            v_vcParamStr1 := q'[ = ''' || nvl(to_char(]';
            v_vcParamStr2 := q'[),'null') || ''', ' ||]';
         when cur_Arg.data_type in ('DATE') then
            v_vcParamStr1 := q'[= ''' || nvl(to_char(]';
            v_vcParamStr2 := q'[,'mm/dd/yyyy hh24:mi:ss'),'null') || ''', ' ||]';
         else
            v_vcParamStr1 := q'[ = '']';
            v_vcParamStr2 := q'[(]' || lower(cur_Arg.data_type) || q'[)' || ''', ' ||]';
      end case;

      p_colErrParam(v_intErrIdx) :=
         q'[']' ||
         lower(cur_Arg.param) ||
         v_vcParamStr1 ||
         case when cur_Arg.param = 'none' then null else lower(cur_Arg.param) end ||
         v_vcParamStr2;
      v_intErrIdx := v_intErrIdx + 1;

   end loop;

   pkg_op_log.prc_trace('bdy: loop end');
   if v_intErrIdx > 1 then
      p_colErrParam(v_intErrIdx-1) := substr(p_colErrParam(v_intErrIdx-1),1,length(p_colErrParam(v_intErrIdx-1))-10);
      p_colErrParam(v_intErrIdx) := q'[   '''.');]';
   end if;

   pkg_op_log.prc_trace('out: p_colErrParam = ''p_colErrParam(dbms_sql.varchar2a)''');
   pkg_op_log.prc_trace('out: p_colTraceParam = ''p_colTraceParam(dbms_sql.varchar2a)''');
   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_get_param_col;

-- **********
-- public: prc_incr_sql_idx
-- **********
procedure prc_incr_sql_idx(p_intIncrAmt in pls_integer := 1) is

   c_vcSubName       constant varchar2(33) := 'prc_incr_sql_idx';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_intIncrAmt = ''' || nvl(p_intIncrAmt,'null') || '''');

   pkg_code_gen.g_intSQLIdx := pkg_code_gen.g_intSQLIdx + p_intIncrAmt;
   pkg_op_log.prc_trace('bdy: incr idx, g_intSQLIdx = ''' || pkg_code_gen.g_intSQLIdx || '''');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_incr_sql_idx;

-- **********
-- public: prc_open_file
-- **********
procedure prc_open_file(p_vcFilename in varchar2 := null) is

   c_vcSubName       constant varchar2(33) := 'prc_open_file';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcFilename = ''' || nvl(p_vcFilename,'null') || '''');

   pkg_code_gen.g_recFileType := utl_file.fopen('EMBOS_OUTPUT',nvl(p_vcFilename,pkg_code_gen.c_vcDefaultFilename),'W');
   pkg_op_log.prc_trace('bdy: opened file, p_vcFilename = ''' || nvl(p_vcFilename,pkg_code_gen.c_vcDefaultFilename) || '''');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_open_file;

-- **********
-- public: prc_output_put
-- **********
procedure prc_output_put(p_vcText in varchar2) is

   c_vcSubName       constant varchar2(33) := 'prc_output_put';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcOutputDest    varchar2(7) := pkg_code_gen.fcn_get_output_dest;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcText = ''' || nvl(p_vcText,'null') || '''');

   if v_vcOutputDest = 'execute' then
      pkg_code_gen.prc_append_sql_col(false,p_vcText);
   elsif v_vcOutputDest = 'file' then
      if not utl_file.is_open(pkg_code_gen.g_recFileType) then
         -- open w/default filename
         pkg_code_gen.prc_open_file;
      end if;
      utl_file.put(pkg_code_gen.g_recFileType,p_vcText);
   elsif v_vcOutputDest = 'screen' then
      dbms_output.put(p_vcText);
   else
      raise pkg_exception.exc_MissingValue;
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_output_put;

-- **********
-- public: prc_output_put_line
-- **********
procedure prc_output_put_line(p_vcText in varchar2) is

   c_vcSubName       constant varchar2(33) := 'prc_output_put_line';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_vcOutputDest    varchar2(7) := pkg_code_gen.fcn_get_output_dest;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcText = ''' || nvl(p_vcText,'null') || '''');

   if v_vcOutputDest = 'execute' then
      pkg_code_gen.prc_append_sql_col(true,p_vcText);
   elsif v_vcOutputDest = 'file' then
      if not utl_file.is_open(pkg_code_gen.g_recFileType) then
         -- open w/default filename
         pkg_code_gen.prc_open_file;
      end if;
      utl_file.put_line(pkg_code_gen.g_recFileType,p_vcText);
   elsif v_vcOutputDest = 'screen' then
      dbms_output.put_line(p_vcText);
   else
      raise pkg_exception.exc_MissingValue;
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_output_put_line;

-- **********
-- public: prc_reset_sql
-- **********
procedure prc_reset_sql is

   c_vcSubName       constant varchar2(33) := 'prc_reset_sql';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_code_gen.prc_reset_sql_col;
   pkg_code_gen.prc_reset_sql_idx;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_reset_sql;

-- **********
-- public: prc_reset_sql_col
-- **********
procedure prc_reset_sql_col is

   c_vcSubName       constant varchar2(33) := 'prc_reset_sql_col';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_code_gen.g_colSQL.delete;
   pkg_op_log.prc_trace('bdy: del g_colSQL');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_reset_sql_col;

-- **********
-- public: prc_reset_sql_idx
-- **********
procedure prc_reset_sql_idx is

   c_vcSubName       constant varchar2(33) := 'prc_reset_sql_idx';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);

   pkg_code_gen.g_intSQLIdx := 1;
   pkg_op_log.prc_trace('bdy: reset idx, g_intSQLIdx = ''' || pkg_code_gen.g_intSQLIdx || '''');

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_reset_sql_idx;

-- **********
-- public: prc_set_output_dest
-- **********
procedure prc_set_output_dest
   (
   p_vcDest in varchar2 := 'screen',
   p_vcFilename in varchar2 := null
   )
is

   c_vcSubName       constant varchar2(33) := 'prc_set_output_dest';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_fldDescr        t_op_log.descr%type;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcDest = ''' || nvl(p_vcDest,'null') || '''');

   if lower(p_vcDest) in ('execute','file','screen') then
      pkg_code_gen.g_vcOutputDest := lower(p_vcDest);
      if lower(p_vcDest) = 'file' then
         pkg_code_gen.prc_open_file(p_vcFilename);
      end if;
   else
      raise pkg_exception.exc_InvalidParam;
   end if;

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'An invalid parameter was passed to the subroutine. ' ||
         'The output destination was unchanged. ' ||
         'Param: ' ||
         'p_vcDest = ''' || nvl(p_vcDest,'null') ||
         '''.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise;

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_set_output_dest;

-- **********
-- public: prc_set_schema_abbrev
-- **********
procedure prc_set_schema_abbrev(p_vcSchemaAbbrev in varchar2) is

   c_vcSubName       constant varchar2(33) := 'prc_set_schema_abbrev';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcSchemaAbbrev = ''' || coalesce(p_vcSchemaAbbrev,'null') || '''');

   pkg_code_gen.g_vcSchemaAbbrev := lower(p_vcSchemaAbbrev);

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_set_schema_abbrev;

-- **********
-- public: prc_set_sys_tbl_list
-- **********
procedure prc_set_sys_tbl_list(p_vcSysTblList in varchar2 := 't_audit_tbl,t_audit_clmn,t_op_log') is

   c_vcSubName       constant varchar2(33) := 'prc_set_sys_tbl_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcSysTblList = ''' || nvl(p_vcSysTblList,'null') || '''');

   pkg_code_gen.g_vcSysTblList := lower(p_vcSysTblList);

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_set_sys_tbl_list;

-- **********
-- public: prc_set_tbl_excl_list
-- **********
procedure prc_set_tbl_excl_list(p_vcTblExclList in varchar2 := 't_audit_tbl,t_audit_clmn,t_op_log') is

   c_vcSubName       constant varchar2(33) := 'prc_set_tbl_excl_list';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcTblExclList = ''' || coalesce(p_vcTblExclList,'null') || '''');

   pkg_code_gen.g_vcTblExclList := lower(p_vcTblExclList);

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_set_tbl_excl_list;

-- **********
-- public: prc_set_tbl_prefix
-- **********
procedure prc_set_tbl_prefix(p_vcPrefix in varchar2 := 't_') is

   c_vcSubName       constant varchar2(33) := 'prc_set_tbl_prefix';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

begin

   pkg_op_log.prc_begin_module(c_vcModuleName);
   pkg_op_log.prc_trace('in: p_vcPrefix = ''' || nvl(p_vcPrefix,'null') || '''');

   pkg_code_gen.g_vcTblPrefix := lower(p_vcPrefix);

   pkg_op_log.prc_end_module(c_vcModuleName);

exception
   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');
      raise_application_error(-20000,sqlerrm);

end prc_set_tbl_prefix;

-- **********
-- end
-- **********

end pkg_code_gen;
/

create or replace package body pkg_code_gen_audit_trg is

-- **********
-- constants
-- **********
c_vcPkgName      constant varchar2(30) := 'pkg_code_gen_audit_trg';

-- **********
-- types
-- **********
type t_recCodeName is record
   (
   id    varchar2(30),
   tbl   varchar2(30),
   trg   varchar2(30)
   );

type t_recClmnName is record(clmn_name user_tab_columns.column_name%type);

type t_recClmnNameType is record
   (
   clmn_name      user_tab_columns.column_name%type,
   data_type      user_tab_columns.data_type%type
   );

type t_recTblName is record(tbl_name user_tables.table_name%type);

-- **********
-- cursors
-- **********
cursor cur_ClmnName(p_vcTblName varchar2) return t_recClmnName is
   select lower(column_name) as clmn_name
   from user_tab_columns
   where table_name = upper(p_vcTblName)
   order by clmn_name;

cursor cur_ClmnNameByDataType(p_vcTblName varchar2) return t_recClmnNameType is
   select
      lower(column_name) as clmn_name,
      case data_type when 'CHAR' then 'VARCHAR2' else data_type end as data_type
   from user_tab_columns
   where table_name = upper(p_vcTblName)
   order by
      data_type,
      clmn_name;

cursor cur_TblName return t_recTblName is
   select lower(ut.table_name) as tbl_name
   from user_tables ut
   where
      regexp_like(ut.table_name,'^' || pkg_code_gen.fcn_get_tbl_prefix || '.*','i')
      and
      not exists (select null from vu_in_list inlist where inlist.token = lower(ut.table_name))
   order by
      tbl_name;

-- **********
-- private: prc_create_exception_handler
-- **********
procedure prc_create_exception_handler(p_vcException in varchar2) is

   c_vcSubName            constant varchar2(30) := 'prc_create_exception_handler';

begin

   case p_vcException
      when 'exc_FailedDelete' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
            'when pkg_exception.' || p_vcException || ' then');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
            'pkg_op_log.prc_error(''Failed to delete t_audit_tbl record. '' ||');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            '''Param: '' ||');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            '''audit_tbl_id = '''''' || v_fldAuditTblID ||'); 
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            '''''''.'');');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
            'pkg_op_log.prc_set_end_sect(c_vcTrgName);');

      when 'exc_Subroutine' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
            'when pkg_exception.' || p_vcException || ' then');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
            'pkg_op_log.prc_set_end_sect(c_vcTrgName);');

      when 'others' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
            'when ' || p_vcException || ' then');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
            'pkg_op_log.prc_error(''An unexpected error occurred.'');');
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
            'pkg_op_log.prc_set_end_sect(c_vcTrgName);');

      else

         pkg_code_gen.prc_output_put_line('*** unexpected exception! ***');

   end case;

   pkg_code_gen.prc_output_put_line('');

exception
   when others then
      pkg_code_gen.prc_output_put_line('*** exception: ' || c_vcSubName || ' (SQLErrM = ' || sqlerrm || ')');
      raise;

end prc_create_exception_handler;

-- **********
-- private: prc_create_pkg_body
-- **********
procedure prc_create_trg_body(p_recCodeName in t_recCodeName) is

   c_vcSubName      constant varchar2(30) := 'prc_create_trg_body';

begin

   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'after delete or insert or update');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'on ' || p_recCodeName.tbl);
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'for each row');

   pkg_code_gen.prc_output_put_line('');
   --pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(0) ||
   --   '');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(0) ||
      'declare');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'c_vcTrgName constant varchar2(30) := ''' || p_recCodeName.trg || ''';');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'v_blnUpdated boolean := false;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'v_colAuditClmn pkg_audit.typ_colAuditClmn;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'v_fldAuditTblID t_audit_tbl.audit_tbl_id%type;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'v_intIdx pls_integer;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'v_recTAuditTbl t_audit_tbl%rowtype;');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(0) ||
      'begin');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'pkg_op_log.prc_set_begin_sect(c_vcTrgName);');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'if pkg_audit.fcn_get_audit_flag then');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
      'if deleting then');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- audit_tbl');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'v_fldAuditTblID := pkg_audit.fcn_ins_audit_tbl(''del'',:old.' || p_recCodeName.id ||
      ',''' || p_recCodeName.tbl || ''');');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- audit_clmn');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'v_intIdx := 0;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '--');

   for v_recRow in pkg_code_gen_audit_trg.cur_ClmnNameByDataType(p_recCodeName.tbl) loop

      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
         'v_intIdx := v_intIdx + 1;');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
         'v_colAuditClmn(v_intIdx).Name := ''' || v_recRow.clmn_name || ''';');
      if v_recRow.data_type = 'BLOB' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            'v_colAuditClmn(v_intIdx).OldValue := case when :old.' || v_recRow.clmn_name ||
            ' is null then null else ''Old BLOB'' end;');
      elsif v_recRow.data_type = 'CLOB' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            'v_colAuditClmn(v_intIdx).OldValue := case when :old.' || v_recRow.clmn_name ||
            ' is null then null else ''Old CLOB'' end;');
      elsif v_recRow.data_type = 'DATE' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            'v_colAuditClmn(v_intIdx).OldValue := to_char(:old.' || v_recRow.clmn_name ||
            ',pkg_global.c_vcDateFormat);');
      elsif v_recRow.data_type = 'NUMBER' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            'v_colAuditClmn(v_intIdx).OldValue := to_char(:old.' || v_recRow.clmn_name || ');');
      elsif v_recRow.data_type = 'VARCHAR2' then
         pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
            'v_colAuditClmn(v_intIdx).OldValue := :old.' || v_recRow.clmn_name || ';');
      else
         pkg_code_gen.prc_output_put_line('*** UNEXPECTED DATA TYPE! ***');
      end if;

      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
         '--');

   end loop;

   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'pkg_audit.prc_ins_audit_clmn(v_fldAuditTblID,v_colAuditClmn);');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
      'elsif inserting then');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- audit_tbl');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'v_fldAuditTblID := pkg_audit.fcn_ins_audit_tbl(''ins'',:new.' || p_recCodeName.id ||
      ',''' || p_recCodeName.tbl || ''');');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
      'elsif updating then');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- audit_tbl');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'v_fldAuditTblID := pkg_audit.fcn_ins_audit_tbl(''upd'',:old.' || p_recCodeName.id ||
      ',''' || p_recCodeName.tbl || ''');');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- compare values');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      '-- use ''or'' operator to ensure that v_blnUpdated remains TRUE once changed to TRUE');

   for v_recRow in pkg_code_gen_audit_trg.cur_ClmnName(p_recCodeName.tbl) loop

      pkg_code_gen.prc_output_put_line('');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
         'v_blnUpdated := ');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
         'pkg_audit.fcn_updated');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(5) ||
         '(v_fldAuditTblID,''' || v_recRow.clmn_name || ''',:old.' ||
         v_recRow.clmn_name || ',:new.' || v_recRow.clmn_name || ')');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
         'or');
      pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
         'v_blnUpdated;');

   end loop;

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'if not v_blnUpdated then');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
      'delete from t_audit_tbl where audit_tbl_id = v_fldAuditTblID;');
--   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
--      'v_recTAuditTbl.audit_tbl_id := v_fldAuditTblID;');
--   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
--      'if (pkg_t_audit_tbl.fcn_del(v_recTAuditTbl) = 0) then');
--   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(5) ||
--      'raise pkg_exception.exc_FailedDelete;');
--   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(4) ||
--      'end if;');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(3) ||
      'end if;');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(2) ||
      'end if;');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'end if;');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(1) ||
      'pkg_op_log.prc_set_end_sect(c_vcTrgName);');

   pkg_code_gen.prc_output_put_line('');
   pkg_code_gen.prc_output_put_line(pkg_code_gen.fcn_tab(0) ||
      'exception');

--   pkg_code_gen_audit_trg.prc_create_exception_handler('exc_FailedDelete');
   pkg_code_gen_audit_trg.prc_create_exception_handler('exc_Subroutine');
   pkg_code_gen_audit_trg.prc_create_exception_handler('others');

exception
   when others then
      pkg_code_gen.prc_output_put_line('*** exception: ' || c_vcSubName || ' (SQLErrM = ' || sqlerrm || ')');
      raise;

end prc_create_trg_body;

-- **********
-- public: prc_create_tbl_trg
-- **********
procedure prc_create_tbl_trg(p_vcTblName in varchar2) is

   c_vcSubName       constant varchar2(30) := 'prc_create_trg_body';

   v_recCodeName     pkg_code_gen_audit_trg.t_recCodeName;

begin
   v_recCodeName.tbl := lower(p_vcTblName);
   v_recCodeName.id := substr(v_recCodeName.tbl,instr(v_recCodeName.tbl,'_')+1) || '_id';
   --v_recCodeName.trg := 'trg_audit_' || substr(v_recCodeName.tbl,1,20);
   -- v_recCodeName.trg := 'trg_aud_' || substr(replace(initcap(substr(v_recCodeName.tbl,instr(v_recCodeName.tbl,'_')+1)), '_'),1,20);
   v_recCodeName.trg := 'trg_aud_' || substr(replace(substr(v_recCodeName.tbl,instr(v_recCodeName.tbl,'_')+1), '_'),1,20);

   pkg_op_log.prc_info('Creating audit trigger ''' || v_recCodeName.trg || '''.');
   pkg_code_gen.prc_output_put_line('create or replace trigger ' || v_recCodeName.trg);
   pkg_code_gen_audit_trg.prc_create_trg_body(v_recCodeName);
   pkg_code_gen.prc_output_put_line('end ' || v_recCodeName.trg || ';');

   -- do stuff based on output
   if pkg_code_gen.fcn_get_output_dest != 'execute' then
       pkg_code_gen.prc_output_put_line('-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$');
   else
      pkg_code_gen.prc_execute_sql;
    end if;

exception
   when others then
      pkg_code_gen.prc_output_put_line('*** exception: ' || c_vcSubName || ' (SQLErrM = ' || sqlerrm || ')');
      raise;

end prc_create_tbl_trg;

-- **********
-- public: prc_create
-- **********
procedure prc_create(p_colObjHier in pkg_code_gen.t_colObjHier) is

   c_vcSubName       constant varchar2(33) := 'prc_create';
   c_vcModuleName    constant varchar2(64) := c_vcPkgName || '.' || c_vcSubName;

   v_colObjHierRec   pkg_code_gen.t_colObjHierRec;
   v_fldDescr        t_op_log.descr%type;
   
begin
   
   pkg_op_log.prc_begin_module(c_vcModuleName);
   if p_colObjHier.exists(1) then
      for i in 1..p_colObjHier.count loop
         pkg_op_log.prc_trace('in: p_colObjHier(' || i || ') = ''' || nvl(p_colObjHier(i),'null') || '''');
      end loop;
   else
      raise pkg_exception.exc_InvalidParam;
   end if;

   if lower(p_colObjHier(1)) = 'all' then
      prc_set_in_list_ctx(pkg_code_gen.fcn_get_tbl_excl_list);
      for v_recUserTbls in pkg_code_gen_audit_trg.cur_TblName loop
         pkg_op_log.prc_trace('bdy: inside loop');
         pkg_code_gen_audit_trg.prc_create_tbl_trg(v_recUserTbls.tbl_name);
      end loop;
   else
      for i in 1..p_colObjHier.count loop
         pkg_code_gen_audit_trg.prc_create_tbl_trg(pkg_code_gen.fcn_get_tbl_prefix || p_colObjHier(i));
      end loop;
   end if;
   
   pkg_op_log.prc_info('Audit trigger code generation complete.');

   pkg_op_log.prc_end_module(c_vcModuleName);
   
exception
   when pkg_exception.exc_InvalidParam then
      v_fldDescr := 'One or more invalid parameters was passed to the subroutine.';
      pkg_op_log.prc_error(v_fldDescr);
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');

   when pkg_exception.exc_Subroutine then
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');

   when others then
      pkg_op_log.prc_error('An unexpected error occurred.');
      pkg_op_log.prc_end_module(c_vcModuleName,'exc');

end prc_create;

-- **********
-- end
-- **********

end pkg_code_gen_audit_trg;
/

CREATE OR REPLACE package pkg_code_gen_view is

-- **********
-- constants
-- **********

-- **********
-- types
-- **********

-- **********
-- curs
-- **********

-- **********
-- vbls
-- **********

-- **********
-- subs: fcns
-- **********
function fcn_create_tbl_alias(p_vcTbl varchar2) return varchar2;

function fcn_trunc_tbl_prefix(p_vcTbl varchar2) return varchar2;

-- **********
-- subs: prcs
-- **********
procedure prc_gen_from_tbl(p_vcTbl in varchar2, p_vcAction in varchar2 := 'display');
/*
Generate a view for a table by incorporating all parents into a joined view.
Does not work if joined to the same table more than once.
- p_vcTbl: name of the table that view will be based on.
- p_vcAction: display (output view creation code), execute (execute view creation code), both (display and execute view creation code)
Utilizes standalone functions: fcn_create_tbl_alias, fcn_trunc_tbl_prefix
*/

-- **********
-- end
-- **********

end pkg_code_gen_view;
/

CREATE OR REPLACE package body pkg_code_gen_view AS

-- **********
-- constants
-- **********
c_vcPkgName constant varchar2(30) := 'pkg_code_gen_view';

-- **********
-- subs: public
-- **********
-- public: fcn_create_tbl_alias
-- **********
function fcn_create_tbl_alias(p_vcTbl varchar2) return varchar2 is
   v_intCnt    int;
   v_vcStr     varchar2(30);
begin
   v_intCnt := regexp_count(p_vcTbl,'_');
   if v_intCnt > 1 then
      for i in 1..v_intCnt loop
         v_vcStr := v_vcStr || replace(regexp_substr(p_vcTbl,'_.',1,i),'_');
      end loop;
   else
      v_vcStr := substr(p_vcTbl, instr(p_vcTbl,'_')+1);
   end if;
   return v_vcStr;
end fcn_create_tbl_alias;

-- **********
-- public: fcn_trunc_tbl_prefix
-- **********
function fcn_trunc_tbl_prefix(p_vcTbl varchar2) return varchar2 is
begin
   return substr(p_vcTbl,instr(p_vcTbl,'_')+1);
end fcn_trunc_tbl_prefix;

-- **********
-- public: prc_gen_from_tbl
-- **********
procedure prc_gen_from_tbl(p_vcTbl in varchar2, p_vcAction in varchar2 := 'display') as

   c_vcCrLf varchar2(2) := chr(13) || chr(10);
   v_vcClmnList varchar2(32767);
   v_vcClmns varchar2(32767);
   v_vcFromClause varchar2(32767) := 'from' || c_vcCrLf;
   v_vcPrmyAbbrev varchar2(30);
   v_vcSql varchar2(32767);
   v_vcTbl varchar2(30) := upper(p_vcTbl);

begin

   v_vcSql := 'create or replace force view vu_' || pkg_code_gen_view.fcn_trunc_tbl_prefix(p_vcTbl => v_vcTbl) || ' as ' || c_vcCrLf;
   v_vcSql := v_vcSql || 'select ';

   for rec in (
      select * from (
         select
            v_vcTbl tbl,
            -- 'tbl' obj_type,
            'prmy' join_type,
            'none' fk_id
         from dual
         union all
         select
            uc.table_name tbl,
            -- case
            --    when (select max(iuc.r_constraint_name) from user_constraints iuc where iuc.table_name = uc.table_name and iuc.constraint_type = 'R') is not null then 'vu'
            --    else 'tbl'
            -- end obj_type,
            case
               when
                  (select nullable
                  from user_tab_columns utc
                  where
                     utc.table_name = v_vcTbl
                     and utc.column_name = (
                        select ucc.column_name from user_cons_columns ucc where ucc.constraint_name = uc.constraint_name and ucc.table_name = uc.table_name)) = 'N' then 'inner'
               else 'left outer'
            end join_type,
            (select ucc.column_name from user_cons_columns ucc where ucc.table_name = uc.table_name and ucc.constraint_name = uc.constraint_name) fk_id
         from
            user_constraints uc
         where
            uc.constraint_name in (
               select iuc2.r_constraint_name from user_constraints iuc2 where iuc2.table_name = v_vcTbl and iuc2.constraint_type = 'R')
            and uc.table_name != v_vcTbl)
      order by case join_type when 'prmy' then 1 else 2 end, tbl) loop
      
      if rec.join_type = 'prmy' then
         v_vcFromClause := v_vcFromClause || rec.tbl || ' ' || pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl);
         v_vcPrmyAbbrev := pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl);
      -- elsif rec.obj_type = 'tbl' then
      --    v_vcFromClause := v_vcFromClause || rec.join_type || ' join ' || rec.tbl || ' ' || fcn_create_tbl_alias(p_vcTbl => rec.tbl) || ' on (' || fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '.' || rec.fk_id || ' = ' || v_vcPrmyAbbrev || '.' || rec.fk_id || ')' || c_vcCrLf;
      else
         v_vcFromClause :=
            v_vcFromClause ||
            case when v_vcFromClause is not null then c_vcCrLf end ||
            rec.join_type || ' join ' || 'VU_' || pkg_code_gen_view.fcn_trunc_tbl_prefix(p_vcTbl => rec.tbl) || ' ' || pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) ||
            ' on (' || pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '.' || rec.fk_id || ' = ' || v_vcPrmyAbbrev || '.' || rec.fk_id || ')';
      end if;
      
      if rec.join_type = 'prmy' then
         with w_clmn as (
            select utc.table_name, utc.column_name, case when uc.constraint_type not in ('P','R') then 'X' else uc.constraint_type end constraint_type
            from
               user_tab_columns utc
               left join user_cons_columns ucc on (ucc.table_name = utc.table_name and ucc.column_name = utc.column_name)
               left join user_constraints uc on (uc.table_name = ucc.table_name and uc.constraint_name = ucc.constraint_name)
            where utc.table_name = rec.tbl)
         select listagg(clmn, ', ') within group (order by case when constraint_type = 'P' then 1 else 2 end, clmn) clmn_list
         into v_vcClmnList
         from (
            select pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '.' || column_name clmn, constraint_type
            from w_clmn
            where
               constraint_type = 'P'
            union all
            -- select distinct fcn_create_tbl_alias(p_vcTbl => wc.table_name) || column_name
            select distinct pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '.' || column_name || ' ' || pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '_' || column_name clmn, constraint_type
            from w_clmn wc
            where
               1=1
               and column_name not in (select column_name from w_clmn where constraint_type in ('P','R')));
      else
      
         select listagg(pkg_code_gen_view.fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '.' || column_name, ', ') within group (order by column_id) clmn_list
         into v_vcClmnList
         from user_tab_columns
         where table_name = 'VU_' || pkg_code_gen_view.fcn_trunc_tbl_prefix(p_vcTbl => rec.tbl);
         
      end if;

      -- dbms_output.put_line(rec.tbl || ', alias/prefix = ''' || fcn_create_tbl_alias(p_vcTbl => rec.tbl) || '''');
      -- dbms_output.put_line('obj type = ''' || rec.obj_type || '''');
      -- dbms_output.put_line('join type = ''' || rec.join_type || '''');
      -- dbms_output.put_line('fk = ''' || rec.fk_id || '''');
      -- dbms_output.put_line('clmns = ''' || v_vcClmnList || '''');
      -- dbms_output.put_line('-----');
      v_vcClmns := v_vcClmns || case when v_vcClmns is not null then c_vcCrLf end || v_vcClmnList || ', ';
   end loop;
   
   if lower(p_vcAction) in ('display','both') then
      dbms_output.put_line(lower(v_vcSql));
      dbms_output.put_line(lower(substr(v_vcClmns,1,length(v_vcClmns)-2)));
      dbms_output.put_line(lower(v_vcFromClause) || ';');
      dbms_output.put_line('-----');
   end if;
   
   if lower(p_vcAction) in ('execute','both') then
      execute immediate lower(v_vcSql || c_vcCrLf || substr(v_vcClmns,1,length(v_vcClmns)-2) || c_vcCrLf || v_vcFromClause);
      dbms_output.put_line('View ''vu_' || lower(pkg_code_gen_view.fcn_trunc_tbl_prefix(p_vcTbl => v_vcTbl)) || ''' created.');
   end if;
      
end prc_gen_from_tbl;

-- **********
-- end
-- **********

end pkg_code_gen_view;
/
