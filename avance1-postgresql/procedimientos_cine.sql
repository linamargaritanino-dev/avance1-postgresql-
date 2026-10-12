CREATE OR REPLACE PROCEDURE registrar_espectador(
    p_nombre VARCHAR(150),
    p_correo VARCHAR(254),
    p_telefono VARCHAR(25)
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_nombre IS NULL OR BTRIM(p_nombre) = '' THEN
        RAISE EXCEPTION 'El nombre es obligatorio';
    END IF;

    IF p_correo IS NULL OR BTRIM(p_correo) = '' THEN
        RAISE EXCEPTION 'El correo es obligatorio';
    END IF;

    IF p_telefono IS NULL OR BTRIM(p_telefono) = '' THEN
        RAISE EXCEPTION 'El telefono es obligatorio';
    END IF;

    INSERT INTO espectador (
        nombre_completo,
        correo,
        telefono
    )
    VALUES (
        p_nombre,
        p_correo,
        p_telefono
    );

    RAISE NOTICE 'Espectador registrado correctamente';

EXCEPTION
    WHEN raise_exception THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al registrar espectador: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE programar_funcion(
    p_id_sala INTEGER,
    p_id_pelicula INTEGER,
    p_fecha_inicio TIMESTAMP,
    p_fecha_fin TIMESTAMP,
    p_formato VARCHAR(10),
    p_idioma VARCHAR(50),
    p_subtitulada BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_sala VARCHAR(25);
BEGIN
    IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL THEN
        RAISE EXCEPTION 'Las fechas de inicio y fin son obligatorias';
    END IF;

    IF p_fecha_fin <= p_fecha_inicio THEN
        RAISE EXCEPTION 'La fecha final debe ser posterior a la inicial';
    END IF;

    SELECT estado
    INTO v_estado_sala
    FROM sala
    WHERE id_sala = p_id_sala
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La sala indicada no existe';
    END IF;

    IF v_estado_sala <> 'disponible' THEN
        RAISE EXCEPTION 'La sala no esta disponible';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pelicula
        WHERE id_pelicula = p_id_pelicula
    ) THEN
        RAISE EXCEPTION 'La pelicula no existe';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM funcion
        WHERE sala_id_sala = p_id_sala
          AND estado = 'programada'
          AND p_fecha_inicio < fecha_hora_fin
          AND p_fecha_fin > fecha_hora_inicio
    ) THEN
        RAISE EXCEPTION 'La sala ya tiene una funcion en ese horario';
    END IF;

    INSERT INTO funcion (
        sala_id_sala,
        pelicula_id_pelicula,
        fecha_hora_inicio,
        fecha_hora_fin,
        formato_proyeccion,
        idioma_proyeccion,
        subtitulada
    )
    VALUES (
        p_id_sala,
        p_id_pelicula,
        p_fecha_inicio,
        p_fecha_fin,
        p_formato,
        p_idioma,
        p_subtitulada
    );

    RAISE NOTICE 'Funcion programada correctamente';

