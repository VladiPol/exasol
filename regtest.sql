OPEN SCHEMA REGTEST;

CREATE OR REPLACE LUA SCRIPT "REGTEST_MAIN" (debug_flag,
                                             src_schema_name,src_table_name,
                                             dst_schema_name,dst_table_name,
                                             all_exclude_columns) RETURNS TABLE AS
-- ******************************************************
-- crript generates the minus select of two tables
-- for the regression test
-- created by Vladimir Poliakov
--
-- input parameters are
-- src_schema, src_table_name     - reference schema.table
-- dst_schema_name,dst_table_name - remap schema.table
-- all_exclude_columns            - the list of exclude columns comma separated
-- ******************************************************  

-- ******************************************************
-- START OF function debug(output_string)
  function debug(output_string)
    if debug_flag == true then
      output(output_string)
    end
  end
-- END OF function debug(output_string)

-- ******************************************************
-- START OF function create_select(schema_name, table_name)
-- ATTENTION: the database user has to have access to the table in EXA_ALL_COLUMNS
-- 
--   The function generates the SELECT ... FROM schema_name.table_name query
--   INPUT:
--     schema_name,table_name - parameter to get all columns for query 
--   OUTPUT:
--     SELECT ... FROM ... schema_name.table_name 
--
  function create_select(schema_name, table_name, exclude_columns)
    debug('get columns for '..schema_name..'.'..table_name)

    -- parse exclude_columns string
    local parsed_exclude_columns = null
    if exclude_columns ~= null then
      parsed_exclude_columns = sqlparsing.tokenize(exclude_columns)
      debug('exclude column(s) --> '..exclude_columns)
    end
    
    -- output('input parameters '..schema_name..'.'..table_name)
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
      -- check exclude columns
      local ifNotExcludedColumns = null
      if parsed_exclude_columns ~= null then
        ifNotExcludedColumns = sqlparsing.find(parsed_exclude_columns,1,true,false,sqlparsing.iswhitespaceorcomment,string.upper(columns[i][1]))
      end

      if ifNotExcludedColumns == nil then
        if i == #columns then
          concat_str = concat_str..columns[i][1]
        else
          concat_str = concat_str..columns[i][1]..', '
        end
      end

    end -- for i=1, #columns do

    concat_str = concat_str..' FROM '..schema_name..'.'..table_name
    debug('create_select RETURN -->; '..concat_str)
    -- output('create_select RETURN -->; '..concat_str)
    return concat_str
  end
-- END OF function get_columns(schema_name, table_name)
-- ******************************************************
  
-- ******************************************************
-- START OF create_MINUS_select(first_select, second_select)
  function create_MINUS_select(first_select, second_select)
    concat_str = first_select..'\n'..'MINUS'..'\n'..second_select..';'
    debug('create_MINUS_select -->; '..concat_str)
    -- output('create_MINUS_select RETURN -->; '..concat_str)
    return concat_str
  end

-- END OF create_MINUS_select(first_select, second_select)
-- ******************************************************

-- ******************************************************
-- MAIN PART OF REGRESSION TEST FRAMEWORK
-- ******************************************************  

  local first_select  = create_select(src_schema_name,src_table_name,all_exclude_columns)
  local second_select = create_select(dst_schema_name,dst_table_name,all_exclude_columns)
  local REGTEST_OUTPUT = 'regtest_output varchar(4000)'

  -- get MINUS query for all differences
  result = { {create_MINUS_select(first_select, second_select)}, {create_MINUS_select(second_select, first_select)} }
  return result, REGTEST_OUTPUT
/

COMMIT;

EXECUTE SCRIPT REGTEST_MAIN (true, 'TEST_USER', 'T_KUNDE_TEST', 'L0D_M00_SANDBOX_301875', 'T_KUNDE_TEST_BKP', 'ID,STRASSE');

EXECUTE SCRIPT REGTEST_MAIN (true, 'TEST_USER', 'T_KUNDE_TEST', 'L0D_M00_SANDBOX_301875', 'T_KUNDE_TEST_BKP', 'ID,STRASSE') with output;

CREATE OR REPLACE TABLE T_KUNDE_TEST (
    ID      DECIMAL(9,0),
    TITEL   VARCHAR(20) UTF8,
    VORNAME VARCHAR(50) UTF8 NOT NULL,
    NAME    VARCHAR(50) UTF8 NOT NULL,
    STRASSE VARCHAR(50) UTF8,
    HAUSNR  VARCHAR(10) UTF8,
    PLZ     VARCHAR(5)  UTF8,
    STADT   VARCHAR(50) UTF8
);
                                                                                      
