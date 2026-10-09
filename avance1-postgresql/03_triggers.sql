-- =====================================================================
-- REELS CINEMA - Avance 1
-- 03_triggers.sql
-- 11 triggers distribuidos en 9 de las 10 tablas del modelo.
-- Ejecutar DESPUÉS de 01_creacion_tablas.sql y 02_datos_prueba.sql
-- (los triggers validan las operaciones nuevas, no los datos ya cargados).
--
-- Resumen:
--  #  Tabla               Trigger                          Momento
--  1  sala                trg_sala_proteger_programacion   BEFORE UPDATE
--  2  espectador          trg_espectador_normalizar        BEFORE INSERT/UPDATE
--  3  staff               trg_staff_validar                BEFORE INSERT/UPDATE
--  4  tipo_boleta         trg_tipo_boleta_precio           BEFORE UPDATE OF precio
--  5  pelicula            trg_pelicula_duracion            BEFORE UPDATE OF duracion
--  6  actores_directores  trg_artista_fecha_nacimiento     BEFORE INSERT/UPDATE
--  7  funcion             trg_funcion_validar_horario      BEFORE INSERT/UPDATE
--  8  funcion             trg_funcion_cancelar_ventas      AFTER UPDATE OF estado
--  9  venta               trg_venta_asignar_precio         BEFORE INSERT
-- 10  venta               trg_venta_validar                BEFORE INSERT/UPDATE
-- 11  contrato            trg_contrato_sin_solapamiento    BEFORE INSERT/UPDATE
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. SALA: proteger la programación existente
-- Regla: no se puede reducir la capacidad de una sala por debajo de las
-- boletas ya vendidas para sus funciones programadas, ni sacarla de
-- servicio (mantenimiento / fuera_servicio) si tiene funciones futuras
-- programadas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sala_proteger_programacion()
RETURNS TRIGGER AS $$
DECLARE
    v_max_vendidas INTEGER;
    v_funciones_futuras INTEGER;
BEGIN
    IF NEW.capacidad < OLD.capacidad THEN
        SELECT COALESCE(MAX(vendidas), 0) INTO v_max_vendidas
        FROM (
            SELECT SUM(v.cantidad_boletas) AS vendidas
            FROM funcion f
            JOIN venta v ON v.funcion_id_funcion = f.id_funcion
            WHERE f.sala_id_sala = NEW.id_sala
              AND f.estado = 'programada'
              AND v.estado <> 'cancelada'
            GROUP BY f.id_funcion
        ) t;

        IF NEW.capacidad < v_max_vendidas THEN
            RAISE EXCEPTION 'Sala %: no se puede reducir la capacidad a % porque una función programada ya tiene % boletas vendidas',
                NEW.numero_sala, NEW.capacidad, v_max_vendidas;
        END IF;
    END IF;

    IF NEW.estado <> 'disponible' AND OLD.estado = 'disponible' THEN
        SELECT COUNT(*) INTO v_funciones_futuras
        FROM funcion
        WHERE sala_id_sala = NEW.id_sala
          AND estado = 'programada'
          AND fecha_hora_inicio > (NOW() AT TIME ZONE 'America/Bogota');

        IF v_funciones_futuras > 0 THEN
            RAISE EXCEPTION 'Sala %: no se puede pasar a "%" porque tiene % función(es) futura(s) programada(s). Cancélelas o reprográmelas primero',
                NEW.numero_sala, NEW.estado, v_funciones_futuras;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sala_proteger_programacion
BEFORE UPDATE ON sala
FOR EACH ROW
EXECUTE FUNCTION fn_sala_proteger_programacion();


