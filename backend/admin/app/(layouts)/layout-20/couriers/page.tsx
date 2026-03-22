"use client";

import dynamic from "next/dynamic";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch, API_URL } from "@/lib/api";

const ReactApexChart = dynamic(() => import("react-apexcharts"), { ssr: false });

type Courier = {
  id: string;
  userId: string;
  phone: string;
  firstName: string;
  lastName: string;
  iin: string;
  isOnline: boolean;
  isActive?: boolean | null;
  lastActiveAt?: string | null;
  lastSeenAt?: string | null;
  onlineForSec?: number | null;
  lastSessionSec?: number | null;
  lastOnlineAt?: string | null;
  lastOfflineAt?: string | null;
  avatarUrl?: string | null;
  personalFeeOverride?: number | null;
  payoutBonusAdd?: number | null;
  courierCommissionPctOverride?: number | null;
};

type StatusSummary = {
  total: number;
  online: number;
  offline: number;
  busy: number;
  sleeping?: number;
  generatedAt?: string;
};

type OnlineTimelinePoint = {
  hour?: number;
  time?: string;
  ts?: string;
  online: number;
};

type OnlineSeriesPoint = {
  date?: string;
  online?: number;
  onlineAvg?: number;
  bucket?: string;
  seenUnique?: number;
  activeUnique?: number;
};

type ActiveTariff = {
  fee: number;
  startsAt?: string | null;
  endsAt?: string | null;
};

const norm = (v: unknown) => String(v ?? "").trim().toLowerCase();

function initials(firstName?: string, lastName?: string) {
  const a = (firstName ?? "").trim();
  const b = (lastName ?? "").trim();
  const s = `${a} ${b}`.trim();
  if (!s) return "C";
  const parts = s.split(/\s+/).filter(Boolean);
  const i1 = parts[0]?.[0] ?? "C";
  const i2 = parts[1]?.[0] ?? "";
  return (i1 + i2).toUpperCase();
}