EXCEPTION
    WHEN raise_exception THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al programar funcion: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE registrar_venta(
    p_id_espectador INTEGER,
    p_id_funcion INTEGER,
    p_id_tipo_boleta INTEGER,
    p_id_staff INTEGER,
    p_cantidad INTEGER,
    p_metodo_pago VARCHAR(20),
    p_canal_venta VARCHAR(15)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_espectador VARCHAR(15);
    v_estado_funcion VARCHAR(20);
    v_estado_sala VARCHAR(25);
    v_capacidad INTEGER;
    v_vendidas INTEGER;
    v_precio NUMERIC(12,2);
    v_estado_staff VARCHAR(15);
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad de boletas debe ser mayor que cero';
    END IF;

    SELECT estado
    INTO v_estado_espectador
    FROM espectador
    WHERE id_espectador = p_id_espectador;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El espectador no existe';
    END IF;

    IF v_estado_espectador <> 'activo' THEN
        RAISE EXCEPTION 'El espectador esta inactivo';
    END IF;

    SELECT f.estado, s.estado, s.capacidad
    INTO v_estado_funcion, v_estado_sala, v_capacidad
    FROM funcion f
    JOIN sala s ON s.id_sala = f.sala_id_sala
    WHERE f.id_funcion = p_id_funcion
    FOR UPDATE OF s;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La funcion no existe';
    END IF;

    IF v_estado_funcion <> 'programada' THEN
        RAISE EXCEPTION 'La funcion no esta programada';
    END IF;

    IF v_estado_sala <> 'disponible' THEN
        RAISE EXCEPTION 'La sala no esta disponible';
    END IF;

    SELECT precio
    INTO v_precio
    FROM tipo_boleta
    WHERE id_tipo_boleta = p_id_tipo_boleta;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El tipo de boleta no existe';
    END IF;

    IF p_canal_venta IS NULL OR p_canal_venta NOT IN ('taquilla', 'en_linea') THEN
        RAISE EXCEPTION 'El canal de venta no es valido';
    END IF;

    IF p_metodo_pago IS NULL OR p_metodo_pago NOT IN ('efectivo', 'tarjeta', 'transferencia') THEN
        RAISE EXCEPTION 'El metodo de pago no es valido';
    END IF;

    IF p_canal_venta = 'taquilla' THEN
        IF p_id_staff IS NULL THEN
            RAISE EXCEPTION 'La venta en taquilla requiere un empleado';
        END IF;

        SELECT estado
        INTO v_estado_staff
        FROM staff
        WHERE id_staff = p_id_staff;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El empleado no existe';
        END IF;

        IF v_estado_staff <> 'activo' THEN
            RAISE EXCEPTION 'El empleado esta inactivo';
        END IF;
    END IF;

    SELECT COALESCE(SUM(cantidad_boletas), 0)
    INTO v_vendidas
    FROM venta
    WHERE funcion_id_funcion = p_id_funcion
      AND estado <> 'cancelada';

    IF v_vendidas + p_cantidad > v_capacidad THEN
        RAISE EXCEPTION
            'No hay suficientes boletas disponibles. Capacidad: %, vendidas: %',
            v_capacidad, v_vendidas;
    END IF;

    INSERT INTO venta (
        espectador_id_espectador,
        funcion_id_funcion,
        tipo_boleta_id_tipo_boleta,
        staff_id_staff,
        cantidad_boletas,
        precio_unitario,
        metodo_pago,
        canal_venta,
        estado
    )
    VALUES (
        p_id_espectador,
        p_id_funcion,
        p_id_tipo_boleta,
        CASE WHEN p_canal_venta = 'taquilla' THEN p_id_staff ELSE NULL END,
        p_cantidad,
        v_precio,
        p_metodo_pago,
        p_canal_venta,
        'pendiente'
    );

    RAISE NOTICE 'Venta registrada correctamente. Total: %', p_cantidad * v_precio;

EXCEPTION
    WHEN raise_exception THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al registrar la venta: %', SQLERRM;
END;
$$;


CREATE OR REPLACE PROCEDURE cambiar_estado_venta(
    p_id_venta INTEGER,
    p_nuevo_estado VARCHAR(15)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual VARCHAR(15);
BEGIN
    IF p_nuevo_estado IS NULL OR p_nuevo_estado NOT IN ('pagada', 'cancelada') THEN
        RAISE EXCEPTION 'El nuevo estado debe ser pagada o cancelada';
    END IF;

    SELECT estado
    INTO v_estado_actual
    FROM venta
    WHERE id_venta = p_id_venta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta indicada no existe';
    END IF;

    IF v_estado_actual <> 'pendiente' THEN
        RAISE EXCEPTION 'Solo se pueden modificar ventas pendientes';
    END IF;

    UPDATE venta
    SET estado = p_nuevo_estado
    WHERE id_venta = p_id_venta;

    RAISE NOTICE 'Estado de la venta actualizado a: %', p_nuevo_estado;

EXCEPTION
    WHEN raise_exception THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al cambiar el estado de la venta: %', SQLERRM;
END;
$$;