-- ---------------------------------------------------------------------
-- 2. ESPECTADOR: normalizar y validar datos de contacto
-- Regla: el correo se guarda en minúsculas y sin espacios, y debe tener
-- un formato válido; el nombre se guarda sin espacios sobrantes. Esto
-- evita registros duplicados que solo difieren en mayúsculas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_espectador_normalizar()
RETURNS TRIGGER AS $$
BEGIN
    NEW.nombre_completo := REGEXP_REPLACE(BTRIM(NEW.nombre_completo), '\s+', ' ', 'g');
    NEW.correo := LOWER(BTRIM(NEW.correo));
    NEW.telefono := BTRIM(NEW.telefono);

    IF NEW.correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Correo de espectador inválido: "%"', NEW.correo;
    END IF;

    IF NEW.fecha_registro > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de registro (%) no puede ser futura', NEW.fecha_registro;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_espectador_normalizar
BEFORE INSERT OR UPDATE ON espectador
FOR EACH ROW
EXECUTE FUNCTION fn_espectador_normalizar();


-- ---------------------------------------------------------------------
-- 3. STAFF: validar ingreso y datos del empleado
-- Regla: la fecha de ingreso no puede ser futura, el correo debe ser
-- válido (se normaliza a minúsculas) y un empleado con ventas pendientes
-- en taquilla no puede pasar a inactivo.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_staff_validar()
RETURNS TRIGGER AS $$
DECLARE
    v_pendientes INTEGER;
BEGIN
    NEW.correo := LOWER(BTRIM(NEW.correo));
    NEW.tipo_documento := UPPER(BTRIM(NEW.tipo_documento));
    NEW.numero_documento := BTRIM(NEW.numero_documento);

    IF NEW.correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Correo de empleado inválido: "%"', NEW.correo;
    END IF;

    IF NEW.fecha_ingreso > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de ingreso (%) no puede ser futura', NEW.fecha_ingreso;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.estado = 'activo' AND NEW.estado = 'inactivo' THEN
        SELECT COUNT(*) INTO v_pendientes
        FROM venta
        WHERE staff_id_staff = NEW.id_staff
          AND estado = 'pendiente';

        IF v_pendientes > 0 THEN
            RAISE EXCEPTION 'El empleado % tiene % venta(s) pendiente(s); ciérrelas antes de inactivarlo',
                NEW.nombre_completo, v_pendientes;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_staff_validar
BEFORE INSERT OR UPDATE ON staff
FOR EACH ROW
EXECUTE FUNCTION fn_staff_validar();


-- ---------------------------------------------------------------------
-- 4. TIPO_BOLETA: proteger el precio de ventas en curso
-- Regla: no se permite cambiar el precio de un tipo de boleta mientras
-- existan ventas PENDIENTES de ese tipo, porque el cliente aceptó el
-- precio anterior y el cobro quedaría inconsistente.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tipo_boleta_precio()
RETURNS TRIGGER AS $$
DECLARE
    v_pendientes INTEGER;
BEGIN
    IF NEW.precio IS DISTINCT FROM OLD.precio THEN
        SELECT COUNT(*) INTO v_pendientes
        FROM venta
        WHERE tipo_boleta_id_tipo_boleta = NEW.id_tipo_boleta
          AND estado = 'pendiente';

        IF v_pendientes > 0 THEN
            RAISE EXCEPTION 'No se puede cambiar el precio de "%": hay % venta(s) pendiente(s) con ese tipo de boleta',
                NEW.categoria, v_pendientes;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tipo_boleta_precio
BEFORE UPDATE OF precio ON tipo_boleta
FOR EACH ROW
EXECUTE FUNCTION fn_tipo_boleta_precio();


-- ---------------------------------------------------------------------
-- 5. PELICULA: coherencia entre duración y funciones programadas
-- Regla: si se aumenta la duración de una película, todas sus funciones
-- programadas deben seguir teniendo tiempo suficiente para proyectarla.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_pelicula_duracion()
RETURNS TRIGGER AS $$
DECLARE
    v_conflictos INTEGER;
BEGIN
    IF NEW.duracion > OLD.duracion THEN
        SELECT COUNT(*) INTO v_conflictos
        FROM funcion
        WHERE pelicula_id_pelicula = NEW.id_pelicula
          AND estado = 'programada'
          AND fecha_hora_fin < fecha_hora_inicio + MAKE_INTERVAL(mins => NEW.duracion);

        IF v_conflictos > 0 THEN
            RAISE EXCEPTION 'No se puede cambiar la duración de "%" a % min: % función(es) programada(s) no alcanzan a proyectarla',
                NEW.titulo, NEW.duracion, v_conflictos;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pelicula_duracion
