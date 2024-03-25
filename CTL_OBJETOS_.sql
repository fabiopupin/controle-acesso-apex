set define off
spool CTL_OBJETOS_.log


create table CTL_APLICACAO
(
  id_aplicacao NUMBER not null,
  ds_aplicacao VARCHAR2(255) not null
)
;
alter table CTL_APLICACAO
  add constraint CTL_APLICACAO primary key (ID_APLICACAO);


create table CTL_EMPRESA
(
  id_empresa NUMBER not null,
  ds_empresa VARCHAR2(255) not null
)
;
alter table CTL_EMPRESA
  add constraint CTL_EMPRESA_PK primary key (ID_EMPRESA);


create table CTL_GRUPO_PAGINA
(
  id_grupo_pagina     NUMBER not null,
  ds_grupo_pagina     VARCHAR2(255) not null,
  id_grupo_pagina_pai NUMBER
)
;
alter table CTL_GRUPO_PAGINA
  add constraint CTL_PAGINA_GRUPO_PK primary key (ID_GRUPO_PAGINA);
alter table CTL_GRUPO_PAGINA
  add constraint CTL_PAGINA_GRUPO_FK_01 foreign key (ID_GRUPO_PAGINA_PAI)
  references CTL_GRUPO_PAGINA (ID_GRUPO_PAGINA);


create table CTL_LOG
(
  txt VARCHAR2(2000),
  seq NUMBER generated always as identity
)
;
alter table CTL_LOG
  add constraint CTL_LOG_PK primary key (SEQ);


create table CTL_PAGINA
(
  id_pagina            NUMBER not null,
  ds_pagina            VARCHAR2(255) not null,
  id_grupo_pagina      NUMBER not null,
  id_apex_app          VARCHAR2(255) not null,
  id_apex_page         VARCHAR2(255) not null,
  lst_page_clear_cache VARCHAR2(255),
  id_aplicacao         NUMBER
)
;
alter table CTL_PAGINA
  add constraint CTL_PAGINA_PK primary key (ID_PAGINA);
alter table CTL_PAGINA
  add constraint CTL_PAGINA_FK_01 foreign key (ID_GRUPO_PAGINA)
  references CTL_GRUPO_PAGINA (ID_GRUPO_PAGINA);
alter table CTL_PAGINA
  add constraint CTL_PAGINA_FK_02 foreign key (ID_APLICACAO)
  references CTL_APLICACAO (ID_APLICACAO);


create table CTL_USUARIO
(
  id_usuario       NUMBER not null,
  cd_usuario       VARCHAR2(255) not null,
  ds_email         VARCHAR2(255) not null,
  ds_nome_completo VARCHAR2(255) not null,
  vl_password      VARCHAR2(255) not null
)
;
alter table CTL_USUARIO
  add constraint CTL_USUARIO_PK primary key (ID_USUARIO);
alter table CTL_USUARIO
  add constraint CTL_USUARIO_UK_01 unique (CD_USUARIO, DS_EMAIL);
alter table CTL_USUARIO
  add constraint CTL_USUARIO_UK_02 unique (DS_EMAIL);


create table CTL_PERFIL
(
  id_perfil       NUMBER not null,
  ds_perfil       VARCHAR2(255) not null,
  id_empresa      NUMBER not null,
  id_usuario      NUMBER not null,
  id_pagina       NUMBER not null,
  lc_show_in_menu VARCHAR2(3) default 'SIM' not null,
  lc_ativo        VARCHAR2(3) default 'SIM'
)
;
alter table CTL_PERFIL
  add constraint CTL_PERFIL_PK primary key (ID_PERFIL);
alter table CTL_PERFIL
  add constraint CTL_PERFIL_UK_01 unique (ID_EMPRESA, ID_USUARIO, ID_PAGINA);
alter table CTL_PERFIL
  add constraint CTL_PERFIL_FK_01 foreign key (ID_EMPRESA)
  references CTL_EMPRESA (ID_EMPRESA);
alter table CTL_PERFIL
  add constraint CTL_PERFIL_FK_02 foreign key (ID_USUARIO)
  references CTL_USUARIO (ID_USUARIO);
alter table CTL_PERFIL
  add constraint CTL_PERFIL_FK_03 foreign key (ID_PAGINA)
  references CTL_PAGINA (ID_PAGINA);


