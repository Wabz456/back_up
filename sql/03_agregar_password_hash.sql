-- Migración incremental. Ejecutar una sola vez sobre caso5_colecciones.
-- No elimina ni reemplaza datos existentes.
USE caso5_colecciones;

SET @columna_existe = (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'cuenta_usuario'
    AND COLUMN_NAME = 'password_hash'
);
SET @ddl = IF(
  @columna_existe = 0,
  'ALTER TABLE cuenta_usuario ADD COLUMN password_hash VARCHAR(255) NULL AFTER usuario',
  'SELECT ''password_hash ya existe'' AS mensaje'
);
PREPARE sentencia FROM @ddl;
EXECUTE sentencia;
DEALLOCATE PREPARE sentencia;

SHOW COLUMNS FROM cuenta_usuario LIKE 'password_hash';
