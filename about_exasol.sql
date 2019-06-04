OPEN SCHEMA L0D_M00_SANDBOX_301875;
CREATE OR REPLACE PYTHON SCALAR SCRIPT "ABOUT_EXASOL" () EMITS ("PARAM" VARCHAR(10000) UTF8, "WERT" VARCHAR(10000) UTF8) AS
def run(ctx):
 ctx.emit('Datenbank Name', exa.meta.database_name)
 ctx.emit('Datenbank Version', exa.meta.database_version)
 ctx.emit('Python Version', exa.meta.script_language)
 ctx.emit('Anzahl Knoten', str(exa.meta.node_count))
/