create sequence CTL_APLICACAO_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_EMPRESA_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_GRUPO_PAGINA_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_LOG_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_PAGINA_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_PERFIL_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create sequence CTL_USUARIO_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 200
increment by 1
nocache;


create or replace package PCK_CTL as

  type r_ctl_menu is record(
    lvl        number,
    lbl        varchar2(255),
    lnk        varchar2(255),
    is_current varchar2(255),
    ico        varchar2(255),
    id_        varchar2(255),
    id_pai     varchar2(255),
    tag        varchar2(255)
    );

  type t_ctl_menu is table of r_ctl_menu;

  function get_ctl_menu (p_app_user   varchar2
                        ,p_empresa_id number
                        ,p_session    varchar2)
    return t_ctl_menu pipelined ;
  -----------------------------------------------------------------------------
  procedure log_ctl(p_txt varchar2) ;

  -----------------------------------------------------------------------------
  function criptografar(p_password varchar2) return varchar2 ;

  -----------------------------------------------------------------------------
  Function autenticacao (p_username Varchar2, p_password Varchar2) Return Boolean ;

  -----------------------------------------------------------------------------
  Function sentinela Return Boolean ;

  -----------------------------------------------------------------------------
  procedure invalid_session;

  -----------------------------------------------------------------------------
  procedure pos_logout;

  -----------------------------------------------------------------------------
  function verificar return boolean;

  -----------------------------------------------------------------------------
  procedure pre_auth;

  -----------------------------------------------------------------------------
  procedure pos_auth;

end;
/


