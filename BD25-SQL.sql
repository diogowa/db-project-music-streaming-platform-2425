-- Drops
drop table utilizadores cascade constraints;
drop table pagos cascade constraints;
drop table gratuitos cascade constraints;
drop table musicas cascade constraints;
drop table generos cascade constraints;
drop table temGenero cascade constraints;
drop table artistas cascade constraints;
drop table temArtista cascade constraints;
drop table albuns cascade constraints;
drop table pertence cascade constraints;
drop table reproducoes cascade constraints;

drop trigger trg_limite_generos_musica;
drop trigger trg_remover_utilizador_pago;
drop trigger trg_remover_utilizador_gratuito;
drop trigger trg_utilizador_default;
drop trigger trg_data_pagamento;
drop trigger trg_vw_inserir_musica;
drop trigger trg_vw_update_musica;
drop trigger trg_vw_remover_musica;

drop view vw_artistas;
drop view vw_catalogo_albuns;
drop view vw_catalogo_musicas;
drop view vw_inserir_musica;
drop view vw_utilizadores;




-- Tabelas
create table utilizadores (
    idU number generated always as identity,
    nome varchar2(100) not null,
    dataAdesao date not null,
    primary key(idU)
);

create table pagos (
    idU number,
    dataPag date not null,
    formaPag varchar2(100) not null,
    primary key(idU),
    foreign key(idU) references utilizadores(idU) on delete cascade
);

create table gratuitos (
    idU number,
    primary key(idU),
    foreign key(idU) references utilizadores(idU) on delete cascade
);

create table musicas (
    idM number generated always as identity,
    titulo varchar2(100) not null,
    duracao number not null,
    primary key(idM)
);

create table generos (
    idG number generated always as identity,
    tipo varchar2(100) not null,
    unique (tipo),
    primary key(idG)
);

create table temGenero (
    idG number,
    idM number,
    primary key(idG, idM),
    foreign key(idG) references generos(idG) on delete cascade,
    foreign key(idM) references musicas(idM) on delete cascade
);

create table artistas (
    idA number generated always as identity,
    nome varchar2(100) not null,
    origem varchar2(100) not null,
    unique (nome),
    primary key(idA)
);

create table temArtista (
    idA number,
    idM number,
    primary key (idA, idM),
    foreign key(idA) references artistas(idA) on delete cascade,
    foreign key(idM) references musicas(idM) on delete cascade
);

create table albuns (
    idA number,
    titulo varchar2(100),
    tipo varchar2(100),
    dataLanc date not null,
    check (upper(tipo) in ('SINGLE', 'EP', 'ALBUM')),
    primary key(idA, titulo, tipo),
    foreign key(idA) references artistas(idA) on delete cascade
);

create table pertence (
    idM number,
    idA number,
    titulo varchar2(100),
    tipo varchar2(100),
    faixa number,
    unique (idA, titulo, tipo, faixa),
    primary key(idM, idA, titulo, tipo),
    foreign key(idM) references musicas(idM) on delete cascade,
    foreign key(idA, titulo, tipo) references albuns(idA, titulo, tipo) on delete cascade
);

create table reproducoes (
    idU number,
    momento timestamp,
    idM number,
    idA number,
    titulo varchar2(100),
    tipo varchar2(100),
    primary key(idU, momento),
    foreign key(idU) references utilizadores(idU) on delete cascade,
    foreign key(idM, idA, titulo, tipo) references pertence(idM, idA, titulo, tipo) on delete cascade
);




-- Functions
create or replace function fn_formatar_duracao(p_ms in number)
    return varchar2
is
    v_horas pls_integer;
    v_minutos pls_integer;
    v_segundos pls_integer;
begin
    -- obter horas, minutos e segundos
    v_horas := trunc(p_ms / 3600000);
    v_minutos := trunc(mod(p_ms, 3600000) / 60000);
    v_segundos := trunc(mod(p_ms, 60000) / 1000);

    -- devolve string
    return to_char(v_horas) 
            || ':' || lpad(to_char(v_minutos), 2, '0') 
            || ':' || lpad(to_char(v_segundos), 2, '0');
