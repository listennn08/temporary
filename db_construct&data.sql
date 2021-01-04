-- admin password is 123456
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE admin;
ALTER ROLE admin WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md5b9d11b3be25f5a1a7dc8ca04cd310b28';
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'md5a3556571e93b0d20722ba62be61e8c2d';






--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4
-- Dumped by pg_dump version 12.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- PostgreSQL database dump complete
--

--
-- Database "newDB" dump
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4
-- Dumped by pg_dump version 12.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: newDB; Type: DATABASE; Schema: -; Owner: admin
--

CREATE DATABASE "newDB" WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'Chinese (Traditional)_Taiwan.utf8' LC_CTYPE = 'Chinese (Traditional)_Taiwan.utf8';


ALTER DATABASE "newDB" OWNER TO admin;

\connect "newDB"

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: checkmeetingroomexist(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.checkmeetingroomexist(_roomid character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  hasExisted boolean;
BEGIN
  SELECT
    COUNT(resource.id) > 0 INTO hasExisted
  FROM
    resource
  WHERE
    resource.id = _roomID;
  RETURN hasExisted;
END;
$$;


ALTER FUNCTION public.checkmeetingroomexist(_roomid character varying) OWNER TO postgres;

--
-- Name: FUNCTION checkmeetingroomexist(_roomid character varying); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.checkmeetingroomexist(_roomid character varying) IS '確認會議室是否存在';


--
-- Name: deletereservation(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.deletereservation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM reservation WHERE reservation.event_id = OLD.event_id;
    RETURN OLD;
END
$$;


ALTER FUNCTION public.deletereservation() OWNER TO postgres;

--
-- Name: freetime(character varying, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.freetime(_id character varying, _start date, _end date) RETURNS TABLE(_time time without time zone)
    LANGUAGE plpgsql
    AS $$
begin
return query
with timelist as (
  select
    generate_series(
        (_start + '08:00:00+08:00'::time)::timestamp
      , (_end + '20:00:00+08:00'::time)::timestamp
      , '15 minute'
    ) as time
)
, withScheTimeList as (
  select
      tl.time
    , sche._time
    from
      timelist  tl
  left join
    (
      select
        generate_series(
            (start_date + start_time)::timestamp
          , (end_date + end_time)::timestamp
          , '15 minute'
        ) as _time
        from
          schedule
      where resource_id = _id
    ) sche
    on
      tl.time = sche._time
)
, freetimelist as (
  (
    select
        withScheTimeList.time
      , withScheTimeList._time
      from
        withScheTimeList
    left join
      schedule sche
      on
        withScheTimeList._time = (sche.start_date + sche.start_time)::timestamp
    where
      withScheTimeList._time is null 
        and
        sche.start_time is null
  ) union all
    (
      select
          withScheTimeList.time
        , withScheTimeList._time
      from
        withScheTimeList
      left join
        schedule sche
        on
          withScheTimeList._time = (sche.start_date + sche.start_time)::timestamp
      where
        withScheTimeList._time is not null
          and 
          sche.start_time is not null
    )
)

select
  time::time
  from
    freetimelist
order by
    time;
end;
$$;


ALTER FUNCTION public.freetime(_id character varying, _start date, _end date) OWNER TO postgres;

--
-- Name: insertdata(character varying, character varying, date, date, time without time zone, time without time zone, character varying, character varying, character varying, character varying, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insertdata(_event_id character varying, _resource_id character varying, _start_date date, _end_date date, _start_time time without time zone, _end_time time without time zone, _title character varying, _empno character varying, _ext character varying, _email character varying DEFAULT NULL::character varying, INOUT _val text DEFAULT NULL::text)
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO 
		Schedule(
			  event_id
			, resource_id
			, start_date
			, end_date
			, start_time
			, end_time
		)
	VALUES
		(
			  _event_id
			, _resource_id
			, _start_date
			, _end_date
			, _start_time
			, _end_time
		);
	INSERT INTO
		Reservation(
			  event_id
			, title
			, empno
			, ext
			, email
		)
	VALUES
		(
			  _event_id
			, _title
			, _empno
			, _ext
			, _email
		);
	COMMIT;
	SELECT 
		  count(schedule.event_id) > 0
		, count(reservation.event_id) < 0
	FROM
		schedule
	LEFT JOIN
		reservation
	ON
		schedule.event_id = reservation.event_id
	WHERE 
		schedule.event_id = _event_id
	INTO _val;
END
$$;


ALTER PROCEDURE public.insertdata(_event_id character varying, _resource_id character varying, _start_date date, _end_date date, _start_time time without time zone, _end_time time without time zone, _title character varying, _empno character varying, _ext character varying, _email character varying, INOUT _val text) OWNER TO postgres;

--
-- Name: insertevent(character varying, character varying, character varying, integer, character varying, character varying, character varying, date, time with time zone, date, time with time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insertevent(id character varying, title character varying, empno character varying, ext integer, email character varying, author character varying, resource_id character varying, start_date date, start_time time with time zone, end_date date, end_time time with time zone)
    LANGUAGE sql
    AS $$
insert into reservation
values (id, title, empno, ext, email, author);
insert into schedule
values(id, resource_id, start_date, end_date, start_time, end_time - interval '1 second');
$$;


ALTER PROCEDURE public.insertevent(id character varying, title character varying, empno character varying, ext integer, email character varying, author character varying, resource_id character varying, start_date date, start_time time with time zone, end_date date, end_time time with time zone) OWNER TO postgres;

--
-- Name: login(character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.login(_id character varying, _pwd text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	success boolean;
begin
	select pwd = crypt(_pwd, users.pwd) INTO success from users where id = _id;
	return success;
end;
$$;


ALTER FUNCTION public.login(_id character varying, _pwd text) OWNER TO postgres;

--
-- Name: searchresourcefreetime(character varying, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.searchresourcefreetime(_id character varying, _startdate date, _enddate date) RETURNS TABLE(_time character varying, _resource character varying)
    LANGUAGE plpgsql
    AS $$
begin
return query
with timelist as (
	select
		  time
		, sche._time
	 	, sche.resource_id
	from
		generate_series(
			  (_startDate + '08:00:00+08:00'::time)::timestamp
			, (_endDate + '20:00:00+08:00'::time)::timestamp
			, '15 minute'
		) as time
  	left join
    (
      select
		 generate_series(
			  (start_date + start_time)::timestamp
			, (end_date + end_time)::timestamp
			, '15 minute'
		  ) as _time
		, schedule.resource_id
      from
		schedule
	  where
		schedule.resource_id = _id
    ) sche
    on
      time = sche._time
)
, freetimelist as (
	select 
		  timelist.time
		, timelist._time
		, sche.resource_id
		, sche.start_date
		, sche.start_time
		, sche.end_date
		, sche.end_time
	from
		timelist
 	left join
	(
		select
			  schedule.resource_id 
	   		, schedule.start_date
	   		, schedule.start_time
	   		, schedule.end_date
	   		, schedule.end_time
		from
			schedule 
	    where resource_id = _id
	) sche
    on timelist._time = (sche.start_date + sche.start_time)::timestamp
 	where
		timelist._time is null and sche.start_time is null
union all
	select
		  timelist.time
		, timelist._time
        , sche.resource_id
        , sche.start_date
        , sche.start_time
        , sche.end_date
        , sche.end_time
	from
		timelist
	left join
      (
		select 
			  schedule.resource_id 
			, schedule.start_date
			, schedule.start_time
	   		, schedule.end_date
	   		, schedule.end_time
	   	from
		  schedule 
	   	where
		  resource_id = _id
	  ) sche
	on timelist._time = (sche.start_date + sche.start_time)::timestamp
    where
      timelist._time is not null and  sche.start_time is not null
)

select
	  freetimelist.time::varchar as _time
	, freetimelist.resource_id as _resource
from
	freetimelist
order by freetimelist.time;
end;
$$;


ALTER FUNCTION public.searchresourcefreetime(_id character varying, _startdate date, _enddate date) OWNER TO postgres;

--
-- Name: searchspecifyconferenceroom(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.searchspecifyconferenceroom(_roomid character varying, _startdate character varying, _enddate character varying) RETURNS TABLE(_time timestamp without time zone, _resource character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY
  
WITH CTE  AS (
	SELECT
		generate_series(
			   (_startDate::Date + '08:00'::time)::timestamp
			,  (_endDate::Date + '20:00'::time)
			, '15 minute'
		) AS TIME
	)
, SCHE AS (
	SELECT
		  CTE.time as _time
		, s.resource_id as _resource
	From
		CTE
	LEFT JOIN (
		SELECT
			  generate_series(
				  (start_Date + start_Time)::timestamp
				, (end_Date + end_Time)
				, '15 minute'
			  ) AS TIME
			, *
        FROM
            Schedule
	  	WHERE
			resource_id = _roomID
      ) s
      ON
        CTE.time = s.time
 	  WHERE
 		resource_id IS NULL
      Order By
        CTE.time asc
  )

  SELECT
    *
  FROM
    SCHE;
END
$$;


ALTER FUNCTION public.searchspecifyconferenceroom(_roomid character varying, _startdate character varying, _enddate character varying) OWNER TO postgres;

--
-- Name: trigger_update_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trigger_update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	new.at_updated = current_timestamp;
	return new;
end;
$$;


ALTER FUNCTION public.trigger_update_timestamp() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: reservation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservation (
    event_id character varying(20) NOT NULL,
    title character varying(50) NOT NULL,
    empno character varying(10) NOT NULL,
    ext character varying(10),
    email character varying(50),
    author character varying(10) NOT NULL,
    at_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    at_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.reservation OWNER TO postgres;

--
-- Name: resource; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resource (
    id character varying(15) NOT NULL,
    name character varying(50) NOT NULL,
    type character varying(20) NOT NULL,
    capacity integer,
    "position" character varying(20) NOT NULL,
    facility character varying(200),
    advance integer,
    description character varying(200),
    enable boolean,
    at_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    at_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.resource OWNER TO postgres;

--
-- Name: COLUMN resource.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.resource.id IS 'STDF: 生達一廠
	 STDS: 生達二廠
	 SYNT: 生展二廠
	 SYNS: 生展南科';


--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schedule (
    event_id character varying(20) NOT NULL,
    resource_id character varying(15) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    start_time time with time zone NOT NULL,
    end_time time with time zone NOT NULL,
    at_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    at_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.schedule OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id character varying(10) NOT NULL,
    name character varying(10) NOT NULL,
    pwd text NOT NULL,
    authority character varying(10) NOT NULL,
    token text,
    at_created timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    at_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Data for Name: reservation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reservation (event_id, title, empno, ext, email, author, at_created, at_updated) FROM stdin;
q069ljl7f	TEST	107073	8702	\N	107073	2020-11-20 16:29:54.587412+08	2020-11-20 16:29:54.587412+08
hwq58g1xx	會議	107073	8702	\N	107073	2021-01-04 09:50:38.852274+08	2021-01-04 09:50:38.852274+08
tpwma7yl6	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwma9jgp	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwma9hub	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwma95xv	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwma9l1d	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwma9saw	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaaeb1	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaa0e9	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaats4	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaafod	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmabbtu	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmab9cj	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmabds1	109年年度體檢超音波檢查	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaboe0	轉訓	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmabial	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmacmy7	轉訓	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmac9w2	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmacyqj	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaczxu	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmachtz	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmadmhn	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmad4du	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmadt18	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmadogo	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaddst	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaeso9	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaeuzc	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaeffc	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmae2dc	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaegyj	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaefs4	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmafucu	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmafbmz	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmafp44	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaf41z	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmafgiq	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmafiji	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaghsi	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmagzga	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmagp72	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmagsof	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmagvdd	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahvsi	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahfnx	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahppg	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahpid	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaheo9	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahu6u	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmahpp9	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaigg1	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaikdg	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmai5fs	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmai0zz	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaisgu	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmai2rs	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajhqn	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajfud	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajk2i	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajato	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajsuv	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmajsb5	福利會會議	81092	6276		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmakboh	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmakgc9	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmakeae	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmak2gw	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmakd9i	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmalior	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmalhmx	職安類證照複訓	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmal169	分析讀書會	103089	0		103089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmall9u	分析聯席會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmalgds	製劑讀書會	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmamgq3	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmamop9	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmamy73	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmamn3u	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmam5e1	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmamc3x	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmami0c	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmannu3	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmanoyh	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmanpqk	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmanod7	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmandlp	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmanvbj	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaoksm	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmao88v	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaonxk	9月份讀書會	107013	5285		107013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmao2to	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaoxtr	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaodbr	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmap9qt	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmap1o1	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmapnoy	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaps73	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmapey8	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmapfmm	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmap1m1	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaqoux	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaq3h6	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaqqoe	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaqke4	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaq1za	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaqtr1	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmardig	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmatcb2	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmatch5	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmat32g	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmatmpz	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmattq4	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmau1h1	產銷會議	107042	5208		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmau3wa	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmauuc0	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaubwq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmau2ol	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmavw6a	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmavfy8	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmavef6	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmavtq2	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmav72p	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmavinz	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmawrds	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmawvf8	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmawygk	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmawz3v	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmawm82	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaw5cp	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmax82z	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaxzsb	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaxi1g	11月份讀書會	107013	5285		107013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaxdvq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmax2hq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmax5w2	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmayi2f	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaykq0	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmayq23	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmay8e9	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmay5y3	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmayo4t	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmayu23	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazcbk	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazws1	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazz96	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazdsq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazklq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmaz1cn	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmazhtv	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb0glh	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb0w46	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb018z	企訓會議	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb000c	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb0zbf	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb0efl	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb18ea	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1ubp	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1ybc	佳格	S108163	8622		S108163	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1z5o	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1x5u	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1jd7	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb1tar	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2sxm	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2qz3	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2o8e	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2liz	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2zkc	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb2483	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb3ft2	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb3cxz	會議	S106136	8371		S106136	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb38xm	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb315d	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb3xgf	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb3m3q	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb3dld	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb4r1h	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb421j	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb489j	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb4m35	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb4bif	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb47id	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb428v	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb5uo3	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb5a66	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb5how	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb50du	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb5fl3	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb5alx	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb6r1i	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb6ip0	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb6v7y	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb6xo4	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb6qek	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb675w	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb797d	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7pae	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7o0b	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7yq8	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7z93	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7wzl	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb7idm	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb82nd	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb8ob1	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb8co4	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb8703	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb8a8e	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb8t77	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb9nyu	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb92uk	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb9y6d	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb9932	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmb9j8u	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbafq3	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbasln	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbajz0	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbaw53	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbard7	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbap5n	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbaioa	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbbe3s	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbbpix	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbb84s	職安室週會	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbbhxq	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbb87i	504會議室冷氣整修	81092	6137		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbbior	五課產能會議	107043	5200		107043	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbcxgh	外部稽核	106089	6048		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbcnf8	守衛會議	81092	6137		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbdc4x	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbd477	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbd7h4	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbdf7y	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbed9q	meeting	84075	5516		84075	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbef4x	守衛會議	81092	6137		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmber7z	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbeqai	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbeh2a	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5omm	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbf76n	液劑產品微生物防阻專案會議	107071	6008		107071	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbgyhq	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbgmwf	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbg6gm	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbgtwa	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbhwhd	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbh7fa	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbhafd	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbhr6n	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbha9z	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbhgzz	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbixe6	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbipat	讀書會	95072	5257		95072	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbiiab	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbir1y	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbi94e	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbixj9	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbj4i7	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbj861	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbjprj	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbjnys	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbjfap	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbjemo	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbk7cf	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbkiqa	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbkmlg	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbk8zs	讀書會	95072	5257		95072	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbkf1g	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbkkyt	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbluw8	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbltmf	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbl8tb	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbly7a	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmblqmq	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbltdb	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbmi7p	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbm8ov	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbmw52	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbmitb	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbm1jb	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbmkhr	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbm8we	讀書會	95072	5257		95072	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbnfzy	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbnai3	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbnh49	品保部定期幹部會議	98022	0		98022	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbnsno	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbn8z6	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbn6ey	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbordo	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmboshb	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmboylb	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmboo4j	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmboe2y	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbo3oc	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbpwbc	固定會議	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbpdle	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbp3de	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbqdsv	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbqq99	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbq4uj	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbq9f5	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbqwvc	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbq0md	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbqnfr	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbrxq8	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbriex	生管課會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbrdmv	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbr2a7	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbrlmz	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbsetd	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbs6wb	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbsg44	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbsh4d	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtaw6	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtv1f	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtwo3	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbt412	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtury	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtug1	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbtc6y	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbuzsf	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbubf0	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbuzsn	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbunjm	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbuj0x	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbui0s	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvid6	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvmw8	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvyci	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvk0i	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvf0y	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvmsu	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbvbop	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwd51	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwqf7	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwwov	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwmbf	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwzmf	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwi3z	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbwaff	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbxsws	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbxah9	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbxkk6	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbx5yd	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbxup7	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbx31x	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbx6bm	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbyi4h	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbyekg	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbyuzw	生產體系會議	107042	0		107042	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbydzi	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbywrb	GMP會議用	101062	5511		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbykex	電商會議	109028	6022		109028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbya78	meeting	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzzzn	不穩定品項會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzcxe	會議	108031	6302		108031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzteo	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzot5	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzolz	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzndw	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmbzpc4	液劑產品微生物防阻專案會議	107071	6008		107071	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc00yf	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc08ze	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc0dek	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc0oz0	佳格查廠	S108163	8622		S108163	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc0r1a	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc03bs	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc2cv0	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc39ap	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc3n9b	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc3jjm	液劑產品微生物防阻專案會議	107071	6008		107071	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc36fm	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc4k5j	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc40o8	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc45dp	借椅子	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc4c0x	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc4aek	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc406d	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc50uw	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc5ggg	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc51nn	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc58zr	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc5jko	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc5a3p	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc5hpa	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc6ta4	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc6z0u	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc6zuy	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc6o10	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc62yh	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc6ya1	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc7g8r	10月份生安會	107013	5285		107013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc7q4d	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc7mf4	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc7hbq	薪酬會議	107039	6115		107039	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc87dm	借椅子	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc93aj	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc96cl	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc9vv9	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmc9cv8	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcajr3	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcados	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcav11	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcasdp	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcayko	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcauo3	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcb1lx	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcb4l2	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcbzrs	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcbrap	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcbd4j	借椅子	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmccd3i	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmccncs	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcc0kt	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmccsii	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcc9im	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmccgmb	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcd8w8	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcdfbk	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcdofy	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcdpt1	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcd51x	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcd2ny	製程讀書會	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcetdz	生產部幹部會議	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmceh3e	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcedae	針劑小組會議	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmceacu	12月份生安會	107013	5285		107013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcex0u	Injection meeting	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmceq3c	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	0		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcf67l	\r\n針劑定期跨部門討論會議(生產，QC，工程，QA)\r\n	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcf9s4	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcfi36	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcfvr3	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcf05l	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcf9ok	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcg664	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcg5er	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcg514	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcg9ey	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcgslp	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcgp2q	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmchzpr	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmch62s	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmchuwh	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmchzvi	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmch1si	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmchvvb	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcift9	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmci8bb	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmci16s	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcihw6	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcii8w	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmciecq	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcjdz1	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcjejn	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcjvio	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcju69	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcjk53	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcj9lp	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmckaxg	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmck85w	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmck7p8	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmckpy9	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmck0cb	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmckzrs	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmclw56	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmclyq2	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcli6z	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcl0s5	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmclhy0	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcmatb	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcmg1t	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcmo7v	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcm4ga	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcmi2y	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcmtns	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcnsjz	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcnhxh	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcn3h9	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcn009	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcnjx1	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcn9c5	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcoqaj	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcox1b	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcolap	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcop1v	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcotn9	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcp8wp	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcpbll	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcp3ff	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcpxps	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcpxy2	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcpx7k	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcqxdp	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcqe6h	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcq2gi	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcqlke	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcqx11	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcqt4m	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcre54	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcracq	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcrmvs	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcrq2t	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcrdgu	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcr2s5	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcrnd8	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcspq1	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5idn	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcsx8v	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcs39q	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcshat	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcs8pe	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcsqv5	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcsv1p	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmctl91	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmctzzy	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmctbeo	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmct7id	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmct7md	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmctts9	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmctjls	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcuq59	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcurac	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcu7a2	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcu5ni	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcu7l6	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcut8s	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcub85	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcv5cx	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcvlwg	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcvcnt	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcvr41	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcvf6d	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcvd1b	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcv043	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcw0m0	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcwr2r	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcwb98	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcwmr8	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcw0iv	針劑定期跨部門討論會議(生產，QC，工程，QA)	85025	5032		85025	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcwsul	外部稽核	106089	6048		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcx5dr	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcxfge	外部稽核	106089	6048		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcxufx	外部稽核	106089	6048		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcxwo9	外部稽核	106089	608		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcx6q8	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcxbta	外部稽核	106089	6048		106089	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcxxh3	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcybtm	讀書會	107056	6107		107056	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcyzm7	部門領料教育訓練	103090	5221		103090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcyw1e	硬體專案	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcy9ra	董監課程	76084	6105		76084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcy4m6	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcyg5i	硬體專案	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmczulg	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmczvsl	讀書會	107056	6107		107056	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmczxm9	EGO	73009	6030		73009	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcz3im	EGO	73009	6030		73009	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmczvau	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmczlu1	生產部讀書會	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmcz15f	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0eei	品管會議	S107068	7913		S107068	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0frd	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0t8z	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0zuk	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0qo9	QA讀書會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd00k2	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd0wto	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd1ezl	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd1id4	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd19rg	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd1ndb	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd1hc1	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd17cv	生產部讀書會	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd1avz	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2bwd	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2nd9	董事會	107039	6115		107039	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2ofw	QA讀書會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2ti7	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd27zq	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2q4z	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd2fja	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd3yln	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd392c	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd3598	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd380h	生產部讀書會	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd3yia	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd3a82	QA讀書會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd365d	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd4ix6	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd4w65	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd4gsd	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd40e6	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd452t	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd4eec	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd4m9n	第一種壓力容器主管證照複訓	108026	6054		108026	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5pd1	生產部讀書會	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5mio	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5py4	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5oh5	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd5mmg	GMP會議	101062	5513		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6i40	會議	96020	6306		96020	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6cma	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6e83	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6br5	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6n26	meeting	82128	6201		82128	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6ta3	月初會	108031	6302		108031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd6in0	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd72e5	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd735c	董監事課程	76084	6105		76084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd7tv2	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd7loh	食策會	S108163	8622		S108163	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd7i6g	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd73s7	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd7y8g	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8r8y	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8az2	研究會議	S107067	7913		S107067	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8veo	生達e大校務會議	82077	6057		82077	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8rfe	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd84wm	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8g2n	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd8x6o	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd9zgs	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd943o	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd9sge	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd9aza	會議	96020	6306		96020	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd9tis	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd90bz	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmd96k4	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdarjf	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdabeu	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmda2gt	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdaz19	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdapsy	研究會議	S107067	7913		S107067	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdaypn	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmda7ik	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdbxdw	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdbvz3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdbc1y	生展董事會	S106136	8371		S106136	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdb7p5	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdb0sq	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdbffw	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdbh9h	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdcxnu	會議	96020	6306		96020	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdc2wl	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdceya	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdcxp1	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdcxbv	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdcnjs	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdcwx6	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmddibz	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmddo3a	生達e大校務會議	82077	6057		82077	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmddifm	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdddhv	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmddrju	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmddb9m	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeo4b	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeqdu	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeeso	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeayb	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdemb7	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeayg	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdeutz	會議	96020	6306		96020	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdfuue	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdfqrn	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdf7y1	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdfbyg	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdfkwz	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdf6j3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdfm5t	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdg5y3	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdg4au	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdgy1v	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdgmxo	生達e大校務會議	82077	6057		82077	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdg26x	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdg1s6	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdgldk	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdhs8c	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdhqlv	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdh7py	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdh014	2020年GMP會議納入生產體系會議9:30開始	101062	0		101062	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdhppd	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdihho	主管會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdi5aj	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdi768	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdim4c	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdj1ld	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdj2ia	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdjrxe	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdjbnp	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdjvoj	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdjsxp	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdkc2w	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdkwbo	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdlj31	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdl9ix	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdlebm	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdloj7	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdlksb	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdm3dw	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdmuxc	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdm9b1	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdna7m	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdn1a7	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdoxtz	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdof5o	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdoyzp	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdorxl	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdomwj	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdoy5w	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdpzum	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdppmc	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdpf1p	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdp81q	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdppli	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqbf1	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqrba	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqie3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqq5w	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqttr	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdq796	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdqtxe	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdr374	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdr7q3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdr8m1	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdsn3h	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdsqer	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdsbov	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdsjxt	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmds8dd	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdsb3u	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmds6ig	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdt5mq	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdtgqo	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdt4fp	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdtyuu	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdtod7	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdt23c	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdtwsq	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdugv3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdupko	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdubbn	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdus0p	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdum6j	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdu2dy	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdu34i	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdvtdz	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdvvob	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdv7c4	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdvh2l	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdvyn5	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdwvb8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdwe0e	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdxsp0	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdx8aw	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdxxc8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdxgom	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdxhjp	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdx8k1	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdxwy3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdy7rl	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdyr34	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdytlt	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdyhrx	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdy6ls	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdyt6v	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzem1	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzru8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzbdq	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzgd6	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzvme	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzlv4	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmdzx3d	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0791	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0etf	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0tx6	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0tyx	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0zjx	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0ev8	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme04az	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme0rby	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme18t1	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme1gua	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme1fch	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme1wd8	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme177g	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme2smd	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme29hn	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme21nh	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme2wp5	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme2ntk	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme2vws	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme2gmp	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme3s5n	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme3mdv	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme3kut	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme3939	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme35ox	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme33qx	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme3jwr	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme4sum	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme4ajn	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme4mlb	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme4ra5	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme48y7	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme48cu	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme4slp	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme514o	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme5rbg	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme5r19	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme5myu	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme5huy	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme5upm	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme624l	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme6luv	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme69be	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme60yl	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme6k8s	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme64pw	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme6swe	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme7oy1	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme7ug8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme7nvd	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme7i4w	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme70zw	QA早會	99105	5506		99105	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme7zd3	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme89e8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme8vh0	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme872z	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme8t1b	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme8ot8	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme8ay6	QA早會	75028	5504		75028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme9isi	面談-莊佳樟	104013	0		104013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme9a6e	國二內部討論	106060	6275		106060	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme9mau	面談-曾仲毅	104013	0		104013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme90u7	TC	106043	6272		106043	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme972q	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwme9d2c	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmea245	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeatio	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeay4p	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmea27k	例行會議	72008	6018		72008	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeat0d	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeak5g	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeamsi	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmebh0j	轉訓	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmebm1v	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeblsx	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmebbb9	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmebh1h	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeb8wz	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeb3uh	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmecpdm	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmecl9b	不穩定品項會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmec019	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmechby	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmecil8	例行會議	72008	6018		72008	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmecbi2	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmec47s	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmec8sj	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmed7an	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmedw1g	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmedj07	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmednet	採購課會	88055	5212		88055	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmed9m0	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmedb6p	不穩定品項會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmedm2c	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeekgu	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeeu47	例行會議	72008	6018		72008	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeehcx	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmee8s2	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmee13z	不穩定品項會議	100021	5724		100021	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeeai5	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeee3t	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeek9e	例行會議	72008	6018		72008	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmefiqd	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmefk7c	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmefqdw	會議	84048	6108		84048	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeffk0	Meeting	107072	6278		107072	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmefamn	【分析研究員】陳怡蓉	104013	0		104013	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmefsn1	2020-09-08報到名單及注意事項	73007	0		73007	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmef29j	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmegngm	2020-09-14報到名單及注意事項	73007	0		73007	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmega06	新人報到	73007	6060		73007	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmegs35	2020-09-16報到名單及注意事項	73007	0		73007	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmegy0l	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmegczt	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeg1qo	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeg4t1	會計師查核	101096	6106		101096	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehceu	會計師查核	101096	6106		101096	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeheak	會計師查核	101096	6106		101096	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehksu	會計師查核	101096	6106		101096	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehskc	會計師查核	101096	6106		101096	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehds7	管理部例行會議	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehz9y	開會	S106130	0		S106130	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehyki	兩廠視訊	S103011	8311		S103011	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmehow9	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmei9ji	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeivl7	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeiuyu	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeihn4	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeiu3v	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmei7if	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeiqy6	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeiqcn	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmej19r	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmejrd0	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmejrfo	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmejd8f	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmejzhp	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmej2pj	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekpp3	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekdsc	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekjd4	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekm9a	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekly1	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmekvf7	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeluzy	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmelbjh	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmel68s	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmelu0s	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmel4bo	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmelf8e	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmemp4d	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmem1am	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmemnin	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmemt67	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmemaxs	週會	S9215	7611		S9215	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmemgto	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmen9ph	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeni9q	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmen2ae	109年會計師查帳-稅抽	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmenjjn	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeocql	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeoezz	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeqcrl	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeq1s8	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeq6av	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeq6x6	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeq1mf	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeqwxr	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmerh3p	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmerkdw	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmer1lw	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmerfe0	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmerou9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmere2q	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmer6a9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesqqa	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesdrk	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesw81	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmescdo	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesa0r	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesuzt	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmesiu2	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmetv0h	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmetdwb	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmetmj9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmetuxz	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeuk1l	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeuzy3	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeuofk	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeul0c	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeu53r	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevsk0	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevl47	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevpk6	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevj48	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevr0j	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmevom2	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmewy2h	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmew7g5	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmewsxs	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmewtp9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmew4ul	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmewyem	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmewfyd	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeww6n	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmex9b9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmexqfr	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmexuww	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmex3j9	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmexema	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmex9rh	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmex8q0	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeybcz	建廠會議	S105127	8315		S105127	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeys5r	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeyca4	康倍新纖美妍酵素飲.諾寶保衛IGY益菌.生達谷樂他美顆粒.健行力錠.律動配方產銷	S103027	0		S103027	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmey2cb	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeykhx	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmeyku7	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmey59s	佳得-教育訓練介紹	s9823	8349		s9823	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf0unp	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf0jxp	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf1nyl	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf12tb	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf1t62	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf156u	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf1940	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf1udw	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf1rel	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf28ky	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf21td	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf259r	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf26jk	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf2kn3	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf27l6	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf39tb	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf3haq	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf3k9k	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf3ku5	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf3hi7	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf35et	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf4lw3	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf418m	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf4izy	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf4ag6	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf44km	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf4hex	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf4max	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf5ax8	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf5kin	排程會議	S102018	7710		S102018	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf5d34	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf503z	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf5sk9	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf5zuh	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf6xj9	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf6jxb	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf6v33	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf6i67	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf653i	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf7cak	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf71x4	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf7nvd	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf7ic0	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf7uxs	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf8s6d	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf86q7	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf8l1e	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf8q4i	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf8zau	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf956a	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf9rkd	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf931h	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf9zkk	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf99aw	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf9bnu	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmf9o8a	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfa56p	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfah72	會議	S109084	0		S109084	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfanr8	臨場服務	S106176	8692		S106176	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfa9lv	109年會計師查帳-稅抽	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfa3gj	109年會計師查帳-稅抽	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfa36q	109年會計師查帳-稅抽	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfb836	109年會計師查帳-稅抽	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfbl48	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfb7le	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfcpoy	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfc7xi	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfcf3z	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfd3xj	109Q3會計師查帳	S107097	8375		S107097	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfd515	臨場服務	S106176	8692		S106176	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfdep6	新進人員報到	S109043	8347		S109043	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfdba9	福利會-好市多辦卡活動	81092	6137		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfdcgz	新人報到	S109043	8347		S109043	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfdz7v	民眾說明會	106053	6142		106053	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfd7vr	新人報到	S109043	8347		S109043	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfedvm	福利會會議	81092	6137		81092	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfeyar	佳格查廠	S108163	8622		S108163	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfeu1i	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfey77	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfe9ft	廠務部會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmffi9f	品管部讀書會	104090	5273		104090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmffw75	品管部讀書會	104090	0		104090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmffo59	GMP教育訓練	104028	5742		104028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfg4hy	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfgagc	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfg07w	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfhdnd	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfhqvm	QC Base SOP Training 每月一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfih8b	QC Base SOP Training 微生物	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfiwgh	生產部教育訓練	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfi1kh	廠務部會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfinl9	品管部讀書會	104090	5273		104090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfj3o7	GMP教育訓練	104028	5742		104028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfjxjt	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfj3dp	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfkqrd	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfk57t	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfk5t7	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmflfmr	廠務部會	104029	5219		104029	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmflmcw	品管部讀書會	104090	5273		104090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfldv6	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfmg4l	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfnxh7	月初會	103065	6222		103065	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfnter	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfny3g	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfnijh	品管部讀書會	104090	5273		104090	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfoec3	生產部教育訓練	77069	5301		77069	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfobr9	GMP教育訓練	104028	5742		104028	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfohh7	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfoowr	QC Base SOP Training 每月一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfoeb0	幹部會議	107031	6016		107031	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfov7o	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfo8mv	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfp8rb	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfp586	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfrcl3	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfrsqr	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfr9vj	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfrx8d	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfs5y9	QC Base SOP Training	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfs2a3	QC Base SOP Training 微生物	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfsr69	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfs9xr	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
tpwmfsqhd	QC Base SOP Training 每月 一次	76098	5276		76098	2020-11-12 16:51:21.981084+08	2020-11-12 16:51:21.981084+08
\.


--
-- Data for Name: resource; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.resource (id, name, type, capacity, "position", facility, advance, description, enable, at_created, at_updated) FROM stdin;
STDS-R506	506會議室	會議室	22	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-20 15:42:17.201908+08
STDS-R401	401會議室	會議室	46	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-17 17:00:45.904528+08
STDS-R507	507會議室	會議室	12	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	接待外賓優先使用	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RO01	戶外會議區1	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RO02	戶外會議區2	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RO03	戶外會議區3	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R502	502會議室	會議室	10	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-17 17:30:17.467639+08
STDS-RO04	戶外會議區4	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RO05	戶外會議區5	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RO06	戶外會議區6	會議室	8	新營二廠	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
SYNS-RO07	戶外會議區7	會議室	8	生展南科	\N	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-17 17:30:57.304412+08
STDS-R501	501會議室	會議室	10	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R503	503會議室	會議室	6	新營二廠	白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R504	504會議室	會議室	14	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R505	505會議室	會議室	14	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
jn7ndjpep	外接喇叭-3	資源	\N	資訊C組	\N	\N	附件：USB線材一條+3.5音源線(請記得一併取用歸還)	t	2020-12-11 10:20:09.698073+08	2020-12-11 10:22:17.706923+08
jn7ndk92x	筆電-1	資源	\N	資訊C組	\N	\N	品牌：ASUS{n}型號：N82JG{n}附件：變壓器(請記得一併取用歸還)	t	2020-12-11 10:20:09.743709+08	2020-12-11 10:22:17.706923+08
jn7ndkpu9	筆電	資源	\N	生展新營管理部	\N	\N	品牌：ASUS 型號：X450V 附件：變壓器、滑鼠(請記得一併取用歸還)	t	2020-12-11 10:20:09.741723+08	2020-12-11 10:22:17.706923+08
STDS-R508	508會議室	會議室	30	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-RLRN	e-Learning錄音室	會議室	1	新營二廠	\N	\N	錄音 / 攝影 專用	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDF-R001	會議室	會議室	30	新營一廠	\N	\N	一廠會議室	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
SYNS-R101	生展南科101	會議室	12	生展南科	投影機、網路	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
SYNS-R102	生展南科102	會議室	16	生展南科	電腦、投影機、網路	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
SYNS-R401	生展南科401	會議室	10	生展南科	網路	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R001	第一會議室-警衛室旁	會議室	12	新營二廠	投影機、布幕、電話、白板、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R002	第二會議室-餐廳	會議室	250	新營二廠	白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R003	第三會議室-製劑大樓B1	會議室	160	新營二廠	電腦、液晶投影機、DVD播放器、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R000	貴賓室	會議室	32	新營二廠	電腦、液晶投影機、DVD播放器、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
jn7ndkn8f	筆電-2	資源	\N	資訊C組	\N	\N	品牌：ASUS  型號：U31J  附件：變壓器 ( 請記得一併取用歸還 )	t	2020-12-11 10:20:09.748421+08	2020-12-11 10:22:17.706923+08
jn7ndka30	筆電-3	資源	\N	資訊C組	\N	\N	品牌：ASUS{n}型號：U20A{n}附件：變壓器(請記得一併取用歸還)	t	2020-12-11 10:20:09.770289+08	2020-12-11 10:22:17.706923+08
jn7ndk8wd	筆電NO.2	資源	\N	管理部	\N	\N	品牌：TOSHIBA(Vista){n}附件：變壓器、滑鼠(請記得一併取用歸還)	t	2020-12-11 10:20:09.774146+08	2020-12-11 10:22:17.706923+08
jn7ndkdh5	視訊會議設備	資源	\N	新營二廠	\N	\N	放置在501會議室，使用完請歸回原位	t	2020-12-11 10:20:09.77883+08	2020-12-11 10:22:17.706923+08
jn7ndkwtn	網路攝影機	資源	\N	生展新營管理部	\N	\N	品牌：Logitech 型號：C310 USB連接、解析度720P	t	2020-12-11 10:20:09.798315+08	2020-12-11 10:22:17.706923+08
jn6q9wths	APPLE-1	資源	\N	資訊C組	\N	\N	APPLE系列  30PIN male  轉  D-SUB(VGA) female{n}iPhone 4 / 4S 適用{n}iPad / iPad 2 / New iPad 適用{n}可一併借用D-SUB(VGA) double male來轉接	t	2020-12-11 10:19:26.688997+08	2020-12-11 10:22:17.706923+08
STDT-R101	北辦101會議室	會議室	30	台北辦事處	固定幻燈機.電腦、實物投影、白板、投影布	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDT-R102	北辦102會議室	會議室	14	台北辦事處	固定幻燈機.電腦、白板、投影布	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDT-R103	北辦103會議室	會議室	10	台北辦事處	白板	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDT-R104	北辦104會議室	會議室	12	台北辦事處	固定幻燈機.電腦、白板、投影布	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDT-R105	北辦105會議室	會議室	8	台北辦事處	固定幻燈機、白板	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDT-R106	北辦106會議室-訓練教室	會議室	25	台北辦事處	訓練教室個人桌椅，固定幻燈機、白板	\N	\N	f	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R509	509會議室	會議室	7	新營二廠	液晶電視(含電腦)、電話、時鐘、白板	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R510	510會議室	會議室	12	新營二廠	電腦、液晶投影機、投影幕、白板、電話、時鐘	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
STDS-R511	511會議室	會議室	8	新營二廠	白板	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
SYNT-R201	生展201會議室	會議室	10	生展二廠	投影機、電腦、白板、投影布	\N	\N	t	2020-11-12 16:51:31.551889+08	2020-11-12 16:51:31.551889+08
jn7ndhcd4	APPLE-2	資源	\N	資訊C組	\N	\N	APPLE系列  30PIN充電組{n}iPhone 4 / 4S 適用{n}iPad / iPad 2 / New iPad 適用{n}附件：充電器一個(請記得一併取用歸還)	t	2020-12-11 10:20:09.62931+08	2020-12-11 10:22:17.706923+08
jn7ndjelo	NR-A	資源	\N	新營二廠	\N	\N		t	2020-12-11 10:20:09.638846+08	2020-12-11 10:22:17.706923+08
jn7ndjbnf	NR-B	資源	\N	新營二廠	\N	\N		t	2020-12-11 10:20:09.644354+08	2020-12-11 10:22:17.706923+08
jn7ndjdzr	SKYPE-1	資源	\N	資訊C組	\N	\N	品牌：IPEVO{n}型號：CDCA-01IP{n}附件：USB線材二條一組(請記得一併取用歸還)	t	2020-12-11 10:20:09.647303+08	2020-12-11 10:22:17.706923+08
jn7ndjt27	ZOOM-1	資源	\N	生展南科管理部	\N	\N	品牌:IPEVO 型號:VX-1  	t	2020-12-11 10:20:09.665989+08	2020-12-11 10:22:17.706923+08
jn7ndjy7t	外接喇叭-1	資源	\N	資訊C組	\N	\N	可連接 USB 或 藍芽{n}附件：USB線材一條(請記得一併取用歸還)	t	2020-12-11 10:20:09.682757+08	2020-12-11 10:22:17.706923+08
jn7ndj38q	外接喇叭-2	資源	\N	資訊C組	\N	\N	可連接 USB 或 藍芽{n}附件：USB線材一條+3.5音源線(請記得一併取用歸還)	t	2020-12-11 10:20:09.696532+08	2020-12-11 10:22:17.706923+08
jn7ndj0vc	液晶投影機	資源	\N	生展南科管理部	\N	\N	品牌：NEC 型號：NP400 附件：電源線、視訊線(請記得一併取用歸還)	t	2020-12-11 10:20:09.700856+08	2020-12-11 10:22:17.706923+08
jn7ndkvoe	液晶投影機-1	資源	\N	管理部	\N	\N	品牌：HITACHI 505004036	t	2020-12-11 10:20:09.738506+08	2020-12-11 10:22:17.706923+08
jn7ndkc73	液晶投影機-2	資源	\N	管理部	\N	\N	品牌：NEC-2  505004036	t	2020-12-11 10:20:09.74039+08	2020-12-11 10:22:17.706923+08
jn7ndk85m	筆電-1	資源	\N	生展南科管理部	\N	\N	品牌:ASUS  型號:X302L 附件:滑鼠、電源線(請記得一併取用歸還)	t	2020-12-11 10:20:09.746838+08	2020-12-11 10:22:17.706923+08
jn7ndkxi9	筆電-2	資源	\N	生展南科管理部	\N	\N	品牌:ASUS  型號:S410UN 附件:滑鼠、電源線(請記得一併取用歸還)	t	2020-12-11 10:20:09.750073+08	2020-12-11 10:22:17.706923+08
jn7ndkmp4	筆電-4	資源	\N	資訊C組	\N	\N	品牌：ASUS{n}型號：P81IJ{n}附件：變壓器(請記得一併取用歸還)	t	2020-12-11 10:20:09.772023+08	2020-12-11 10:22:17.706923+08
jn7ndkogf	筆電NO.3	資源	\N	管理部	\N	\N	品牌：ASUS(WIN 7){n}附件：變壓器、滑鼠(請記得一併取用歸還)	t	2020-12-11 10:20:09.776202+08	2020-12-11 10:22:17.706923+08
jn7ndkhq9	視訊鏡頭-1	資源	\N	資訊C組	\N	\N	品牌：Logitech{n}型號：V-U0028{n}USB連接    解析度1080P 	t	2020-12-11 10:20:09.782823+08	2020-12-11 10:22:17.706923+08
jn7ndk9n6	視訊轉接-1	資源	\N	資訊C組	\N	\N	視訊接頭  HDMI Type A male (19pin 4.45 mm × 13.9 mm) TO D-SUB(VGA) female{n}轉投影機、螢幕接頭使用{n}可一併借用D-SUB(VGA) double male來轉接	t	2020-12-11 10:20:09.780933+08	2020-12-11 10:22:17.706923+08
jn7ndkbi8	廣角會議電話	資源	\N	生展新營管理部	\N	\N	品牌：PeriPower 型號：7P211S001 附件：USB線材(請記得一併取用歸還)	t	2020-12-11 10:20:09.800301+08	2020-12-11 10:22:17.706923+08
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schedule (event_id, resource_id, start_date, end_date, start_time, end_time, at_created, at_updated) FROM stdin;
hwq58g1xx	STDS-R401	2021-01-08	2021-01-08	08:00:00+08	08:59:59+08	2021-01-04 09:50:38.852274+08	2021-01-04 09:50:38.852274+08
q069ljl7f	STDS-R401	2020-11-23	2020-11-23	08:00:00+08	09:29:59+08	2020-11-20 16:29:54.587412+08	2020-11-20 16:29:54.587412+08
tpwmazcbk	STDS-R502	2020-12-17	2020-12-17	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmazws1	STDS-R502	2020-12-17	2020-12-17	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmazz96	STDS-R502	2020-12-21	2020-12-21	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmazdsq	STDS-R502	2020-12-21	2020-12-21	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmazklq	STDS-R502	2020-12-24	2020-12-24	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaz1cn	STDS-R502	2020-12-24	2020-12-24	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmazhtv	STDS-R502	2020-12-28	2020-12-28	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb0glh	STDS-R502	2020-12-28	2020-12-28	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb0w46	STDS-R502	2020-12-31	2020-12-31	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb018z	STDS-R502	2020-12-31	2020-12-31	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb000c	STDS-R503	2020-09-08	2020-09-08	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb0zbf	STDS-R503	2020-09-10	2020-09-10	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb0efl	STDS-R503	2020-09-15	2020-09-15	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb18ea	STDS-R503	2020-09-17	2020-09-17	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1ubp	STDS-R503	2020-09-22	2020-09-22	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1ybc	STDS-R503	2020-09-23	2020-09-23	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1z5o	STDS-R503	2020-09-24	2020-09-24	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1x5u	STDS-R503	2020-09-29	2020-09-29	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1jd7	STDS-R503	2020-10-01	2020-10-01	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb1tar	STDS-R503	2020-10-06	2020-10-06	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2sxm	STDS-R503	2020-10-08	2020-10-08	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2qz3	STDS-R503	2020-10-13	2020-10-13	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2o8e	STDS-R503	2020-10-15	2020-10-15	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2liz	STDS-R503	2020-10-20	2020-10-20	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2zkc	STDS-R503	2020-10-22	2020-10-22	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb2483	STDS-R503	2020-10-27	2020-10-27	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb3ft2	STDS-R503	2020-10-29	2020-10-29	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb3cxz	STDS-R503	2020-10-30	2020-10-30	08:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb38xm	STDS-R503	2020-11-03	2020-11-03	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb315d	STDS-R503	2020-11-05	2020-11-05	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb3xgf	STDS-R503	2020-11-10	2020-11-10	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb3m3q	STDS-R503	2020-11-12	2020-11-12	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb3dld	STDS-R503	2020-11-17	2020-11-17	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb4r1h	STDS-R503	2020-11-19	2020-11-19	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb421j	STDS-R503	2020-11-24	2020-11-24	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb489j	STDS-R503	2020-11-26	2020-11-26	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb4m35	STDS-R503	2020-12-01	2020-12-01	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb4bif	STDS-R503	2020-12-03	2020-12-03	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb47id	STDS-R503	2020-12-08	2020-12-08	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb428v	STDS-R503	2020-12-10	2020-12-10	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb5uo3	STDS-R503	2020-12-15	2020-12-15	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb5a66	STDS-R503	2020-12-17	2020-12-17	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb5how	STDS-R503	2020-12-22	2020-12-22	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb50du	STDS-R503	2020-12-24	2020-12-24	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb5fl3	STDS-R503	2020-12-29	2020-12-29	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb5alx	STDS-R503	2020-12-31	2020-12-31	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb6r1i	STDS-R503	2021-01-05	2021-01-05	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb6ip0	STDS-R503	2021-01-07	2021-01-07	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb6v7y	STDS-R503	2021-01-12	2021-01-12	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb6xo4	STDS-R503	2021-01-14	2021-01-14	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb6qek	STDS-R503	2021-01-19	2021-01-19	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb675w	STDS-R503	2021-01-21	2021-01-21	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb797d	STDS-R503	2021-01-26	2021-01-26	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7pae	STDS-R503	2021-01-28	2021-01-28	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7o0b	STDS-R503	2021-02-02	2021-02-02	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7yq8	STDS-R503	2021-02-04	2021-02-04	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7z93	STDS-R503	2021-02-09	2021-02-09	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7wzl	STDS-R503	2021-02-11	2021-02-11	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb7idm	STDS-R503	2021-02-16	2021-02-16	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb82nd	STDS-R503	2021-02-18	2021-02-18	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb8ob1	STDS-R503	2021-02-23	2021-02-23	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb8co4	STDS-R503	2021-02-25	2021-02-25	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb8703	STDS-R503	2021-03-02	2021-03-02	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb8a8e	STDS-R503	2021-03-04	2021-03-04	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb8t77	STDS-R503	2021-03-09	2021-03-09	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb9nyu	STDS-R503	2021-03-11	2021-03-11	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb92uk	STDS-R503	2021-03-16	2021-03-16	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb9y6d	STDS-R503	2021-03-18	2021-03-18	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb9932	STDS-R503	2021-03-23	2021-03-23	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmb9j8u	STDS-R503	2021-03-25	2021-03-25	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbafq3	STDS-R503	2021-03-30	2021-03-30	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbasln	STDS-R503	2021-04-01	2021-04-01	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbajz0	STDS-R503	2021-04-06	2021-04-06	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbaw53	STDS-R503	2021-04-08	2021-04-08	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbard7	STDS-R503	2021-04-13	2021-04-13	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbap5n	STDS-R503	2021-04-15	2021-04-15	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbaioa	STDS-R503	2021-04-20	2021-04-20	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbbe3s	STDS-R503	2021-04-22	2021-04-22	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbbpix	STDS-R503	2021-04-27	2021-04-27	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbb84s	STDS-R503	2021-04-29	2021-04-29	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbbhxq	STDS-R504	2020-09-07	2020-09-07	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbb87i	STDS-R504	2020-09-07	2020-09-07	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbbior	STDS-R504	2020-09-09	2020-09-09	10:15:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbcxgh	STDS-R504	2020-09-09	2020-09-09	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbcnf8	STDS-R504	2020-09-10	2020-09-10	09:30:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbdc4x	STDS-R504	2020-09-10	2020-09-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbd477	STDS-R504	2020-09-10	2020-09-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbd7h4	STDS-R504	2020-09-11	2020-09-11	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbdf7y	STDS-R504	2020-09-14	2020-09-14	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbed9q	STDS-R504	2020-09-16	2020-09-16	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbef4x	STDS-R504	2020-09-17	2020-09-17	09:30:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmber7z	STDS-R504	2020-09-17	2020-09-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbeqai	STDS-R504	2020-09-18	2020-09-18	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbeh2a	STDS-R504	2020-09-21	2020-09-21	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbf76n	STDS-R504	2020-09-23	2020-09-23	10:10:00+08	11:39:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbgyhq	STDS-R504	2020-09-24	2020-09-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbgmwf	STDS-R504	2020-09-24	2020-09-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbg6gm	STDS-R504	2020-09-25	2020-09-25	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbgtwa	STDS-R504	2020-09-28	2020-09-28	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbhwhd	STDS-R504	2020-10-01	2020-10-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbh7fa	STDS-R504	2020-10-02	2020-10-02	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbhafd	STDS-R504	2020-10-05	2020-10-05	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbhr6n	STDS-R504	2020-10-08	2020-10-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbha9z	STDS-R504	2020-10-08	2020-10-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbhgzz	STDS-R504	2020-10-09	2020-10-09	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbixe6	STDS-R504	2020-10-12	2020-10-12	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbipat	STDS-R504	2020-10-13	2020-10-13	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbiiab	STDS-R504	2020-10-15	2020-10-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbir1y	STDS-R504	2020-10-16	2020-10-16	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbi94e	STDS-R504	2020-10-19	2020-10-19	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbixj9	STDS-R504	2020-10-22	2020-10-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbj4i7	STDS-R504	2020-10-22	2020-10-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbj861	STDS-R504	2020-10-23	2020-10-23	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbjprj	STDS-R504	2020-10-26	2020-10-26	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbjnys	STDS-R504	2020-10-29	2020-10-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbjfap	STDS-R504	2020-10-30	2020-10-30	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbjemo	STDS-R504	2020-11-02	2020-11-02	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbk7cf	STDS-R504	2020-11-05	2020-11-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbkiqa	STDS-R504	2020-11-06	2020-11-06	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbkmlg	STDS-R504	2020-11-09	2020-11-09	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbk8zs	STDS-R504	2020-11-10	2020-11-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbkf1g	STDS-R504	2020-11-12	2020-11-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbkkyt	STDS-R504	2020-11-12	2020-11-12	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbluw8	STDS-R504	2020-11-13	2020-11-13	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbltmf	STDS-R504	2020-11-16	2020-11-16	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbl8tb	STDS-R504	2020-11-19	2020-11-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbly7a	STDS-R504	2020-11-20	2020-11-20	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmblqmq	STDS-R504	2020-11-23	2020-11-23	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbltdb	STDS-R504	2020-11-26	2020-11-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbmi7p	STDS-R504	2020-11-26	2020-11-26	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbm8ov	STDS-R504	2020-11-27	2020-11-27	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbmw52	STDS-R504	2020-11-30	2020-11-30	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbmitb	STDS-R504	2020-12-03	2020-12-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbm1jb	STDS-R504	2020-12-04	2020-12-04	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbmkhr	STDS-R504	2020-12-07	2020-12-07	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbm8we	STDS-R504	2020-12-08	2020-12-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbnfzy	STDS-R504	2020-12-10	2020-12-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbnai3	STDS-R504	2020-12-10	2020-12-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbnh49	STDS-R504	2020-12-11	2020-12-11	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbnsno	STDS-R504	2020-12-14	2020-12-14	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbn8z6	STDS-R504	2020-12-17	2020-12-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbn6ey	STDS-R504	2020-12-21	2020-12-21	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbordo	STDS-R504	2020-12-24	2020-12-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmboshb	STDS-R504	2020-12-24	2020-12-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmboylb	STDS-R504	2020-12-28	2020-12-28	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmboo4j	STDS-R504	2020-12-31	2020-12-31	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmboe2y	STDS-R504	2021-01-04	2021-01-04	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbo3oc	STDS-R504	2021-01-07	2021-01-07	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbpwbc	STDS-R504	2021-01-11	2021-01-11	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbpdle	STDS-R504	2021-01-14	2021-01-14	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbp3de	STDS-R504	2021-01-18	2021-01-18	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbqdsv	STDS-R504	2021-01-21	2021-01-21	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbqq99	STDS-R504	2021-01-25	2021-01-25	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbq4uj	STDS-R504	2021-01-28	2021-01-28	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbq9f5	STDS-R504	2021-02-01	2021-02-01	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbqwvc	STDS-R504	2021-02-04	2021-02-04	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbq0md	STDS-R504	2021-02-08	2021-02-08	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbqnfr	STDS-R504	2021-02-11	2021-02-11	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbrxq8	STDS-R504	2021-02-15	2021-02-15	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbriex	STDS-R504	2021-02-18	2021-02-18	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbrdmv	STDS-R504	2021-02-22	2021-02-22	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbr2a7	STDS-R504	2021-03-01	2021-03-01	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbrlmz	STDS-R504	2021-03-08	2021-03-08	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbsetd	STDS-R504	2021-03-15	2021-03-15	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbs6wb	STDS-R504	2021-03-22	2021-03-22	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbsg44	STDS-R504	2021-03-29	2021-03-29	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbsh4d	STDS-R504	2021-04-05	2021-04-05	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtaw6	STDS-R504	2021-04-12	2021-04-12	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtv1f	STDS-R504	2021-04-19	2021-04-19	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtwo3	STDS-R504	2021-04-26	2021-04-26	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbt412	STDS-R504	2021-05-03	2021-05-03	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtury	STDS-R504	2021-05-10	2021-05-10	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtug1	STDS-R504	2021-05-17	2021-05-17	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbtc6y	STDS-R504	2021-05-24	2021-05-24	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbuzsf	STDS-R504	2021-05-31	2021-05-31	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbubf0	STDS-R504	2021-06-07	2021-06-07	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbuzsn	STDS-R504	2021-06-14	2021-06-14	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbunjm	STDS-R504	2021-06-21	2021-06-21	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbuj0x	STDS-R504	2021-06-28	2021-06-28	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbui0s	STDS-R504	2021-07-05	2021-07-05	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvid6	STDS-R504	2021-07-12	2021-07-12	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvmw8	STDS-R504	2021-07-19	2021-07-19	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvyci	STDS-R504	2021-07-26	2021-07-26	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvk0i	STDS-R504	2021-08-02	2021-08-02	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvf0y	STDS-R504	2021-08-09	2021-08-09	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvmsu	STDS-R504	2021-08-16	2021-08-16	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbvbop	STDS-R504	2021-08-23	2021-08-23	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwd51	STDS-R504	2021-08-30	2021-08-30	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwqf7	STDS-R504	2021-09-06	2021-09-06	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwwov	STDS-R504	2021-09-13	2021-09-13	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwmbf	STDS-R504	2021-09-20	2021-09-20	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwzmf	STDS-R504	2021-09-27	2021-09-27	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwi3z	STDS-R504	2021-10-04	2021-10-04	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbwaff	STDS-R504	2021-10-11	2021-10-11	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbxsws	STDS-R504	2021-10-18	2021-10-18	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbxah9	STDS-R504	2021-10-25	2021-10-25	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbxkk6	STDS-R504	2021-11-01	2021-11-01	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbx5yd	STDS-R504	2021-11-08	2021-11-08	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbxup7	STDS-R504	2021-11-15	2021-11-15	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbx31x	STDS-R504	2021-11-22	2021-11-22	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbx6bm	STDS-R504	2021-11-29	2021-11-29	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbyi4h	STDS-R504	2021-12-06	2021-12-06	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbyekg	STDS-R504	2021-12-13	2021-12-13	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbyuzw	STDS-R504	2021-12-20	2021-12-20	09:30:00+08	10:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbydzi	STDS-R505	2020-09-07	2020-09-07	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbywrb	STDS-R505	2020-09-07	2020-09-07	10:10:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbykex	STDS-R505	2020-09-07	2020-09-07	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbya78	STDS-R505	2020-09-08	2020-09-08	11:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzzzn	STDS-R505	2020-09-08	2020-09-08	14:15:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzcxe	STDS-R505	2020-09-10	2020-09-10	09:30:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzteo	STDS-R505	2020-09-10	2020-09-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzot5	STDS-R505	2020-09-10	2020-09-10	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzolz	STDS-R505	2020-09-10	2020-09-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzndw	STDS-R505	2020-09-14	2020-09-14	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmbzpc4	STDS-R505	2020-09-16	2020-09-16	15:30:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc00yf	STDS-R505	2020-09-17	2020-09-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc08ze	STDS-R505	2020-09-17	2020-09-17	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc0dek	STDS-R505	2020-09-21	2020-09-21	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc0oz0	STDS-R505	2020-09-23	2020-09-23	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc0r1a	STDS-R505	2020-09-24	2020-09-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc03bs	STDS-R505	2020-09-24	2020-09-24	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc2cv0	STDS-R505	2020-09-24	2020-09-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc39ap	STDS-R505	2020-09-25	2020-09-25	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc3n9b	STDS-R505	2020-09-28	2020-09-28	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc3jjm	STDS-R505	2020-09-30	2020-09-30	10:10:00+08	11:39:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc36fm	STDS-R505	2020-10-01	2020-10-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc4k5j	STDS-R505	2020-10-02	2020-10-02	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc40o8	STDS-R505	2020-10-05	2020-10-05	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc45dp	STDS-R505	2020-10-07	2020-10-07	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc4c0x	STDS-R505	2020-10-08	2020-10-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc4aek	STDS-R505	2020-10-08	2020-10-08	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc406d	STDS-R505	2020-10-08	2020-10-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc50uw	STDS-R505	2020-10-09	2020-10-09	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc5ggg	STDS-R505	2020-10-12	2020-10-12	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc51nn	STDS-R505	2020-10-15	2020-10-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc58zr	STDS-R505	2020-10-15	2020-10-15	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc5jko	STDS-R505	2020-10-16	2020-10-16	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc5a3p	STDS-R505	2020-10-19	2020-10-19	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc5hpa	STDS-R505	2020-10-22	2020-10-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc6ta4	STDS-R505	2020-10-22	2020-10-22	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc6z0u	STDS-R505	2020-10-22	2020-10-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc6zuy	STDS-R505	2020-10-23	2020-10-23	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc6o10	STDS-R505	2020-10-26	2020-10-26	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc62yh	STDS-R505	2020-10-29	2020-10-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc6ya1	STDS-R505	2020-10-29	2020-10-29	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc7g8r	STDS-R505	2020-10-29	2020-10-29	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc7q4d	STDS-R505	2020-10-30	2020-10-30	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc7mf4	STDS-R505	2020-11-02	2020-11-02	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc7hbq	STDS-R505	2020-11-03	2020-11-03	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc87dm	STDS-R505	2020-11-04	2020-11-04	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc93aj	STDS-R505	2020-11-05	2020-11-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc96cl	STDS-R505	2020-11-06	2020-11-06	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc9vv9	STDS-R505	2020-11-09	2020-11-09	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmc9cv8	STDS-R505	2020-11-12	2020-11-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcajr3	STDS-R505	2020-11-12	2020-11-12	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcados	STDS-R505	2020-11-13	2020-11-13	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcav11	STDS-R505	2020-11-16	2020-11-16	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcasdp	STDS-R505	2020-11-19	2020-11-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcayko	STDS-R505	2020-11-20	2020-11-20	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcauo3	STDS-R505	2020-11-23	2020-11-23	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcb1lx	STDS-R505	2020-11-26	2020-11-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcb4l2	STDS-R505	2020-11-26	2020-11-26	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcbzrs	STDS-R505	2020-11-27	2020-11-27	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcbrap	STDS-R505	2020-11-30	2020-11-30	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcbd4j	STDS-R505	2020-12-02	2020-12-02	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmccd3i	STDS-R505	2020-12-03	2020-12-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmccncs	STDS-R505	2020-12-04	2020-12-04	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcc0kt	STDS-R505	2020-12-07	2020-12-07	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmccsii	STDS-R505	2020-12-10	2020-12-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcc9im	STDS-R505	2020-12-10	2020-12-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmccgmb	STDS-R505	2020-12-11	2020-12-11	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcd8w8	STDS-R505	2020-12-14	2020-12-14	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcdfbk	STDS-R505	2020-12-17	2020-12-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcdofy	STDS-R505	2020-12-18	2020-12-18	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcdpt1	STDS-R505	2020-12-21	2020-12-21	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcd51x	STDS-R505	2020-12-24	2020-12-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcd2ny	STDS-R505	2020-12-24	2020-12-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcetdz	STDS-R505	2020-12-25	2020-12-25	13:30:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmceh3e	STDS-R505	2020-12-28	2020-12-28	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcedae	STDS-R505	2020-12-31	2020-12-31	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmceacu	STDS-R505	2020-12-31	2020-12-31	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcex0u	STDS-R505	2021-01-04	2021-01-04	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmceq3c	STDS-R505	2021-01-07	2021-01-07	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcf67l	STDS-R505	2021-01-07	2021-01-07	14:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcf9s4	STDS-R505	2021-01-14	2021-01-14	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcfi36	STDS-R505	2021-01-21	2021-01-21	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcfvr3	STDS-R505	2021-01-28	2021-01-28	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcf05l	STDS-R505	2021-02-04	2021-02-04	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcf9ok	STDS-R505	2021-02-11	2021-02-11	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcg664	STDS-R505	2021-02-18	2021-02-18	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcg5er	STDS-R505	2021-02-25	2021-02-25	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcg514	STDS-R505	2021-03-04	2021-03-04	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcg9ey	STDS-R505	2021-03-11	2021-03-11	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcgslp	STDS-R505	2021-03-18	2021-03-18	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcgp2q	STDS-R505	2021-03-25	2021-03-25	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmchzpr	STDS-R505	2021-04-01	2021-04-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmch62s	STDS-R505	2021-04-08	2021-04-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmchuwh	STDS-R505	2021-04-15	2021-04-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmchzvi	STDS-R505	2021-04-22	2021-04-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmch1si	STDS-R505	2021-04-29	2021-04-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmchvvb	STDS-R505	2021-05-06	2021-05-06	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcift9	STDS-R505	2021-05-13	2021-05-13	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmci8bb	STDS-R505	2021-05-20	2021-05-20	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmci16s	STDS-R505	2021-05-27	2021-05-27	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcihw6	STDS-R505	2021-06-03	2021-06-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcii8w	STDS-R505	2021-06-10	2021-06-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmciecq	STDS-R505	2021-06-17	2021-06-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcjdz1	STDS-R505	2021-06-24	2021-06-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcjejn	STDS-R505	2021-07-01	2021-07-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcjvio	STDS-R505	2021-07-08	2021-07-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcju69	STDS-R505	2021-07-15	2021-07-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcjk53	STDS-R505	2021-07-22	2021-07-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcj9lp	STDS-R505	2021-07-29	2021-07-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmckaxg	STDS-R505	2021-08-05	2021-08-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmck85w	STDS-R505	2021-08-12	2021-08-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmck7p8	STDS-R505	2021-08-19	2021-08-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmckpy9	STDS-R505	2021-08-26	2021-08-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmck0cb	STDS-R505	2021-09-02	2021-09-02	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmckzrs	STDS-R505	2021-09-09	2021-09-09	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmclw56	STDS-R505	2021-09-16	2021-09-16	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmclyq2	STDS-R505	2021-09-23	2021-09-23	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcli6z	STDS-R505	2021-09-30	2021-09-30	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcl0s5	STDS-R505	2021-10-07	2021-10-07	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmclhy0	STDS-R505	2021-10-14	2021-10-14	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcmatb	STDS-R505	2021-10-21	2021-10-21	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcmg1t	STDS-R505	2021-10-28	2021-10-28	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcmo7v	STDS-R505	2021-11-04	2021-11-04	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcm4ga	STDS-R505	2021-11-11	2021-11-11	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcmi2y	STDS-R505	2021-11-18	2021-11-18	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcmtns	STDS-R505	2021-11-25	2021-11-25	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcnsjz	STDS-R505	2021-12-02	2021-12-02	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcnhxh	STDS-R505	2021-12-09	2021-12-09	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcn3h9	STDS-R505	2021-12-16	2021-12-16	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcn009	STDS-R505	2021-12-23	2021-12-23	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcnjx1	STDS-R505	2021-12-30	2021-12-30	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcn9c5	STDS-R505	2022-01-06	2022-01-06	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcoqaj	STDS-R505	2022-01-13	2022-01-13	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcox1b	STDS-R505	2022-01-20	2022-01-20	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcolap	STDS-R505	2022-01-27	2022-01-27	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcop1v	STDS-R505	2022-02-03	2022-02-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcotn9	STDS-R505	2022-02-10	2022-02-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcp8wp	STDS-R505	2022-02-17	2022-02-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcpbll	STDS-R505	2022-02-24	2022-02-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcp3ff	STDS-R505	2022-03-03	2022-03-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcpxps	STDS-R505	2022-03-10	2022-03-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcpxy2	STDS-R505	2022-03-17	2022-03-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcpx7k	STDS-R505	2022-03-24	2022-03-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcqxdp	STDS-R505	2022-03-31	2022-03-31	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcqe6h	STDS-R505	2022-04-07	2022-04-07	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcq2gi	STDS-R505	2022-04-14	2022-04-14	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcqlke	STDS-R505	2022-04-21	2022-04-21	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcqx11	STDS-R505	2022-04-28	2022-04-28	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcqt4m	STDS-R505	2022-05-05	2022-05-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcre54	STDS-R505	2022-05-12	2022-05-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcracq	STDS-R505	2022-05-19	2022-05-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcrmvs	STDS-R505	2022-05-26	2022-05-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcrq2t	STDS-R505	2022-06-02	2022-06-02	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcrdgu	STDS-R505	2022-06-09	2022-06-09	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcr2s5	STDS-R505	2022-06-16	2022-06-16	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcrnd8	STDS-R505	2022-06-23	2022-06-23	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcspq1	STDS-R505	2022-06-30	2022-06-30	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcsx8v	STDS-R505	2022-07-07	2022-07-07	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcs39q	STDS-R505	2022-07-14	2022-07-14	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcshat	STDS-R505	2022-07-21	2022-07-21	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcs8pe	STDS-R505	2022-07-28	2022-07-28	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcsqv5	STDS-R505	2022-08-04	2022-08-04	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcsv1p	STDS-R505	2022-08-11	2022-08-11	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmctl91	STDS-R505	2022-08-18	2022-08-18	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmctzzy	STDS-R505	2022-08-25	2022-08-25	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmctbeo	STDS-R505	2022-09-01	2022-09-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmct7id	STDS-R505	2022-09-08	2022-09-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmct7md	STDS-R505	2022-09-15	2022-09-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmctts9	STDS-R505	2022-09-22	2022-09-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmctjls	STDS-R505	2022-09-29	2022-09-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcuq59	STDS-R505	2022-10-06	2022-10-06	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcurac	STDS-R505	2022-10-13	2022-10-13	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcu7a2	STDS-R505	2022-10-20	2022-10-20	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcu5ni	STDS-R505	2022-10-27	2022-10-27	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcu7l6	STDS-R505	2022-11-03	2022-11-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcut8s	STDS-R505	2022-11-10	2022-11-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcub85	STDS-R505	2022-11-17	2022-11-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcv5cx	STDS-R505	2022-11-24	2022-11-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcvlwg	STDS-R505	2022-12-01	2022-12-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcvcnt	STDS-R505	2022-12-08	2022-12-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcvr41	STDS-R505	2022-12-15	2022-12-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcvf6d	STDS-R505	2022-12-22	2022-12-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcvd1b	STDS-R505	2022-12-29	2022-12-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcv043	STDS-R505	2023-01-05	2023-01-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcw0m0	STDS-R505	2023-01-12	2023-01-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcwr2r	STDS-R505	2023-01-19	2023-01-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcwb98	STDS-R505	2023-01-26	2023-01-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcwmr8	STDS-R505	2023-02-02	2023-02-02	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcw0iv	STDS-R505	2023-02-09	2023-02-09	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcwsul	STDS-R506	2020-09-07	2020-09-07	08:00:00+08	10:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcx5dr	STDS-R506	2020-09-07	2020-09-07	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcxfge	STDS-R506	2020-09-07	2020-09-07	11:10:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcxufx	STDS-R506	2020-09-08	2020-09-08	08:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcxwo9	STDS-R506	2020-09-09	2020-09-09	08:00:00+08	12:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcx6q8	STDS-R506	2020-09-09	2020-09-09	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcxbta	STDS-R506	2020-09-09	2020-09-09	14:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcxxh3	STDS-R506	2020-09-10	2020-09-10	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcybtm	STDS-R506	2020-09-10	2020-09-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcyzm7	STDS-R506	2020-09-11	2020-09-11	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcyw1e	STDS-R506	2020-09-14	2020-09-14	13:30:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcy9ra	STDS-R506	2020-09-15	2020-09-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcy4m6	STDS-R506	2020-09-16	2020-09-16	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcyg5i	STDS-R506	2020-09-16	2020-09-16	14:00:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmczulg	STDS-R506	2020-09-17	2020-09-17	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmczvsl	STDS-R506	2020-09-17	2020-09-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmczxm9	STDS-R506	2020-09-21	2020-09-21	15:00:00+08	18:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcz3im	STDS-R506	2020-09-22	2020-09-22	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmczvau	STDS-R506	2020-09-23	2020-09-23	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmczlu1	STDS-R506	2020-09-23	2020-09-23	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmcz15f	STDS-R506	2020-09-24	2020-09-24	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0eei	STDS-R506	2020-09-26	2020-09-26	13:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0frd	STDS-R506	2020-09-30	2020-09-30	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0t8z	STDS-R506	2020-10-01	2020-10-01	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0zuk	STDS-R506	2020-10-05	2020-10-05	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0qo9	STDS-R506	2020-10-07	2020-10-07	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd00k2	STDS-R506	2020-10-07	2020-10-07	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd0wto	STDS-R506	2020-10-08	2020-10-08	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd1ezl	STDS-R506	2020-10-14	2020-10-14	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd1id4	STDS-R506	2020-10-15	2020-10-15	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd19rg	STDS-R506	2020-10-21	2020-10-21	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd1ndb	STDS-R506	2020-10-22	2020-10-22	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd1hc1	STDS-R506	2020-10-28	2020-10-28	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd17cv	STDS-R506	2020-10-28	2020-10-28	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd1avz	STDS-R506	2020-10-29	2020-10-29	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2bwd	STDS-R506	2020-11-02	2020-11-02	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2nd9	STDS-R506	2020-11-03	2020-11-03	09:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2ofw	STDS-R506	2020-11-04	2020-11-04	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2ti7	STDS-R506	2020-11-04	2020-11-04	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd27zq	STDS-R506	2020-11-05	2020-11-05	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2q4z	STDS-R506	2020-11-11	2020-11-11	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd2fja	STDS-R506	2020-11-12	2020-11-12	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd3yln	STDS-R506	2020-11-18	2020-11-18	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd392c	STDS-R506	2020-11-19	2020-11-19	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd3598	STDS-R506	2020-11-25	2020-11-25	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd380h	STDS-R506	2020-11-25	2020-11-25	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd3yia	STDS-R506	2020-11-26	2020-11-26	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd3a82	STDS-R506	2020-12-02	2020-12-02	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd365d	STDS-R506	2020-12-02	2020-12-02	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd4ix6	STDS-R506	2020-12-03	2020-12-03	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd4w65	STDS-R506	2020-12-07	2020-12-07	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd4gsd	STDS-R506	2020-12-09	2020-12-09	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd40e6	STDS-R506	2020-12-10	2020-12-10	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd452t	STDS-R506	2020-12-16	2020-12-16	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd4eec	STDS-R506	2020-12-17	2020-12-17	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd4m9n	STDS-R506	2020-12-23	2020-12-23	08:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5pd1	STDS-R506	2020-12-23	2020-12-23	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5mio	STDS-R506	2020-12-24	2020-12-24	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5py4	STDS-R506	2020-12-30	2020-12-30	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5omm	STDS-R506	2020-12-31	2020-12-31	16:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5idn	STDS-R506	2021-01-04	2021-01-04	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5oh5	STDS-R506	2021-02-01	2021-02-01	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd5mmg	STDS-R506	2021-03-01	2021-03-01	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6i40	STDS-R508	2020-09-07	2020-09-07	08:30:00+08	18:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6cma	STDS-R508	2020-09-08	2020-09-08	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6e83	STDS-R508	2020-09-08	2020-09-08	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6br5	STDS-R508	2020-09-09	2020-09-09	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6n26	STDS-R508	2020-09-10	2020-09-10	13:15:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6ta3	STDS-R508	2020-09-11	2020-09-11	09:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd6in0	STDS-R508	2020-09-14	2020-09-14	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd72e5	STDS-R508	2020-09-15	2020-09-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd735c	STDS-R508	2020-09-15	2020-09-15	09:30:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd7tv2	STDS-R508	2020-09-16	2020-09-16	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd7loh	STDS-R508	2020-09-16	2020-09-16	09:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd7i6g	STDS-R508	2020-09-21	2020-09-21	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd73s7	STDS-R508	2020-09-22	2020-09-22	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd7y8g	STDS-R508	2020-09-22	2020-09-22	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8r8y	STDS-R508	2020-09-23	2020-09-23	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8az2	STDS-R508	2020-09-23	2020-09-23	13:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8veo	STDS-R508	2020-09-24	2020-09-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8rfe	STDS-R508	2020-09-28	2020-09-28	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd84wm	STDS-R508	2020-09-29	2020-09-29	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8g2n	STDS-R508	2020-09-30	2020-09-30	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd8x6o	STDS-R508	2020-10-05	2020-10-05	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd9zgs	STDS-R508	2020-10-06	2020-10-06	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd943o	STDS-R508	2020-10-06	2020-10-06	09:30:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd9sge	STDS-R508	2020-10-07	2020-10-07	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd9aza	STDS-R508	2020-10-08	2020-10-08	08:30:00+08	18:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd9tis	STDS-R508	2020-10-12	2020-10-12	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd90bz	STDS-R508	2020-10-13	2020-10-13	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmd96k4	STDS-R508	2020-10-13	2020-10-13	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdarjf	STDS-R508	2020-10-14	2020-10-14	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdabeu	STDS-R508	2020-10-19	2020-10-19	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmda2gt	STDS-R508	2020-10-20	2020-10-20	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdaz19	STDS-R508	2020-10-21	2020-10-21	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdapsy	STDS-R508	2020-10-23	2020-10-23	13:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdaypn	STDS-R508	2020-10-26	2020-10-26	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmda7ik	STDS-R508	2020-10-27	2020-10-27	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdbxdw	STDS-R508	2020-10-27	2020-10-27	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdbvz3	STDS-R508	2020-10-28	2020-10-28	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdbc1y	STDS-R508	2020-10-30	2020-10-30	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdb7p5	STDS-R508	2020-11-02	2020-11-02	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdb0sq	STDS-R508	2020-11-03	2020-11-03	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdbffw	STDS-R508	2020-11-03	2020-11-03	09:30:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdbh9h	STDS-R508	2020-11-04	2020-11-04	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdcxnu	STDS-R508	2020-11-06	2020-11-06	08:30:00+08	18:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdc2wl	STDS-R508	2020-11-09	2020-11-09	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdceya	STDS-R508	2020-11-10	2020-11-10	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdcxp1	STDS-R508	2020-11-10	2020-11-10	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdcxbv	STDS-R508	2020-11-11	2020-11-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdcnjs	STDS-R508	2020-11-16	2020-11-16	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdcwx6	STDS-R508	2020-11-17	2020-11-17	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmddibz	STDS-R508	2020-11-18	2020-11-18	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmddo3a	STDS-R508	2020-11-19	2020-11-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmddifm	STDS-R508	2020-11-23	2020-11-23	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdddhv	STDS-R508	2020-11-24	2020-11-24	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmddrju	STDS-R508	2020-11-24	2020-11-24	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmddb9m	STDS-R508	2020-11-25	2020-11-25	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeo4b	STDS-R508	2020-11-30	2020-11-30	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeqdu	STDS-R508	2020-12-01	2020-12-01	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeeso	STDS-R508	2020-12-01	2020-12-01	09:30:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeayb	STDS-R508	2020-12-02	2020-12-02	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdemb7	STDS-R508	2020-12-03	2020-12-03	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeayg	STDS-R508	2020-12-04	2020-12-04	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdeutz	STDS-R508	2020-12-07	2020-12-07	08:30:00+08	18:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdfuue	STDS-R508	2020-12-08	2020-12-08	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdfqrn	STDS-R508	2020-12-08	2020-12-08	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdf7y1	STDS-R508	2020-12-09	2020-12-09	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdfbyg	STDS-R508	2020-12-14	2020-12-14	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdfkwz	STDS-R508	2020-12-15	2020-12-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdf6j3	STDS-R508	2020-12-16	2020-12-16	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdfm5t	STDS-R508	2020-12-21	2020-12-21	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdg5y3	STDS-R508	2020-12-22	2020-12-22	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdg4au	STDS-R508	2020-12-22	2020-12-22	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdgy1v	STDS-R508	2020-12-23	2020-12-23	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdgmxo	STDS-R508	2020-12-24	2020-12-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdg26x	STDS-R508	2020-12-28	2020-12-28	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdg1s6	STDS-R508	2020-12-29	2020-12-29	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdgldk	STDS-R508	2020-12-30	2020-12-30	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdhs8c	STDS-R508	2021-01-04	2021-01-04	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdhqlv	STDS-R508	2021-01-05	2021-01-05	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdh7py	STDS-R508	2021-01-06	2021-01-06	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdh014	STDS-R508	2021-01-11	2021-01-11	10:10:00+08	11:09:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdhppd	STDS-R508	2021-01-12	2021-01-12	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdihho	STDS-R508	2021-01-12	2021-01-12	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdi5aj	STDS-R508	2021-01-13	2021-01-13	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdi768	STDS-R508	2021-01-19	2021-01-19	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdim4c	STDS-R508	2021-01-20	2021-01-20	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdj1ld	STDS-R508	2021-01-26	2021-01-26	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdj2ia	STDS-R508	2021-01-27	2021-01-27	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdjrxe	STDS-R508	2021-02-02	2021-02-02	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdjbnp	STDS-R508	2021-02-03	2021-02-03	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdjvoj	STDS-R508	2021-02-09	2021-02-09	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdjsxp	STDS-R508	2021-02-10	2021-02-10	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdkc2w	STDS-R508	2021-02-16	2021-02-16	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdkwbo	STDS-R508	2021-02-17	2021-02-17	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdlj31	STDS-R508	2021-02-23	2021-02-23	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdl9ix	STDS-R508	2021-02-24	2021-02-24	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdlebm	STDS-R508	2021-03-02	2021-03-02	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdloj7	STDS-R508	2021-03-03	2021-03-03	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdlksb	STDS-R508	2021-03-09	2021-03-09	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdm3dw	STDS-R508	2021-03-10	2021-03-10	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdmuxc	STDS-R508	2021-03-16	2021-03-16	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdm9b1	STDS-R508	2021-03-17	2021-03-17	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdna7m	STDS-R508	2021-03-23	2021-03-23	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdn1a7	STDS-R508	2021-03-24	2021-03-24	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdoxtz	STDS-R508	2021-03-30	2021-03-30	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdof5o	STDS-R508	2021-03-31	2021-03-31	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdoyzp	STDS-R508	2021-04-06	2021-04-06	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdorxl	STDS-R508	2021-04-07	2021-04-07	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdomwj	STDS-R508	2021-04-13	2021-04-13	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdoy5w	STDS-R508	2021-04-14	2021-04-14	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdpzum	STDS-R508	2021-04-20	2021-04-20	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdppmc	STDS-R508	2021-04-21	2021-04-21	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdpf1p	STDS-R508	2021-04-27	2021-04-27	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdp81q	STDS-R508	2021-04-28	2021-04-28	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdppli	STDS-R508	2021-05-04	2021-05-04	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqbf1	STDS-R508	2021-05-05	2021-05-05	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqrba	STDS-R508	2021-05-11	2021-05-11	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqie3	STDS-R508	2021-05-12	2021-05-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqq5w	STDS-R508	2021-05-18	2021-05-18	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqttr	STDS-R508	2021-05-19	2021-05-19	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdq796	STDS-R508	2021-05-25	2021-05-25	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdqtxe	STDS-R508	2021-05-26	2021-05-26	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdr374	STDS-R508	2021-06-01	2021-06-01	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdr7q3	STDS-R508	2021-06-02	2021-06-02	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdr8m1	STDS-R508	2021-06-08	2021-06-08	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdsn3h	STDS-R508	2021-06-09	2021-06-09	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdsqer	STDS-R508	2021-06-15	2021-06-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdsbov	STDS-R508	2021-06-16	2021-06-16	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdsjxt	STDS-R508	2021-06-22	2021-06-22	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmds8dd	STDS-R508	2021-06-23	2021-06-23	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdsb3u	STDS-R508	2021-06-29	2021-06-29	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmds6ig	STDS-R508	2021-06-30	2021-06-30	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdt5mq	STDS-R508	2021-07-06	2021-07-06	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdtgqo	STDS-R508	2021-07-07	2021-07-07	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdt4fp	STDS-R508	2021-07-13	2021-07-13	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdtyuu	STDS-R508	2021-07-14	2021-07-14	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdtod7	STDS-R508	2021-07-20	2021-07-20	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdt23c	STDS-R508	2021-07-21	2021-07-21	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdtwsq	STDS-R508	2021-07-27	2021-07-27	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdugv3	STDS-R508	2021-07-28	2021-07-28	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdupko	STDS-R508	2021-08-03	2021-08-03	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdubbn	STDS-R508	2021-08-04	2021-08-04	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdus0p	STDS-R508	2021-08-10	2021-08-10	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdum6j	STDS-R508	2021-08-11	2021-08-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdu2dy	STDS-R508	2021-08-17	2021-08-17	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdu34i	STDS-R508	2021-08-18	2021-08-18	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdvtdz	STDS-R508	2021-08-24	2021-08-24	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdvvob	STDS-R508	2021-08-25	2021-08-25	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdv7c4	STDS-R508	2021-08-31	2021-08-31	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdvh2l	STDS-R508	2021-09-01	2021-09-01	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdvyn5	STDS-R508	2021-09-07	2021-09-07	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdwvb8	STDS-R508	2021-09-08	2021-09-08	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdwe0e	STDS-R508	2021-09-14	2021-09-14	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdxsp0	STDS-R508	2021-09-15	2021-09-15	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdx8aw	STDS-R508	2021-09-21	2021-09-21	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdxxc8	STDS-R508	2021-09-22	2021-09-22	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdxgom	STDS-R508	2021-09-28	2021-09-28	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdxhjp	STDS-R508	2021-09-29	2021-09-29	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdx8k1	STDS-R508	2021-10-05	2021-10-05	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdxwy3	STDS-R508	2021-10-06	2021-10-06	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdy7rl	STDS-R508	2021-10-12	2021-10-12	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdyr34	STDS-R508	2021-10-13	2021-10-13	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdytlt	STDS-R508	2021-10-19	2021-10-19	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdyhrx	STDS-R508	2021-10-20	2021-10-20	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdy6ls	STDS-R508	2021-10-26	2021-10-26	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdyt6v	STDS-R508	2021-10-27	2021-10-27	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzem1	STDS-R508	2021-11-02	2021-11-02	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzru8	STDS-R508	2021-11-03	2021-11-03	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzbdq	STDS-R508	2021-11-09	2021-11-09	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzgd6	STDS-R508	2021-11-10	2021-11-10	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzvme	STDS-R508	2021-11-16	2021-11-16	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzlv4	STDS-R508	2021-11-17	2021-11-17	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmdzx3d	STDS-R508	2021-11-23	2021-11-23	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0791	STDS-R508	2021-11-24	2021-11-24	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0etf	STDS-R508	2021-11-30	2021-11-30	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0tx6	STDS-R508	2021-12-01	2021-12-01	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0tyx	STDS-R508	2021-12-07	2021-12-07	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0zjx	STDS-R508	2021-12-08	2021-12-08	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0ev8	STDS-R508	2021-12-14	2021-12-14	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme04az	STDS-R508	2021-12-15	2021-12-15	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme0rby	STDS-R508	2021-12-21	2021-12-21	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme18t1	STDS-R508	2021-12-22	2021-12-22	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme1gua	STDS-R508	2021-12-28	2021-12-28	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme1fch	STDS-R508	2021-12-29	2021-12-29	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme1wd8	STDS-R508	2022-01-04	2022-01-04	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme177g	STDS-R508	2022-01-05	2022-01-05	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme2smd	STDS-R508	2022-01-11	2022-01-11	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme29hn	STDS-R508	2022-01-12	2022-01-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme21nh	STDS-R508	2022-01-18	2022-01-18	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme2wp5	STDS-R508	2022-01-19	2022-01-19	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme2ntk	STDS-R508	2022-01-25	2022-01-25	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme2vws	STDS-R508	2022-01-26	2022-01-26	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme2gmp	STDS-R508	2022-02-01	2022-02-01	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme3s5n	STDS-R508	2022-02-02	2022-02-02	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme3mdv	STDS-R508	2022-02-08	2022-02-08	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme3kut	STDS-R508	2022-02-09	2022-02-09	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme3939	STDS-R508	2022-02-15	2022-02-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme35ox	STDS-R508	2022-02-16	2022-02-16	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme33qx	STDS-R508	2022-02-22	2022-02-22	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme3jwr	STDS-R508	2022-02-23	2022-02-23	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme4sum	STDS-R508	2022-03-01	2022-03-01	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme4ajn	STDS-R508	2022-03-02	2022-03-02	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme4mlb	STDS-R508	2022-03-08	2022-03-08	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme4ra5	STDS-R508	2022-03-09	2022-03-09	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme48y7	STDS-R508	2022-03-15	2022-03-15	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme48cu	STDS-R508	2022-03-16	2022-03-16	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme4slp	STDS-R508	2022-03-22	2022-03-22	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme514o	STDS-R508	2022-03-23	2022-03-23	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme5rbg	STDS-R508	2022-03-29	2022-03-29	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme5r19	STDS-R508	2022-03-30	2022-03-30	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme5myu	STDS-R508	2022-04-05	2022-04-05	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme5huy	STDS-R508	2022-04-06	2022-04-06	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme5upm	STDS-R508	2022-04-12	2022-04-12	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme624l	STDS-R508	2022-04-13	2022-04-13	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme6luv	STDS-R508	2022-04-19	2022-04-19	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme69be	STDS-R508	2022-04-20	2022-04-20	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme60yl	STDS-R508	2022-04-26	2022-04-26	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme6k8s	STDS-R508	2022-04-27	2022-04-27	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme64pw	STDS-R508	2022-05-03	2022-05-03	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme6swe	STDS-R508	2022-05-04	2022-05-04	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme7oy1	STDS-R508	2022-05-10	2022-05-10	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme7ug8	STDS-R508	2022-05-11	2022-05-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme7nvd	STDS-R508	2022-05-17	2022-05-17	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme7i4w	STDS-R508	2022-05-18	2022-05-18	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme70zw	STDS-R508	2022-05-24	2022-05-24	08:00:00+08	09:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme7zd3	STDS-R508	2022-05-25	2022-05-25	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme89e8	STDS-R508	2022-06-01	2022-06-01	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme8vh0	STDS-R508	2022-06-08	2022-06-08	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme872z	STDS-R508	2022-06-15	2022-06-15	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme8t1b	STDS-R508	2022-06-22	2022-06-22	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme8ot8	STDS-R508	2022-06-29	2022-06-29	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme8ay6	STDS-R508	2022-07-06	2022-07-06	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme9isi	STDS-R509	2020-09-08	2020-09-08	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme9a6e	STDS-R510	2020-09-07	2020-09-07	10:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme9mau	STDS-R510	2020-09-08	2020-09-08	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme90u7	STDS-R510	2020-09-08	2020-09-08	13:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme972q	STDS-R510	2020-09-09	2020-09-09	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwme9d2c	STDS-R510	2020-09-09	2020-09-09	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmea245	STDS-R510	2020-09-11	2020-09-11	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeatio	STDS-R510	2020-09-16	2020-09-16	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeay4p	STDS-R510	2020-09-16	2020-09-16	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmea27k	STDS-R510	2020-09-16	2020-09-16	11:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeat0d	STDS-R510	2020-09-18	2020-09-18	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeak5g	STDS-R510	2020-09-23	2020-09-23	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeamsi	STDS-R510	2020-09-23	2020-09-23	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmebh0j	STDS-R510	2020-09-24	2020-09-24	17:00:00+08	17:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmebm1v	STDS-R510	2020-09-25	2020-09-25	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeblsx	STDS-R510	2020-09-30	2020-09-30	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmebbb9	STDS-R510	2020-09-30	2020-09-30	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmebh1h	STDS-R510	2020-10-02	2020-10-02	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeb8wz	STDS-R510	2020-10-07	2020-10-07	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeb3uh	STDS-R510	2020-10-07	2020-10-07	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmecpdm	STDS-R510	2020-10-09	2020-10-09	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmecl9b	STDS-R510	2020-10-13	2020-10-13	14:30:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmec019	STDS-R510	2020-10-14	2020-10-14	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmechby	STDS-R510	2020-10-14	2020-10-14	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmecil8	STDS-R510	2020-10-14	2020-10-14	11:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmecbi2	STDS-R510	2020-10-15	2020-10-15	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmec47s	STDS-R510	2020-10-16	2020-10-16	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmec8sj	STDS-R510	2020-10-21	2020-10-21	09:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmed7an	STDS-R510	2020-10-21	2020-10-21	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmedw1g	STDS-R510	2020-10-23	2020-10-23	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmedj07	STDS-R510	2020-10-28	2020-10-28	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmednet	STDS-R510	2020-10-30	2020-10-30	09:00:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmed9m0	STDS-R510	2020-11-04	2020-11-04	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmedb6p	STDS-R510	2020-11-10	2020-11-10	14:30:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmedm2c	STDS-R510	2020-11-11	2020-11-11	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeekgu	STDS-R510	2020-11-18	2020-11-18	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeeu47	STDS-R510	2020-11-18	2020-11-18	11:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeehcx	STDS-R510	2020-11-25	2020-11-25	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmee8s2	STDS-R510	2020-12-02	2020-12-02	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmee13z	STDS-R510	2020-12-08	2020-12-08	14:30:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeeai5	STDS-R510	2020-12-09	2020-12-09	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeee3t	STDS-R510	2020-12-16	2020-12-16	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeek9e	STDS-R510	2020-12-16	2020-12-16	11:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmefiqd	STDS-R510	2020-12-23	2020-12-23	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmefk7c	STDS-R510	2020-12-23	2020-12-23	13:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmefqdw	STDS-R510	2020-12-30	2020-12-30	10:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeffk0	STDS-R511	2020-09-07	2020-09-07	10:10:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmefamn	STDS-R511	2020-09-07	2020-09-07	13:15:00+08	16:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmefsn1	STDS-R511	2020-09-08	2020-09-08	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmef29j	STDS-R511	2020-09-10	2020-09-10	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmegngm	STDS-R511	2020-09-14	2020-09-14	08:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmega06	STDS-R511	2020-09-15	2020-09-15	08:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmegs35	STDS-R511	2020-09-16	2020-09-16	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmegy0l	STDS-R511	2020-09-17	2020-09-17	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmegczt	STDS-R511	2020-09-24	2020-09-24	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeg1qo	STDS-R511	2020-10-08	2020-10-08	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeg4t1	STDS-R511	2020-10-12	2020-10-12	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehceu	STDS-R511	2020-10-13	2020-10-13	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeheak	STDS-R511	2020-10-14	2020-10-14	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehksu	STDS-R511	2020-10-15	2020-10-15	08:00:00+08	12:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehskc	STDS-R511	2020-10-15	2020-10-15	13:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehds7	STDS-R511	2020-10-22	2020-10-22	13:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehz9y	SYNT-R201	2020-09-07	2020-09-07	13:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehyki	SYNT-R201	2020-09-08	2020-09-08	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmehow9	SYNT-R201	2020-09-10	2020-09-10	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmei9ji	SYNT-R201	2020-09-11	2020-09-11	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeivl7	SYNT-R201	2020-09-17	2020-09-17	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeiuyu	SYNT-R201	2020-09-18	2020-09-18	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeihn4	SYNT-R201	2020-09-24	2020-09-24	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeiu3v	SYNT-R201	2020-09-25	2020-09-25	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmei7if	SYNT-R201	2020-10-01	2020-10-01	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeiqy6	SYNT-R201	2020-10-02	2020-10-02	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeiqcn	SYNT-R201	2020-10-08	2020-10-08	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmej19r	SYNT-R201	2020-10-09	2020-10-09	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmejrd0	SYNT-R201	2020-10-15	2020-10-15	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmejrfo	SYNT-R201	2020-10-16	2020-10-16	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmejd8f	SYNT-R201	2020-10-22	2020-10-22	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmejzhp	SYNT-R201	2020-10-23	2020-10-23	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmej2pj	SYNT-R201	2020-10-29	2020-10-29	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekpp3	SYNT-R201	2020-10-30	2020-10-30	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekdsc	SYNT-R201	2020-11-05	2020-11-05	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekjd4	SYNT-R201	2020-11-06	2020-11-06	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekm9a	SYNT-R201	2020-11-12	2020-11-12	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekly1	SYNT-R201	2020-11-13	2020-11-13	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmekvf7	SYNT-R201	2020-11-19	2020-11-19	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeluzy	SYNT-R201	2020-11-20	2020-11-20	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmelbjh	SYNT-R201	2020-11-26	2020-11-26	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmel68s	SYNT-R201	2020-11-27	2020-11-27	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmelu0s	SYNT-R201	2020-12-03	2020-12-03	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmel4bo	SYNT-R201	2020-12-04	2020-12-04	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmelf8e	SYNT-R201	2020-12-10	2020-12-10	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmemp4d	SYNT-R201	2020-12-11	2020-12-11	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmem1am	SYNT-R201	2020-12-17	2020-12-17	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmemnin	SYNT-R201	2020-12-18	2020-12-18	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmemt67	SYNT-R201	2020-12-24	2020-12-24	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmemaxs	SYNT-R201	2020-12-25	2020-12-25	09:00:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmemgto	SYNT-R201	2020-12-31	2020-12-31	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmen9ph	SYNS-R101	2020-09-08	2020-09-08	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeni9q	SYNS-R101	2020-09-08	2020-09-08	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmen2ae	SYNS-R101	2020-09-10	2020-09-10	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmenjjn	SYNS-R101	2020-09-15	2020-09-15	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeocql	SYNS-R101	2020-09-15	2020-09-15	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeoezz	SYNS-R101	2020-09-22	2020-09-22	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeqcrl	SYNS-R101	2020-09-22	2020-09-22	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeq1s8	SYNS-R101	2020-09-29	2020-09-29	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeq6av	SYNS-R101	2020-09-29	2020-09-29	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeq6x6	SYNS-R101	2020-10-06	2020-10-06	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeq1mf	SYNS-R101	2020-10-06	2020-10-06	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeqwxr	SYNS-R101	2020-10-13	2020-10-13	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmerh3p	SYNS-R101	2020-10-13	2020-10-13	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmerkdw	SYNS-R101	2020-10-20	2020-10-20	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmer1lw	SYNS-R101	2020-10-20	2020-10-20	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmerfe0	SYNS-R101	2020-10-27	2020-10-27	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmerou9	SYNS-R101	2020-10-27	2020-10-27	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmere2q	SYNS-R101	2020-11-03	2020-11-03	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmer6a9	SYNS-R101	2020-11-03	2020-11-03	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesqqa	SYNS-R101	2020-11-10	2020-11-10	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesdrk	SYNS-R101	2020-11-10	2020-11-10	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesw81	SYNS-R101	2020-11-17	2020-11-17	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmescdo	SYNS-R101	2020-11-17	2020-11-17	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesa0r	SYNS-R101	2020-11-24	2020-11-24	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesuzt	SYNS-R101	2020-11-24	2020-11-24	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmesiu2	SYNS-R101	2020-12-01	2020-12-01	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmetv0h	SYNS-R101	2020-12-01	2020-12-01	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmetdwb	SYNS-R101	2020-12-08	2020-12-08	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmetmj9	SYNS-R101	2020-12-08	2020-12-08	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmetuxz	SYNS-R101	2020-12-15	2020-12-15	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeuk1l	SYNS-R101	2020-12-15	2020-12-15	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeuzy3	SYNS-R101	2020-12-22	2020-12-22	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeuofk	SYNS-R101	2020-12-22	2020-12-22	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeul0c	SYNS-R101	2020-12-29	2020-12-29	12:15:00+08	14:14:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeu53r	SYNS-R101	2020-12-29	2020-12-29	14:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevsk0	SYNS-R101	2021-01-05	2021-01-05	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevl47	SYNS-R101	2021-01-12	2021-01-12	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevpk6	SYNS-R101	2021-01-19	2021-01-19	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevj48	SYNS-R101	2021-01-26	2021-01-26	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevr0j	SYNS-R101	2021-02-02	2021-02-02	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmevom2	SYNS-R101	2021-02-09	2021-02-09	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmewy2h	SYNS-R101	2021-02-16	2021-02-16	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmew7g5	SYNS-R101	2021-02-23	2021-02-23	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmewsxs	SYNS-R101	2021-03-02	2021-03-02	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmewtp9	SYNS-R101	2021-03-09	2021-03-09	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmew4ul	SYNS-R101	2021-03-16	2021-03-16	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmewyem	SYNS-R101	2021-03-23	2021-03-23	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmewfyd	SYNS-R101	2021-03-30	2021-03-30	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeww6n	SYNS-R101	2021-04-06	2021-04-06	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmex9b9	SYNS-R101	2021-04-13	2021-04-13	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmexqfr	SYNS-R101	2021-04-20	2021-04-20	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmexuww	SYNS-R101	2021-04-27	2021-04-27	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmex3j9	SYNS-R101	2021-05-04	2021-05-04	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmexema	SYNS-R101	2021-05-11	2021-05-11	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmex9rh	SYNS-R101	2021-05-18	2021-05-18	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmex8q0	SYNS-R101	2021-05-25	2021-05-25	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeybcz	SYNS-R101	2021-06-01	2021-06-01	12:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeys5r	SYNS-R102	2020-09-08	2020-09-08	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeyca4	SYNS-R102	2020-09-08	2020-09-08	14:00:00+08	15:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmey2cb	SYNS-R102	2020-09-10	2020-09-10	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeykhx	SYNS-R102	2020-09-15	2020-09-15	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmeyku7	SYNS-R102	2020-09-17	2020-09-17	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmey59s	SYNS-R102	2020-09-22	2020-09-22	09:30:00+08	10:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf0unp	SYNS-R102	2020-09-22	2020-09-22	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf0jxp	SYNS-R102	2020-09-24	2020-09-24	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf1nyl	SYNS-R102	2020-09-29	2020-09-29	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf12tb	SYNS-R102	2020-10-01	2020-10-01	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf1t62	SYNS-R102	2020-10-06	2020-10-06	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf156u	SYNS-R102	2020-10-08	2020-10-08	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf1940	SYNS-R102	2020-10-13	2020-10-13	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf1udw	SYNS-R102	2020-10-15	2020-10-15	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf1rel	SYNS-R102	2020-10-20	2020-10-20	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf28ky	SYNS-R102	2020-10-22	2020-10-22	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf21td	SYNS-R102	2020-10-27	2020-10-27	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf259r	SYNS-R102	2020-10-29	2020-10-29	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf26jk	SYNS-R102	2020-11-03	2020-11-03	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf2kn3	SYNS-R102	2020-11-05	2020-11-05	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf27l6	SYNS-R102	2020-11-10	2020-11-10	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf39tb	SYNS-R102	2020-11-12	2020-11-12	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf3haq	SYNS-R102	2020-11-17	2020-11-17	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf3k9k	SYNS-R102	2020-11-19	2020-11-19	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf3ku5	SYNS-R102	2020-11-24	2020-11-24	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf3hi7	SYNS-R102	2020-11-26	2020-11-26	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf35et	SYNS-R102	2020-12-01	2020-12-01	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf4lw3	SYNS-R102	2020-12-03	2020-12-03	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf418m	SYNS-R102	2020-12-08	2020-12-08	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf4izy	SYNS-R102	2020-12-10	2020-12-10	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf4ag6	SYNS-R102	2020-12-15	2020-12-15	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf44km	SYNS-R102	2020-12-17	2020-12-17	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf4hex	SYNS-R102	2020-12-22	2020-12-22	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf4max	SYNS-R102	2020-12-24	2020-12-24	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf5ax8	SYNS-R102	2020-12-29	2020-12-29	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf5kin	SYNS-R102	2020-12-31	2020-12-31	10:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf5d34	SYNS-R102	2021-01-05	2021-01-05	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf503z	SYNS-R102	2021-01-12	2021-01-12	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf5sk9	SYNS-R102	2021-01-19	2021-01-19	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf5zuh	SYNS-R102	2021-01-26	2021-01-26	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf6xj9	SYNS-R102	2021-02-02	2021-02-02	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf6jxb	SYNS-R102	2021-02-09	2021-02-09	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf6v33	SYNS-R102	2021-02-16	2021-02-16	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf6i67	SYNS-R102	2021-02-23	2021-02-23	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf653i	SYNS-R102	2021-03-02	2021-03-02	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf7cak	SYNS-R102	2021-03-09	2021-03-09	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf71x4	SYNS-R102	2021-03-16	2021-03-16	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf7nvd	SYNS-R102	2021-03-23	2021-03-23	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf7ic0	SYNS-R102	2021-03-30	2021-03-30	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf7uxs	SYNS-R102	2021-04-06	2021-04-06	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf8s6d	SYNS-R102	2021-04-13	2021-04-13	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf86q7	SYNS-R102	2021-04-20	2021-04-20	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf8l1e	SYNS-R102	2021-04-27	2021-04-27	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf8q4i	SYNS-R102	2021-05-04	2021-05-04	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf8zau	SYNS-R102	2021-05-11	2021-05-11	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf956a	SYNS-R102	2021-05-18	2021-05-18	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf9rkd	SYNS-R102	2021-05-25	2021-05-25	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf931h	SYNS-R102	2021-06-01	2021-06-01	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf9zkk	SYNS-R102	2021-06-08	2021-06-08	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf99aw	SYNS-R102	2021-06-15	2021-06-15	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf9bnu	SYNS-R102	2021-06-22	2021-06-22	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmf9o8a	SYNS-R102	2021-06-29	2021-06-29	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfa56p	SYNS-R102	2021-07-06	2021-07-06	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfah72	SYNS-R102	2021-07-13	2021-07-13	11:00:00+08	12:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfanr8	SYNS-R401	2020-09-10	2020-09-10	08:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfa9lv	SYNS-R401	2020-09-11	2020-09-11	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfa3gj	SYNS-R401	2020-09-14	2020-09-14	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfa36q	SYNS-R401	2020-09-15	2020-09-15	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfb836	SYNS-R401	2020-09-16	2020-09-16	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfbl48	SYNS-R401	2020-10-08	2020-10-08	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfb7le	SYNS-R401	2020-10-12	2020-10-12	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfcpoy	SYNS-R401	2020-10-13	2020-10-13	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfc7xi	SYNS-R401	2020-10-14	2020-10-14	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfcf3z	SYNS-R401	2020-10-15	2020-10-15	06:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfd3xj	SYNS-R401	2020-10-16	2020-10-16	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfd515	SYNS-R401	2020-10-26	2020-10-26	08:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfdba9	STDS-R001	2020-09-08	2020-09-08	11:00:00+08	13:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfdcgz	STDS-R001	2020-09-09	2020-09-09	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfdz7v	STDS-R001	2020-09-11	2020-09-11	09:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfd7vr	STDS-R001	2020-09-14	2020-09-14	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfedvm	STDS-R001	2020-09-17	2020-09-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfeyar	STDS-R001	2020-09-23	2020-09-23	08:15:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfeu1i	STDS-R003	2020-09-07	2020-09-07	08:30:00+08	10:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfe9ft	STDS-R003	2020-09-16	2020-09-16	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmffi9f	STDS-R003	2020-09-17	2020-09-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmffw75	STDS-R003	2020-09-24	2020-09-24	16:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmffo59	STDS-R003	2020-09-30	2020-09-30	16:30:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfg4hy	STDS-R003	2020-10-05	2020-10-05	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfgagc	STDS-R003	2020-10-06	2020-10-06	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfg07w	STDS-R003	2020-10-07	2020-10-07	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfhdnd	STDS-R003	2020-10-12	2020-10-12	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfhqvm	STDS-R003	2020-10-13	2020-10-13	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfih8b	STDS-R003	2020-10-14	2020-10-14	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfiwgh	STDS-R003	2020-10-19	2020-10-19	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfi1kh	STDS-R003	2020-10-21	2020-10-21	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfinl9	STDS-R003	2020-10-22	2020-10-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfj3o7	STDS-R003	2020-10-28	2020-10-28	16:30:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfjxjt	STDS-R003	2020-11-02	2020-11-02	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfj3dp	STDS-R003	2020-11-03	2020-11-03	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfkqrd	STDS-R003	2020-11-04	2020-11-04	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfk57t	STDS-R003	2020-11-09	2020-11-09	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfk5t7	STDS-R003	2020-11-11	2020-11-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmflfmr	STDS-R003	2020-11-18	2020-11-18	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmflmcw	STDS-R003	2020-11-19	2020-11-19	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfldv6	STDS-R003	2020-12-01	2020-12-01	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfmg4l	STDS-R003	2020-12-02	2020-12-02	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfnxh7	STDS-R003	2020-12-03	2020-12-03	08:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfnter	STDS-R003	2020-12-11	2020-12-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfny3g	STDS-R003	2020-12-14	2020-12-14	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma7yl6	STDS-R401	2020-09-08	2020-09-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma9jgp	STDS-R401	2020-09-10	2020-09-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma9hub	STDS-R401	2020-09-10	2020-09-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma95xv	STDS-R401	2020-09-11	2020-09-11	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma9l1d	STDS-R401	2020-09-14	2020-09-14	07:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwma9saw	STDS-R401	2020-09-15	2020-09-15	07:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaaeb1	STDS-R401	2020-09-15	2020-09-15	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaa0e9	STDS-R401	2020-09-16	2020-09-16	07:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaats4	STDS-R401	2020-09-17	2020-09-17	07:00:00+08	12:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaafod	STDS-R401	2020-09-17	2020-09-17	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmabbtu	STDS-R401	2020-09-17	2020-09-17	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmab9cj	STDS-R401	2020-09-17	2020-09-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmabds1	STDS-R401	2020-09-18	2020-09-18	07:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaboe0	STDS-R401	2020-09-21	2020-09-21	17:00:00+08	17:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmabial	STDS-R401	2020-09-22	2020-09-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmacmy7	STDS-R401	2020-09-23	2020-09-23	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmac9w2	STDS-R401	2020-09-24	2020-09-24	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmacyqj	STDS-R401	2020-09-24	2020-09-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaonxk	STDS-R502	2020-09-24	2020-09-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmao2to	STDS-R502	2020-09-28	2020-09-28	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaoxtr	STDS-R502	2020-09-28	2020-09-28	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaodbr	STDS-R502	2020-09-28	2020-09-28	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmap9qt	STDS-R502	2020-10-01	2020-10-01	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmap1o1	STDS-R502	2020-10-01	2020-10-01	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmapnoy	STDS-R502	2020-10-05	2020-10-05	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaps73	STDS-R502	2020-10-05	2020-10-05	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmapey8	STDS-R502	2020-10-05	2020-10-05	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmapfmm	STDS-R502	2020-10-08	2020-10-08	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmap1m1	STDS-R502	2020-10-08	2020-10-08	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaqoux	STDS-R502	2020-10-12	2020-10-12	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaq3h6	STDS-R502	2020-10-12	2020-10-12	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaqqoe	STDS-R502	2020-10-12	2020-10-12	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaqke4	STDS-R502	2020-10-15	2020-10-15	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaq1za	STDS-R502	2020-10-15	2020-10-15	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaqtr1	STDS-R502	2020-10-19	2020-10-19	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmardig	STDS-R502	2020-10-19	2020-10-19	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmatcb2	STDS-R502	2020-10-19	2020-10-19	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaczxu	STDS-R401	2020-09-25	2020-09-25	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmachtz	STDS-R401	2020-09-29	2020-09-29	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmadmhn	STDS-R401	2020-10-01	2020-10-01	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmad4du	STDS-R401	2020-10-01	2020-10-01	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmadt18	STDS-R401	2020-10-02	2020-10-02	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmadogo	STDS-R401	2020-10-06	2020-10-06	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaddst	STDS-R401	2020-10-08	2020-10-08	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaeso9	STDS-R401	2020-10-08	2020-10-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaeuzc	STDS-R401	2020-10-09	2020-10-09	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaeffc	STDS-R401	2020-10-13	2020-10-13	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmae2dc	STDS-R401	2020-10-15	2020-10-15	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaegyj	STDS-R401	2020-10-15	2020-10-15	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaefs4	STDS-R401	2020-10-16	2020-10-16	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmafucu	STDS-R401	2020-10-20	2020-10-20	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmafbmz	STDS-R401	2020-10-22	2020-10-22	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfdep6	STDS-R001	2020-09-07	2020-09-07	08:00:00+08	11:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmafp44	STDS-R401	2020-10-22	2020-10-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaf41z	STDS-R401	2020-10-23	2020-10-23	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmafgiq	STDS-R401	2020-10-27	2020-10-27	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmamy73	STDS-R502	2020-09-07	2020-09-07	15:00:00+08	16:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmamn3u	STDS-R502	2020-09-10	2020-09-10	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmam5e1	STDS-R502	2020-09-10	2020-09-10	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmamc3x	STDS-R502	2020-09-14	2020-09-14	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmami0c	STDS-R502	2020-09-14	2020-09-14	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmannu3	STDS-R502	2020-09-14	2020-09-14	15:00:00+08	16:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmanoyh	STDS-R502	2020-09-17	2020-09-17	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmanpqk	STDS-R502	2020-09-17	2020-09-17	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmanod7	STDS-R502	2020-09-21	2020-09-21	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmandlp	STDS-R502	2020-09-21	2020-09-21	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmanvbj	STDS-R502	2020-09-21	2020-09-21	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaoksm	STDS-R502	2020-09-24	2020-09-24	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmao88v	STDS-R502	2020-09-24	2020-09-24	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmatch5	STDS-R502	2020-10-22	2020-10-22	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmat32g	STDS-R502	2020-10-22	2020-10-22	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmatmpz	STDS-R502	2020-10-26	2020-10-26	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmattq4	STDS-R502	2020-10-26	2020-10-26	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmau1h1	STDS-R502	2020-10-26	2020-10-26	15:00:00+08	15:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmau3wa	STDS-R502	2020-10-29	2020-10-29	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmauuc0	STDS-R502	2020-10-29	2020-10-29	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaubwq	STDS-R502	2020-11-02	2020-11-02	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmau2ol	STDS-R502	2020-11-02	2020-11-02	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmavw6a	STDS-R502	2020-11-05	2020-11-05	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmavfy8	STDS-R502	2020-11-05	2020-11-05	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmavef6	STDS-R502	2020-11-09	2020-11-09	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmavtq2	STDS-R502	2020-11-09	2020-11-09	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmav72p	STDS-R502	2020-11-12	2020-11-12	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmavinz	STDS-R502	2020-11-12	2020-11-12	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmawrds	STDS-R502	2020-11-16	2020-11-16	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmawvf8	STDS-R502	2020-11-16	2020-11-16	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmawygk	STDS-R502	2020-11-19	2020-11-19	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmawz3v	STDS-R502	2020-11-19	2020-11-19	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmawm82	STDS-R502	2020-11-23	2020-11-23	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaw5cp	STDS-R502	2020-11-23	2020-11-23	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmax82z	STDS-R502	2020-11-26	2020-11-26	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaxzsb	STDS-R502	2020-11-26	2020-11-26	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaxi1g	STDS-R502	2020-11-26	2020-11-26	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaxdvq	STDS-R502	2020-11-30	2020-11-30	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmax2hq	STDS-R502	2020-11-30	2020-11-30	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmax5w2	STDS-R502	2020-12-03	2020-12-03	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmayi2f	STDS-R502	2020-12-03	2020-12-03	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaykq0	STDS-R502	2020-12-07	2020-12-07	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmayq23	STDS-R502	2020-12-07	2020-12-07	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmay8e9	STDS-R502	2020-12-10	2020-12-10	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmay5y3	STDS-R502	2020-12-10	2020-12-10	15:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmayo4t	STDS-R502	2020-12-14	2020-12-14	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmayu23	STDS-R502	2020-12-14	2020-12-14	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmafiji	STDS-R401	2020-10-29	2020-10-29	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaghsi	STDS-R401	2020-10-29	2020-10-29	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmagzga	STDS-R401	2020-10-30	2020-10-30	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmagp72	STDS-R401	2020-11-03	2020-11-03	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmagsof	STDS-R401	2020-11-05	2020-11-05	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmagvdd	STDS-R401	2020-11-05	2020-11-05	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahvsi	STDS-R401	2020-11-06	2020-11-06	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahfnx	STDS-R401	2020-11-10	2020-11-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahppg	STDS-R401	2020-11-12	2020-11-12	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahpid	STDS-R401	2020-11-12	2020-11-12	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaheo9	STDS-R401	2020-11-13	2020-11-13	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahu6u	STDS-R401	2020-11-17	2020-11-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmahpp9	STDS-R401	2020-11-19	2020-11-19	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaigg1	STDS-R401	2020-11-19	2020-11-19	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaikdg	STDS-R401	2020-11-20	2020-11-20	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmai5fs	STDS-R401	2020-11-24	2020-11-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmai0zz	STDS-R401	2020-11-26	2020-11-26	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmaisgu	STDS-R401	2020-11-26	2020-11-26	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmai2rs	STDS-R401	2020-11-27	2020-11-27	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajhqn	STDS-R401	2020-12-01	2020-12-01	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajfud	STDS-R401	2020-12-03	2020-12-03	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajk2i	STDS-R401	2020-12-03	2020-12-03	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajato	STDS-R401	2020-12-04	2020-12-04	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajsuv	STDS-R401	2020-12-08	2020-12-08	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmajsb5	STDS-R401	2020-12-10	2020-12-10	13:00:00+08	14:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmakboh	STDS-R401	2020-12-10	2020-12-10	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmakgc9	STDS-R401	2020-12-11	2020-12-11	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmakeae	STDS-R401	2020-12-15	2020-12-15	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmak2gw	STDS-R401	2020-12-17	2020-12-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmakd9i	STDS-R401	2020-12-18	2020-12-18	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmalior	STDS-R401	2020-12-22	2020-12-22	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmalhmx	STDS-R401	2020-12-23	2020-12-23	08:00:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmal169	STDS-R401	2020-12-24	2020-12-24	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmall9u	STDS-R401	2020-12-25	2020-12-25	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmalgds	STDS-R401	2020-12-29	2020-12-29	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmamgq3	STDS-R502	2020-09-07	2020-09-07	09:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmamop9	STDS-R502	2020-09-07	2020-09-07	13:00:00+08	14:29:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfnijh	STDS-R003	2020-12-17	2020-12-17	17:00:00+08	17:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfoec3	STDS-R003	2020-12-21	2020-12-21	08:00:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfobr9	STDS-R003	2020-12-30	2020-12-30	16:30:00+08	16:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfohh7	STDS-R003	2021-01-11	2021-01-11	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfoowr	STDS-R003	2021-01-12	2021-01-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfoeb0	STDS-R003	2021-02-08	2021-02-08	08:30:00+08	09:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfov7o	STDS-R003	2021-02-11	2021-02-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfo8mv	STDS-R003	2021-03-11	2021-03-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfp8rb	STDS-R003	2021-04-12	2021-04-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfp586	STDS-R003	2021-05-11	2021-05-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfrcl3	STDS-R003	2021-06-11	2021-06-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfrsqr	STDS-R003	2021-07-12	2021-07-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfr9vj	STDS-R003	2021-08-11	2021-08-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfrx8d	STDS-R003	2021-09-10	2021-09-10	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfs5y9	STDS-R003	2021-10-12	2021-10-12	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfs2a3	STDS-R003	2021-10-13	2021-10-13	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfsr69	STDS-R003	2021-11-11	2021-11-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfs9xr	STDS-R003	2021-12-10	2021-12-10	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfsqhd	STDS-R003	2022-01-11	2022-01-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
tpwmfey77	STDS-R003	2020-09-11	2020-09-11	08:00:00+08	08:59:59+08	2020-11-12 16:50:22.201227+08	2020-11-12 16:50:22.201227+08
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, name, pwd, authority, token, at_created, at_updated) FROM stdin;
84070	Keven	$2a$06$0TxhM19f/t2ogBUlYOUYlOQQfUIJQRJrcHbaKmCy0xJ4.vZxHFGuG	user	\N	2020-11-12 16:51:39.44202+08	2020-11-12 16:51:39.44202+08
103065	TestUser	$2a$06$/LyfNzVI6/TNgSx9d.GHw.w/fuSeCl25pOP/HTc6nM3D/4qIMDO5.	user	\N	2020-11-12 16:51:39.44202+08	2020-11-12 16:51:39.44202+08
104013	HR	$2a$06$2eX6/UEkTnNtk5t.mTPzfeIFJqamPBi820wXgveobOBaE4djKFuve	manager	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEwNDAxMyIsImlhdCI6MTYwNjg5ODA2NCwiZXhwIjoxNjA5MTA5NDUyNjc5fQ.R4QYnf_MDnvlT7vMMxQTdl-njhacjKQ_IlR9HI12qvg	2020-11-12 16:51:39.44202+08	2020-12-02 16:34:24.10163+08
107073	Matt	$2a$06$8acMWK3n57aYHdxX1w3CheCLyZIufDdr54Q/sDbsSGIWF0EYeB0Yi	IT	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEwNzA3MyIsImlhdCI6MTYwOTcyNDg3MSwiZXhwIjoxNjExOTM2MTcwMDEzfQ.rn2mTj2vGL_GtOW8occk6w3dFEpJnmXpv4a7hXy_wWY	2020-11-12 16:51:39.44202+08	2021-01-04 09:47:51.345747+08
\.


--
-- Name: reservation reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_pkey PRIMARY KEY (event_id);


--
-- Name: resource resource_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: schedule schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (event_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: schedule delete_reservation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER delete_reservation BEFORE DELETE ON public.schedule FOR EACH ROW EXECUTE FUNCTION public.deletereservation();


--
-- Name: reservation update_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON public.reservation FOR EACH ROW EXECUTE FUNCTION public.trigger_update_timestamp();


--
-- Name: resource update_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON public.resource FOR EACH ROW EXECUTE FUNCTION public.trigger_update_timestamp();


--
-- Name: schedule update_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON public.schedule FOR EACH ROW EXECUTE FUNCTION public.trigger_update_timestamp();


--
-- Name: users update_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.trigger_update_timestamp();


--
-- Name: schedule schedule_resource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schedule
    ADD CONSTRAINT schedule_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES public.resource(id);


--
-- PostgreSQL database dump complete
--

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4
-- Dumped by pg_dump version 12.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: adminpack; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION adminpack; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