create or replace package body PCK_CTL as

  function get_ctl_menu (p_app_user   varchar2
                        ,p_empresa_id number
                        ,p_session    varchar2)
    return t_ctl_menu pipelined is

    r pck_ctl.r_ctl_menu;

    -- Recupera a menu de forma hierarquico
    cursor c1 is
        Select Case When connect_by_isleaf = 1 Then 0
                    When Level = 1 Then 1
                    Else -1 End As sta
              ,Level as lvl
              ,lbl
              ,ico
              ,val
              ,tip
              ,lnk
              ,pai
              ,id_apex_page
        From
        (
                -- APLICACAO
                Select distinct d.ds_Aplicacao  as lbl
                       ,'fa-apex'        as ico
                       ,'APP:'||d.Id_Aplicacao  as val
                       ,d.ds_aplicacao          as tip
                       ,''                      as lnk
                       ,''                      as pai
                       ,''                      as id_apex_page
                    From ctl_empresa   a
                        ,ctl_usuario   u
                        ,ctl_perfil    b
                        ,ctl_pagina    c
                        ,ctl_aplicacao d
                Where
                    a.id_empresa        = p_empresa_id
                And lower(u.cd_usuario) = lower(p_app_user)
                And b.id_usuario        = u.id_usuario
                and b.id_empresa        = a.id_empresa
                And c.id_pagina         = b.id_pagina
                And d.id_aplicacao      = c.id_aplicacao
                --
                Union
                --
                -- GRUPO
                Select distinct d.ds_Grupo_Pagina                      as lbl
                       ,'fa-folder-o'                                  as ico
                       ,'GRP:'||c.id_aplicacao||':'||d.Id_Grupo_Pagina as val
                       ,d.ds_grupo_pagina                              as tip
                       ,''                                             as lnk
                       ,'APP:'||c.Id_Aplicacao                         as pai
                       ,''                                             as id_apex_page
                    From ctl_empresa      a
                        ,ctl_usuario      u
                        ,ctl_perfil       b
                        ,ctl_pagina       c
                        ,ctl_grupo_pagina d
                Where
                        a.id_empresa        = p_empresa_id
                    And lower(u.cd_usuario) = lower(p_APP_USER)
                    and b.id_empresa        = a.id_empresa
                    and b.id_usuario        = u.id_usuario
                    And c.id_pagina         = b.id_pagina
                    And d.Id_Grupo_Pagina   = c.Id_Grupo_Pagina
                --
                Union
                --
                -- PAGINA
                Select c.ds_Pagina          as lbl
                      ,'fa-file-o'          as ico
                      ,to_char(c.Id_Pagina) as val
                      ,c.ds_pagina          as tip
                      ,apex_util.prepare_url( 'f?p='||c.id_apex_app
                                              ||':'||c.id_apex_page
                                              ||':'||v('SESSION')
                                              ||'::'||c.lst_page_clear_cache ) as lnk
                      ,'GRP:'||c.id_aplicacao||':'||c.Id_Grupo_Pagina          as pai
                      ,c.id_apex_page                                          as id_apex_page
                 From
                         ctl_empresa a
                        ,ctl_usuario u
                        ,ctl_perfil  b
                        ,ctl_pagina  c
                Where
                        a.id_empresa        = p_empresa_id
                    And lower(u.cd_usuario) = lower(p_app_user)
                    And b.id_EMPRESA        = a.id_empresa
                    and b.id_usuario        = u.id_usuario
                    And c.id_pagina         = b.id_pagina
        )
        Connect By Prior val = pai
        Start With pai Is Null
        Order Siblings By lbl ;

  BEGIN

    r.lvl        := 1     ;
    r.lbl        := 'Home';
    r.lnk        := '#'   ;
    r.ico        := 'fa-home';
    r.id_        := ''       ;
    r.id_pai     := ''    ;
    r.tag        := ''    ;
    r.is_current := case v('APP_PAGE_ID') when '1' then 'YES' else 'NO' end ;

    pipe row(r);

    for r1 in c1 loop

      r.lvl        := r1.lvl;
      r.lbl        := r1.lbl;
      r.lnk        := r1.lnk;
      r.ico        := r1.ico;
      r.id_        := r1.val;
      r.id_pai     := r1.pai;
      r.tag        := ''    ;
      r.is_current := case v('APP_PAGE_ID') when r1.id_apex_page then 'YES' else 'NO' end ;

      pipe row(r);

    end loop;

  END get_ctl_menu;


  -----------------------------------------------------------------------------
  procedure log_ctl (p_txt varchar2) is

    pragma autonomous_transaction;
    --
    -- apex_application.G_REQUEST
    -- apex_application.G_BROWSER_LANGUAGE
    -- apex_application.G_HOME_LINK
    -- apex_application.G_LOGIN_URL
    -- apex_application.G_FLOW_SCHEMA_OWNER
    -- apex_application.G_SYSDATE
    --
    v_txt varchar2(999) :=       '['  ||to_char(CTL_LOG_SEQ.nextval, 'fm0000000000')
                           ||'] ['    ||to_char(sysdate,'yyyy-mm-dd hh24:mi:ss')
                           ||'] APP: '||apex_application.g_flow_id
                           ||' PAG: ' ||apex_application.g_flow_step_id
                           || ' - '   ||p_txt;

  begin
     insert into ctl_log (txt) values (v_txt);
    commit;
  end log_ctl;

  -----------------------------------------------------------------------------
  function criptografar(p_password varchar2) return varchar2 is
  begin
    return -- rawtohex(sys.dbms_crypto.hash(sys.utl_raw.cast_to_raw(p_password), sys.dbms_crypto.hash_sh512));
           p_password ;

  end criptografar;

  -----------------------------------------------------------------------------
  Function autenticacao (p_username Varchar2, p_password Varchar2) Return Boolean is

    v_user Varchar2(255) := upper(p_username);
    v_pwd  Varchar2(255);
    v_id   Number;

  begin

    log_ctl('[autenticacao] LOGON : ' || p_username || ' / ' ||  p_password );