BEFORE UPDATE OF duracion ON pelicula
FOR EACH ROW
EXECUTE FUNCTION fn_pelicula_duracion();


-- ---------------------------------------------------------------------
-- 6. ACTORES_DIRECTORES: fecha de nacimiento razonable
-- Regla: la fecha de nacimiento no puede ser futura ni absurda
-- (más de 120 años), y el nombre se guarda sin espacios sobrantes.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_artista_fecha_nacimiento()
RETURNS TRIGGER AS $$
BEGIN
    NEW.nombre_completo := REGEXP_REPLACE(BTRIM(NEW.nombre_completo), '\s+', ' ', 'g');

    IF NEW.fecha_nacimiento >= CURRENT_DATE THEN
        RAISE EXCEPTION 'Fecha de nacimiento inválida para %: % no puede ser hoy ni futura',
            NEW.nombre_completo, NEW.fecha_nacimiento;
    END IF;

    IF NEW.fecha_nacimiento < CURRENT_DATE - INTERVAL '120 years' THEN
        RAISE EXCEPTION 'Fecha de nacimiento inválida para %: % supera los 120 años',
            NEW.nombre_completo, NEW.fecha_nacimiento;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_artista_fecha_nacimiento
BEFORE INSERT OR UPDATE ON actores_directores
FOR EACH ROW
EXECUTE FUNCTION fn_artista_fecha_nacimiento();


-- ---------------------------------------------------------------------
-- 7. FUNCION: validar horario, sala y duración
-- Regla: (a) la sala debe estar disponible; (b) dos funciones
-- programadas no pueden cruzarse en la misma sala; (c) la función debe
-- durar al menos lo que dura la película.
-- Solo se dispara cuando cambian sala, película u horario, para no
-- bloquear cambios de estado sobre funciones históricas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_funcion_validar_horario()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_sala VARCHAR(25);
    v_numero_sala INTEGER;
    v_duracion INTEGER;
    v_titulo VARCHAR(200);
    v_cruce INTEGER;
BEGIN
    IF NEW.estado <> 'programada' THEN
        RETURN NEW;
    END IF;

    SELECT estado, numero_sala INTO v_estado_sala, v_numero_sala
    FROM sala WHERE id_sala = NEW.sala_id_sala;

    IF v_estado_sala <> 'disponible' THEN
        RAISE EXCEPTION 'No se puede programar en la sala %: estado actual "%"',
            v_numero_sala, v_estado_sala;
    END IF;

    SELECT duracion, titulo INTO v_duracion, v_titulo
    FROM pelicula WHERE id_pelicula = NEW.pelicula_id_pelicula;

    IF NEW.fecha_hora_fin < NEW.fecha_hora_inicio + MAKE_INTERVAL(mins => v_duracion) THEN
        RAISE EXCEPTION 'La función de "%" dura menos que la película (% min)',
            v_titulo, v_duracion;
    END IF;

    SELECT f.id_funcion INTO v_cruce
    FROM funcion f
    WHERE f.sala_id_sala = NEW.sala_id_sala
      AND f.estado = 'programada'
      AND f.id_funcion <> COALESCE(NEW.id_funcion, -1)
      AND TSRANGE(f.fecha_hora_inicio, f.fecha_hora_fin)
          && TSRANGE(NEW.fecha_hora_inicio, NEW.fecha_hora_fin)
    LIMIT 1;

    IF v_cruce IS NOT NULL THEN
        RAISE EXCEPTION 'Cruce de horario en la sala %: la función % ya ocupa ese horario',
            v_numero_sala, v_cruce;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_funcion_validar_horario
BEFORE INSERT OR UPDATE OF sala_id_sala, pelicula_id_pelicula,
                           fecha_hora_inicio, fecha_hora_fin
ON funcion
FOR EACH ROW
EXECUTE FUNCTION fn_funcion_validar_horario();


