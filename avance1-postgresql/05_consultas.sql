-- =====================================================================
-- REELS CINEMA - Avance 1
-- 05_consultas.sql
-- 6 consultas de negocio (JOIN, agregaciones, subconsultas y
-- funciones de ventana).
--
--  #  Consulta                                     Técnica principal
--  1  Ocupación por función                        JOIN + GROUP BY + LEFT JOIN
--  2  Ingresos por película y canal                JOIN + agregación con FILTER
--  3  Espectadores que gastan más que el promedio  Subconsulta
--  4  Ranking de películas por ingresos            Ventana: RANK / ROW_NUMBER
--  5  Evolución diaria de ventas                   Ventana: LAG + SUM acumulado
--  6  Artistas con contrato vigente y películas    JOIN N:M + STRING_AGG
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Ocupación por función
-- Propósito: saber qué tan llena está cada función (boletas vendidas
-- frente a la capacidad de la sala) para decidir si abrir más horarios
-- de una película o mover funciones a salas más pequeñas.
-- ---------------------------------------------------------------------
SELECT f.id_funcion,
       p.titulo,
       s.numero_sala,
       f.fecha_hora_inicio,
       f.estado,
       s.capacidad,
       COALESCE(SUM(v.cantidad_boletas), 0)                         AS boletas_vendidas,
       s.capacidad - COALESCE(SUM(v.cantidad_boletas), 0)           AS puestos_libres,
       ROUND(COALESCE(SUM(v.cantidad_boletas), 0) * 100.0 / s.capacidad, 1) AS ocupacion_pct
FROM funcion f
JOIN pelicula p ON p.id_pelicula = f.pelicula_id_pelicula
JOIN sala s     ON s.id_sala = f.sala_id_sala
LEFT JOIN venta v ON v.funcion_id_funcion = f.id_funcion
                 AND v.estado <> 'cancelada'
GROUP BY f.id_funcion, p.titulo, s.numero_sala, f.fecha_hora_inicio,
         f.estado, s.capacidad
ORDER BY ocupacion_pct DESC, f.fecha_hora_inicio;


-- ---------------------------------------------------------------------
-- 2. Ingresos por película y canal de venta
-- Propósito: comparar cuánto recauda cada película y qué parte de las
-- ventas llega por taquilla y cuál en línea, para orientar la inversión
-- en la plataforma web y el personal de taquilla.
-- ---------------------------------------------------------------------
SELECT p.titulo,
       COUNT(v.id_venta)                                              AS ventas,
       SUM(v.cantidad_boletas)                                        AS boletas,
       SUM(v.total)                                                   AS ingresos_totales,
       COALESCE(SUM(v.total) FILTER (WHERE v.canal_venta = 'taquilla'), 0) AS ingresos_taquilla,
       COALESCE(SUM(v.total) FILTER (WHERE v.canal_venta = 'en_linea'), 0) AS ingresos_en_linea,
       ROUND(AVG(v.total), 2)                                         AS ticket_promedio
FROM venta v
JOIN funcion f  ON f.id_funcion = v.funcion_id_funcion
JOIN pelicula p ON p.id_pelicula = f.pelicula_id_pelicula
WHERE v.estado = 'pagada'
GROUP BY p.titulo
ORDER BY ingresos_totales DESC;


-- ---------------------------------------------------------------------
-- 3. Espectadores que gastan más que el promedio
-- Propósito: identificar a los clientes de mayor valor (gasto total
-- superior al gasto promedio por espectador) para un futuro programa
-- de fidelización o promociones dirigidas.
-- ---------------------------------------------------------------------
SELECT e.id_espectador,
       e.nombre_completo,
       e.correo,
       COUNT(v.id_venta)       AS compras,
       SUM(v.cantidad_boletas) AS boletas,
       SUM(v.total)            AS gasto_total
FROM espectador e
JOIN venta v ON v.espectador_id_espectador = e.id_espectador
WHERE v.estado = 'pagada'
GROUP BY e.id_espectador, e.nombre_completo, e.correo
HAVING SUM(v.total) > (
    SELECT AVG(gasto)
    FROM (
        SELECT SUM(total) AS gasto
        FROM venta
        WHERE estado = 'pagada'
        GROUP BY espectador_id_espectador
    ) gasto_por_espectador
)
ORDER BY gasto_total DESC;