--    if (lower(p_username) = 'root' and p_password = '123') then
--      return true;
--    end if;

    select a.vl_password
      into v_pwd
      from ctl_usuario a
     where lower(a.cd_usuario) = lower(p_username) ;

    if (v_pwd = /*p_password)*/ pck_ctl.criptografar(p_password) )
     then
      return true;
    end if;

    raise NO_DATA_FOUND;

  exception
    when NO_DATA_FOUND then
      log_ctl('[autenticacao]' || p_username || '/' || p_password ||  ' - ACESSO NEGADO');
      return false;

  end autenticacao;

  -----------------------------------------------------------------------------
  function tem_acesso (p_usuario varchar2, p_aplicacao varchar2, p_pagina varchar2) return boolean is
  begin
    log_ctl('[tem_acesso] v_app_corrente=' || p_aplicacao
           || '; v_pag_corrente=' || p_pagina
           || '; v_user=' || p_usuario
           || '; ALIAS=' || V('APP_ALIAS') );

    if lower(p_aplicacao) = 'app-ctl' and p_pagina = 1 then
      return true;
    end if;

    for r in ( select 1
                 from ctl_perfil p
                     ,ctl_usuario u
                     ,ctl_pagina pg
                where u.id_usuario = p.id_usuario
                  and lower(u.cd_usuario)   = lower(p_usuario)
                  and pg.id_pagina          = p.id_pagina
                  and lower(pg.id_apex_app) = lower(p_aplicacao) -- alias
                  and (pg.id_apex_page       = p_pagina or p_pagina in ( select a.column_value from apex_string.split(p_str => replace(pg.lst_page_clear_cache,' '), p_sep => ',' ) a ) )
                  and p.lc_ativo             = 'SIM'    )
    loop
      return true ;
    end loop ;
    return false ;
  end tem_acesso;

  -----------------------------------------------------------------------------
  Function sentinela Return Boolean Is
    v_user         varchar2(255) := APEX_APPLICATION.G_USER;
    v_app_corrente varchar2(255) := APEX_APPLICATION.G_FLOW_ID;
    v_pag_corrente varchar2(255) := APEX_APPLICATION.G_FLOW_STEP_ID;

  begin

    log_ctl('[sentinela] v_app_corrente=' || v_app_corrente
           || '; v_pag_corrente=' || v_pag_corrente
           || '; v_user=' || v_user
           || '; ALIAS=' || V('APP_ALIAS') );

    if APEX_CUSTOM_AUTH.CURRENT_PAGE_IS_PUBLIC then
      return true;
    end if;

    if v_user = 'nobody' then
      return false;
        apex_util.redirect_url( p_url => apex_page.get_url(p_application  => 'app-ctl',
                                                           p_page         => '9999',
                                                           p_session      => v('APP_SESSION') ) );
        apex_application.stop_apex_engine;

    end if;

    /*if not tem_acesso(p_usuario   => v_user
                     ,p_aplicacao => v('APP_ALIAS')  --v_app_corrente -- alias
                     ,p_pagina    => v_pag_corrente)
    then
      begin
        apex_util.redirect_url( p_url => apex_page.get_url(p_application  => 'app-ctl',
                                                           p_page         => 'error',
                                                           p_session      => v('APP_SESSION') ) );
        apex_application.stop_apex_engine;
      exception
        when OTHERS then
          null ;
      end ;
      return false ;
    end if;*/

    return true;

  end sentinela;

  -----------------------------------------------------------------------------
  procedure invalid_session is
  begin
    log_ctl('[invalid_session] ' || v('APP_USER'));
    /*  owa_util.status_line (
            nstatus       => 401,
            creason       => 'Basic Authentication required',
            bclose_header => false);
        htp.p('WWW-Authenticate: Basic realm="protected realm"');
        apex_application.stop_apex_engine; */
  end invalid_session;

  -----------------------------------------------------------------------------
  procedure pos_logout is
  begin
    log_ctl('[pos_logout] ' || v('APP_USER'));
  end pos_logout;

  -----------------------------------------------------------------------------
  function verificar return boolean is
  begin
    log_ctl('[verificar] ' || v('APP_USER'));
    /*if v('APP_PAGE_ID') = 8  then
      -- return false ;
      apex_util.redirect_url( p_url => apex_page.get_url(p_application      => 'app-ctl',
                                                         p_page             => 'error',
                                                         p_session          => v('APP_SESSION') ));
      apex_application.stop_apex_engine;
    end if;
    */
    return true;
  end verificar;

  -----------------------------------------------------------------------------
  procedure pre_auth is
  begin
    log_ctl('[pre_auth] ' || v('APP_USER'));
  end;

  -----------------------------------------------------------------------------
  procedure pos_auth is
  begin
    log_ctl('[pos_auth] ' || v('APP_USER'));
  end;

  -----------------------------------------------------------------------------
  function qry_ctl_menu return t_ctl_menu pipelined is
    rec pck_ctl.r_ctl_menu;
  begin

    return;

  end qry_ctl_menu;
end;
/


create or replace trigger "CTL_APLICACAO_TR_01"
  before insert on ctl_aplicacao
  for each row
declare
begin
  :New.Id_Aplicacao := CTL_APLICACAO_SEQ.Nextval;