-- ---------------------------------------------------------------------
-- 8. FUNCION: cancelar en cascada las ventas de una función cancelada
-- Regla: cuando una función pasa a "cancelada", todas sus ventas
-- pendientes o pagadas se cancelan automáticamente, para que no queden
-- boletas válidas de una función que no se va a proyectar.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_funcion_cancelar_ventas()
RETURNS TRIGGER AS $$
DECLARE
    v_afectadas INTEGER;
BEGIN
    UPDATE venta
    SET estado = 'cancelada'
    WHERE funcion_id_funcion = NEW.id_funcion
      AND estado IN ('pendiente', 'pagada');

    GET DIAGNOSTICS v_afectadas = ROW_COUNT;
    RAISE NOTICE 'Función % cancelada: % venta(s) cancelada(s) automáticamente',
        NEW.id_funcion, v_afectadas;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_funcion_cancelar_ventas
AFTER UPDATE OF estado ON funcion
FOR EACH ROW
WHEN (NEW.estado = 'cancelada' AND OLD.estado <> 'cancelada')
EXECUTE FUNCTION fn_funcion_cancelar_ventas();


-- ---------------------------------------------------------------------
-- 9. VENTA: asignar el precio unitario desde el catálogo
-- Regla: el precio unitario de una venta nueva siempre es el precio
-- vigente del tipo de boleta; no se puede digitar a mano. Así el total
-- (columna generada) siempre corresponde a la tarifa oficial.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_venta_asignar_precio()
RETURNS TRIGGER AS $$
BEGIN
    SELECT precio INTO NEW.precio_unitario
    FROM tipo_boleta
    WHERE id_tipo_boleta = NEW.tipo_boleta_id_tipo_boleta;

    IF NEW.precio_unitario IS NULL THEN
        RAISE EXCEPTION 'El tipo de boleta % no existe', NEW.tipo_boleta_id_tipo_boleta;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_venta_asignar_precio
BEFORE INSERT ON venta
FOR EACH ROW
EXECUTE FUNCTION fn_venta_asignar_precio();


-- ---------------------------------------------------------------------
-- 10. VENTA: validar aforo, estados y participantes
-- Regla:
--  (a) solo se vende para funciones programadas;
--  (b) la suma de boletas no canceladas no puede superar la capacidad
--      de la sala (se bloquea la función con FOR UPDATE para evitar
--      sobreventa por ventas simultáneas);
--  (c) el espectador debe estar activo;
--  (d) en taquilla, el empleado debe estar activo y ser taquillero
--      o administrador;
--  (e) transiciones de estado válidas: pendiente -> pagada | cancelada,
--      pagada -> cancelada. Una venta cancelada no se reactiva.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_venta_validar()
RETURNS TRIGGER AS $$
DECLARE
    v_estado_funcion VARCHAR(20);
    v_capacidad INTEGER;
    v_vendidas INTEGER;
    v_estado_espectador VARCHAR(15);
    v_estado_staff VARCHAR(15);
    v_cargo_staff VARCHAR(30);
