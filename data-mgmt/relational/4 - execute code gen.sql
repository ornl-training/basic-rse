-- **********
-- 2019-01-17 - code gen
-- **********

-- gen views
declare
   procedure prc_gen_views is
   begin
      for cur in (select table_name tbl from user_tables where table_name in (select token table_name from vu_in_list) order by 1) loop
         pkg_code_gen_view.prc_gen_from_tbl(p_vcTbl => cur.tbl, p_vcAction => 'both');
      end loop;
   end prc_gen_views;
begin

   pkg_op_log.prc_set_sess_log_vbls(p_blnLogTblStat => false, p_vcLevel => 'info', p_vcLogDBMSOutputStat => 'abbrev');

   prc_set_in_list_ctx('T_LOOKUP,T_FUND_B,T_AUDIT_TBL');
   prc_gen_views;

   prc_set_in_list_ctx('T_FUND_A,T_AUDIT_CLMN');
   prc_gen_views;

   prc_set_in_list_ctx('T_ASSOC');
   prc_gen_views;

end;