end fn_formatar_duracao;
/




-- Views
-- View para adicionar novas músicas
create or replace view vw_inserir_musica as
select
    a.idA,
    m.idM,
    m.titulo,
    m.duracao,
    alb.titulo as album,
    alb.tipo,
    g.idG
from
    musicas m
    join temArtista ta on m.idM = ta.idM
    join artistas a on ta.idA = a.idA

    join pertence p on m.idM = p.idM
    join albuns alb on p.idA = alb.idA 
        and p.titulo = alb.titulo 
        and p.tipo = alb.tipo

    join temGenero tg on m.idM = tg.idM
    join generos g on tg.idG = g.idG
;

-- View para mostrar todas as músicas
create or replace view vw_catalogo_musicas as
select
    a.idA,
    m.idM,
    nvl(r.numReproducoes, 0) as numReproducoes,
    fn_formatar_duracao(m.duracao) as duracao,
    g.idG
from
    musicas m
    join temArtista ta on m.idM = ta.idM
    join artistas a on ta.idA = a.idA

    join temGenero tg on m.idM = tg.idM
    join generos g on tg.idG = g.idG

    left join (
        select idM, count(*) as numReproducoes 
        from reproducoes 
        group by idM
    ) r on m.idM = r.idM
;

-- View para mostrar todos os álbuns
create or replace view vw_catalogo_albuns as
with info_album as (
    select 
        alb.idA,
        alb.titulo,
        alb.tipo,
        count(*) as numMusicas,
        sum(m.duracao) as duracaoTotal
    from 
        albuns alb 
        join pertence p on alb.idA = p.idA 
            and alb.titulo = p.titulo 
            and alb.tipo = p.tipo
        join musicas m on p.idM = m.idM
    group by alb.idA, alb.titulo, alb.tipo
)
select 
    idA,
    titulo, 
    tipo,
    dataLanc,
    numMusicas,
    fn_formatar_duracao(duracaoTotal) as duracaoTotal
from 
    info_album 
    join albuns using (idA, titulo, tipo)
    join artistas using (idA)
;

-- View para mostrar os artistas com soma das reproduções, soma dos álbuns, e soma das músicas
create or replace view vw_artistas as
with count_reproducoes_artista as (
    select idA, count(*) as numReproducoes
    from reproducoes
    group by idA
),
count_albuns_artista as (
    select idA, count(*) as numAlbuns
    from albuns
    group by idA
), 
count_musicas_artista as (
    select idA, count(*) as numMusicas
    from temArtista
    group by idA
)
select
    idA,
    nome,
    origem,
    nvl(numReproducoes, 0) as numReproducoes,
    nvl(numAlbuns, 0) as numAlbuns,
    nvl(numMusicas, 0) as numMusicas
from
    artistas
    left join count_reproducoes_artista using (idA)
    left join count_albuns_artista using (idA)
    left join count_musicas_artista using (idA)
;

-- View para mostrar todos os utilizadores
create or replace view vw_utilizadores as
select
    idU,
    nome,
    dataAdesao,
    'GRATUITO' as tipo,
    null as dataPag,
    null as formaPag
from
    utilizadores
    join gratuitos using (idU)
union all
select
    idU,
    nome,
    dataAdesao,
    'PAGO' as tipo,
    dataPag,
    formaPag
from
    utilizadores
    join pagos using (idU)
;




-- Triggers
-- Inserir música
create or replace trigger trg_vw_inserir_musica
instead of insert on vw_inserir_musica
for each row
declare
    v_idM number;
    v_faixa number;
begin
    -- inserir em músicas e obter o idM gerado
    insert into musicas (titulo, duracao) 
    values (:new.titulo, :new.duracao)
    returning idM into v_idM;

    -- número de músicas no álbum
    select count(*) into v_faixa 
    from albuns join pertence using (idA, titulo, tipo)
    where idA = :new.idA 
        and titulo = :new.album 
        and tipo = :new.tipo;

    -- ligar música a álbum
    insert into pertence 
    values (v_idM, :new.idA, :new.album, :new.tipo, v_faixa + 1);

    -- ligar música a género
    insert into temGenero 
    values (:new.idG, v_idM);

    -- ligar música a artista
    insert into temArtista 
    values (:new.idA, v_idM);
