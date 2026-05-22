-- =============================================================================
-- Family Score: Phase 4 RPCs — Activity Logging & Dashboard
-- Migration: 20260516_phase4_rpcs.sql
-- Neue Funktionen — keine neuen Tabellen (Schema aus Phase 1 vollstaendig)
-- Sicherheit: SECURITY DEFINER + SET search_path = '' (Pitfall 7 aus RESEARCH.md)
-- =============================================================================

-- 1. get_today_score(p_user_id uuid DEFAULT NULL)
--    Tagesscore fuer den aktuellen User (oder optional Kind-Profil)
--    Datenbasis: activity_entries (Trigger aus Phase 1 pflegt nur weekly_summaries)

CREATE OR REPLACE FUNCTION public.get_today_score(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
    duty_minutes    int,
    duty_points     numeric,
    leisure_minutes int,
    leisure_points  numeric,
    total_points    numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_today   date;
BEGIN
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    -- Explizite Timezone (Pitfall 1: UTC vs. Europe/Berlin bei Wochenbeginn)
    v_today   := (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Berlin')::date;

    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                          THEN ae.duration_minutes ELSE 0 END), 0)::int AS duty_minutes,
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                          THEN ae.points ELSE 0.0 END), 0.0) AS duty_points,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                          THEN ae.duration_minutes ELSE 0 END), 0)::int AS leisure_minutes,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                          THEN ae.points ELSE 0.0 END), 0.0) AS leisure_points,
        COALESCE(SUM(ae.points), 0.0) AS total_points
    FROM public.activity_entries ae
    JOIN public.category_config cc ON cc.id = ae.category_id
    WHERE ae.user_id = v_user_id
      AND (ae.logged_at AT TIME ZONE 'Europe/Berlin')::date = v_today;
END;
$$;

-- =============================================================================
-- 2. get_family_today_scores()
--    Tagesscores aller Mitglieder der Familie des aufrufenden Users
--    Sicherheit: SECURITY DEFINER — prueft Familienzugehoerigkeit via family_members

CREATE OR REPLACE FUNCTION public.get_family_today_scores()
RETURNS TABLE (
    user_id        uuid,
    display_name   text,
    avatar_color   text,
    duty_points    numeric,
    leisure_points numeric,
    total_points   numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_today date;
BEGIN
    v_today := (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Berlin')::date;

    RETURN QUERY
    SELECT
        fm.id AS user_id,
        fm.display_name,
        COALESCE(fm.avatar_color, '#007AFF') AS avatar_color,
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                          THEN ae.points ELSE 0.0 END), 0.0) AS duty_points,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                          THEN ae.points ELSE 0.0 END), 0.0) AS leisure_points,
        COALESCE(SUM(ae.points), 0.0) AS total_points
    FROM public.family_members fm
    LEFT JOIN public.activity_entries ae
        ON ae.user_id = fm.id
        AND ae.family_id = fm.family_id
        AND (ae.logged_at AT TIME ZONE 'Europe/Berlin')::date = v_today
    LEFT JOIN public.category_config cc ON cc.id = ae.category_id
    WHERE fm.family_id = (
        SELECT family_id FROM public.family_members WHERE id = (SELECT auth.uid())
    )
    GROUP BY fm.id, fm.display_name, fm.avatar_color;
END;
$$;

-- =============================================================================
-- 3. create_activity_for_child(...)
--    Kind-Eintrag via SECURITY DEFINER — Eltern-Kind-Beziehung wird atomisch geprueft
--    Problem: RLS user_id = auth.uid() erlaubt kein INSERT mit anderem user_id
--    Loesung: SECURITY DEFINER prueft Rolle des Elternteils vor INSERT (Pitfall T-4-01)
--    DoS-Schutz: duration_minutes auf 240 Minuten gecappt (T-4-05)

CREATE OR REPLACE FUNCTION public.create_activity_for_child(
    p_child_user_id  uuid,
    p_category_id    uuid,
    p_duration_min   int,
    p_points         numeric,
    p_title          text DEFAULT NULL
)
RETURNS public.activity_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_parent_id   uuid := (SELECT auth.uid());
    v_family_id   uuid;
    v_capped_min  int;
    v_result      public.activity_entries;
BEGIN
    -- DoS-Schutz: duration_minutes auf 1–240 min cappen (T-4-05)
    v_capped_min := GREATEST(1, LEAST(240, p_duration_min));

    -- Elternteil muss in derselben Familie sein und Admin- oder Adult-Rolle haben
    SELECT fm_parent.family_id INTO v_family_id
    FROM public.family_members fm_parent
    JOIN public.family_members fm_child ON fm_child.id = p_child_user_id
    WHERE fm_parent.id = v_parent_id
      AND fm_parent.role IN ('admin', 'adult')
      AND fm_parent.family_id = fm_child.family_id;

    IF v_family_id IS NULL THEN
        RAISE EXCEPTION 'Nicht berechtigt, Eintraege fuer dieses Kind zu erstellen';
    END IF;

    INSERT INTO public.activity_entries
        (family_id, user_id, category_id, duration_minutes, points, title)
    VALUES
        (v_family_id, p_child_user_id, p_category_id, v_capped_min,
         GREATEST(0.0, p_points), p_title)
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$;

-- =============================================================================
-- 4. insert_default_categories(p_family_id uuid)
--    Seed-Funktion: legt 4 Standardkategorien fuer eine neue Familie an
--    Wird von FamilyService (Phase 3) bei create_family() aufgerufen.
--    Phase 4 Wave 0: Migration stellt sicher dass die Funktion existiert.
--    Idempotent: ON CONFLICT DO NOTHING verhindert Duplikate bei Mehrfach-Aufruf.

CREATE OR REPLACE FUNCTION public.insert_default_categories(p_family_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.category_config (family_id, name, icon, point_weight, is_enabled, sort_order)
    VALUES
        (p_family_id, 'Haushalt',       'house.fill',          1.0, true, 0),
        (p_family_id, 'Besorgungen',    'cart.fill',           1.0, true, 1),
        (p_family_id, 'Arbeit/Schule',  'briefcase.fill',      1.0, true, 2),
        (p_family_id, 'Hobby/Freizeit', 'gamecontroller.fill', 1.0, true, 3)
    ON CONFLICT DO NOTHING;
END;
$$;
