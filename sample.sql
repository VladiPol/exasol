import ('tools.tools_package','tools')

skript_komponente = 'EXEC_REGTEST'
skript_name = 'EXEC_REGTEST'
return_struct = 'RETURN_CODE INTEGER, RETURN_MESSAGE VARCHAR(1000) UTF8'

-- Ermittlung der nächsten Lauf-ID
status, lauf_id = pquery([[SELECT NVL(MAX(TEST_LAUF_ID), 0) + 1 FROM TOOLS.T_REGTEST_ERGEBNIS]]);

if not status then
   log_msg = 'Fehler bei der Ermittlung der nächsten Lauf-ID'
   output(log_msg)
   tools.protokoll(skript_komponente, skript_name, 1, log_msg, spalten_fuer_test.error_message)
   exit( {{ decimal(1), error_msg }}, return_struct)
end

log_msg = 'Starte Regressionstest für Lauf-ID = ' .. lauf_id[1][1]
output(log_msg)
tools.protokoll(skript_komponente, skript_name, 1, log_msg, '')

-- Ermittlung aller Spalten für den Regressionstest
status, spalten_fuer_test = pquery( [[
   SELECT COLUMN_SCHEMA,
          COLUMN_TABLE,
          COLUMN_NAME,
          COLUMN_TYPE
     FROM SYS.EXA_ALL_COLUMNS
    WHERE (COLUMN_SCHEMA LIKE 'L2C%'           -- Begrenzung auf Spalten in L2C...
       OR COLUMN_SCHEMA LIKE 'L3%')            -- ...und L3
      AND COLUMN_OBJECT_TYPE = 'TABLE'         -- Begrenzung auf Tabellen (persistierte Kennzahlen)
      AND UPPER(COLUMN_NAME) NOT LIKE '%_%ID'  -- Ausschluss der Haskey-Spalten
      AND COLUMN_TYPE NOT LIKE 'VARCHAR%'      -- Ausschluss der Spalten mit Text
]] );

if not status then
   log_msg = 'Fehler bei der Ermittlung der zu testenden Spalten'
   output(log_msg)
   tools.protokoll(skript_komponente, skript_name, 1, log_msg, spalten_fuer_test.error_message)
   exit( {{ decimal(1), error_msg }}, return_struct)
end

if #spalten_fuer_test == 0 then
   log_msg = 'Keine zu testenden Spalten gefunden'
   output(log_msg)
   tools.protokoll(skript_komponente, skript_name, 1, log_msg, '')
   exit( {{ decimal(1), error_msg }}, return_struct)
end

-- Loop über alle zu testenden Spalten
for i = 1, #spalten_fuer_test do
   log_msg = 'Berechne ' ..
          spalten_fuer_test[i].COLUMN_SCHEMA .. ' | ' ..
          spalten_fuer_test[i].COLUMN_TABLE .. ' | ' ..
          spalten_fuer_test[i].COLUMN_NAME .. ' | ' ..
          spalten_fuer_test[i].COLUMN_TYPE

   tools.protokoll(skript_komponente, skript_name, 1, log_msg, '')

   -- Operation anhand des Datentyps
   if spalten_fuer_test[i].COLUMN_TYPE == 'TIMESTAMP' or spalten_fuer_test[i].COLUMN_TYPE == 'DATE' then
      sql_operation = 'NVL(SUM(CAST(TO_CHAR(CAST(' .. spalten_fuer_test[i].COLUMN_NAME .. ' AS DATE), \'YYYYMMDD\') AS DECIMAL(36,8))), 0)'
   elseif string.sub(spalten_fuer_test[i].COLUMN_TYPE, 1, 7) == 'DECIMAL' or spalten_fuer_test[i].COLUMN_TYPE == 'DOUBLE' then
      sql_operation = 'NVL(SUM(' .. spalten_fuer_test[i].COLUMN_NAME .. '), 0)'
   end

   -- SQL für zu testende Spalte bauen und ausführen
   sql_test_fuer_spalte = [[
      SELECT ]] .. sql_operation .. [[ AS ERGEBNIS]] ..
      [[ FROM ]] .. spalten_fuer_test[i].COLUMN_SCHEMA .. [[.]] .. spalten_fuer_test[i].COLUMN_TABLE

   output(sql_test_fuer_spalte)

   status, test_ergebnis_fuer_spalte = pquery(sql_test_fuer_spalte)

   if not status then
      log_msg = 'Fehler beim Test der Kennzahl'
      output(log_msg)
      tools.protokoll(skript_komponente, skript_name, 1, log_msg, test_ergebnis_fuer_spalte.error_message)
      exit( {{ decimal(1), error_msg }}, return_struct)
   end

   -- Ergebnis des Test protokollieren
   status, ergebnis_protokoll = pquery([[
      INSERT INTO TOOLS.T_REGTEST_ERGEBNIS (
         TEST_LAUF_ID,
         TEST_ZEITPUNKT,
         TEST_SCHEMA,
         TEST_OBJEKT,
         TEST_SPALTE,
         TEST_ERGEBNIS
      ) VALUES (
         :p1, CURRENT_TIMESTAMP, :p2, :p3, :p4, :p5
      )
   ]], { p1 = lauf_id[1][1], p2 = spalten_fuer_test[i].COLUMN_SCHEMA, p3 = spalten_fuer_test[i].COLUMN_TABLE,
         p4 = spalten_fuer_test[i].COLUMN_NAME, p5 = test_ergebnis_fuer_spalte[1][1] } )

   if not status then
      log_msg = 'Fehler bei der Protokollierung'
      output(log_msg)
      tools.protokoll(skript_komponente, skript_name, 1, log_msg, test_ergebnis_fuer_spalte.error_message)
      exit( {{ decimal(1), error_msg }}, return_struct)
   end
end

log_msg = 'Beende Regressionstest für Lauf-ID = ' .. lauf_id[1][1]
output(log_msg)
tools.protokoll(skript_komponente, skript_name, 1, log_msg, '')
/