-- ---------------------------------------------------------------------
-- 4. Ranking de películas por ingresos (FUNCIÓN DE VENTANA)
-- Propósito: ordenar la cartelera por desempeño comercial, ver la
-- participación de cada película en el total y, dentro de cada género,
-- cuál es la más taquillera. Sirve para decidir qué títulos mantener
-- en cartelera y cuáles retirar.
-- RANK() da la posición general (empates comparten puesto),
-- ROW_NUMBER() numera dentro de cada género y SUM() OVER () calcula
-- el gran total sin colapsar las filas.
-- ---------------------------------------------------------------------
WITH ingresos_pelicula AS (
    SELECT p.id_pelicula,
           p.titulo,
           p.genero,
           SUM(v.total)            AS ingresos,
           SUM(v.cantidad_boletas) AS boletas
    FROM pelicula p
    JOIN funcion f ON f.pelicula_id_pelicula = p.id_pelicula
    JOIN venta v   ON v.funcion_id_funcion = f.id_funcion
    WHERE v.estado = 'pagada'
    GROUP BY p.id_pelicula, p.titulo, p.genero
)
SELECT RANK() OVER (ORDER BY ingresos DESC)                          AS puesto_general,
       titulo,
       genero,
       ROW_NUMBER() OVER (PARTITION BY genero ORDER BY ingresos DESC) AS puesto_en_genero,
       boletas,
       ingresos,
       ROUND(ingresos * 100.0 / SUM(ingresos) OVER (), 1)           AS participacion_pct
FROM ingresos_pelicula
ORDER BY puesto_general;


-- ---------------------------------------------------------------------
-- 5. Evolución diaria de ventas (FUNCIÓN DE VENTANA)
-- Propósito: seguir el comportamiento de las ventas día a día,
-- comparando cada día con el anterior (LAG) y llevando el acumulado del
-- periodo, para detectar caídas o picos (estrenos, fines de semana).
-- ---------------------------------------------------------------------
WITH ventas_dia AS (
    SELECT (v.fecha_hora_venta AT TIME ZONE 'America/Bogota')::DATE AS dia,
           SUM(v.cantidad_boletas) AS boletas,
           SUM(v.total)            AS ingresos
    FROM venta v
    WHERE v.estado = 'pagada'
    GROUP BY 1
)
SELECT dia,
       boletas,
       ingresos,
       LAG(ingresos) OVER (ORDER BY dia)                   AS ingresos_dia_anterior,
       ingresos - LAG(ingresos) OVER (ORDER BY dia)        AS variacion,
       ROUND((ingresos - LAG(ingresos) OVER (ORDER BY dia)) * 100.0
             / NULLIF(LAG(ingresos) OVER (ORDER BY dia), 0), 1) AS variacion_pct,
       SUM(ingresos) OVER (ORDER BY dia)                   AS ingresos_acumulados
FROM ventas_dia
ORDER BY dia;


-- ---------------------------------------------------------------------
-- 6. Artistas con contrato vigente y sus películas
-- Propósito: listar los invitados disponibles para funciones
-- especiales (contrato vigente hoy), con el valor contratado y las
-- películas en las que participan, para planear eventos con invitados.
-- ---------------------------------------------------------------------
SELECT a.nombre_completo,
       a.rol,
       a.nacionalidad,
       c.fecha_inicio,
       c.fecha_fin,
       c.valor,
       COALESCE(STRING_AGG(p.titulo, ', ' ORDER BY p.titulo), '(sin películas registradas)') AS peliculas
FROM actores_directores a
JOIN contrato c ON c.actores_directores_id_artista = a.id_artista
LEFT JOIN pelicula_actores_directores pad ON pad.actores_directores_id_artista = a.id_artista
LEFT JOIN pelicula p ON p.id_pelicula = pad.pelicula_id_pelicula
WHERE c.estado = 'vigente'
  AND CURRENT_DATE BETWEEN c.fecha_inicio AND c.fecha_fin
GROUP BY a.id_artista, a.nombre_completo, a.rol, a.nacionalidad,
         c.id_contrato, c.fecha_inicio, c.fecha_fin, c.valor
ORDER BY c.valor DESC;
