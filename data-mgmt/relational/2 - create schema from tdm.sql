exec prc_drop_all_objs;

/*
Created: 3/6/2018
Modified: 1/16/2019
Project: Software Council
Model: Database Tutorial
Company: ORNL
Author: WB Ray
Version: 1.0
Database: Oracle 12c
*/


-- Create sequences section -------------------------------------------------

CREATE SEQUENCE sq_lookup
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 20
/

CREATE SEQUENCE sq_fund_a
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 20
/

CREATE SEQUENCE sq_assoc
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 20
/

CREATE SEQUENCE sq_fund_b
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 20
/

CREATE SEQUENCE sq_op_log
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 100
/

CREATE SEQUENCE sq_audit_tbl
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 100
/

CREATE SEQUENCE sq_audit_clmn
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 100
/

-- Create tables section -------------------------------------------------

-- Table t_lookup

CREATE TABLE t_lookup(
  lookup_id Integer CONSTRAINT nn_Lookup_LookupId NOT NULL,
  abbrev Varchar2(15 ) CONSTRAINT nn_Lookup_Abbrev NOT NULL,
  code Integer CONSTRAINT nn_Lookup_Code NOT NULL,
  curr_flag Varchar2(1 ) CONSTRAINT nn_Lookup_CurrFlag NOT NULL
        CONSTRAINT ck_Lookup_CurrFlag CHECK (curr_flag in ('N','Y')),
  descr Varchar2(80 ) CONSTRAINT nn_Lookup_Descr NOT NULL,
  order_by Integer CONSTRAINT nn_Lookup_OrderBy NOT NULL,
 CONSTRAINT pk_Lookup PRIMARY KEY (lookup_id),
 CONSTRAINT uk_Lookup_Abbrev UNIQUE (abbrev),
 CONSTRAINT uk_Lookup_Code UNIQUE (code)
)
organization index
/

-- Table t_fund_a

CREATE TABLE t_fund_a(
  fund_a_id Integer CONSTRAINT nn_FundA_FundAId NOT NULL,
  lookup_id Integer CONSTRAINT nn_FundA_LookupId NOT NULL,
  name Varchar2(30 ) CONSTRAINT nn_FundA_Name NOT NULL,
 CONSTRAINT pk_FundA PRIMARY KEY (fund_a_id)
)
/

-- Create indexes for table t_fund_a

CREATE INDEX fk_Relationship1 ON t_fund_a (lookup_id)
/

-- Table t_fund_b

CREATE TABLE t_fund_b(
  fund_b_id Integer CONSTRAINT nn_FundB_FundBId NOT NULL,
  compl_date Date CONSTRAINT nn_FundB_ComplDate NOT NULL
        CONSTRAINT ck_FundB_ComplDate CHECK (compl_date = trunc(compl_date)),
  name Varchar2(30 ) CONSTRAINT nn_FundB_Name NOT NULL,
 CONSTRAINT pk_FundB PRIMARY KEY (fund_b_id)
)
/

-- Table t_assoc

CREATE TABLE t_assoc(
  assoc_id Integer CONSTRAINT nn_Assoc_AssocId NOT NULL,
  create_dt Date DEFAULT ON NULL sysdate CONSTRAINT nn_Assoc_CreateDt NOT NULL,
  fund_a_id Integer CONSTRAINT nn_Assoc_FundAId NOT NULL,
  fund_b_id Integer,
 CONSTRAINT pk_Assoc PRIMARY KEY (assoc_id),
 CONSTRAINT uk_Assoc_Comp01 UNIQUE (fund_a_id,create_dt,fund_b_id)
)
/

-- Create indexes for table t_assoc

CREATE INDEX fk_Relationship2 ON t_assoc (fund_a_id)
/

CREATE INDEX fk_Relationship3 ON t_assoc (fund_b_id)
/

-- Table t_op_log

CREATE TABLE t_op_log(
  op_log_id Integer,
  cat Varchar2(5 ),
  descr Varchar2(4000 ),
  err_code Integer,
  err_msg Varchar2(512 ),
  module Varchar2(4000 ),
  sess_id Varchar2(256 ),
  ts Timestamp(4) with local time zone,
  usr Varchar2(30 )
)
/

-- Table t_audit_clmn

CREATE TABLE t_audit_clmn(
  audit_clmn_id Integer CONSTRAINT nn_AuditClmn_AuditClmnId NOT NULL,
  audit_tbl_id Integer CONSTRAINT nn_AuditClmn_AuditTblId NOT NULL,
  clmn_name Varchar2(30 ) CONSTRAINT nn_AuditClmn_ClmnName NOT NULL,
  new_value Varchar2(4000 ),
  old_value Varchar2(4000 ),
 CONSTRAINT pk_AuditClmn PRIMARY KEY (audit_clmn_id)
)
/

-- Create indexes for table t_audit_clmn

CREATE INDEX fk_AuditTbl_AuditClmn ON t_audit_clmn (audit_tbl_id)
/

-- Table t_audit_tbl

CREATE TABLE t_audit_tbl(
  audit_tbl_id Integer CONSTRAINT nn_AuditTbl_AuditTblId NOT NULL,
  action Varchar2(3 ) CONSTRAINT nn_AuditTbl_Action NOT NULL,
  dt Date CONSTRAINT nn_AuditTbl_Dt NOT NULL,
  rec_id Integer CONSTRAINT nn_AuditTbl_RecId NOT NULL,
  tbl_name Varchar2(30 ) CONSTRAINT nn_AuditTbl_TblName NOT NULL,
  usr Varchar2(30 ) CONSTRAINT nn_AuditTbl_Usr NOT NULL,
 CONSTRAINT pk_AuditTbl PRIMARY KEY (audit_tbl_id)
)
/


-- Create foreign keys (relationships) section ------------------------------------------------- 

ALTER TABLE t_fund_a ADD CONSTRAINT fk_Lookup_FundA FOREIGN KEY (lookup_id) REFERENCES t_lookup (lookup_id) ON DELETE CASCADE
/


ALTER TABLE t_assoc ADD CONSTRAINT fk_FundA_Assoc FOREIGN KEY (fund_a_id) REFERENCES t_fund_a (fund_a_id) ON DELETE CASCADE
/


ALTER TABLE t_assoc ADD CONSTRAINT fk_FundB_Assoc FOREIGN KEY (fund_b_id) REFERENCES t_fund_b (fund_b_id) ON DELETE CASCADE
/


ALTER TABLE t_audit_clmn ADD CONSTRAINT fk_AuditTbl_AuditClmn FOREIGN KEY (audit_tbl_id) REFERENCES t_audit_tbl (audit_tbl_id) ON DELETE CASCADE
/
