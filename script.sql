CREATE SEQUENCE pedido_numero_seq START 1;

CREATE TABLE cliente (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre    VARCHAR(150) NOT NULL,
    documento VARCHAR(20)  NOT NULL UNIQUE,
    email     VARCHAR(150) NOT NULL UNIQUE,
    activo    BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE producto (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(30)    NOT NULL UNIQUE,
    nombre VARCHAR(150)   NOT NULL,
    precio NUMERIC(12,2)  NOT NULL CHECK (precio >= 0),
    stock  INT            NOT NULL DEFAULT 0 CHECK (stock >= 0),
    activo BOOLEAN        NOT NULL DEFAULT TRUE
);

CREATE TABLE pedido (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero         VARCHAR(20) NOT NULL UNIQUE
                   DEFAULT ('P-' || LPAD(nextval('pedido_numero_seq')::TEXT, 6, '0')),
    cliente_id     BIGINT      NOT NULL REFERENCES cliente(id),
    estado         VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE','CONFIRMADO','CANCELADO','COMPLETADO')),
    subtotal       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    descuento      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (descuento >= 0),
    total          NUMERIC(12,2) NOT NULL DEFAULT 0,
    fecha_creacion TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_pedido_descuento CHECK (descuento <= subtotal),
    CONSTRAINT ck_pedido_total     CHECK (total = subtotal - descuento)
);

CREATE TABLE detalle_pedido (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id       BIGINT        NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    producto_id     BIGINT        NOT NULL REFERENCES producto(id),
    cantidad        INT           NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0), -- precio histórico
    subtotal        NUMERIC(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    UNIQUE (pedido_id, producto_id)
);

CREATE INDEX ix_pedido_cliente ON pedido(cliente_id);
CREATE INDEX ix_pedido_estado  ON pedido(estado);
CREATE INDEX ix_detalle_pedido ON detalle_pedido(pedido_id);







-- Ejecutar en la base "distribucion" (después de crear las tablas)

-- Porcentaje de descuento guardado en el pedido (el monto se calcula en BD/backend)
ALTER TABLE pedido
    ADD COLUMN IF NOT EXISTS descuento_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 0
    CHECK (descuento_porcentaje BETWEEN 0 AND 100);

-- =========================================================
-- CLIENTES
-- =========================================================
CREATE OR REPLACE FUNCTION public.crear_cliente_v1(
    p_nombre VARCHAR, p_documento VARCHAR, p_email VARCHAR
) RETURNS cliente LANGUAGE plpgsql AS $$
DECLARE v cliente;
BEGIN
    INSERT INTO cliente (nombre, documento, email)
    VALUES (p_nombre, p_documento, p_email)
    RETURNING * INTO v;
    RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_clientes_v1(
    p_nombre VARCHAR DEFAULT NULL, p_documento VARCHAR DEFAULT NULL
) RETURNS SETOF cliente LANGUAGE sql STABLE AS $$
    SELECT * FROM cliente
    WHERE (p_nombre IS NULL OR nombre ILIKE '%' || p_nombre || '%')
      AND (p_documento IS NULL OR documento = p_documento)
    ORDER BY id
$$;

-- =========================================================
-- PRODUCTOS
-- =========================================================
CREATE OR REPLACE FUNCTION public.crear_producto_v1(
    p_codigo VARCHAR, p_nombre VARCHAR, p_precio NUMERIC, p_stock INT
) RETURNS producto LANGUAGE plpgsql AS $$
DECLARE v producto;
BEGIN
    INSERT INTO producto (codigo, nombre, precio, stock)
    VALUES (p_codigo, p_nombre, p_precio, p_stock)
    RETURNING * INTO v;
    RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_productos_v1(
    p_nombre VARCHAR DEFAULT NULL, p_codigo VARCHAR DEFAULT NULL
) RETURNS SETOF producto LANGUAGE sql STABLE AS $$
    SELECT * FROM producto
    WHERE (p_nombre IS NULL OR nombre ILIKE '%' || p_nombre || '%')
      AND (p_codigo IS NULL OR codigo = p_codigo)
    ORDER BY id
$$;

-- =========================================================
-- PEDIDOS (helpers)
-- =========================================================
CREATE OR REPLACE FUNCTION public.recalcular_pedido(p_pedido_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_sub  NUMERIC(12,2);
    v_pct  NUMERIC(5,2);
    v_desc NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0) INTO v_sub
    FROM detalle_pedido WHERE pedido_id = p_pedido_id;

    SELECT descuento_porcentaje INTO v_pct FROM pedido WHERE id = p_pedido_id;
    v_desc := ROUND(v_sub * v_pct / 100, 2);

    UPDATE pedido
    SET subtotal = v_sub, descuento = v_desc, total = v_sub - v_desc
    WHERE id = p_pedido_id;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_pedido_v1(p_pedido_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE v JSONB;
BEGIN
    SELECT to_jsonb(p) || jsonb_build_object(
        'cliente', c.nombre,
        'items', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', d.id,
                'producto_id', d.producto_id,
                'codigo', pr.codigo,
                'producto', pr.nombre,
                'cantidad', d.cantidad,
                'precio_unitario', d.precio_unitario,
                'subtotal', d.subtotal
            ) ORDER BY d.id)
            FROM detalle_pedido d
            JOIN producto pr ON pr.id = d.producto_id
            WHERE d.pedido_id = p.id
        ), '[]'::jsonb)
    )
    INTO v
    FROM pedido p
    JOIN cliente c ON c.id = p.cliente_id
    WHERE p.id = p_pedido_id;

    IF v IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_pedidos_v1(
    p_estado VARCHAR DEFAULT NULL, p_cliente_id BIGINT DEFAULT NULL
) RETURNS TABLE (
    id BIGINT, numero VARCHAR, cliente VARCHAR, estado VARCHAR,
    subtotal NUMERIC, descuento NUMERIC, total NUMERIC, fecha_creacion TIMESTAMPTZ
) LANGUAGE sql STABLE AS $$
    SELECT p.id, p.numero, c.nombre, p.estado, p.subtotal, p.descuento, p.total, p.fecha_creacion
    FROM pedido p
    JOIN cliente c ON c.id = p.cliente_id
    WHERE (p_estado IS NULL OR p.estado = p_estado)
      AND (p_cliente_id IS NULL OR p.cliente_id = p_cliente_id)
    ORDER BY p.id DESC