end;
/

-- Remover música
create or replace trigger trg_vw_remover_musica
instead of delete on vw_inserir_musica
for each row
begin
    delete from musicas where :old.idM = idM;
end;
/

-- Update música
create or replace trigger trg_vw_update_musica
instead of update on vw_inserir_musica
for each row
declare
    v_faixa number;
begin
    update musicas 
    set titulo = :new.titulo, duracao = :new.duracao
    where idm = :old.idM;

    delete from temArtista where :old.idM = idM;
    insert into temArtista 
    values (:new.idA, :old.idM);
    
    -- número de músicas no álbum
    select count(*) into v_faixa 
    from albuns join pertence using (idA, titulo, tipo)
    where idA = :new.idA 
        and titulo = :new.album 
        and tipo = :new.tipo;
    
    delete from pertence where :old.idM = idM;
    insert into pertence 
    values (:old.idM, :new.idA, :new.album, :new.tipo, v_faixa + 1);
    
    delete from temGenero where :old.idM = idM;
    insert into temGenero 
    values (:new.idG, :old.idM);
end;
/

-- Garantir que a data de pagamento é depois da data de adesão
create or replace trigger trg_data_pagamento
before insert on pagos
for each row
declare 
    dAdesao date;
begin
    select dataAdesao into dAdesao
    from utilizadores
    where idU = :new.idU;
    if (:new.dataPag < dAdesao) then
        Raise_Application_Error(-20019, 'Data de pagamento inválida.');
    end if;
end;
/

-- Ao criar um novo utilizador, registá-lo automaticamente como gratuito
create or replace trigger trg_utilizador_default
after insert on utilizadores
for each row
begin
    insert into gratuitos (idU) values (:new.idU);
end;
/

-- Quando um utilizador passa de gratuito a pago, removê-lo de gratuito
create or replace trigger trg_remover_utilizador_gratuito
after insert on pagos
for each row
begin
    delete from gratuitos where idU = :new.idU;
end;
/

-- Quando um utilizador passa de pago a gratuito, removê-lo de pago
create or replace trigger trg_remover_utilizador_pago
after insert on gratuitos
for each row
begin
    delete from pagos where idU = :new.idU;
end;
/

-- Garantir que uma música só pode ter um máximo de 2 géneros
create or replace trigger trg_limite_generos_musica
before insert on temGenero
for each row
declare
    numTotal number;
begin
    select count(*) into numTotal
    from temGenero
    where idM = :new.idM;
    if (numTotal = 2) then
        Raise_Application_Error(-20020, 'Música não pode ter mais que dois géneros.');
    end if;
end;
/




-- Inserção de dados
-- Utilizadores
insert into utilizadores (nome, dataAdesao) values ('Diogo', date '2016-01-14');
insert into utilizadores (nome, dataAdesao) values ('Rafael', date '2018-01-14');
insert into utilizadores (nome, dataAdesao) values ('Rodrigo', date '2020-01-14');
insert into utilizadores (nome, dataAdesao) values ('Maria', date '2021-01-14');
insert into utilizadores (nome, dataAdesao) values ('Carolina', date '2024-01-14');

insert into pagos values (1, date '2016-01-15', 'Cartao');
insert into pagos values (2, date '2018-01-15', 'Cartao');


-- Adicionar géneros
insert into generos (tipo) values ('Alternative Rock');
insert into generos (tipo) values ('Dream Pop');
insert into generos (tipo) values ('Indie Pop');
insert into generos (tipo) values ('Hip-Hop');
insert into generos (tipo) values ('Pop');

-- Adicionar artistas
insert into artistas (nome, origem) values ('Terno Rei', 'Brasil');
insert into artistas (nome, origem) values ('Lô Borges', 'Brasil');
insert into artistas (nome, origem) values ('Capitão Fausto', 'Portugal');
insert into artistas (nome, origem) values ('Travis Scott', 'Estados Unidos da América');
insert into artistas (nome, origem) values ('Paira', 'Brasil');


