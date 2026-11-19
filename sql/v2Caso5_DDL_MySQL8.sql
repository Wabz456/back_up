-- Caso 5 - Modelo relacional DDL para MySQL 8.x
-- Hipotesis de diseno basadas en DD-01 a DD-16.
-- No incluye datos, vistas, procedimientos ni codigo de aplicacion.

DROP DATABASE IF EXISTS caso5_colecciones;
CREATE DATABASE caso5_colecciones
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;
USE caso5_colecciones;

CREATE TABLE coleccion (
  id_coleccion VARCHAR(10) NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  tematica VARCHAR(100) NOT NULL,
  fecha_creacion DATE NOT NULL,
  responsable VARCHAR(100) NOT NULL,
  estado_conservacion VARCHAR(40) NOT NULL,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_coleccion PRIMARY KEY (id_coleccion)
) ENGINE=InnoDB;

CREATE TABLE pieza (
  id_pieza VARCHAR(10) NOT NULL,
  id_coleccion VARCHAR(10) NOT NULL,
  nombre_comercial VARCHAR(100) NOT NULL,
  procedencia_pais VARCHAR(60) NOT NULL,
  procedencia_region VARCHAR(60) NULL,
  procedencia_localidad VARCHAR(80) NULL,
  fecha_adquisicion DATE NOT NULL,
  valor_estimado DECIMAL(12,2) NOT NULL,
  estado_conservacion VARCHAR(40) NOT NULL,
  nivel_rareza VARCHAR(30) NOT NULL,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_pieza PRIMARY KEY (id_pieza),
  CONSTRAINT ck_pieza_valor_estimado CHECK (valor_estimado >= 0),
  CONSTRAINT fk_pieza_coleccion FOREIGN KEY (id_coleccion)
    REFERENCES coleccion (id_coleccion)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Especializacion parcial. La exclusividad entre subtipos requiere ratificacion
-- y no puede garantizarse solo con PK/FK en tres tablas separadas.
CREATE TABLE mineral (
  id_pieza VARCHAR(10) NOT NULL,
  formula_quimica VARCHAR(100) NOT NULL,
  dureza_mohs DECIMAL(3,1) NOT NULL,
  sistema_cristalino VARCHAR(60) NOT NULL,
  CONSTRAINT pk_mineral PRIMARY KEY (id_pieza),
  CONSTRAINT ck_mineral_dureza CHECK (dureza_mohs BETWEEN 1.0 AND 10.0),
  CONSTRAINT fk_mineral_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE fosil (
  id_pieza VARCHAR(10) NOT NULL,
  taxon VARCHAR(120) NOT NULL,
  periodo_geologico VARCHAR(80) NOT NULL,
  antiguedad_estimada DECIMAL(12,2) NOT NULL,
  CONSTRAINT pk_fosil PRIMARY KEY (id_pieza),
  CONSTRAINT ck_fosil_antiguedad CHECK (antiguedad_estimada >= 0),
  CONSTRAINT fk_fosil_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE gema (
  id_pieza VARCHAR(10) NOT NULL,
  peso_quilates DECIMAL(10,3) NOT NULL,
  tipo_talla VARCHAR(60) NOT NULL,
  transparencia VARCHAR(40) NOT NULL,
  CONSTRAINT pk_gema PRIMARY KEY (id_pieza),
  CONSTRAINT ck_gema_peso CHECK (peso_quilates >= 0),
  CONSTRAINT fk_gema_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pieza_certificacion (
  id_pieza VARCHAR(10) NOT NULL,
  codigo_certificado VARCHAR(40) NOT NULL,
  entidad_emisora VARCHAR(120) NOT NULL,
  fecha_emision DATE NOT NULL,
  CONSTRAINT pk_pieza_certificacion PRIMARY KEY (id_pieza, codigo_certificado),
  CONSTRAINT fk_certificacion_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE exposicion (
  id_exposicion VARCHAR(10) NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_termino DATE NOT NULL,
  ubicacion VARCHAR(150) NOT NULL,
  CONSTRAINT pk_exposicion PRIMARY KEY (id_exposicion),
  CONSTRAINT ck_exposicion_fechas CHECK (fecha_termino >= fecha_inicio)
) ENGINE=InnoDB;

CREATE TABLE participacion_exposicion (
  id_pieza VARCHAR(10) NOT NULL,
  id_exposicion VARCHAR(10) NOT NULL,
  fecha_incorporacion DATE NOT NULL,
  ubicacion_en_exposicion VARCHAR(120) NOT NULL,
  estado_conservacion VARCHAR(40) NOT NULL,
  observaciones VARCHAR(300) NULL,
  CONSTRAINT pk_participacion_exposicion PRIMARY KEY (id_pieza, id_exposicion),
  CONSTRAINT fk_participacion_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_participacion_exposicion FOREIGN KEY (id_exposicion)
    REFERENCES exposicion (id_exposicion)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE cliente (
  id_cliente VARCHAR(10) NOT NULL,
  nombre_razon_social VARCHAR(120) NOT NULL,
  telefono VARCHAR(30) NULL,
  correo VARCHAR(120) NULL,
  CONSTRAINT pk_cliente PRIMARY KEY (id_cliente)
) ENGINE=InnoDB;

CREATE TABLE reserva (
  id_reserva VARCHAR(12) NOT NULL,
  id_cliente VARCHAR(10) NOT NULL,
  id_pieza VARCHAR(10) NOT NULL,
  fecha_reserva DATE NOT NULL,
  fecha_vencimiento DATE GENERATED ALWAYS AS (DATE_ADD(fecha_reserva, INTERVAL 1 MONTH)) STORED,
  estado VARCHAR(30) NOT NULL,
  CONSTRAINT pk_reserva PRIMARY KEY (id_reserva),
  CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_reserva_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Eliminar tabla si ya existe
DROP TABLE IF EXISTS trabajador;

-- Crear tabla sin CHECK
CREATE TABLE trabajador (
    id_trabajador VARCHAR(10) NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    antecedentes_laborales VARCHAR(250) NULL,
    id_supervisor VARCHAR(10) NULL,
    CONSTRAINT pk_trabajador PRIMARY KEY (id_trabajador)
) ENGINE=InnoDB;

-- Agregar la foreign key auto-referenciada
ALTER TABLE trabajador
ADD CONSTRAINT fk_trabajador_supervisor
FOREIGN KEY (id_supervisor)
REFERENCES trabajador (id_trabajador)
ON UPDATE CASCADE
ON DELETE SET NULL;

-- Crear triggers para evitar auto-supervisión
DELIMITER $$

CREATE TRIGGER trg_no_autosupervision_insert
BEFORE INSERT ON trabajador
FOR EACH ROW
BEGIN
    IF NEW.id_supervisor = NEW.id_trabajador THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Un trabajador no puede supervisarse a sí mismo.';
    END IF;
END$$

CREATE TRIGGER trg_no_autosupervision_update
BEFORE UPDATE ON trabajador
FOR EACH ROW
BEGIN
    IF NEW.id_supervisor = NEW.id_trabajador THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Un trabajador no puede supervisarse a sí mismo.';
    END IF;
END$$

DELIMITER ;


CREATE TABLE cuenta_usuario (
  id_cuenta VARCHAR(10) NOT NULL,
  id_trabajador VARCHAR(10) NOT NULL,
  usuario VARCHAR(80) NOT NULL,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_cuenta_usuario PRIMARY KEY (id_cuenta),
  CONSTRAINT uq_cuenta_trabajador UNIQUE (id_trabajador),
  CONSTRAINT uq_cuenta_usuario UNIQUE (usuario),
  CONSTRAINT fk_cuenta_trabajador FOREIGN KEY (id_trabajador)
    REFERENCES trabajador (id_trabajador)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE rol (
  id_rol VARCHAR(10) NOT NULL,
  nombre_rol VARCHAR(80) NOT NULL,
  descripcion VARCHAR(250) NULL,
  CONSTRAINT pk_rol PRIMARY KEY (id_rol),
  CONSTRAINT uq_rol_nombre UNIQUE (nombre_rol)
) ENGINE=InnoDB;

CREATE TABLE usuario_rol (
  id_cuenta VARCHAR(10) NOT NULL,
  id_rol VARCHAR(10) NOT NULL,
  CONSTRAINT pk_usuario_rol PRIMARY KEY (id_cuenta, id_rol),
  CONSTRAINT fk_usuario_rol_cuenta FOREIGN KEY (id_cuenta)
    REFERENCES cuenta_usuario (id_cuenta)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_usuario_rol_rol FOREIGN KEY (id_rol)
    REFERENCES rol (id_rol)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE venta (
  id_venta VARCHAR(12) NOT NULL,
  id_cliente VARCHAR(10) NOT NULL,
  id_trabajador VARCHAR(10) NOT NULL,
  fecha DATE NOT NULL,
  monto_total DECIMAL(12,2) NOT NULL,
  CONSTRAINT pk_venta PRIMARY KEY (id_venta),
  CONSTRAINT ck_venta_monto CHECK (monto_total >= 0),
  CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente)
    REFERENCES cliente (id_cliente)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_venta_trabajador FOREIGN KEY (id_trabajador)
    REFERENCES trabajador (id_trabajador)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE detalle_venta (
  id_venta VARCHAR(12) NOT NULL,
  nro_detalle INT NOT NULL,
  id_pieza VARCHAR(10) NOT NULL,
  precio_venta DECIMAL(12,2) NOT NULL,
  condiciones VARCHAR(250) NULL,
  CONSTRAINT pk_detalle_venta PRIMARY KEY (id_venta, nro_detalle),
  CONSTRAINT ck_detalle_numero CHECK (nro_detalle > 0),
  CONSTRAINT ck_detalle_precio CHECK (precio_venta >= 0),
  CONSTRAINT uq_detalle_venta_pieza UNIQUE (id_venta, id_pieza),
  CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta)
    REFERENCES venta (id_venta)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_detalle_pieza FOREIGN KEY (id_pieza)
    REFERENCES pieza (id_pieza)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE evaluacion (
  id_venta VARCHAR(12) NOT NULL,
  nro_evaluacion INT NOT NULL,
  fecha DATE NULL,
  calificacion SMALLINT NOT NULL,
  comentario VARCHAR(500) NULL,
  CONSTRAINT pk_evaluacion PRIMARY KEY (id_venta, nro_evaluacion),
  CONSTRAINT ck_evaluacion_numero CHECK (nro_evaluacion > 0),
  CONSTRAINT ck_evaluacion_calificacion CHECK (calificacion BETWEEN 1 AND 5),
  CONSTRAINT fk_evaluacion_venta FOREIGN KEY (id_venta)
    REFERENCES venta (id_venta)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Indices de apoyo para FK y rutas frecuentes de consulta.
CREATE INDEX ix_pieza_coleccion ON pieza (id_coleccion);
CREATE INDEX ix_reserva_cliente ON reserva (id_cliente);
CREATE INDEX ix_reserva_pieza_estado ON reserva (id_pieza, estado);
CREATE INDEX ix_venta_cliente_fecha ON venta (id_cliente, fecha);
CREATE INDEX ix_venta_trabajador ON venta (id_trabajador);
CREATE INDEX ix_detalle_pieza ON detalle_venta (id_pieza);
CREATE INDEX ix_evaluacion_calificacion ON evaluacion (calificacion);

-- Verificacion estructural, no inserta datos.
SHOW TABLES;
