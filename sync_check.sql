create or replace procedure gg_sync_records(pi_table_name in varchar2,
                                            pi_batch_size in number default 1000,
                                            pi_destination_db_link in varchar2,
                                            pi_diff       out number,
                                            pi_err        out varchar2)
AUTHID CURRENT_USER as
v_str varchar2(4000):=null;
v_err varchar2(4000):=null;
v_status varchar2(2):='S';
v_pk_seq_tab_col varchar2(100):=null;
v_pk_tab_col_list varchar2(1000):=null;
v_all_tab_col_list varchar2(1000):=null;

v_col_min_val number:=0;
v_col_max_val number:=0;

v_strt_no number:=0;
v_end_no  number:=0;

v_iter number:=0;

v_global_name varchar2(100):=null;

TYPE t_row IS RECORD (column1  NUMBER,hash_val NUMBER);

TYPE t_tab IS TABLE OF t_row;
  l_tab t_tab := t_tab();
  l_tab2 t_tab := t_tab();
  l_tab3 t_tab := t_tab();


begin

--check if db link works
v_str:='select count(1) from dual@'||pi_destination_db_link;

select * into v_global_name from global_name;

begin
execute immediate v_str;
exception when others then
v_err:='Error connecting via db link '||substr(sqlerrm,1,150);
v_status:='E';
end;

--fetch the column of the table that is a seq and part of primary key
if v_status='S' then
begin
    SELECT pk1_column into v_pk_seq_tab_col
    FROM gg_primary_key_list
    WHERE
    table_name=UPPER(pi_table_name);
exception when others then
v_err:='Error fetching the table info '||substr(sqlerrm,1,150);
v_status:='E';
end;
end if;


--fetch all the columns that are part of primary key
if v_status='S' then
begin
    SELECT LISTAGG(cols.column_name, ', ') WITHIN GROUP (ORDER BY POSITION ASC)
    into v_pk_tab_col_list
    FROM all_constraints cons NATURAL JOIN all_cons_columns cols
    WHERE cons.constraint_type = 'P' AND table_name = UPPER(pi_table_name);  
exception when others then
v_err:='Error fetching primary key column list'||substr(sqlerrm,1,150);
v_status:='E';
end;
end if;

--select max and min value of the pk sequence table column
if v_status='S' then
begin
    v_str:='select min('||v_pk_seq_tab_col||'),max('||v_pk_seq_tab_col||')'||chr(10)||
            ' from '||pi_table_name||' where '||v_pk_seq_tab_col||' > 0';
    execute immediate v_str into v_col_min_val,v_col_max_val;
    
exception when others then
v_err:='Error fetching primary key column list'||substr(sqlerrm,1,150);
v_status:='E';
end;
end if;

--calculate no of iterations based on input batch size
if v_status='S' then
select round((v_col_max_val-v_col_min_val)/pi_batch_size) into v_iter from dual;
select decode(v_iter,0,1,v_iter) into v_iter from dual ;
end if;

---fetch rest of the columns excluding the pk columns of the table
if v_status='S' then
begin
        SELECT LISTAGG(COLUMN_NAME, '||') WITHIN GROUP (ORDER BY COLUMN_ID ASC)
        into v_all_tab_col_list
        FROM all_TAB_columns 
        WHERE 
        TABLE_NAME=UPPER(pi_table_name);
exception when others then
v_err:='Error fetching rest of columns excluding primary key'||substr(sqlerrm,1,150);
v_status:='E';
end;
end if;

--select statement format pkcolumn,hash_value
if v_status='S' then
begin
    v_str:='select '||v_pk_tab_col_list||' ,ora_hash('||v_all_tab_col_list||') hash_val'||chr(10)||
            ' from '||pi_table_name||'@DB_LINK '||chr(10)||
            'where '||v_pk_seq_tab_col||' between :v_strt_no and :v_end_no'||chr(10)||
            'order by '||v_pk_seq_tab_col||' asc';
end;
end if;
DBMS_OUTPUT.PUT_LINE(v_str);

if v_status='S' then

for idx in 1..v_iter
loop

    --select the start and end value of the pk seq table col 
    v_strt_no:= case idx when 1 then v_col_min_val else v_end_no+1 end;
    v_end_no := case idx when 1 then v_col_min_val+pi_batch_size else v_end_no+pi_batch_size end;
    
    --dbms_output.put_line('the no of iterations '||idx||' start:'||v_strt_no||' end:'||v_end_no);

    v_str:=REPLACE(v_str,'DB_LINK',v_global_name);
    execute immediate v_str bulk collect into l_tab using v_strt_no,v_end_no;
    DBMS_OUTPUT.PUT_LINE('l_tab COUNT '||l_tab.COUNT);
    v_str:=REPLACE(v_str,'DB_LINK',pi_destination_db_link);
    execute immediate v_str bulk collect into l_tab2 using v_strt_no,v_end_no;
    DBMS_OUTPUT.PUT_LINE('l_tab COUNT '||l_tab2.COUNT);
    
     l_tab3 := l_tab MULTISET EXCEPT l_tab2;
     
     FOR i IN l_tab3.first .. l_tab3.last LOOP
    DBMS_OUTPUT.put_line(l_tab3(i));
    END LOOP;

end loop;
end if;


pi_err:=v_err;
end;