end;
/


create or replace trigger "CTL_EMPRESA_TR_01"
  before insert on ctl_empresa
  for each row
declare
begin
  :New.Id_empresa := ctl_empresa_SEQ.Nextval;
end;
/


create or replace trigger "CTL_GRUPO_PAGINA_TR_01"
  before insert on ctl_grupo_pagina
  for each row
declare
begin
  :New.Id_grupo_pagina := ctl_grupo_pagina_SEQ.Nextval;
end;
/


create or replace trigger "CTL_PAGINA_TR_01"
  before insert on ctl_pagina
  for each row
declare
begin
  :New.Id_pagina := ctl_pagina_SEQ.Nextval;
end;
/


create or replace trigger "CTL_PERFIL_TR_01"
  before insert on ctl_perfil
  for each row
declare
begin
  :New.Id_perfil := ctl_perfil_SEQ.Nextval;
  :new.ds_perfil := nvl(:new.ds_perfil, :new.id_perfil);
  :new.lc_ativo  := nvl(:new.lc_ativo, 'SIM');
  :new.lc_show_in_menu := nvl(:new.lc_show_in_menu, 'SIM');
end;
/


create or replace trigger "CTL_USUARIO_TR_01"
  before insert or update on ctl_usuario
  for each row
declare
begin
  if inserting then
    :New.Id_usuario  := ctl_usuario_SEQ.Nextval;
  end if ;
  :new.vl_password := pck_ctl.criptografar(:new.vl_password) ;
end;
/