-- Adicionar albuns
insert into albuns values (1, 'Nenhuma Estrela', 'ALBUM', date '2025-04-15');
insert into albuns values (3, 'Subida Infinita', 'ALBUM', date '2024-03-15');
insert into albuns values (4, 'ASTROWORLD', 'ALBUM', date '2018-08-03');
insert into albuns values (1, 'Relógio', 'SINGLE', date '2025-04-16');
insert into albuns values (1, 'Nenhuma Estrela', 'EP', date '2025-04-08');
insert into albuns values (1, 'Próxima Parada', 'SINGLE', date '2025-03-11');
insert into albuns values (1, 'Nada Igual', 'SINGLE', date '2025-02-20');


-- Adicionar músicas
-- Terno Rei, Nada Igual SINGLE
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Nada Igual', 161000, 'Nada Igual', 'SINGLE', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Viver de Amor', 165000, 'Nada Igual', 'SINGLE', 1);

-- Terno Rei, Próxima Parada SINGLE
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Próxima Parada', 171000, 'Próxima Parada', 'SINGLE', 1);
-- ligar músicas a álbum
insert into pertence (idM, idA, titulo, tipo, faixa) values (1, 1, 'Próxima Parada', 'SINGLE', 2);
insert into pertence (idM, idA, titulo, tipo, faixa) values (2, 1, 'Próxima Parada', 'SINGLE', 3);

-- Terno Rei, Nenhuma Estrela EP
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Nenhuma Estrela', 190000, 'Nenhuma Estrela', 'EP', 1);
-- ligar músicas a álbum
insert into pertence (idM, idA, titulo, tipo, faixa) values (3, 1, 'Nenhuma Estrela', 'EP', 2);
insert into pertence (idM, idA, titulo, tipo, faixa) values (2, 1, 'Nenhuma Estrela', 'EP', 3);
insert into pertence (idM, idA, titulo, tipo, faixa) values (1, 1, 'Nenhuma Estrela', 'EP', 4);

-- Terno Rei, Nenhuma Estrela ALBUM
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Peito', 222000, 'Nenhuma Estrela', 'ALBUM', 1);
-- ligar músicas a álbum
insert into pertence (idM, idA, titulo, tipo, faixa) values (1, 1, 'Nenhuma Estrela', 'ALBUM', 2);
insert into pertence (idM, idA, titulo, tipo, faixa) values (4, 1, 'Nenhuma Estrela', 'ALBUM', 3);
insert into pertence (idM, idA, titulo, tipo, faixa) values (3, 1, 'Nenhuma Estrela', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Casa Vazia', 146000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Relógio', 164000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Pega', 179000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Programação Normal', 240000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, '32', 145000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Coração Partido', 191000, 'Nenhuma Estrela', 'ALBUM', 1);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Tempo', 232000, 'Nenhuma Estrela', 'ALBUM', 1);
-- ligar músicas a álbum
insert into pertence (idM, idA, titulo, tipo, faixa) values (2, 1, 'Nenhuma Estrela', 'ALBUM', 12);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (1, 'Acordo', 211000, 'Nenhuma Estrela', 'ALBUM', 1);

-- Terno Rei, Relógio SINGLE
insert into pertence (idM, idA, titulo, tipo, faixa) values (7, 1, 'Relógio', 'SINGLE', 1);

-- Ligar artistas a músicas, Paira e Lô Borges
insert into temArtista values (2, 7);
insert into temArtista values (5, 12);

-- Capitão Fausto, Subida Infinita ALBUM
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Muitos Mais Virão', 331000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Andar à Solta', 211000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Na Na Nada', 163000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Nunca Nada Muda', 241000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Fantasia', 22000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Nada de Mal', 219000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Há Sempre um Fardo', 180000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Cantiga Infinita', 220000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Nuvem Negra', 269000, 'Subida Infinita', 'ALBUM', 3);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (3, 'Subida Infinita', 68000, 'Subida Infinita', 'ALBUM', 3);

