-- Reels Cinema: datos de prueba ficticios para PostgreSQL.
-- Ejecutar después de 01_creacion_tablas.sql y antes de 03_triggers.sql.
-- Requiere las diez tablas vacías. No borra ni reemplaza datos existentes.
-- Fechas del escenario académico: octubre de 2026. Moneda: COP.
BEGIN;
SET LOCAL TIME ZONE 'America/Bogota';
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM sala) OR EXISTS (SELECT 1 FROM espectador)
       OR EXISTS (SELECT 1 FROM staff) OR EXISTS (SELECT 1 FROM tipo_boleta)
       OR EXISTS (SELECT 1 FROM pelicula) OR EXISTS (SELECT 1 FROM actores_directores)
       OR EXISTS (SELECT 1 FROM funcion) OR EXISTS (SELECT 1 FROM venta)
       OR EXISTS (SELECT 1 FROM contrato) OR EXISTS (SELECT 1 FROM pelicula_actores_directores)
    THEN
        RAISE EXCEPTION 'Las tablas deben estar vacías. Estos datos de prueba se cargan una sola vez.';
    END IF;
END;
$$;

INSERT INTO sala (id_sala, numero_sala, capacidad, estado) VALUES
    (1, 1, 80, 'disponible'),
    (2, 2, 60, 'disponible'),
    (3, 3, 40, 'disponible');

INSERT INTO staff (id_staff, nombre_completo, tipo_documento, numero_documento, cargo, correo, telefono, fecha_ingreso, estado) VALUES
    (1, 'Patricia Molina', 'CC', '1000000001', 'taquillero', 'staff1@example.com', '3000000001', '2026-01-15', 'activo'),
    (2, 'Jorge Beltrán', 'CC', '1000000002', 'taquillero', 'staff2@example.com', '3000000002', '2026-01-15', 'activo'),
    (3, 'Andrea Fuentes', 'CC', '1000000003', 'administrador', 'staff3@example.com', '3000000003', '2026-01-15', 'activo'),
    (4, 'Luis Cabrera', 'CC', '1000000004', 'proyeccionista', 'staff4@example.com', '3000000004', '2026-01-15', 'activo'),
    (5, 'Diana Peña', 'CC', '1000000005', 'proyeccionista', 'staff5@example.com', '3000000005', '2026-01-15', 'activo'),
    (6, 'Mario Espinosa', 'CC', '1000000006', 'auxiliar', 'staff6@example.com', '3000000006', '2026-01-15', 'activo');

INSERT INTO tipo_boleta (id_tipo_boleta, categoria, descripcion, precio) VALUES
    (1, 'General', 'Entrada general para funciones regulares', 22000),
    (2, 'Estudiante', 'Tarifa con acreditación estudiantil', 16000),
    (3, 'Adulto mayor', 'Tarifa para personas mayores de 60 años', 14000),
    (4, 'Especial', 'Entrada para funciones especiales', 30000);

INSERT INTO pelicula (id_pelicula, titulo, duracion, genero, clasificacion_edad, idioma_original, fecha_estreno) VALUES
    (1, 'Luces de Bogotá', 100, 'Aventura', 'Todos', 'Español', '2026-10-01'),
    (2, 'El último tren', 110, 'Comedia', 'Todos', 'Español', '2026-10-01'),
    (3, 'Horizonte azul', 120, 'Suspenso', 'Todos', 'Español', '2026-10-01'),
    (4, 'Una noche de octubre', 90, 'Drama', 'Todos', 'Español', '2026-10-01'),
    (5, 'La casa del viento', 100, 'Aventura', 'Todos', 'Español', '2026-10-01'),
    (6, 'Código secreto', 110, 'Comedia', 'Todos', 'Español', '2026-10-01'),
    (7, 'Voces del barrio', 120, 'Suspenso', 'Todos', 'Español', '2026-10-01'),
    (8, 'El viaje de Luna', 90, 'Drama', 'Todos', 'Español', '2026-10-01'),
    (9, 'Memorias de papel', 100, 'Aventura', 'Todos', 'Español', '2026-10-01'),
    (10, 'Camino al sol', 110, 'Comedia', 'Todos', 'Español', '2026-10-01');