function resolveAvatarSrc(avatarUrl?: string | null) {
  if (!avatarUrl) return "";
  if (/^https?:\/\//i.test(avatarUrl)) return avatarUrl;
  return `${API_URL}${avatarUrl}`;
}

function lockScrollParents(root: HTMLElement | null) {
  if (!root) return () => {};

  const locked: Array<{
    el: HTMLElement;
    overflow: string;
    overflowY: string;
    overscrollBehavior: string;
  }> = [];

  const isScrollable = (el: HTMLElement) => {
    const style = window.getComputedStyle(el);
    const oy = style.overflowY;
    const ox = style.overflowX;
    const canScrollY =
      (oy === "auto" || oy === "scroll") && el.scrollHeight > el.clientHeight + 2;
    const canScrollX =
      (ox === "auto" || ox === "scroll") && el.scrollWidth > el.clientWidth + 2;
    return canScrollY || canScrollX;
  };

  let cur: HTMLElement | null = root.parentElement;
  while (cur && cur !== document.body) {
    if (isScrollable(cur)) {
      locked.push({
        el: cur,
        overflow: cur.style.overflow || "",
        overflowY: cur.style.overflowY || "",
        overscrollBehavior: cur.style.overscrollBehavior || "",
      });
      cur.style.overflow = "hidden";
      cur.style.overflowY = "hidden";
      cur.style.overscrollBehavior = "none";
    }
    cur = cur.parentElement;
  }

  const html = document.documentElement;
  const body = document.body;

  const htmlPrev = {
    overflow: html.style.overflow || "",
    overflowY: html.style.overflowY || "",
    overscrollBehavior: html.style.overscrollBehavior || "",
  };
  const bodyPrev = {
    overflow: body.style.overflow || "",
    overflowY: body.style.overflowY || "",
    overscrollBehavior: body.style.overscrollBehavior || "",
  };

  const prevHtml = window.getComputedStyle(html);
  const prevBody = window.getComputedStyle(body);

  if (prevHtml.overflowY !== "hidden") {
    html.style.overflowY = "hidden";
    html.style.overscrollBehavior = "none";
  }
  if (prevBody.overflowY !== "hidden") {
    body.style.overflowY = "hidden";
    body.style.overscrollBehavior = "none";
  }

  return () => {
    for (const x of locked) {
      x.el.style.overflow = x.overflow;
      x.el.style.overflowY = x.overflowY;
      x.el.style.overscrollBehavior = x.overscrollBehavior;
    }
    html.style.overflow = htmlPrev.overflow;
    html.style.overflowY = htmlPrev.overflowY;
    html.style.overscrollBehavior = htmlPrev.overscrollBehavior;

    body.style.overflow = bodyPrev.overflow;
    body.style.overflowY = bodyPrev.overflowY;
    body.style.overscrollBehavior = bodyPrev.overscrollBehavior;
  };
}

function safeNumber(x: any, fallback = 0) {
  const n = Number(x);
  return Number.isFinite(n) ? n : fallback;
}

function formatDurationHM(sec: number | null | undefined) {
  const s = typeof sec === "number" && Number.isFinite(sec) && sec >= 0 ? Math.floor(sec) : null;
  if (s == null) return "—";

  const totalMin = Math.floor(s / 60);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;

  if (h > 0) return m > 0 ? `${h}ч ${m}м` : `${h}ч`;
  return `${m}м`;
}

function formatAgoHM(iso: string | null | undefined) {
  if (!iso) return "—";
  const d = new Date(iso);
  const t = d.getTime();
  if (!Number.isFinite(t)) return "—";
  const sec = Math.floor((Date.now() - t) / 1000);
  if (sec < 0) return "—";
  return formatDurationHM(sec);
}

function moneyKZT(v: number | null | undefined) {
  const n = typeof v === "number" && Number.isFinite(v) ? Math.round(v) : null;
  if (n == null) return "—";
  return `${n.toLocaleString("ru-RU")} ₸`;
}

function pctText(v: number | null | undefined) {
  const n = typeof v === "number" && Number.isFinite(v) ? Math.round(v) : null;
  if (n == null) return "—";
  return `${n}%`;
}

function commissionAmountKZT(fee: number | null | undefined, pct: number | null | undefined) {
  const f = typeof fee === "number" && Number.isFinite(fee) ? fee : null;
  const p = typeof pct === "number" && Number.isFinite(pct) ? pct : null;
  if (f == null || p == null) return "—";
  const amt = Math.round((f * p) / 100);
  return `${amt.toLocaleString("ru-RU")} ₸`;
}

const LS_SHOW_STATS = "couriers_show_stats_v1";
const LS_STATS_EXPANDED = "couriers_stats_expanded_v1";

function StatCard({
  title,
  value,
  subtitle,
  gradient,
}: {
  title: string;
  value: string;
  subtitle: string;
  gradient: string;
}) {
  return (
    <div
      className="rounded-3xl p-5 text-white shadow-sm min-h-[140px] flex flex-col justify-between"
      style={{ background: gradient }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="text-sm font-semibold opacity-90">{title}</div>
        <div className="h-10 w-10 rounded-2xl bg-white/20 flex items-center justify-center text-lg">
          ●
        </div>
      </div>

      <div>
        <div className="text-3xl font-bold leading-none mb-2">{value}</div>
        <div className="text-sm opacity-90">{subtitle}</div>
      </div>
    </div>
  );
}

export default function CouriersPage() {
  const router = useRouter();
  const rootRef = useRef<HTMLDivElement | null>(null);

  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [q, setQ] = useState("");
  const [onlineFilter, setOnlineFilter] = useState<"all" | "online" | "offline">("all");
  const [activeFilter, setActiveFilter] = useState<"all" | "active" | "blocked">("all");

  const [summary, setSummary] = useState<StatusSummary | null>(null);
  const [summaryLoading, setSummaryLoading] = useState(false);
  const [summaryError, setSummaryError] = useState<string | null>(null);

  const [timeline, setTimeline] = useState<OnlineTimelinePoint[]>([]);
  const [timelineLoading, setTimelineLoading] = useState(false);
  const [timelineError, setTimelineError] = useState<string | null>(null);

  const [series, setSeries] = useState<OnlineSeriesPoint[]>([]);
  const [seriesLoading, setSeriesLoading] = useState(false);
  const [seriesError, setSeriesError] = useState<string | null>(null);

  const [showStats, setShowStats] = useState(true);
  const [statsExpanded, setStatsExpanded] = useState(false);

  const [activeTariff, setActiveTariff] = useState<ActiveTariff | null>(null);
  const [tariffLoading, setTariffLoading] = useState(false);
  const [tariffError, setTariffError] = useState<string | null>(null);

  const [globalCommissionPct, setGlobalCommissionPct] = useState<number>(15);
  const [commissionLoading, setCommissionLoading] = useState(false);

  const [showTariffModal, setShowTariffModal] = useState(false);
  const [globalFeeInput, setGlobalFeeInput] = useState<string>("");

  const [showCommissionModal, setShowCommissionModal] = useState(false);
  const [globalCommissionInput, setGlobalCommissionInput] = useState<string>("15");

  const [showCourierTariffModal, setShowCourierTariffModal] = useState(false);
  const [tariffCourier, setTariffCourier] = useState<Courier | null>(null);
  const [courierFeeInput, setCourierFeeInput] = useState<string>("");
  const [courierUseGlobal, setCourierUseGlobal] = useState<boolean>(false);

  const [tariffSaving, setTariffSaving] = useState(false);

  useEffect(() => {
    const unlock = lockScrollParents(rootRef.current);
    return () => unlock();
  }, []);

  useEffect(() => {
    try {
      const v = localStorage.getItem(LS_SHOW_STATS);
      if (v === "0") setShowStats(false);
      if (v === "1") setShowStats(true);

      const e = localStorage.getItem(LS_STATS_EXPANDED);
      if (e === "1") setStatsExpanded(true);
    } catch {}
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(LS_SHOW_STATS, showStats ? "1" : "0");
    } catch {}
  }, [showStats]);

  useEffect(() => {
    try {
      localStorage.setItem(LS_STATS_EXPANDED, statsExpanded ? "1" : "0");
    } catch {}
  }, [statsExpanded]);

  useEffect(() => {
    let alive = true;

    const loadTariff = async () => {
      try {
        setTariffLoading(true);
        setTariffError(null);
        const t = (await apiFetch(`/couriers/tariff/active`)) as any;
        if (!alive) return;

        if (t && typeof t.fee === "number") {
          setActiveTariff({
            fee: safeNumber(t.fee, 0),
            startsAt: t.startsAt ?? null,
            endsAt: t.endsAt ?? null,
          });
          setGlobalFeeInput(String(Math.max(0, Math.round(Number(t.fee) || 0))));
        } else {
          setActiveTariff(null);
        }
      } catch (e: any) {
        if (!alive) return;
        setTariffError(e?.message || "Ошибка тарифа");
      } finally {
        if (!alive) return;
        setTariffLoading(false);
      }
    };

    loadTariff();
    const t = setInterval(loadTariff, 15000);

    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);

  useEffect(() => {
    let alive = true;

    const loadCommission = async () => {
      try {
        setCommissionLoading(true);
        const res = (await apiFetch(`/couriers/commission/default`)) as any;
        if (!alive) return;
        const pct = Math.max(0, Math.min(100, Math.round(Number(res?.pct) || 0)));
        setGlobalCommissionPct(pct);
        setGlobalCommissionInput(String(pct));
      } catch {
      } finally {
        if (!alive) return;
        setCommissionLoading(false);
      }
    };

    loadCommission();
    const t = setInterval(loadCommission, 20000);

    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);

  useEffect(() => {
    let alive = true;
    let first = true;

    const loadCouriers = async () => {
      try {
        if (first) {
          setLoading(true);
          setError(null);
        }
        const data = (await apiFetch(`/couriers?page=1&limit=200`)) as any;
        if (!alive) return;
        setCouriers(data?.items || []);
      } catch (e: any) {
        if (!alive) return;
        if (first) setError(e?.message || "Ошибка");
      } finally {
        if (!alive) return;
        if (first) setLoading(false);
      }
    };

    const loadSummary = async () => {
      try {
        if (first) {
          setSummaryLoading(true);
          setSummaryError(null);
        }
        const data = (await apiFetch(`/couriers/metrics/status-summary`)) as StatusSummary;
        if (!alive) return;
        setSummary(data);
      } catch (e: any) {
        if (!alive) return;
        if (first) setSummaryError(e?.message || "Ошибка метрик");
      } finally {
        if (!alive) return;
        if (first) setSummaryLoading(false);
      }
    };

    const tick = async () => {
      await Promise.all([loadCouriers(), loadSummary()]);
      first = false;
    };

    tick();
    const t = setInterval(tick, 5000);
    const onFocus = () => tick();
    window.addEventListener("focus", onFocus);

    return () => {
      alive = false;
      clearInterval(t);
      window.removeEventListener("focus", onFocus);
    };
  }, []);

  useEffect(() => {
    if (!showStats || !statsExpanded) return;

    let alive = true;

    (async () => {
      setTimelineLoading(true);
      setTimelineError(null);

      try {
        const raw = (await apiFetch(`/couriers/metrics/online-timeline`)) as any;

        const items: any[] = Array.isArray(raw)
          ? raw
          : raw?.items
          ? raw.items
          : raw?.points
          ? raw.points
          : [];

        const mapped: OnlineTimelinePoint[] = (items || [])
          .map((p: any) => ({
            hour: typeof p?.hour === "number" ? p.hour : undefined,
            time: p?.time != null ? String(p.time) : undefined,
            ts: p?.ts != null ? String(p.ts) : undefined,
            online: safeNumber(p?.online ?? p?.count ?? p?.value, 0),
          }))
          .filter((p) => Number.isFinite(p.online));

        if (!alive) return;
        setTimeline(mapped);
      } catch (e: any) {
        if (!alive) return;
        setTimelineError(e?.message || "Нет данных");
      } finally {
        if (!alive) return;
        setTimelineLoading(false);
      }
    })();

    return () => {
      alive = false;
    };
  }, [showStats, statsExpanded]);

  useEffect(() => {
    if (!showStats || !statsExpanded) return;

    let alive = true;

    (async () => {
      setSeriesLoading(true);
      setSeriesError(null);

      try {
        const raw = (await apiFetch(`/couriers/metrics/online-series`)) as any;

        const items: any[] = Array.isArray(raw)
          ? raw
          : raw?.items
          ? raw.items
          : raw?.series
          ? raw.series
          : [];

        const mapped: OnlineSeriesPoint[] = (items || [])
          .map((p: any) => ({
            bucket: p?.bucket != null ? String(p.bucket) : undefined,
            seenUnique: p?.seenUnique != null ? safeNumber(p.seenUnique, 0) : undefined,
            activeUnique: p?.activeUnique != null ? safeNumber(p.activeUnique, 0) : undefined,
            date:
              p?.date != null
                ? String(p.date)
                : p?.day != null
                ? String(p.day)
                : p?.label != null
                ? String(p.label)
                : undefined,
            online: p?.online != null ? safeNumber(p.online, 0) : undefined,
            onlineAvg: p?.onlineAvg != null ? safeNumber(p.onlineAvg, 0) : undefined,
          }))
          .filter((p) => !!p.bucket || !!p.date);

        if (!alive) return;
        setSeries(mapped);
      } catch (e: any) {
        if (!alive) return;
        setSeriesError(e?.message || "Нет данных");
      } finally {
        if (!alive) return;
        setSeriesLoading(false);
      }
    })();

    return () => {
      alive = false;
    };
  }, [showStats, statsExpanded]);

  const rows = useMemo(() => couriers ?? [], [couriers]);

  const filtered = useMemo(() => {
    const query = norm(q);

    return rows.filter((c) => {
      const active = (c.isActive ?? true) === true;

      if (activeFilter === "active" && !active) return false;
      if (activeFilter === "blocked" && active) return false;

      if (onlineFilter === "online" && !c.isOnline) return false;
      if (onlineFilter === "offline" && c.isOnline) return false;

      if (!query) return true;

      const fullName = `${c.firstName ?? ""} ${c.lastName ?? ""}`.trim();
      const hay = norm([c.phone, c.iin, fullName].join(" "));
      return hay.includes(query);
    });
  }, [rows, q, onlineFilter, activeFilter]);

  const counts = useMemo(() => {
    const total = rows.length;
    const online = rows.filter((c) => c.isOnline).length;
    const offline = total - online;
    const active = rows.filter((c) => (c.isActive ?? true) === true).length;
    const blocked = total - active;
    return { total, online, offline, active, blocked };
  }, [rows]);

  const stat = useMemo(() => {
    const s = summary;
    const total = s?.total ?? counts.total;
    const online = s?.online ?? counts.online;
    const offline = s?.offline ?? counts.offline;
    const busy = s?.busy ?? 0;
    const active = counts.active;
    const blocked = counts.blocked;
    return { total, online, offline, busy, active, blocked };
  }, [summary, counts]);

  const pieSeries = useMemo(() => [stat.online, stat.offline, stat.busy], [stat]);
  const pieLabels = useMemo(() => ["На линии", "Оффлайн", "На заказе"], []);

  const pieOptions: any = useMemo(() => {
    const seriesRef = pieSeries;
    return {
      chart: { type: "pie", toolbar: { show: false }, animations: { enabled: true } },
      labels: pieLabels,
      colors: ["#16a34a", "#ef4444", "#f59e0b"],
      stroke: { show: true, width: 2, colors: ["#ffffff"] },
      legend: { show: false },
      dataLabels: {
        enabled: true,
        style: { fontSize: "12px", fontWeight: 900, colors: ["#111111"] },
        dropShadow: { enabled: false },
        formatter: function (val: number, opts: any) {
          const i = opts.seriesIndex as number;
          const label = opts.w.globals.labels[i] as string;
          const count = Number(seriesRef[i] ?? 0);
          const pct = Math.round(val);
          return `${label}\n${pct}%\n${count}`;
        },
      },
      plotOptions: {
        pie: { expandOnClick: false, dataLabels: { offset: 10, minAngleToShowLabel: 5 } },
      },
      tooltip: {
        y: {
          formatter: (value: number, opts: any) => {
            const total =
              opts?.w?.globals?.seriesTotals?.reduce((a: number, b: number) => a + b, 0) ?? 0;
            const pct = total > 0 ? Math.round((value / total) * 100) : 0;
            return `${value} (${pct}%)`;
          },
        },
      },
    };
  }, [pieSeries, pieLabels]);

  const timelineChart = useMemo(() => {
    const labels =
      timeline.length > 0
        ? timeline.map((p, idx) => {
            if (typeof p.hour === "number") return `${String(p.hour).padStart(2, "0")}:00`;
            if (p.time) return String(p.time);
            if (p.ts) {
              const d = new Date(p.ts);
              if (!Number.isNaN(d.getTime())) {
                const hh = String(d.getHours()).padStart(2, "0");
                return `${hh}:00`;
              }
              return p.ts;
            }
            return String(idx + 1);
          })
        : [];

    const values = timeline.length > 0 ? timeline.map((p) => safeNumber(p.online, 0)) : [];

    return {
      series: [{ name: "На линии", data: values }],
      options: {
        chart: { type: "area", toolbar: { show: false }, sparkline: { enabled: false } },
        dataLabels: { enabled: false },
        stroke: { curve: "smooth", width: 2 },
        xaxis: { categories: labels, labels: { rotate: -45 } },
        yaxis: { labels: { formatter: (v: number) => String(Math.round(v)) } },
        tooltip: { x: { show: true } },
      } as any,
    };
  }, [timeline]);

  const seriesChart = useMemo(() => {
    const hasNew = series.some((p) => p.bucket && (p.seenUnique != null || p.activeUnique != null));

    if (hasNew) {
      const labels =
        series.length > 0
          ? series.map((p) => {
              const key = p.bucket ?? p.date ?? "";
              if (!key) return "";
              const d = new Date(key);
              if (!Number.isNaN(d.getTime())) return d.toISOString().slice(0, 10);
              return key;
            })
          : [];

      const seen = series.map((p) => safeNumber(p.seenUnique ?? 0, 0));
      const active = series.map((p) => safeNumber(p.activeUnique ?? 0, 0));

      return {
        series: [
          { name: "Видимые", data: seen },
          { name: "Активные", data: active },
        ],
        options: {
          chart: { type: "line", toolbar: { show: false } },
          dataLabels: { enabled: false },
          stroke: { curve: "smooth", width: 2 },
          xaxis: { categories: labels, labels: { rotate: -45 } },
          yaxis: { labels: { formatter: (v: number) => String(Math.round(v)) } },
          tooltip: { x: { show: true } },
          legend: { show: true },
        } as any,
      };
    }

    const labels = series.length > 0 ? series.map((p) => p.date ?? "") : [];
    const values =
      series.length > 0 ? series.map((p) => safeNumber(p.onlineAvg ?? p.online ?? 0, 0)) : [];

    return {
      series: [{ name: "На линии (среднее)", data: values }],
      options: {
        chart: { type: "line", toolbar: { show: false } },
        dataLabels: { enabled: false },
        stroke: { curve: "smooth", width: 2 },
        xaxis: { categories: labels, labels: { rotate: -45 } },
        yaxis: { labels: { formatter: (v: number) => String(Math.round(v)) } },
        tooltip: { x: { show: true } },
      } as any,
    };
  }, [series]);

  const openGlobalTariffModal = () => {
    const fee = activeTariff?.fee ?? 0;
    setGlobalFeeInput(String(Math.max(0, Math.round(Number(fee) || 0))));
    setShowTariffModal(true);
  };

  const openGlobalCommissionModal = () => {
    setGlobalCommissionInput(String(globalCommissionPct ?? 0));
    setShowCommissionModal(true);
  };

  const openCourierTariffModal = (c: Courier) => {
    setTariffCourier(c);

    const hasOverride = c.personalFeeOverride != null;
    setCourierUseGlobal(!hasOverride);

    if (hasOverride) {
      setCourierFeeInput(String(Math.max(0, Math.round(Number(c.personalFeeOverride) || 0))));
    } else {
      const base = activeTariff?.fee ?? 0;
      setCourierFeeInput(String(Math.max(0, Math.round(Number(base) || 0))));
    }

    setShowCourierTariffModal(true);
  };

  const refreshCouriersOnce = async () => {
    const data = (await apiFetch(`/couriers?page=1&limit=200`)) as any;
    setCouriers(data?.items || []);
  };

  const refreshTariffOnce = async () => {
    const t = (await apiFetch(`/couriers/tariff/active`)) as any;
    if (t && typeof t.fee === "number") {
      setActiveTariff({
        fee: safeNumber(t.fee, 0),
        startsAt: t.startsAt ?? null,
        endsAt: t.endsAt ?? null,
      });
      setGlobalFeeInput(String(Math.max(0, Math.round(Number(t.fee) || 0))));
    } else {
      setActiveTariff(null);
    }
  };

  const refreshCommissionOnce = async () => {
    const res = (await apiFetch(`/couriers/commission/default`)) as any;
    const pct = Math.max(0, Math.min(100, Math.round(Number(res?.pct) || 0)));
    setGlobalCommissionPct(pct);
    setGlobalCommissionInput(String(pct));
  };

  const saveGlobalTariff = async () => {
    const fee = Math.max(0, Math.round(Number(globalFeeInput) || 0));
    if (!fee) {
      setTariffError("fee must be > 0");
      return;
    }

    try {
      setTariffSaving(true);
      setTariffError(null);
      await apiFetch(`/couriers/tariff`, {
        method: "POST",
        body: JSON.stringify({ fee }),
      });

      await refreshTariffOnce();
      setShowTariffModal(false);
    } catch (e: any) {
      setTariffError(e?.message || "Ошибка сохранения тарифа");
    } finally {
      setTariffSaving(false);
    }
  };

  const saveGlobalCommission = async () => {
    const pct = Math.max(0, Math.min(100, Math.round(Number(globalCommissionInput) || 0)));

    try {
      setTariffSaving(true);
      setTariffError(null);
      await apiFetch(`/couriers/commission/default`, {
        method: "POST",
        body: JSON.stringify({ pct }),
      });

      await refreshCommissionOnce();
      setShowCommissionModal(false);
    } catch (e: any) {
      setTariffError(e?.message || "Ошибка сохранения комиссии");
    } finally {
      setTariffSaving(false);
    }
  };

  const saveCourierTariff = async () => {
    if (!tariffCourier) return;

    try {
      setTariffSaving(true);
      setTariffError(null);

      if (courierUseGlobal) {
        await apiFetch(`/couriers/${tariffCourier.id}/personal-fee`, {
          method: "PATCH",
          body: JSON.stringify({ fee: null }),
        });
      } else {
        const fee = Math.max(0, Math.round(Number(courierFeeInput) || 0));
        if (!fee) {
          setTariffError("fee must be > 0");
          setTariffSaving(false);
          return;
        }

        await apiFetch(`/couriers/${tariffCourier.id}/personal-fee`, {
          method: "PATCH",
          body: JSON.stringify({ fee }),
        });
      }

      await refreshCouriersOnce();
      setShowCourierTariffModal(false);
      setTariffCourier(null);
    } catch (e: any) {
      setTariffError(e?.message || "Ошибка сохранения тарифа курьера");
    } finally {
      setTariffSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="text-slate-900 text-lg font-semibold mb-2">Загрузка курьеров</div>
          <div className="text-slate-500">Подготавливаем список и статистику...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-rose-200 bg-white p-8 shadow-sm">
          <div className="text-rose-700 text-lg font-semibold mb-2">Ошибка загрузки</div>
          <div className="text-slate-700">{error}</div>
        </div>
      </div>
    );
  }

  return (
    <div ref={rootRef} className="p-6 bg-[#f5f7fb] min-h-screen">
      <div className="max-w-none">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <h1 className="text-4xl font-bold tracking-tight text-slate-900">Курьеры</h1>
            <p className="mt-2 text-sm text-slate-500">
              Управление курьерами, тарифами, комиссиями и онлайн-статистикой
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <button
              className="rounded-2xl bg-emerald-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-emerald-700"
            >
              Выгрузить в Excel
            </button>

            <button
              className="rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-95"
            >
              Добавить курьера
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4 mb-6">
          <StatCard
            title="Всего курьеров"
            value={String(stat.total)}
            subtitle={`Активные: ${stat.active} · Заблокированные: ${stat.blocked}`}
            gradient="linear-gradient(135deg, #1bc5bd 0%, #0bb783 100%)"
          />
          <StatCard
            title="На линии"
            value={String(stat.online)}
            subtitle={`Оффлайн: ${stat.offline}`}
            gradient="linear-gradient(135deg, #3699ff 0%, #3f51f7 100%)"
          />
          <StatCard
            title="Тариф по умолчанию"
            value={activeTariff ? moneyKZT(activeTariff.fee) : "—"}
            subtitle={tariffLoading ? "Обновление..." : "Выплата курьеру"}
            gradient="linear-gradient(135deg, #8950fc 0%, #d65db1 100%)"
          />
          <StatCard
            title="Комиссия сервиса"
            value={commissionLoading ? "…" : pctText(globalCommissionPct)}
            subtitle={`На заказе: ${stat.busy}`}
            gradient="linear-gradient(135deg, #ff6b6b 0%, #f64e60 100%)"
          />
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.2fr_0.8fr] mb-6">
          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-bold text-slate-900">Фильтр и поиск</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Телефон, имя, фамилия, ИИН, статус активности и онлайн
                </p>
              </div>

              <button
                className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100"
                onClick={() => {
                  setQ("");
                  setOnlineFilter("all");
                  setActiveFilter("all");
                }}
              >
                Сброс
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_220px_220px]">
              <div>
                <label className="mb-2 block text-sm font-semibold text-slate-700">Поиск</label>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Поиск: телефон / имя / ИИН"
                />
              </div>

              <div>
                <label className="mb-2 block text-sm font-semibold text-slate-700">Статус</label>
                <select
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                  value={activeFilter}
                  onChange={(e) => setActiveFilter(e.target.value as any)}
                >
                  <option value="all">Все</option>
                  <option value="active">Только активные</option>
                  <option value="blocked">Только заблокированные</option>
                </select>
              </div>

              <div>
                <label className="mb-2 block text-sm font-semibold text-slate-700">Онлайн</label>
                <select
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                  value={onlineFilter}
                  onChange={(e) => setOnlineFilter(e.target.value as any)}
                >
                  <option value="all">Все</option>
                  <option value="online">Только онлайн</option>
                  <option value="offline">Только оффлайн</option>
                </select>
              </div>
            </div>

            <div className="mt-4 flex flex-wrap gap-3">
              <span className="rounded-full bg-emerald-50 px-4 py-2 text-xs font-semibold text-emerald-700">
                Найдено: {filtered.length}
              </span>
              <span className="rounded-full bg-blue-50 px-4 py-2 text-xs font-semibold text-blue-700">
                На линии: {counts.online}
              </span>
              <span className="rounded-full bg-slate-100 px-4 py-2 text-xs font-semibold text-slate-700">
                Оффлайн: {counts.offline}
              </span>
              <button
                className={`rounded-full px-4 py-2 text-xs font-semibold transition ${
                  showStats
                    ? "bg-slate-900 text-white"
                    : "bg-slate-100 text-slate-700"
                }`}
                onClick={() => setShowStats((v) => !v)}
              >
                {showStats ? "Скрыть статистику" : "Показать статистику"}
              </button>
            </div>
          </div>

          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold text-slate-900 mb-5">Тарифы и комиссия</h2>

            <div className="grid grid-cols-1 gap-4">
              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Тариф по умолчанию</div>
                <div className="mt-1 text-2xl font-bold text-slate-900">
                  {activeTariff ? moneyKZT(activeTariff.fee) : "—"}
                </div>
                {activeTariff?.startsAt ? (
                  <div className="mt-2 text-xs text-slate-500">
                    Начало: {String(activeTariff.startsAt).slice(0, 19).replace("T", " ")}
                  </div>
                ) : null}
                <div className="mt-3">
                  <button
                    className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
                    onClick={openGlobalTariffModal}
                  >
                    Изменить тариф
                  </button>
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Комиссия сервиса</div>
                <div className="mt-1 text-2xl font-bold text-slate-900">
                  {pctText(globalCommissionPct)}
                </div>
                <div className="mt-2 text-xs text-slate-500">
                  Рассчитывается от выплаты курьеру
                </div>
                <div className="mt-3">
                  <button
                    className="rounded-xl bg-blue-600 px-4 py-2 text-sm font-semibold text-white"
                    onClick={openGlobalCommissionModal}
                  >
                    Изменить комиссию
                  </button>
                </div>
              </div>

              {(tariffError || summaryError) && (
                <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
                  {tariffError || summaryError}
                </div>
              )}
            </div>
          </div>
        </div>

        <div className={`grid gap-6 ${showStats ? "xl:grid-cols-[1.2fr_0.8fr]" : "grid-cols-1"}`}>
          <div className="rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
            <div className="border-b border-slate-200 px-6 py-5">
              <h2 className="text-2xl font-bold text-slate-900">Список курьеров</h2>
              <p className="mt-1 text-sm text-slate-500">
                Нажми на строку, чтобы открыть карточку курьера
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="min-w-full">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/80">
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Курьер
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      ИИН
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Статус
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Онлайн
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Тариф
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Комиссия
                    </th>
                    <th className="px-6 py-4 text-right text-xs font-bold uppercase tracking-wider text-slate-500">
                      Действия
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {filtered.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="px-6 py-16 text-center">
                        <div className="text-5xl mb-3">🛵</div>
                        <div className="text-xl font-bold text-slate-900 mb-2">Ничего не найдено</div>
                        <div className="text-sm text-slate-500">
                          Измени поиск или параметры фильтра
                        </div>
                      </td>
                    </tr>
                  ) : (
                    filtered.map((c) => {
                      const fullName = `${c.firstName ?? ""} ${c.lastName ?? ""}`.trim() || "-";
                      const active = (c.isActive ?? true) === true;

                      const onlineMain = c.isOnline
                        ? `На линии · ${formatDurationHM(c.onlineForSec)}`
                        : `Оффлайн · был ${formatAgoHM(c.lastSeenAt ?? c.lastActiveAt)} назад`;

                      const offlineSub =
                        !c.isOnline && c.lastSessionSec != null
                          ? `последняя сессия: ${formatDurationHM(c.lastSessionSec)}`
                          : null;

                      const isIndTariff = c.personalFeeOverride != null;
                      const shownFee = isIndTariff ? c.personalFeeOverride : activeTariff?.fee ?? null;

                      const isIndComm = c.courierCommissionPctOverride != null;
                      const shownPct = isIndComm ? c.courierCommissionPctOverride : globalCommissionPct;

                      const avatarSrc = resolveAvatarSrc(c.avatarUrl);

                      return (
                        <tr
                          key={c.id}
                          className="cursor-pointer border-b border-slate-100 transition hover:bg-slate-50"
                          onClick={() => router.push(`/layout-20/couriers/${c.userId}`)}
                          title="Открыть карточку курьера"
                        >
                          <td className="px-6 py-5 align-top">
                            <div className="flex items-start gap-4">
                              <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-2xl bg-slate-100 text-sm font-bold text-slate-700">
                                {avatarSrc ? (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img
                                    src={avatarSrc}
                                    alt="avatar"
                                    className="h-full w-full object-cover"
                                  />
                                ) : (
                                  initials(c.firstName, c.lastName)
                                )}
                              </div>

                              <div className="min-w-0">
                                <div className="text-sm font-bold text-slate-900">{fullName}</div>
                                <div className="mt-1 text-xs text-slate-500">{c.phone || "-"}</div>
                              </div>
                            </div>
                          </td>

                          <td className="px-6 py-5 align-top">
                            <div className="text-sm font-semibold text-slate-800">{c.iin || "-"}</div>
                          </td>

                          <td className="px-6 py-5 align-top">
                            <div className="flex flex-col gap-2">
                              <span
                                className={`inline-flex w-fit rounded-full border px-3 py-2 text-xs font-semibold ${
                                  active
                                    ? "bg-emerald-50 text-emerald-700 border-emerald-200"
                                    : "bg-rose-50 text-rose-700 border-rose-200"
                                }`}
                              >
                                {active ? "Активный" : "Заблокирован"}
                              </span>

                              <span
                                className={`inline-flex w-fit items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${
                                  c.isOnline
                                    ? "bg-blue-50 text-blue-700 border-blue-200"
                                    : "bg-slate-50 text-slate-700 border-slate-200"
                                }`}
                              >
                                <span
                                  className={`h-2 w-2 rounded-full ${
                                    c.isOnline ? "bg-emerald-500" : "bg-slate-400"
                                  }`}
                                />
                                {c.isOnline ? "Онлайн" : "Оффлайн"}
                              </span>
                            </div>
                          </td>

                          <td className="px-6 py-5 align-top">
                            <div className="text-sm font-bold text-slate-900">{onlineMain}</div>
                            {offlineSub ? (
                              <div className="mt-1 text-xs text-slate-500">{offlineSub}</div>
                            ) : null}
                          </td>

                          <td className="px-6 py-5 align-top">
                            <div className="flex items-center gap-2 mb-2">
                              <span
                                className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${
                                  isIndTariff
                                    ? "bg-blue-50 text-blue-700 border-blue-200"
                                    : "bg-slate-50 text-slate-700 border-slate-200"
                                }`}
                              >
                                {isIndTariff ? "Индивидуальный" : "Общий"}
                              </span>
                            </div>

                            <div className="text-sm font-bold text-slate-900">{moneyKZT(shownFee)}</div>

                            <button
                              className="mt-3 rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 transition hover:bg-slate-50"
                              onClick={(e) => {
                                e.stopPropagation();
                                openCourierTariffModal(c);
                              }}
                            >
                              Изменить
                            </button>
                          </td>

                          <td className="px-6 py-5 align-top">
                            <div className="flex items-center gap-2 mb-2">
                              <span
                                className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${
                                  isIndComm
                                    ? "bg-blue-50 text-blue-700 border-blue-200"
                                    : "bg-slate-50 text-slate-700 border-slate-200"
                                }`}
                              >
                                {isIndComm ? "Индивидуальная" : "Общая"}
                              </span>
                            </div>

                            <div className="text-sm font-bold text-slate-900">{pctText(shownPct)}</div>
                            <div className="mt-1 text-xs text-slate-500">
                              от тарифа: {commissionAmountKZT(shownFee, shownPct)}
                            </div>
                          </td>

                          <td className="px-6 py-5 align-top text-right">
                            <button
                              className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white"
                              onClick={(e) => {
                                e.stopPropagation();
                                router.push(`/layout-20/couriers/${c.userId}`);
                              }}
                            >
                              Редактировать
                            </button>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {showStats ? (
            <div className="space-y-6">
              <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                <div className="mb-5 flex items-center justify-between gap-3">
                  <div>
                    <h2 className="text-2xl font-bold text-slate-900">Статистика</h2>
                    <p className="mt-1 text-sm text-slate-500">
                      Оперативная сводка по статусам курьеров
                    </p>
                  </div>

                  <button
                    className="rounded-xl border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700"
                    onClick={() => setStatsExpanded((v) => !v)}
                  >
                    {statsExpanded ? "Скрыть графики" : "Показать графики"}
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Всего</div>
                    <div className="mt-1 text-3xl font-bold text-slate-900">{stat.total}</div>
                  </div>
                  <div className="rounded-2xl bg-emerald-50 p-4">
                    <div className="text-xs font-medium text-emerald-700">На линии</div>
                    <div className="mt-1 text-3xl font-bold text-emerald-700">{stat.online}</div>
                  </div>
                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Оффлайн</div>
                    <div className="mt-1 text-3xl font-bold text-slate-900">{stat.offline}</div>
                  </div>
                  <div className="rounded-2xl bg-amber-50 p-4">
                    <div className="text-xs font-medium text-amber-700">На заказе</div>
                    <div className="mt-1 text-3xl font-bold text-amber-700">{stat.busy}</div>
                  </div>
                  <div className="rounded-2xl bg-blue-50 p-4">
                    <div className="text-xs font-medium text-blue-700">Активные</div>
                    <div className="mt-1 text-3xl font-bold text-blue-700">{stat.active}</div>
                  </div>
                  <div className="rounded-2xl bg-rose-50 p-4">
                    <div className="text-xs font-medium text-rose-700">Заблок.</div>
                    <div className="mt-1 text-3xl font-bold text-rose-700">{stat.blocked}</div>
                  </div>
                </div>
              </div>

              {statsExpanded ? (
                <>
                  <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                    <div className="text-lg font-bold text-slate-900 mb-4">Статусы курьеров</div>
                    <ReactApexChart options={pieOptions} series={pieSeries} type="pie" height={260} />
                  </div>

                  <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                    <div className="mb-4 flex items-center justify-between gap-3">
                      <div className="text-lg font-bold text-slate-900">На линии по часам</div>
                      <div className="text-xs text-slate-500">
                        {timelineLoading ? "загрузка…" : timeline.length ? "готово" : "—"}
                      </div>
                    </div>

                    {timelineError ? (
                      <div className="text-sm text-slate-500 mb-3">{timelineError}</div>
                    ) : null}

                    {timeline.length ? (
                      <ReactApexChart
                        options={timelineChart.options}
                        series={timelineChart.series}
                        type="area"
                        height={220}
                      />
                    ) : (
                      <div className="rounded-2xl border border-dashed border-slate-300 px-4 py-10 text-center text-sm text-slate-500">
                        Нет данных
                      </div>
                    )}
                  </div>

                  <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                    <div className="mb-4 flex items-center justify-between gap-3">
                      <div className="text-lg font-bold text-slate-900">Онлайн по дням</div>
                      <div className="text-xs text-slate-500">
                        {seriesLoading ? "загрузка…" : series.length ? "готово" : "—"}
                      </div>
                    </div>

                    {seriesError ? (
                      <div className="text-sm text-slate-500 mb-3">{seriesError}</div>
                    ) : null}

                    {series.length ? (
                      <ReactApexChart
                        options={seriesChart.options}
                        series={seriesChart.series}
                        type="line"
                        height={220}
                      />
                    ) : (
                      <div className="rounded-2xl border border-dashed border-slate-300 px-4 py-10 text-center text-sm text-slate-500">
                        Нет данных
                      </div>
                    )}
                  </div>
                </>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>

      {showTariffModal ? (
        <div className="fixed inset-0 z-[9999] bg-black/35 flex items-center justify-center p-4" onClick={() => setShowTariffModal(false)}>
          <div className="w-full max-w-xl rounded-3xl border border-slate-200 bg-white shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-3 border-b border-slate-200 px-6 py-4">
              <div className="text-xl font-bold text-slate-900">Тариф для всех</div>
              <button className="rounded-xl bg-slate-100 px-3 py-2 text-sm font-semibold text-slate-700" onClick={() => setShowTariffModal(false)}>
                ✕
              </button>
            </div>

            <div className="px-6 py-5">
              <div className="text-sm text-slate-500">
                Установит новый активный тариф по умолчанию. Индивидуальные переопределения у курьеров сохраняются.
              </div>

              <div className="mt-4">
                <label className="mb-2 block text-sm font-semibold text-slate-700">Выплата курьеру (₸)</label>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  type="number"
                  min={0}
                  value={globalFeeInput}
                  onChange={(e) => setGlobalFeeInput(e.target.value)}
                  placeholder="Например: 1500"
                />
              </div>

              {tariffError ? (
                <div className="mt-3 text-sm font-semibold text-rose-700">{tariffError}</div>
              ) : null}
            </div>

            <div className="flex justify-end gap-3 border-t border-slate-200 px-6 py-4">
              <button className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700" onClick={() => setShowTariffModal(false)} disabled={tariffSaving}>
                Отмена
              </button>
              <button className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white" onClick={saveGlobalTariff} disabled={tariffSaving}>
                {tariffSaving ? "Сохранение…" : "Сохранить"}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {showCommissionModal ? (
        <div className="fixed inset-0 z-[9999] bg-black/35 flex items-center justify-center p-4" onClick={() => setShowCommissionModal(false)}>
          <div className="w-full max-w-xl rounded-3xl border border-slate-200 bg-white shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-3 border-b border-slate-200 px-6 py-4">
              <div className="text-xl font-bold text-slate-900">Комиссия для всех</div>
              <button className="rounded-xl bg-slate-100 px-3 py-2 text-sm font-semibold text-slate-700" onClick={() => setShowCommissionModal(false)}>
                ✕
              </button>
            </div>

            <div className="px-6 py-5">
              <div className="text-sm text-slate-500">
                Это глобальная комиссия сервиса от выплаты курьеру. Индивидуальные override сохраняются.
              </div>

              <div className="mt-4">
                <label className="mb-2 block text-sm font-semibold text-slate-700">Комиссия (%)</label>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  type="number"
                  min={0}
                  max={100}
                  value={globalCommissionInput}
                  onChange={(e) => setGlobalCommissionInput(e.target.value)}
                  placeholder="Например: 15"
                />
              </div>

              {tariffError ? (
                <div className="mt-3 text-sm font-semibold text-rose-700">{tariffError}</div>
              ) : null}
            </div>

            <div className="flex justify-end gap-3 border-t border-slate-200 px-6 py-4">
              <button className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700" onClick={() => setShowCommissionModal(false)} disabled={tariffSaving}>
                Отмена
              </button>
              <button className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white" onClick={saveGlobalCommission} disabled={tariffSaving}>
                {tariffSaving ? "Сохранение…" : "Сохранить"}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {showCourierTariffModal ? (
        <div className="fixed inset-0 z-[9999] bg-black/35 flex items-center justify-center p-4" onClick={() => setShowCourierTariffModal(false)}>
          <div className="w-full max-w-xl rounded-3xl border border-slate-200 bg-white shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between gap-3 border-b border-slate-200 px-6 py-4">
              <div className="text-xl font-bold text-slate-900">Тариф курьера</div>
              <button
                className="rounded-xl bg-slate-100 px-3 py-2 text-sm font-semibold text-slate-700"
                onClick={() => {
                  setShowCourierTariffModal(false);
                  setTariffCourier(null);
                }}
              >
                ✕
              </button>
            </div>

            <div className="px-6 py-5">
              <div className="text-sm text-slate-500">
                Курьер:{" "}
                <b>
                  {tariffCourier
                    ? `${tariffCourier.firstName ?? ""} ${tariffCourier.lastName ?? ""}`.trim() || tariffCourier.phone
                    : "—"}
                </b>
              </div>

              <div className="mt-4 rounded-2xl bg-slate-50 p-4">
                <label className="inline-flex items-center gap-3 text-sm font-semibold text-slate-800">
                  <input
                    type="checkbox"
                    checked={courierUseGlobal}
                    onChange={(e) => setCourierUseGlobal(e.target.checked)}
                  />
                  Использовать общий тариф
                </label>

                <div className="mt-2 text-sm text-slate-500">
                  Общий тариф сейчас: <b>{activeTariff ? moneyKZT(activeTariff.fee) : "—"}</b>
                </div>
              </div>

              {!courierUseGlobal ? (
                <div className="mt-4">
                  <label className="mb-2 block text-sm font-semibold text-slate-700">
                    Индивидуальная выплата (₸)
                  </label>
                  <input
                    className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                    type="number"
                    min={0}
                    value={courierFeeInput}
                    onChange={(e) => setCourierFeeInput(e.target.value)}
                    placeholder="Например: 1800"
                  />
                </div>
              ) : null}

              {tariffError ? (
                <div className="mt-3 text-sm font-semibold text-rose-700">{tariffError}</div>
              ) : null}
            </div>

            <div className="flex justify-end gap-3 border-t border-slate-200 px-6 py-4">
              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
                onClick={() => {
                  setShowCourierTariffModal(false);
                  setTariffCourier(null);
                }}
                disabled={tariffSaving}
              >
                Отмена
              </button>
              <button className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white" onClick={saveCourierTariff} disabled={tariffSaving}>
                {tariffSaving ? "Сохранение…" : "Сохранить"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}  