$$;

-- =========================================================
-- PEDIDOS (operaciones)
-- =========================================================
CREATE OR REPLACE FUNCTION public.crear_pedido_v1(
    p_cliente_id BIGINT, p_descuento_porcentaje NUMERIC DEFAULT 0
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE v_id BIGINT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id = p_cliente_id AND activo) THEN
        RAISE EXCEPTION 'El cliente no existe o está inactivo';
    END IF;
    IF p_descuento_porcentaje < 0 OR p_descuento_porcentaje > 100 THEN
        RAISE EXCEPTION 'El descuento debe estar entre 0 y 100';
    END IF;

    INSERT INTO pedido (cliente_id, descuento_porcentaje)
    VALUES (p_cliente_id, p_descuento_porcentaje)
    RETURNING id INTO v_id;

    RETURN obtener_pedido_v1(v_id);
END $$;

CREATE OR REPLACE FUNCTION public.agregar_item_pedido_v1(
    p_pedido_id BIGINT, p_producto_id BIGINT, p_cantidad INT
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_estado VARCHAR;
    v_prod   producto%ROWTYPE;
    v_actual INT;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a 0';
    END IF;

    SELECT estado INTO v_estado FROM pedido WHERE id = p_pedido_id FOR UPDATE;
    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se puede modificar un pedido PENDIENTE (actual: %)', v_estado;
    END IF;

    SELECT * INTO v_prod FROM producto WHERE id = p_producto_id AND activo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto no existe o está inactivo';
    END IF;

    v_actual := COALESCE((
        SELECT cantidad FROM detalle_pedido
        WHERE pedido_id = p_pedido_id AND producto_id = p_producto_id
    ), 0);

    IF v_actual + p_cantidad > v_prod.stock THEN
        RAISE EXCEPTION 'Stock insuficiente para "%": disponible %, solicitado %',
            v_prod.nombre, v_prod.stock, v_actual + p_cantidad;
    END IF;

    -- precio_unitario = precio vigente hoy (se conserva si el producto cambia después)
    INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
    VALUES (p_pedido_id, p_producto_id, p_cantidad, v_prod.precio)
    ON CONFLICT (pedido_id, producto_id)
    DO UPDATE SET cantidad = detalle_pedido.cantidad + EXCLUDED.cantidad;

    PERFORM recalcular_pedido(p_pedido_id);
    RETURN obtener_pedido_v1(p_pedido_id);
END $$;

CREATE OR REPLACE FUNCTION public.eliminar_item_pedido_v1(
    p_pedido_id BIGINT, p_item_id BIGINT
) RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE v_estado VARCHAR;
BEGIN
    SELECT estado INTO v_estado FROM pedido WHERE id = p_pedido_id FOR UPDATE;
    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se puede modificar un pedido PENDIENTE (actual: %)', v_estado;
    END IF;

    DELETE FROM detalle_pedido WHERE id = p_item_id AND pedido_id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El item no existe en este pedido';
    END IF;

    PERFORM recalcular_pedido(p_pedido_id);
    RETURN obtener_pedido_v1(p_pedido_id);
END $$;

-- PENDIENTE -> CONFIRMADO (revalida y descuenta stock en una sola transacción)
CREATE OR REPLACE FUNCTION public.confirmar_pedido_v1(p_pedido_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_estado VARCHAR;
    r RECORD;
BEGIN
    SELECT estado INTO v_estado FROM pedido WHERE id = p_pedido_id FOR UPDATE;
    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'Solo se puede confirmar un pedido PENDIENTE (actual: %)', v_estado;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'El pedido no tiene items';
    END IF;

    -- ORDER BY evita deadlocks entre confirmaciones concurrentes
    FOR r IN
        SELECT d.producto_id, d.cantidad, p.nombre
        FROM detalle_pedido d
        JOIN producto p ON p.id = d.producto_id
        WHERE d.pedido_id = p_pedido_id
        ORDER BY d.producto_id
    LOOP
        UPDATE producto SET stock = stock - r.cantidad
        WHERE id = r.producto_id AND stock >= r.cantidad;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Stock insuficiente para "%"', r.nombre; -- rollback total
        END IF;
    END LOOP;

    UPDATE pedido SET estado = 'CONFIRMADO' WHERE id = p_pedido_id;
    RETURN obtener_pedido_v1(p_pedido_id);
END $$;

-- CONFIRMADO -> COMPLETADO
CREATE OR REPLACE FUNCTION public.completar_pedido_v1(p_pedido_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE v_estado VARCHAR;
BEGIN
    SELECT estado INTO v_estado FROM pedido WHERE id = p_pedido_id FOR UPDATE;
    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    IF v_estado <> 'CONFIRMADO' THEN
        RAISE EXCEPTION 'Solo se puede completar un pedido CONFIRMADO (actual: %)', v_estado;
    END IF;

    UPDATE pedido SET estado = 'COMPLETADO' WHERE id = p_pedido_id;
    RETURN obtener_pedido_v1(p_pedido_id);
END $$;

-- PENDIENTE|CONFIRMADO -> CANCELADO (si estaba confirmado, devuelve el stock)
CREATE OR REPLACE FUNCTION public.cancelar_pedido_v1(p_pedido_id BIGINT)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE v_estado VARCHAR;
BEGIN
    SELECT estado INTO v_estado FROM pedido WHERE id = p_pedido_id FOR UPDATE;
    IF v_estado IS NULL THEN
        RAISE EXCEPTION 'Pedido no encontrado';
    END IF;
    IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADO') THEN
        RAISE EXCEPTION 'No se puede cancelar un pedido % ', v_estado;
    END IF;

    IF v_estado = 'CONFIRMADO' THEN
        UPDATE producto p SET stock = p.stock + d.cantidad
        FROM detalle_pedido d
        WHERE d.producto_id = p.id AND d.pedido_id = p_pedido_id;
    END IF;

    UPDATE pedido SET estado = 'CANCELADO' WHERE id = p_pedido_id;
    RETURN obtener_pedido_v1(p_pedido_id);
END $$;




-- Ejecutar DESPUÉS de 01_funciones.sql

-- Clientes (el último está inactivo para probar la validación)
INSERT INTO cliente (nombre, documento, email, activo) VALUES
('Juan Pérez',        '45871236', 'juan.perez@mail.com',     TRUE),
('María García',      '40125896', 'maria.garcia@mail.com',   TRUE),
('Carlos Ramírez',    '72658401', 'carlos.ramirez@mail.com', TRUE),
('Lucía Fernández',   '46983257', 'lucia.fernandez@mail.com', TRUE),
('Pedro Torres',      '70413582', 'pedro.torres@mail.com',   TRUE),
('Cliente Inactivo',  '10000001', 'inactivo@mail.com',       FALSE)
ON CONFLICT DO NOTHING;

-- Productos (WEB-001 con stock 5 para probar el rechazo por stock; DES-001 inactivo)
INSERT INTO producto (codigo, nombre, precio, stock, activo) VALUES
('LAP-001', 'Laptop Lenovo IdeaPad 15',    2500.00,  10, TRUE),
('MOU-001', 'Mouse inalámbrico',             50.00,  50, TRUE),
('TEC-001', 'Teclado mecánico',             150.00,  30, TRUE),
('MON-001', 'Monitor 24" Full HD',          650.00,  15, TRUE),
('AUD-001', 'Audífonos Bluetooth',          120.00,  25, TRUE),
('WEB-001', 'Webcam Full HD',               180.00,   5, TRUE),
('USB-001', 'Memoria USB 64GB',              35.00, 100, TRUE),
('IMP-001', 'Impresora multifuncional',     480.00,   8, TRUE),
('DES-001', 'Producto descontinuado',        99.00,   0, FALSE)
ON CONFLICT DO NOTHING;

-- Pedido de ejemplo (opcional): Juan Pérez -> Subtotal S/ 2,750
DO $$
DECLARE v JSONB;
BEGIN
    v := public.crear_pedido_v1((SELECT id FROM cliente WHERE documento = '45871236'), 0);
    PERFORM public.agregar_item_pedido_v1((v->>'id')::BIGINT, (SELECT id FROM producto WHERE codigo = 'LAP-001'), 1);
    PERFORM public.agregar_item_pedido_v1((v->>'id')::BIGINT, (SELECT id FROM producto WHERE codigo = 'MOU-001'), 2);
    PERFORM public.agregar_item_pedido_v1((v->>'id')::BIGINT, (SELECT id FROM producto WHERE codigo = 'TEC-001'), 1);
END $$;

-- Verificar
SELECT public.obtener_pedido_v1(1);