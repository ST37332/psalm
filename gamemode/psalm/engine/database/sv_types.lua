local DB = Psalm.DB

DB.Types = {
    [TYPE_STRING] = "VARCHAR(255)", 
    [TYPE_NUMBER] = "INT", 
    [TYPE_BOOL] = "TINYINT(1)", 
    [TYPE_TABLE] = "TEXT"
}