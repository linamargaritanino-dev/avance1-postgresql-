-- =====================================================================
-- REELS CINEMA - Avance 1
-- 04_procedimientos.sql
-- 5 procedimientos almacenados, todos con manejo de excepciones
-- (bloque EXCEPTION + RAISE). Ejecutar después de 03_triggers.sql.
--
--  #  Procedimiento                    Tipo
--  1  sp_confirmar_pago_venta          Cálculo / transacción
--  2  sp_reporte_ventas_periodo        Reporte con agregación
--  3  sp_mantenimiento_cierre_diario   Mantenimiento
--  4  sp_registrar_venta               Flujo de negocio completo (adicional)
--  5  sp_cancelar_funcion              Operación
--
-- Los parámetros INOUT permiten que CALL devuelva una fila con el
-- resultado (útil para ver la salida en el SQL Editor de Neon).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. sp_confirmar_pago_venta  (cálculo / transacción)
-- Propósito: confirmar el pago de una venta pendiente (típicamente en
-- línea). Valida el estado de la venta y de la función, registra el
-- método de pago definitivo, cambia la venta a "pagada" y devuelve el
-- total cobrado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_confirmar_pago_venta(
    p_id_venta     INTEGER,
    p_metodo_pago  VARCHAR,
    INOUT p_total  NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_venta   venta%ROWTYPE;
    v_funcion funcion%ROWTYPE;
BEGIN
    IF p_metodo_pago NOT IN ('efectivo', 'tarjeta', 'transferencia') THEN
        RAISE EXCEPTION 'Método de pago no válido: "%"', p_metodo_pago;
    END IF;

    SELECT * INTO v_venta FROM venta WHERE id_venta = p_id_venta FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta % no existe', p_id_venta;
    END IF;

    IF v_venta.estado <> 'pendiente' THEN
        RAISE EXCEPTION 'La venta % está "%"; solo se confirman ventas pendientes',
            p_id_venta, v_venta.estado;
    END IF;

    IF v_venta.canal_venta = 'en_linea' AND p_metodo_pago = 'efectivo' THEN
        RAISE EXCEPTION 'Una venta en línea no puede pagarse en efectivo';
    END IF;

    SELECT * INTO v_funcion FROM funcion WHERE id_funcion = v_venta.funcion_id_funcion;
    IF v_funcion.estado <> 'programada' THEN
        RAISE EXCEPTION 'La función % está "%"; no se puede confirmar el pago',
            v_funcion.id_funcion, v_funcion.estado;
    END IF;

    UPDATE venta
    SET estado = 'pagada',
        metodo_pago = p_metodo_pago
    WHERE id_venta = p_id_venta
    RETURNING total INTO p_total;

    RAISE NOTICE 'Venta % pagada con %: total $%', p_id_venta, p_metodo_pago, p_total;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_confirmar_pago_venta: %', SQLERRM
            USING ERRCODE = SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- 2. sp_reporte_ventas_periodo  (reporte con agregación)
-- Propósito: resumen gerencial de un periodo. Muestra, por película,
-- funciones, boletas vendidas, ingresos y ocupación promedio (RAISE
-- NOTICE), y devuelve los totales generales del periodo.
-- Solo cuenta ventas pagadas y funciones no canceladas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_reporte_ventas_periodo(
    p_desde              DATE,
    p_hasta              DATE,
    INOUT p_boletas      INTEGER DEFAULT NULL,
    INOUT p_ingresos     NUMERIC DEFAULT NULL,
    INOUT p_ocupacion_pct NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    IF p_desde IS NULL OR p_hasta IS NULL THEN
        RAISE EXCEPTION 'Debe indicar fecha inicial y final';
    END IF;
    IF p_hasta < p_desde THEN
        RAISE EXCEPTION 'Rango inválido: % es anterior a %', p_hasta, p_desde;
    END IF;

    RAISE NOTICE '=== Reporte de ventas % a % ===', p_desde, p_hasta;

    FOR r IN
        WITH ocupacion AS (
            SELECT f.id_funcion,
                   f.pelicula_id_pelicula,
                   s.capacidad,
                   COALESCE(SUM(v.cantidad_boletas)
                            FILTER (WHERE v.estado = 'pagada'), 0) AS boletas,
                   COALESCE(SUM(v.total)
                            FILTER (WHERE v.estado = 'pagada'), 0) AS ingresos
            FROM funcion f
            JOIN sala s ON s.id_sala = f.sala_id_sala
            LEFT JOIN venta v ON v.funcion_id_funcion = f.id_funcion
            WHERE f.estado <> 'cancelada'
              AND f.fecha_hora_inicio::DATE BETWEEN p_desde AND p_hasta
            GROUP BY f.id_funcion, f.pelicula_id_pelicula, s.capacidad
        )
        SELECT p.titulo,
               COUNT(*)                                        AS funciones,
               SUM(o.boletas)                                  AS boletas,
               SUM(o.ingresos)                                 AS ingresos,
               ROUND(AVG(o.boletas * 100.0 / o.capacidad), 1) AS ocupacion
        FROM ocupacion o
        JOIN pelicula p ON p.id_pelicula = o.pelicula_id_pelicula
        GROUP BY p.titulo
        ORDER BY ingresos DESC
    LOOP
        RAISE NOTICE '% | funciones: % | boletas: % | ingresos: $% | ocupación prom.: % %%',
            r.titulo, r.funciones, r.boletas, r.ingresos, r.ocupacion;
    END LOOP;

    SELECT COALESCE(SUM(v.cantidad_boletas), 0),
           COALESCE(SUM(v.total), 0)
      INTO p_boletas, p_ingresos
    FROM venta v
    JOIN funcion f ON f.id_funcion = v.funcion_id_funcion
    WHERE v.estado = 'pagada'
      AND f.estado <> 'cancelada'
      AND f.fecha_hora_inicio::DATE BETWEEN p_desde AND p_hasta;

    SELECT ROUND(COALESCE(p_boletas * 100.0 / NULLIF(SUM(s.capacidad), 0), 0), 1)
      INTO p_ocupacion_pct
    FROM funcion f
    JOIN sala s ON s.id_sala = f.sala_id_sala
    WHERE f.estado <> 'cancelada'
      AND f.fecha_hora_inicio::DATE BETWEEN p_desde AND p_hasta;

    IF p_boletas = 0 THEN
        RAISE NOTICE 'No hay ventas pagadas en el periodo indicado';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_reporte_ventas_periodo: %', SQLERRM
            USING ERRCODE = SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- 3. sp_mantenimiento_cierre_diario  (mantenimiento)
-- Propósito: tarea de cierre que deja la base consistente con el paso
-- del tiempo:
--   a) funciones programadas que ya terminaron -> "finalizada";
--   b) ventas pendientes de funciones que ya terminaron -> "cancelada"
--      (nunca se pagaron);
--   c) contratos vigentes con fecha_fin vencida -> "finalizado".
-- Devuelve cuántos registros se actualizaron en cada caso.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_mantenimiento_cierre_diario(
    INOUT p_funciones_finalizadas INTEGER DEFAULT NULL,
    INOUT p_ventas_canceladas     INTEGER DEFAULT NULL,
    INOUT p_contratos_finalizados INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ahora TIMESTAMP := (NOW() AT TIME ZONE 'America/Bogota');
BEGIN
    UPDATE venta v
    SET estado = 'cancelada'
    FROM funcion f
    WHERE f.id_funcion = v.funcion_id_funcion
      AND f.estado = 'programada'
      AND f.fecha_hora_fin < v_ahora
      AND v.estado = 'pendiente';
    GET DIAGNOSTICS p_ventas_canceladas = ROW_COUNT;

    UPDATE funcion
    SET estado = 'finalizada'
    WHERE estado = 'programada'
      AND fecha_hora_fin < v_ahora;
    GET DIAGNOSTICS p_funciones_finalizadas = ROW_COUNT;

    UPDATE contrato
    SET estado = 'finalizado'
    WHERE estado = 'vigente'
      AND fecha_fin < v_ahora::DATE;
    GET DIAGNOSTICS p_contratos_finalizados = ROW_COUNT;

    RAISE NOTICE 'Cierre: % función(es) finalizada(s), % venta(s) pendiente(s) cancelada(s), % contrato(s) finalizado(s)',
        p_funciones_finalizadas, p_ventas_canceladas, p_contratos_finalizados;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_mantenimiento_cierre_diario: % (no se aplicó ningún cambio)', SQLERRM
            USING ERRCODE = SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- 4. sp_registrar_venta  (flujo de negocio completo - ADICIONAL)
-- Propósito: registrar una venta de boletas con TODAS sus validaciones
-- en una sola transacción:
--   - existencia de espectador, función, tipo de boleta y empleado;
--   - espectador activo; función programada y que no haya iniciado;
--   - sala disponible y aforo suficiente (con bloqueo de la función);
--   - máximo 10 boletas por venta;
--   - reglas de canal: taquilla exige empleado taquillero/administrador
--     activo; en línea no admite efectivo ni empleado;
--   - precio tomado del catálogo y total calculado.
-- Estado resultante: taquilla -> "pagada" (se cobra en el momento);
-- en línea -> "pendiente" (se confirma con sp_confirmar_pago_venta).
-- Si cualquier validación falla, no se inserta nada.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_venta(
    p_id_espectador   INTEGER,
    p_id_funcion      INTEGER,
    p_id_tipo_boleta  INTEGER,
    p_cantidad        INTEGER,
    p_metodo_pago     VARCHAR,
    p_canal_venta     VARCHAR,
    p_id_staff        INTEGER DEFAULT NULL,
    INOUT p_id_venta  INTEGER DEFAULT NULL,
    INOUT p_total     NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    c_max_boletas CONSTANT INTEGER := 10;
    v_espectador  espectador%ROWTYPE;
    v_funcion     funcion%ROWTYPE;
    v_sala        sala%ROWTYPE;
    v_tipo        tipo_boleta%ROWTYPE;
    v_staff       staff%ROWTYPE;
    v_vendidas    INTEGER;
    v_estado      VARCHAR(15);
BEGIN
    -- Parámetros básicos
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de boletas debe ser mayor que cero';
    END IF;
    IF p_cantidad > c_max_boletas THEN
        RAISE EXCEPTION 'Máximo % boletas por venta (solicitadas: %)', c_max_boletas, p_cantidad;
    END IF;
    IF p_canal_venta NOT IN ('taquilla', 'en_linea') THEN
        RAISE EXCEPTION 'Canal de venta no válido: "%"', p_canal_venta;
    END IF;
    IF p_metodo_pago NOT IN ('efectivo', 'tarjeta', 'transferencia') THEN
        RAISE EXCEPTION 'Método de pago no válido: "%"', p_metodo_pago;
    END IF;

    -- Espectador
    SELECT * INTO v_espectador FROM espectador WHERE id_espectador = p_id_espectador;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El espectador % no existe', p_id_espectador;
    END IF;
    IF v_espectador.estado <> 'activo' THEN
        RAISE EXCEPTION 'El espectador % (%) está inactivo', p_id_espectador, v_espectador.nombre_completo;
    END IF;

    -- Función (bloqueada para evitar sobreventa concurrente)
    SELECT * INTO v_funcion FROM funcion WHERE id_funcion = p_id_funcion FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La función % no existe', p_id_funcion;
    END IF;
    IF v_funcion.estado <> 'programada' THEN
        RAISE EXCEPTION 'La función % está "%"', p_id_funcion, v_funcion.estado;
    END IF;
    IF v_funcion.fecha_hora_inicio <= (NOW() AT TIME ZONE 'America/Bogota') THEN
        RAISE EXCEPTION 'La función % ya inició (%); no se venden más boletas',
            p_id_funcion, v_funcion.fecha_hora_inicio;
    END IF;

    -- Sala y aforo
    SELECT * INTO v_sala FROM sala WHERE id_sala = v_funcion.sala_id_sala;
    IF v_sala.estado <> 'disponible' THEN
        RAISE EXCEPTION 'La sala % no está disponible (%)', v_sala.numero_sala, v_sala.estado;
    END IF;

    SELECT COALESCE(SUM(cantidad_boletas), 0) INTO v_vendidas
    FROM venta
    WHERE funcion_id_funcion = p_id_funcion
      AND estado <> 'cancelada';

    IF v_vendidas + p_cantidad > v_sala.capacidad THEN
        RAISE EXCEPTION 'Solo quedan % puesto(s) en la función % (solicitados: %)',
            v_sala.capacidad - v_vendidas, p_id_funcion, p_cantidad;
    END IF;

    -- Tipo de boleta
    SELECT * INTO v_tipo FROM tipo_boleta WHERE id_tipo_boleta = p_id_tipo_boleta;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El tipo de boleta % no existe', p_id_tipo_boleta;
    END IF;

    -- Reglas por canal
    IF p_canal_venta = 'taquilla' THEN
        IF p_id_staff IS NULL THEN
            RAISE EXCEPTION 'Una venta en taquilla requiere el empleado que la registra';
        END IF;
        SELECT * INTO v_staff FROM staff WHERE id_staff = p_id_staff;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'El empleado % no existe', p_id_staff;
        END IF;
        IF v_staff.estado <> 'activo' THEN
            RAISE EXCEPTION 'El empleado % está inactivo', p_id_staff;
        END IF;
        IF v_staff.cargo NOT IN ('taquillero', 'administrador') THEN
            RAISE EXCEPTION 'El empleado % es "%"; no puede vender en taquilla', p_id_staff, v_staff.cargo;
        END IF;
        v_estado := 'pagada';
    ELSE
        IF p_id_staff IS NOT NULL THEN
            RAISE EXCEPTION 'Una venta en línea no se asocia a un empleado';
        END IF;
        IF p_metodo_pago = 'efectivo' THEN
            RAISE EXCEPTION 'Una venta en línea no puede pagarse en efectivo';
        END IF;
        v_estado := 'pendiente';
    END IF;

    -- Registro (el trigger trg_venta_asignar_precio fija el precio del catálogo)
    INSERT INTO venta (espectador_id_espectador, funcion_id_funcion,
                       tipo_boleta_id_tipo_boleta, staff_id_staff,
                       cantidad_boletas, precio_unitario,
                       metodo_pago, canal_venta, estado)
    VALUES (p_id_espectador, p_id_funcion, p_id_tipo_boleta, p_id_staff,
            p_cantidad, v_tipo.precio, p_metodo_pago, p_canal_venta, v_estado)
    RETURNING id_venta, total INTO p_id_venta, p_total;

    RAISE NOTICE 'Venta % registrada (%): % boleta(s) "%" para "%" -> total $%',
        p_id_venta, v_estado, p_cantidad, v_tipo.categoria,
        (SELECT titulo FROM pelicula WHERE id_pelicula = v_funcion.pelicula_id_pelicula),
        p_total;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'sp_registrar_venta: referencia inexistente (%)', SQLERRM
            USING ERRCODE = SQLSTATE;
    WHEN check_violation THEN
        RAISE EXCEPTION 'sp_registrar_venta: dato fuera de las reglas de la tabla (%)', SQLERRM
            USING ERRCODE = SQLSTATE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_registrar_venta: %', SQLERRM
            USING ERRCODE = SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- 5. sp_cancelar_funcion  (operación)
-- Propósito: cancelar una función programada (por ejemplo, por daño en
-- la sala o ausencia del invitado). El trigger trg_funcion_cancelar_ventas
-- cancela sus ventas; el procedimiento devuelve cuántas boletas y cuánto
-- dinero pagado debe reembolsarse.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cancelar_funcion(
    p_id_funcion            INTEGER,
    INOUT p_boletas_afectadas INTEGER DEFAULT NULL,
    INOUT p_valor_reembolso   NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR(20);
BEGIN
    SELECT estado INTO v_estado FROM funcion WHERE id_funcion = p_id_funcion FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La función % no existe', p_id_funcion;
    END IF;
    IF v_estado <> 'programada' THEN
        RAISE EXCEPTION 'Solo se cancelan funciones programadas (la función % está "%")',
            p_id_funcion, v_estado;
    END IF;

    -- Se calcula lo que se va a reembolsar ANTES de cancelar
    SELECT COALESCE(SUM(cantidad_boletas), 0),
           COALESCE(SUM(total) FILTER (WHERE estado = 'pagada'), 0)
      INTO p_boletas_afectadas, p_valor_reembolso
    FROM venta
    WHERE funcion_id_funcion = p_id_funcion
      AND estado IN ('pendiente', 'pagada');

    UPDATE funcion SET estado = 'cancelada' WHERE id_funcion = p_id_funcion;

    RAISE NOTICE 'Función % cancelada: % boleta(s) afectada(s), reembolso $%',
        p_id_funcion, p_boletas_afectadas, p_valor_reembolso;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_cancelar_funcion: %', SQLERRM
            USING ERRCODE = SQLSTATE;
END;
$$;