BEGIN
    -- (e) Transiciones de estado
    IF TG_OP = 'UPDATE' AND NEW.estado IS DISTINCT FROM OLD.estado THEN
        IF OLD.estado = 'cancelada' THEN
            RAISE EXCEPTION 'La venta % está cancelada y no puede cambiar a "%"',
                OLD.id_venta, NEW.estado;
        ELSIF OLD.estado = 'pagada' AND NEW.estado = 'pendiente' THEN
            RAISE EXCEPTION 'La venta % ya está pagada y no puede volver a pendiente',
                OLD.id_venta;
        END IF;
    END IF;

    -- Una venta que se está cancelando no necesita más validaciones
    IF NEW.estado = 'cancelada' THEN
        RETURN NEW;
    END IF;

    -- En UPDATE solo se revalida si cambian función, cantidad o participantes
    IF TG_OP = 'UPDATE'
       AND NEW.funcion_id_funcion = OLD.funcion_id_funcion
       AND NEW.cantidad_boletas <= OLD.cantidad_boletas
       AND NEW.espectador_id_espectador = OLD.espectador_id_espectador
       AND NEW.staff_id_staff IS NOT DISTINCT FROM OLD.staff_id_staff THEN
        RETURN NEW;
    END IF;

    -- (a) y (b) Función programada y aforo
    SELECT f.estado, s.capacidad INTO v_estado_funcion, v_capacidad
    FROM funcion f
    JOIN sala s ON s.id_sala = f.sala_id_sala
    WHERE f.id_funcion = NEW.funcion_id_funcion
    FOR UPDATE OF f;

    IF v_estado_funcion <> 'programada' THEN
        RAISE EXCEPTION 'No se pueden vender boletas para la función %: estado "%"',
            NEW.funcion_id_funcion, v_estado_funcion;
    END IF;

    SELECT COALESCE(SUM(cantidad_boletas), 0) INTO v_vendidas
    FROM venta
    WHERE funcion_id_funcion = NEW.funcion_id_funcion
      AND estado <> 'cancelada'
      AND id_venta <> COALESCE(NEW.id_venta, -1);

    IF v_vendidas + NEW.cantidad_boletas > v_capacidad THEN
        RAISE EXCEPTION 'Aforo excedido en la función %: capacidad %, vendidas %, solicitadas %',
            NEW.funcion_id_funcion, v_capacidad, v_vendidas, NEW.cantidad_boletas;
    END IF;

    -- (c) Espectador activo
    SELECT estado INTO v_estado_espectador
    FROM espectador WHERE id_espectador = NEW.espectador_id_espectador;

    IF v_estado_espectador <> 'activo' THEN
        RAISE EXCEPTION 'El espectador % está inactivo y no puede comprar boletas',
            NEW.espectador_id_espectador;
    END IF;

    -- (d) Empleado válido en taquilla
    IF NEW.staff_id_staff IS NOT NULL THEN
        SELECT estado, cargo INTO v_estado_staff, v_cargo_staff
        FROM staff WHERE id_staff = NEW.staff_id_staff;

        IF v_estado_staff <> 'activo' THEN
            RAISE EXCEPTION 'El empleado % está inactivo y no puede registrar ventas',
                NEW.staff_id_staff;
        END IF;

        IF NEW.canal_venta = 'taquilla'
           AND v_cargo_staff NOT IN ('taquillero', 'administrador') THEN
            RAISE EXCEPTION 'El empleado % es "%": solo taquilleros o administradores venden en taquilla',
                NEW.staff_id_staff, v_cargo_staff;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_venta_validar
BEFORE INSERT OR UPDATE ON venta
FOR EACH ROW
EXECUTE FUNCTION fn_venta_validar();


-- ---------------------------------------------------------------------
-- 11. CONTRATO: un artista no puede tener contratos vigentes solapados
-- Regla: para un mismo artista no pueden existir dos contratos en
-- estado "vigente" cuyos periodos se crucen (evita pagar dos veces el
-- mismo periodo de participación).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_contrato_sin_solapamiento()
RETURNS TRIGGER AS $$
DECLARE
    v_otro INTEGER;
BEGIN
    IF NEW.estado = 'vigente' THEN
        SELECT id_contrato INTO v_otro
        FROM contrato
        WHERE actores_directores_id_artista = NEW.actores_directores_id_artista
          AND estado = 'vigente'
          AND id_contrato <> COALESCE(NEW.id_contrato, -1)
          AND DATERANGE(fecha_inicio, fecha_fin, '[]')
              && DATERANGE(NEW.fecha_inicio, NEW.fecha_fin, '[]')
        LIMIT 1;

        IF v_otro IS NOT NULL THEN
            RAISE EXCEPTION 'El artista % ya tiene el contrato vigente % en ese periodo',
                NEW.actores_directores_id_artista, v_otro;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_contrato_sin_solapamiento
BEFORE INSERT OR UPDATE ON contrato
FOR EACH ROW
EXECUTE FUNCTION fn_contrato_sin_solapamiento();