INSERT INTO actores_directores (id_artista, nombre_completo, fecha_nacimiento, nacionalidad, rol, biografia) VALUES
    (1, 'Ana Torres', '1971-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (2, 'Carlos Mendoza', '1972-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (3, 'Laura Rojas', '1973-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (4, 'Diego Vargas', '1974-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (5, 'Camila Herrera', '1975-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (6, 'Andrés Castro', '1976-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (7, 'Valentina Ruiz', '1977-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (8, 'Juan Morales', '1978-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (9, 'Sofía Ramírez', '1979-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (10, 'Mateo Silva', '1980-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (11, 'Daniela Ortiz', '1981-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (12, 'Sebastián Gómez', '1982-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (13, 'Mariana López', '1983-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (14, 'Nicolás Pérez', '1984-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (15, 'Paula Sánchez', '1985-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (16, 'Felipe Díaz', '1986-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (17, 'Isabella Moreno', '1987-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (18, 'Santiago Romero', '1988-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (19, 'Lucía Navarro', '1989-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (20, 'David Cárdenas', '1990-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (21, 'Sara Jiménez', '1991-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (22, 'Gabriel Salazar', '1992-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (23, 'Juliana Medina', '1993-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (24, 'Tomás Reyes', '1994-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (25, 'Natalia Rincón', '1995-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (26, 'Samuel Suárez', '1996-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (27, 'Manuela Vega', '1997-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (28, 'Alejandro León', '1998-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (29, 'Victoria Pardo', '1999-05-15', 'Colombiana', 'actor', 'Artista ficticio del catálogo de prueba de Reels Cinema.'),
    (30, 'Emilio Acosta', '2000-05-15', 'Colombiana', 'director', 'Artista ficticio del catálogo de prueba de Reels Cinema.');

INSERT INTO espectador (id_espectador, nombre_completo, correo, telefono, fecha_registro, estado) VALUES
    (1, 'Ana Torres Martínez', 'espectador1@example.com', '3100000001', '2026-10-01', 'activo'),
    (2, 'Carlos Mendoza Martínez', 'espectador2@example.com', '3100000002', '2026-10-01', 'activo'),
    (3, 'Laura Rojas Martínez', 'espectador3@example.com', '3100000003', '2026-10-01', 'activo'),
    (4, 'Diego Vargas Martínez', 'espectador4@example.com', '3100000004', '2026-10-01', 'activo'),
    (5, 'Camila Herrera Martínez', 'espectador5@example.com', '3100000005', '2026-10-01', 'activo'),
    (6, 'Andrés Castro Martínez', 'espectador6@example.com', '3100000006', '2026-10-01', 'activo'),
    (7, 'Valentina Ruiz Martínez', 'espectador7@example.com', '3100000007', '2026-10-01', 'activo'),
    (8, 'Juan Morales Martínez', 'espectador8@example.com', '3100000008', '2026-10-01', 'activo'),
    (9, 'Sofía Ramírez Martínez', 'espectador9@example.com', '3100000009', '2026-10-01', 'activo'),
    (10, 'Mateo Silva Martínez', 'espectador10@example.com', '3100000010', '2026-10-01', 'activo'),
    (11, 'Daniela Ortiz Martínez', 'espectador11@example.com', '3100000011', '2026-10-01', 'activo'),
    (12, 'Sebastián Gómez Martínez', 'espectador12@example.com', '3100000012', '2026-10-01', 'activo'),
    (13, 'Mariana López Martínez', 'espectador13@example.com', '3100000013', '2026-10-01', 'activo'),
    (14, 'Nicolás Pérez Martínez', 'espectador14@example.com', '3100000014', '2026-10-01', 'activo'),
    (15, 'Paula Sánchez Martínez', 'espectador15@example.com', '3100000015', '2026-10-01', 'activo'),
    (16, 'Felipe Díaz Martínez', 'espectador16@example.com', '3100000016', '2026-10-01', 'activo'),
    (17, 'Isabella Moreno Martínez', 'espectador17@example.com', '3100000017', '2026-10-01', 'activo'),
    (18, 'Santiago Romero Martínez', 'espectador18@example.com', '3100000018', '2026-10-01', 'activo'),
    (19, 'Lucía Navarro Martínez', 'espectador19@example.com', '3100000019', '2026-10-01', 'activo'),
    (20, 'David Cárdenas Martínez', 'espectador20@example.com', '3100000020', '2026-10-01', 'activo'),
    (21, 'Sara Jiménez Martínez', 'espectador21@example.com', '3100000021', '2026-10-01', 'activo'),
    (22, 'Gabriel Salazar Martínez', 'espectador22@example.com', '3100000022', '2026-10-01', 'activo'),
    (23, 'Juliana Medina Martínez', 'espectador23@example.com', '3100000023', '2026-10-01', 'activo'),
    (24, 'Tomás Reyes Martínez', 'espectador24@example.com', '3100000024', '2026-10-01', 'activo'),
    (25, 'Natalia Rincón Martínez', 'espectador25@example.com', '3100000025', '2026-10-01', 'activo'),
    (26, 'Samuel Suárez Martínez', 'espectador26@example.com', '3100000026', '2026-10-01', 'activo'),
    (27, 'Manuela Vega Martínez', 'espectador27@example.com', '3100000027', '2026-10-01', 'activo'),
    (28, 'Alejandro León Martínez', 'espectador28@example.com', '3100000028', '2026-10-01', 'activo'),
    (29, 'Victoria Pardo Martínez', 'espectador29@example.com', '3100000029', '2026-10-01', 'activo'),
    (30, 'Emilio Acosta Martínez', 'espectador30@example.com', '3100000030', '2026-10-01', 'activo');

INSERT INTO pelicula_actores_directores (pelicula_id_pelicula, actores_directores_id_artista) VALUES
    (1, 1),
    (1, 2),
    (1, 3),
    (2, 4),
    (2, 5),
    (2, 6),
    (3, 7),
    (3, 8),
    (3, 9),
    (4, 10),
    (4, 11),
    (4, 12),
    (5, 13),
    (5, 14),
    (5, 15),
    (6, 16),
    (6, 17),
    (6, 18),
    (7, 19),
    (7, 20),
    (7, 21),
    (8, 22),
    (8, 23),
    (8, 24),
    (9, 25),
    (9, 26),
    (9, 27),
    (10, 28),
    (10, 29),
    (10, 30);

INSERT INTO funcion (id_funcion, sala_id_sala, pelicula_id_pelicula, fecha_hora_inicio, fecha_hora_fin, formato_proyeccion, idioma_proyeccion, subtitulada, estado) VALUES
    (1, 1, 1, '2026-10-10 14:00:00', '2026-10-10 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (2, 1, 2, '2026-10-10 18:00:00', '2026-10-10 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (3, 2, 3, '2026-10-10 14:00:00', '2026-10-10 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (4, 2, 4, '2026-10-10 18:00:00', '2026-10-10 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (5, 3, 5, '2026-10-10 14:00:00', '2026-10-10 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (6, 3, 6, '2026-10-10 18:00:00', '2026-10-10 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (7, 1, 7, '2026-10-11 14:00:00', '2026-10-11 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (8, 1, 8, '2026-10-11 18:00:00', '2026-10-11 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (9, 2, 9, '2026-10-11 14:00:00', '2026-10-11 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (10, 2, 10, '2026-10-11 18:00:00', '2026-10-11 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (11, 3, 1, '2026-10-11 14:00:00', '2026-10-11 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (12, 3, 2, '2026-10-11 18:00:00', '2026-10-11 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (13, 1, 3, '2026-10-12 14:00:00', '2026-10-12 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (14, 1, 4, '2026-10-12 18:00:00', '2026-10-12 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (15, 2, 5, '2026-10-12 14:00:00', '2026-10-12 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (16, 2, 6, '2026-10-12 18:00:00', '2026-10-12 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (17, 3, 7, '2026-10-12 14:00:00', '2026-10-12 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (18, 3, 8, '2026-10-12 18:00:00', '2026-10-12 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (19, 1, 9, '2026-10-13 14:00:00', '2026-10-13 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (20, 1, 10, '2026-10-13 18:00:00', '2026-10-13 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (21, 2, 1, '2026-10-13 14:00:00', '2026-10-13 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (22, 2, 2, '2026-10-13 18:00:00', '2026-10-13 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (23, 3, 3, '2026-10-13 14:00:00', '2026-10-13 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (24, 3, 4, '2026-10-13 18:00:00', '2026-10-13 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (25, 1, 5, '2026-10-14 14:00:00', '2026-10-14 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (26, 1, 6, '2026-10-14 18:00:00', '2026-10-14 19:50:00', '2D', 'Español', FALSE, 'programada'),
    (27, 2, 7, '2026-10-14 14:00:00', '2026-10-14 16:00:00', '2D', 'Español', FALSE, 'programada'),
    (28, 2, 8, '2026-10-14 18:00:00', '2026-10-14 19:30:00', '2D', 'Español', FALSE, 'programada'),
    (29, 3, 9, '2026-10-14 14:00:00', '2026-10-14 15:40:00', '2D', 'Español', FALSE, 'programada'),
    (30, 3, 10, '2026-10-14 18:00:00', '2026-10-14 19:50:00', '2D', 'Español', FALSE, 'programada');

INSERT INTO contrato (id_contrato, actores_directores_id_artista, fecha_inicio, fecha_fin, descripcion, valor, estado) VALUES
    (1, 1, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 550000, 'vigente'),
    (2, 2, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 600000, 'vigente'),
    (3, 3, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 650000, 'vigente'),
    (4, 4, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 700000, 'vigente'),
    (5, 5, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 750000, 'vigente'),
    (6, 6, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 800000, 'vigente'),
    (7, 7, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 850000, 'vigente'),
    (8, 8, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 900000, 'vigente'),
    (9, 9, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 950000, 'vigente'),
    (10, 10, '2026-10-01', '2026-10-31', 'Participación en actividades promocionales y encuentros de cine.', 1000000, 'vigente');

INSERT INTO venta (id_venta, espectador_id_espectador, funcion_id_funcion, tipo_boleta_id_tipo_boleta, staff_id_staff, fecha_hora_venta, cantidad_boletas, precio_unitario, metodo_pago, canal_venta, estado) VALUES
    (1, 1, 1, 1, 1, '2026-10-06 13:00:00-05', 2, 22000, 'efectivo', 'taquilla', 'pagada'),
    (2, 2, 2, 2, NULL, '2026-10-06 13:00:00-05', 3, 16000, 'tarjeta', 'en_linea', 'pagada'),
    (3, 3, 3, 3, 1, '2026-10-06 13:00:00-05', 1, 14000, 'efectivo', 'taquilla', 'pagada'),
    (4, 4, 4, 1, NULL, '2026-10-06 13:00:00-05', 2, 22000, 'tarjeta', 'en_linea', 'pagada'),
    (5, 5, 5, 2, 1, '2026-10-06 13:00:00-05', 3, 16000, 'efectivo', 'taquilla', 'pagada'),
    (6, 6, 6, 3, NULL, '2026-10-06 13:00:00-05', 1, 14000, 'tarjeta', 'en_linea', 'pagada'),
    (7, 7, 7, 1, 1, '2026-10-06 13:00:00-05', 2, 22000, 'efectivo', 'taquilla', 'pagada'),
    (8, 8, 8, 2, NULL, '2026-10-06 13:00:00-05', 3, 16000, 'tarjeta', 'en_linea', 'pagada'),
    (9, 9, 9, 3, 1, '2026-10-06 13:00:00-05', 1, 14000, 'efectivo', 'taquilla', 'pagada'),
    (10, 10, 10, 1, NULL, '2026-10-06 13:00:00-05', 2, 22000, 'tarjeta', 'en_linea', 'pagada'),
    (11, 11, 11, 2, 1, '2026-10-06 13:00:00-05', 3, 16000, 'efectivo', 'taquilla', 'pagada'),
    (12, 12, 12, 3, NULL, '2026-10-06 13:00:00-05', 1, 14000, 'tarjeta', 'en_linea', 'pagada'),
    (13, 13, 13, 1, 1, '2026-10-06 13:00:00-05', 2, 22000, 'efectivo', 'taquilla', 'pagada'),
    (14, 14, 14, 2, NULL, '2026-10-06 13:00:00-05', 3, 16000, 'tarjeta', 'en_linea', 'pagada'),
    (15, 15, 15, 3, 1, '2026-10-06 13:00:00-05', 1, 14000, 'efectivo', 'taquilla', 'pagada'),
    (16, 16, 16, 1, NULL, '2026-10-06 13:00:00-05', 2, 22000, 'tarjeta', 'en_linea', 'pagada'),
    (17, 17, 17, 2, 1, '2026-10-06 13:00:00-05', 3, 16000, 'efectivo', 'taquilla', 'pagada'),
    (18, 18, 18, 3, NULL, '2026-10-06 13:00:00-05', 1, 14000, 'tarjeta', 'en_linea', 'pagada'),
    (19, 19, 19, 1, 1, '2026-10-06 13:00:00-05', 2, 22000, 'efectivo', 'taquilla', 'pagada'),
    (20, 20, 20, 2, NULL, '2026-10-06 13:00:00-05', 3, 16000, 'tarjeta', 'en_linea', 'pagada'),
    (21, 21, 21, 3, 1, '2026-10-06 13:00:00-05', 1, 14000, 'efectivo', 'taquilla', 'pagada'),
    (22, 22, 22, 1, NULL, '2026-10-06 13:00:00-05', 2, 22000, 'tarjeta', 'en_linea', 'pagada'),
    (23, 23, 23, 2, 1, '2026-10-06 13:00:00-05', 3, 16000, 'efectivo', 'taquilla', 'pagada'),
    (24, 24, 24, 3, NULL, '2026-10-06 13:00:00-05', 1, 14000, 'tarjeta', 'en_linea', 'pagada'),
    (25, 25, 25, 1, 1, '2026-10-06 13:00:00-05', 2, 22000, 'efectivo', 'taquilla', 'pagada'),
    (26, 26, 26, 2, NULL, '2026-10-06 13:00:00-05', 3, 16000, 'tarjeta', 'en_linea', 'pagada'),
    (27, 27, 27, 3, 1, '2026-10-06 13:00:00-05', 1, 14000, 'efectivo', 'taquilla', 'pagada'),
    (28, 28, 28, 1, NULL, '2026-10-06 13:00:00-05', 2, 22000, 'tarjeta', 'en_linea', 'pagada'),
    (29, 29, 29, 2, 1, '2026-10-06 13:00:00-05', 3, 16000, 'efectivo', 'taquilla', 'pagada'),
    (30, 30, 30, 3, NULL, '2026-10-06 13:00:00-05', 1, 14000, 'tarjeta', 'en_linea', 'pagada');

-- Sincronizar identidades después de insertar identificadores explícitos.

SELECT setval(pg_get_serial_sequence('sala', 'id_sala'), (SELECT MAX(id_sala) FROM sala), true);

SELECT setval(pg_get_serial_sequence('staff', 'id_staff'), (SELECT MAX(id_staff) FROM staff), true);

SELECT setval(pg_get_serial_sequence('tipo_boleta', 'id_tipo_boleta'), (SELECT MAX(id_tipo_boleta) FROM tipo_boleta), true);

SELECT setval(pg_get_serial_sequence('pelicula', 'id_pelicula'), (SELECT MAX(id_pelicula) FROM pelicula), true);

SELECT setval(pg_get_serial_sequence('actores_directores', 'id_artista'), (SELECT MAX(id_artista) FROM actores_directores), true);

SELECT setval(pg_get_serial_sequence('espectador', 'id_espectador'), (SELECT MAX(id_espectador) FROM espectador), true);

SELECT setval(pg_get_serial_sequence('funcion', 'id_funcion'), (SELECT MAX(id_funcion) FROM funcion), true);

SELECT setval(pg_get_serial_sequence('contrato', 'id_contrato'), (SELECT MAX(id_contrato) FROM contrato), true);

SELECT setval(pg_get_serial_sequence('venta', 'id_venta'), (SELECT MAX(id_venta) FROM venta), true);

COMMIT;

-- Comprobación de cantidades: 30 en cada una de las cuatro tablas principales.

SELECT 'actores_directores' AS tabla, COUNT(*) AS registros FROM actores_directores
UNION ALL
SELECT 'espectador' AS tabla, COUNT(*) AS registros FROM espectador
UNION ALL
SELECT 'funcion' AS tabla, COUNT(*) AS registros FROM funcion
UNION ALL
SELECT 'venta' AS tabla, COUNT(*) AS registros FROM venta
UNION ALL
SELECT 'sala' AS tabla, COUNT(*) AS registros FROM sala
UNION ALL
SELECT 'staff' AS tabla, COUNT(*) AS registros FROM staff
UNION ALL
SELECT 'tipo_boleta' AS tabla, COUNT(*) AS registros FROM tipo_boleta
UNION ALL
SELECT 'pelicula' AS tabla, COUNT(*) AS registros FROM pelicula
UNION ALL
SELECT 'contrato' AS tabla, COUNT(*) AS registros FROM contrato
UNION ALL
SELECT 'pelicula_actores_directores' AS tabla, COUNT(*) AS registros FROM pelicula_actores_directores
ORDER BY tabla;