-- Travis Scott, ASTROWORLD ALBUM
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'STARGAZING', 270000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'CAROUSEL', 180000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'SICKO MODE', 312000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'R.I.P.SCREW', 185000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'STOP TRYING TO BE GOOD', 338000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'NO BYSTANDERS', 218000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'SKELETONS', 145000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'WAKE UP', 231000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (4, '5% TINT', 196000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'NC-17', 156000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'ASTROHUNDER', 142000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (4, 'YOSEMITE', 150000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (4, 'CANT SAY', 198000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'WHO? WHAT!', 176000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'BUTTERFLY EFFECT', 190000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG)
values (4, 'HOUSTONFORNICATION', 217000, 'ASTROWORLD', 'ALBUM', 4);
insert into vw_inserir_musica (idA, titulo, duracao, album, tipo, idG) 
values (4, 'COFFEE BEAN', 209000, 'ASTROWORLD', 'ALBUM', 4);


-- Inserir reproduções
-- USER 1
insert into reproducoes values (1, timestamp '2025-05-24 09:00:00', 1, 1, 'Nada Igual', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 09:02:00', 2, 1, 'Nada Igual', 'SINGLE');

insert into reproducoes values (1, timestamp '2025-05-24 09:04:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 09:06:00', 1, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 09:08:00', 2, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (1, timestamp '2025-05-24 09:10:00', 4, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (1, timestamp '2025-05-24 09:12:00', 3, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (1, timestamp '2025-05-24 09:14:00', 2, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (1, timestamp '2025-05-24 09:16:00', 1, 1, 'Nenhuma Estrela', 'EP');

-- USER 4
insert into reproducoes values (4, timestamp '2025-05-24 09:00:00', 1, 1, 'Nada Igual', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 09:02:00', 2, 1, 'Nada Igual', 'SINGLE');

insert into reproducoes values (4, timestamp '2025-05-24 09:04:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 09:06:00', 1, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 09:08:00', 2, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (4, timestamp '2025-05-24 09:10:00', 4, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (4, timestamp '2025-05-24 09:12:00', 3, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (4, timestamp '2025-05-24 09:14:00', 2, 1, 'Nenhuma Estrela', 'EP');
insert into reproducoes values (4, timestamp '2025-05-24 09:16:00', 1, 1, 'Nenhuma Estrela', 'EP');

-- USER 1
insert into reproducoes values (1, timestamp '2025-05-24 10:00:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:02:00', 1, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:04:00', 4, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:06:00', 3, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:08:00', 6, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:10:00', 7, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:12:00', 8, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:14:00', 9, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:16:00', 10, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:18:00', 11, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:20:00', 12, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:22:00', 2, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 10:24:00', 13, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 4
insert into reproducoes values (4, timestamp '2025-05-24 10:00:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:02:00', 1, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:04:00', 4, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:06:00', 3, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:08:00', 6, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:10:00', 7, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:12:00', 8, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:14:00', 9, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:16:00', 10, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:18:00', 11, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:20:00', 12, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:22:00', 2, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 10:24:00', 13, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 1
insert into reproducoes values (1, timestamp '2025-05-24 11:00:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 11:01:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 11:02:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 11:03:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (1, timestamp '2025-05-24 11:04:00', 3, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (1, timestamp '2025-05-24 11:05:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 11:06:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 11:07:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 11:08:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-24 11:09:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 2
insert into reproducoes values (2, timestamp '2025-05-24 11:00:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (2, timestamp '2025-05-24 11:01:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (2, timestamp '2025-05-24 11:02:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (2, timestamp '2025-05-24 11:03:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (2, timestamp '2025-05-24 11:04:00', 3, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (2, timestamp '2025-05-24 11:05:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-24 11:06:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-24 11:07:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-24 11:08:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-24 11:09:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 3
insert into reproducoes values (3, timestamp '2025-05-24 11:00:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (3, timestamp '2025-05-24 11:01:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (3, timestamp '2025-05-24 11:02:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (3, timestamp '2025-05-24 11:03:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (3, timestamp '2025-05-24 11:04:00', 3, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (3, timestamp '2025-05-24 11:05:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-24 11:06:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-24 11:07:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-24 11:08:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-24 11:09:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 4
insert into reproducoes values (4, timestamp '2025-05-24 11:00:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 11:01:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 11:02:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 11:03:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (4, timestamp '2025-05-24 11:04:00', 3, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (4, timestamp '2025-05-24 11:05:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 11:06:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 11:07:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 11:08:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-24 11:09:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 5
insert into reproducoes values (5, timestamp '2025-05-24 11:00:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (5, timestamp '2025-05-24 11:01:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (5, timestamp '2025-05-24 11:02:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (5, timestamp '2025-05-24 11:03:00', 3, 1, 'Próxima Parada', 'SINGLE');
insert into reproducoes values (5, timestamp '2025-05-24 11:04:00', 3, 1, 'Próxima Parada', 'SINGLE');

insert into reproducoes values (5, timestamp '2025-05-24 11:05:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-24 11:06:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-24 11:07:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-24 11:08:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-24 11:09:00', 5, 1, 'Nenhuma Estrela', 'ALBUM');

-- USER 1
insert into reproducoes values (1, timestamp '2025-05-25 18:00:00', 14, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:01:00', 15, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:02:00', 16, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:03:00', 17, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:04:00', 18, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:05:00', 19, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:06:00', 20, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:07:00', 21, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:08:00', 22, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-05-25 18:10:00', 23, 3, 'Subida Infinita', 'ALBUM');

-- USER 2
insert into reproducoes values (2, timestamp '2025-05-25 18:00:00', 14, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-25 18:04:00', 18, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-25 18:05:00', 19, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (2, timestamp '2025-05-25 18:08:00', 23, 3, 'Subida Infinita', 'ALBUM');

-- USER 3
insert into reproducoes values (3, timestamp '2025-05-25 18:00:00', 16, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-25 18:01:00', 17, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-25 18:04:00', 20, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (3, timestamp '2025-05-25 18:08:00', 22, 3, 'Subida Infinita', 'ALBUM');

-- USER 4
insert into reproducoes values (4, timestamp '2025-05-25 18:00:00', 14, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-25 18:01:00', 15, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-25 18:04:00', 18, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-25 18:05:00', 19, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-25 18:06:00', 20, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (4, timestamp '2025-05-25 18:07:00', 21, 3, 'Subida Infinita', 'ALBUM');

-- USER 5
insert into reproducoes values (5, timestamp '2025-05-25 18:01:00', 15, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-25 18:05:00', 19, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-25 18:06:00', 20, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-25 18:07:00', 21, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-25 18:08:00', 22, 3, 'Subida Infinita', 'ALBUM');
insert into reproducoes values (5, timestamp '2025-05-25 18:10:00', 23, 3, 'Subida Infinita', 'ALBUM');

-- USER 2 DEZEMBRO 2024
insert into reproducoes values (2, timestamp '2024-12-26 10:00:00', 24, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:02:00', 24, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:04:30', 25, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:08:50', 26, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:10:00', 27, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:12:30', 28, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:13:50', 29, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (2, timestamp '2024-12-26 10:16:50', 29, 4, 'ASTROWORLD', 'ALBUM');

-- USER 3 DEZEMBRO 2024
insert into reproducoes values (3, timestamp '2024-12-26 10:00:00', 26, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:02:00', 26, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:04:30', 27, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:08:50', 28, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:10:00', 28, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:12:30', 29, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:13:50', 31, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (3, timestamp '2024-12-26 10:16:50', 33, 4, 'ASTROWORLD', 'ALBUM');

-- USER 1 Último mês (04-2025)
insert into reproducoes values (1, timestamp '2025-04-26 10:00:00', 24, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:02:00', 25, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:04:30', 26, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:08:50', 27, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:10:00', 28, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:12:30', 29, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:13:50', 30, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:16:50', 31, 4, 'ASTROWORLD', 'ALBUM');
insert into reproducoes values (1, timestamp '2025-04-26 10:19:40', 31, 4, 'ASTROWORLD', 'ALBUM');
