-- ============================================================
-- Tecnomat · Control de Materiales — configuración de Supabase
-- ============================================================

-- 1) Almacén genérico de clave/valor — sustituye a los documentos de
--    Firestore para todo lo que Tecnomat ya gestiona por su cuenta
--    (catálogo, movimientos, chat, pedidos, ajustes...)
create table if not exists tecnomat_kv (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- 2) Órdenes de trabajo — la tabla compartida con la otra app.
--    La otra app inserta aquí cada OT/proyecto que genera.
create table if not exists ordenes_trabajo (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo_orden text not null check (tipo_orden in ('montaje','proyecto')),
  interno_externo text not null check (interno_externo in ('Interno','Externo')),
  solicitante text not null,
  estado text not null default 'activo' check (estado in ('activo','finalizado')),
  origen text not null default 'tecnomat',
  plano text,
  created_at timestamptz not null default now()
);

-- 3) Materiales que trae ya definidos una orden de trabajo
create table if not exists orden_materiales (
  id uuid primary key default gen_random_uuid(),
  orden_id uuid not null references ordenes_trabajo(id) on delete cascade,
  codigo text not null,
  descripcion text,
  cantidad numeric not null default 1,
  referencia text
);

-- 3b) Catálogo de materiales sincronizado desde A3 (vía la otra app) — datos
--     maestros (código, descripción, precio), no cantidades. El stock físico
--     real lo sigue llevando Tecnomat aparte, sumando y restando por escaneo.
create table if not exists materiales (
  id uuid primary key default gen_random_uuid(),
  codigo_articulo text not null unique,
  descripcion text,
  stock_a3 numeric,
  precio_venta numeric,
  origen text not null default 'a3',
  updated_at timestamptz not null default now()
);

-- 3c) Lista rápida de materiales frecuentes — la misma para todas las órdenes
--     y proyectos, pensada para elegir de un vistazo en vez de escanear o
--     escribir a mano. Separada de "materiales" (el catálogo de A3): esta la
--     mantiene quien haga falta directamente en Supabase, a mano.
create table if not exists materiales_rapidos (
  id uuid primary key default gen_random_uuid(),
  codigo text,
  nombre text not null,
  orden integer not null default 0,
  updated_at timestamptz not null default now()
);

-- 4) Función para ajustar el stock de forma segura, aunque dos
--    dispositivos escriban a la vez (evita que se pisen un cambio)
create or replace function ajustar_stock(clave text, item_id text, delta numeric, item_nuevo jsonb)
returns void
language plpgsql
as $$
declare
  catalogo jsonb;
  encontrado boolean := false;
  resultado jsonb := '[]'::jsonb;
  articulo jsonb;
begin
  select value into catalogo from tecnomat_kv where key = clave;
  if catalogo is null then catalogo := '[]'::jsonb; end if;

  for articulo in select * from jsonb_array_elements(catalogo) loop
    if articulo->>'id' = item_id then
      articulo := jsonb_set(articulo, '{qty}', to_jsonb(coalesce((articulo->>'qty')::numeric,0) + delta));
      encontrado := true;
    end if;
    resultado := resultado || jsonb_build_array(articulo);
  end loop;

  if not encontrado then
    resultado := resultado || jsonb_build_array(item_nuevo);
  end if;

  insert into tecnomat_kv (key, value, updated_at)
  values (clave, resultado, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

-- 5) Tiempo real activado en las tablas que hace falta escuchar
alter publication supabase_realtime add table tecnomat_kv;
alter publication supabase_realtime add table ordenes_trabajo;
alter publication supabase_realtime add table materiales;
alter publication supabase_realtime add table materiales_rapidos;

-- 6) Seguridad — de momento, cualquiera con sesión iniciada puede leer
--    y escribir (igual de abierto que Tecnomat ahora mismo con Firebase).
--    Se puede cerrar más adelante sin tocar el código de ninguna app.
alter table tecnomat_kv enable row level security;
alter table ordenes_trabajo enable row level security;
alter table orden_materiales enable row level security;
alter table materiales enable row level security;
alter table materiales_rapidos enable row level security;

create policy "lectura y escritura con sesión iniciada" on tecnomat_kv
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "lectura y escritura con sesión iniciada" on ordenes_trabajo
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "lectura y escritura con sesión iniciada" on orden_materiales
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "lectura y escritura con sesión iniciada" on materiales
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "lectura y escritura con sesión iniciada" on materiales_rapidos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
