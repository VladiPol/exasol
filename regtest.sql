OPEN SCHEMA REGTEST;
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Exasol Script Framework for Regression Test
-- Created by Vladimir Poliakov (www.datenanalyseexpert.de)
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/*  
  INPUT
    src_schema_name,src_table_name - first schema_name.table_name in MINUS query
    dst_schema_name,dst_table_name - second schema_name.table_name in MINUS query
  OUTPUT
    select ... from src_schema_name.src_table_name MINUS select ... from dst_schema_name.dst_table_name
*/
CREATE OR REPLACE SCRIPT "REGTEST_MAIN" (src_schema_name,src_table_name,dst_schema_name,dst_table_name) RETURNS TABLE AS
-- ******************************************************
-- START OF function create_select(schema_name, table_name)
-- ATTENTION: the database user has to have access to the table in EXA_ALL_COLUMNS
/* 
   The function generates the SELECT ... FROM schema_name.table_name query
   INPUT:
     schema_name,table_name - parameter to get all columns for query 
   OUTPUT:
     SELECT ... FROM ... schema_name.table_name 
*/   
  function create_select(schema_name, table_name)
    output('input parameters '..schema_name..'.'..table_name)
    -- get all columns for MINUS query
    local success, columns = pquery([[SELECT COLUMN_NAME FROM EXA_ALL_COLUMNS WHERE COLUMN_SCHEMA = :s AND COLUMN_TABLE = :t]], {s=schema_name,t=table_name})
    if not success then
      error()
    end
   
    -- no columns found
    -- user has no access to this table
    if #columns == 0 then
      error('no columns found for '..src_schema_name..'.'..src_table_name..' Please check if your database user has sccess to this information')
    end
    -- concat columns and generate query
    -- generate query
    local concat_str = 'SELECT '  
    for i=1, #columns do
      if i == #columns then
        concat_str = concat_str..columns[i][1]
      else
        concat_str = concat_str..columns[i][1]..', '
      end
    end
    concat_str = concat_str..' FROM '..schema_name..'.'..table_name
    -- debug
    output('create_select RETURN --> '..concat_str)
    return concat_str
  end
-- END OF function get_columns(schema_name, table_name)
-- ******************************************************
  
-- ******************************************************
-- START OF create_MINUS_select(first_select, second_select)
  function create_MINUS_select(first_select, second_select)
    concat_str = first_select..'\n'..'MINUS'..'\n'..second_select..';'
    -- debug
    output('create_MINUS_select RETURN --> '..concat_str)
    return concat_str
  end

-- END OF create_MINUS_select(first_select, second_select)
-- ******************************************************

-- ******************************************************
-- MAIN PART OF REGRESSION TEST FRAMEWORK
-- ******************************************************  

  local first_select  = create_select(src_schema_name,src_table_name)
  local second_select = create_select(dst_schema_name,dst_table_name)
  
  -- get MINUS query for all differences
  result = { {create_MINUS_select(first_select, second_select)}, {create_MINUS_select(second_select, first_select)} }
  return result, "regtest_output varchar(4000)"
/

EXECUTE SCRIPT REGTEST_MAIN ('TEST_USER', 'DOENER_IMBISS', 'TEST_USER', 'DOENER_IMBISS_BKP');

EXECUTE SCRIPT REGTEST_MAIN ('TEST_USER', 'DOENER_IMBISS', 'TEST_USER', 'DOENER_IMBISS_BKP') WITH OUTPUT;