prompt Disabling triggers for CTL_APLICACAO...
alter table CTL_APLICACAO disable all triggers;
prompt Disabling triggers for CTL_EMPRESA...
alter table CTL_EMPRESA disable all triggers;
prompt Disabling triggers for CTL_GRUPO_PAGINA...
alter table CTL_GRUPO_PAGINA disable all triggers;
prompt Disabling triggers for CTL_LOG...
alter table CTL_LOG disable all triggers;
prompt Disabling triggers for CTL_PAGINA...
alter table CTL_PAGINA disable all triggers;
prompt Disabling triggers for CTL_USUARIO...
alter table CTL_USUARIO disable all triggers;
prompt Disabling triggers for CTL_PERFIL...
alter table CTL_PERFIL disable all triggers;
prompt Disabling foreign key constraints for CTL_GRUPO_PAGINA...
alter table CTL_GRUPO_PAGINA disable constraint CTL_PAGINA_GRUPO_FK_01;
prompt Disabling foreign key constraints for CTL_PAGINA...
alter table CTL_PAGINA disable constraint CTL_PAGINA_FK_01;
alter table CTL_PAGINA disable constraint CTL_PAGINA_FK_02;
prompt Disabling foreign key constraints for CTL_PERFIL...
alter table CTL_PERFIL disable constraint CTL_PERFIL_FK_01;
alter table CTL_PERFIL disable constraint CTL_PERFIL_FK_02;
alter table CTL_PERFIL disable constraint CTL_PERFIL_FK_03;
prompt Truncating CTL_PERFIL...
truncate table CTL_PERFIL;
prompt Truncating CTL_USUARIO...
truncate table CTL_USUARIO;
prompt Truncating CTL_PAGINA...
truncate table CTL_PAGINA;
prompt Truncating CTL_LOG...
truncate table CTL_LOG;
prompt Truncating CTL_GRUPO_PAGINA...
truncate table CTL_GRUPO_PAGINA;
prompt Truncating CTL_EMPRESA...
truncate table CTL_EMPRESA;
prompt Truncating CTL_APLICACAO...
truncate table CTL_APLICACAO;
prompt Loading CTL_APLICACAO...
insert into CTL_APLICACAO (id_aplicacao, ds_aplicacao)
values (1, 'CONTROLE DE ACESSO');
insert into CTL_APLICACAO (id_aplicacao, ds_aplicacao)
values (2, 'ESTOQUE');
insert into CTL_APLICACAO (id_aplicacao, ds_aplicacao)
values (3, 'VENDAS');
commit;
prompt 3 records loaded
prompt Loading CTL_EMPRESA...
insert into CTL_EMPRESA (id_empresa, ds_empresa)
values (1, 'ACME');
insert into CTL_EMPRESA (id_empresa, ds_empresa)
values (2, 'ORACLE');
commit;
prompt 2 records loaded
prompt Loading CTL_GRUPO_PAGINA...
insert into CTL_GRUPO_PAGINA (id_grupo_pagina, ds_grupo_pagina, id_grupo_pagina_pai)
values (1, 'CADASTROS', null);
insert into CTL_GRUPO_PAGINA (id_grupo_pagina, ds_grupo_pagina, id_grupo_pagina_pai)
values (2, 'CONSULTAS', null);
insert into CTL_GRUPO_PAGINA (id_grupo_pagina, ds_grupo_pagina, id_grupo_pagina_pai)
values (3, 'RELATORIOS', null);
commit;
prompt 3 records loaded
prompt Loading CTL_LOG...
prompt Table is empty
prompt Loading CTL_PAGINA...
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (1, 'Empresas', 1, 'APP-CTL', '4', '4,5', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (2, 'Aplicação', 1, 'APP-CTL', '2', '2,3', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (3, 'Grupo de Páginas', 1, 'APP-CTL', '6', '6,7', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (4, 'Páginas', 1, 'APP-CTL', '10', '10,11', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (5, 'Usuários', 1, 'APP-CTL', '12', '12,13', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (6, 'Usuários', 1, 'APP-CTL', '12', '12,13', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (7, 'Log do Controle de Acesso', 2, 'APP-CTL', '8', '8', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (8, 'Perfil', 1, 'APP-CTL', '14', '14,15', 1);
insert into CTL_PAGINA (id_pagina, ds_pagina, id_grupo_pagina, id_apex_app, id_apex_page, lst_page_clear_cache, id_aplicacao)
values (9, 'Kardex', 2, 'APP-ESTOQUE', '2', '2', 2);
commit;
prompt 7 records loaded
prompt Loading CTL_USUARIO...
insert into CTL_USUARIO (id_usuario, cd_usuario, ds_email, ds_nome_completo, vl_password)
values (1, 'fabio.pupin', 'fabio.pupin@email.com', 'Fabio Pupin', '123');
commit;
prompt 1 records loaded
prompt Loading CTL_PERFIL...
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (1, '1', 1, 1, 2, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (2, '2', 1, 1, 1, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (3, '3', 1, 1, 3, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (4, '4', 1, 1, 4, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (5, '5', 1, 1, 5, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (6, '6', 1, 1, 6, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (7, '7', 1, 1, 7, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (8, '8', 1, 1, 8, 'SIM', 'SIM');
insert into CTL_PERFIL (id_perfil, ds_perfil, id_empresa, id_usuario, id_pagina, lc_show_in_menu, lc_ativo)
values (9, '9', 2, 1, 7, 'SIM', 'SIM');
commit;
prompt 8 records loaded
prompt Enabling foreign key constraints for CTL_GRUPO_PAGINA...
alter table CTL_GRUPO_PAGINA enable constraint CTL_PAGINA_GRUPO_FK_01;
prompt Enabling foreign key constraints for CTL_PAGINA...
alter table CTL_PAGINA enable constraint CTL_PAGINA_FK_01;
alter table CTL_PAGINA enable constraint CTL_PAGINA_FK_02;
prompt Enabling foreign key constraints for CTL_PERFIL...
alter table CTL_PERFIL enable constraint CTL_PERFIL_FK_01;
alter table CTL_PERFIL enable constraint CTL_PERFIL_FK_02;
alter table CTL_PERFIL enable constraint CTL_PERFIL_FK_03;
prompt Enabling triggers for CTL_APLICACAO...
alter table CTL_APLICACAO enable all triggers;
prompt Enabling triggers for CTL_EMPRESA...
alter table CTL_EMPRESA enable all triggers;
prompt Enabling triggers for CTL_GRUPO_PAGINA...
alter table CTL_GRUPO_PAGINA enable all triggers;
prompt Enabling triggers for CTL_LOG...
alter table CTL_LOG enable all triggers;
prompt Enabling triggers for CTL_PAGINA...
alter table CTL_PAGINA enable all triggers;
prompt Enabling triggers for CTL_USUARIO...
alter table CTL_USUARIO enable all triggers;
prompt Enabling triggers for CTL_PERFIL...
alter table CTL_PERFIL enable all triggers;

spool off
set define on
