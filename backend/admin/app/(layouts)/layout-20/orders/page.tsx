"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

type OrderRow = {
  id: string;
  number?: number | null;
  createdAt: string;
  status: string;
  total: number;
  phone?: string | null;
  restaurant?: {
    id: string;
    nameRu?: string | null;
    nameKk?: string | null;
  };
  courier?: {
    userId?: string;
    firstName?: string | null;
    lastName?: string | null;
    phone?: string | null;
  } | null;
};

function isDigitsOnly(v: string) {
  return /^[0-9]+$/.test(v);
}

function formatCourier(c: OrderRow["courier"]) {
  if (!c) return "Не назначен";
  const name = `${c.firstName ?? ""} ${c.lastName ?? ""}`.trim();
  const phone = c.phone ? ` (${c.phone})` : "";
  return (name || "Курьер") + phone;
}

function formatRestaurant(r: OrderRow["restaurant"]) {
  if (!r) return "-";
  return (r.nameRu ?? r.nameKk ?? "-") as string;
}

function formatMoney(value: number | null | undefined) {
  return `${Number(value ?? 0).toLocaleString("ru-RU")} ₸`;
}

function formatDate(value: string) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString("ru-RU");
}

function getStatusUi(status?: string) {
  const s = (status ?? "").toUpperCase();

  if (["DELIVERED", "COMPLETED"].includes(s)) {
    return {
      label: "Доставлен",
      pill: "bg-emerald-50 text-emerald-700 border-emerald-200",
      dot: "bg-emerald-500",
    };
  }

  if (["CANCELLED", "CANCELED", "REJECTED"].includes(s)) {
    return {
      label: "Отменён",
      pill: "bg-rose-50 text-rose-700 border-rose-200",
      dot: "bg-rose-500",
    };
  }

  if (
    ["COURIER_ASSIGNED", "ASSIGNED", "ON_THE_WAY", "IN_DELIVERY", "PICKED_UP"].includes(s)
  ) {
    return {
      label: "В доставке",
      pill: "bg-blue-50 text-blue-700 border-blue-200",
      dot: "bg-blue-500",
    };
  }

  if (["CREATED", "NEW", "PENDING", "PREPARING"].includes(s)) {
    return {
      label: "Новый",
      pill: "bg-amber-50 text-amber-700 border-amber-200",
      dot: "bg-amber-500",
    };
  }

  return {
    label: status || "—",
    pill: "bg-slate-50 text-slate-700 border-slate-200",
    dot: "bg-slate-400",
  };
}

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

export default function OrdersPage() {
  const router = useRouter();

  const [rows, setRows] = useState<OrderRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState("");

  async function load() {
    const data = (await apiFetch(`/orders?limit=200`)) as any;

    const list: OrderRow[] = Array.isArray(data)
      ? data
      : Array.isArray(data?.items)
      ? data.items
      : Array.isArray(data?.data)
      ? data.data
      : [];

    setRows(list);
  }

  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        setLoading(true);
        setError(null);
        await load();
      } catch (e: any) {
        if (!alive) return;
        setError(e?.message || "Ошибка загрузки");
      } finally {
        if (!alive) return;
        setLoading(false);
      }
    })();

    return () => {
      alive = false;
    };
  }, []);

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return rows;

    const sDigits = isDigitsOnly(s);

    return rows.filter((o) => {
      const id = (o.id ?? "").toLowerCase();
      const num = o.number == null ? "" : String(o.number);
      const phone = (o.phone ?? "").toLowerCase();
      const status = (o.status ?? "").toLowerCase();
      const rest = formatRestaurant(o.restaurant).toLowerCase();
      const cour = formatCourier(o.courier).toLowerCase();

      if (sDigits) {
        return num.includes(s) || phone.includes(s);
      }

      return (
        id.includes(s) ||
        num.includes(s) ||
        phone.includes(s) ||
        status.includes(s) ||
        rest.includes(s) ||
        cour.includes(s)
      );
    });
  }, [rows, q]);

  const stats = useMemo(() => {
    const delivered = rows.filter((o) =>
      ["DELIVERED", "COMPLETED"].includes((o.status ?? "").toUpperCase())
    );
    const cancelled = rows.filter((o) =>
      ["CANCELLED", "CANCELED", "REJECTED"].includes((o.status ?? "").toUpperCase())
    );
    const active = rows.filter((o) =>
      ["COURIER_ASSIGNED", "ASSIGNED", "ON_THE_WAY", "IN_DELIVERY", "PICKED_UP", "CREATED", "NEW", "PENDING", "PREPARING"].includes(
        (o.status ?? "").toUpperCase()
      )
    );

    const revenue = delivered.reduce((sum, o) => sum + Number(o.total ?? 0), 0);
    const avg = delivered.length ? Math.round(revenue / delivered.length) : 0;

    return {
      total: rows.length,
      delivered: delivered.length,
      cancelled: cancelled.length,
      active: active.length,
      revenue,
      avg,
    };
  }, [rows]);

  if (loading) {
    return (
      <div className="p-6">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="text-slate-900 text-lg font-semibold mb-2">Загрузка заказов</div>
          <div className="text-slate-500">Подготавливаем список и метрики...</div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="rounded-3xl border border-rose-200 bg-white p-8 shadow-sm">
          <div className="text-rose-700 text-lg font-semibold mb-2">Ошибка загрузки</div>
          <div className="text-slate-700 mb-4">{error}</div>
          <button
            className="rounded-xl bg-slate-900 px-4 py-2 text-white"
            onClick={() => router.refresh()}
          >
            Обновить
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-[#f5f7fb] min-h-screen">
      <div className="max-w-none">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <h1 className="text-4xl font-bold tracking-tight text-slate-900">Заказы</h1>
            <p className="mt-2 text-sm text-slate-500">
              Список заказов, быстрый поиск и краткая сводка по статусам
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <div className="text-xs font-medium text-slate-500">Всего заказов</div>
              <div className="text-2xl font-bold text-slate-900">{stats.total}</div>
            </div>

            <button
              onClick={() => load()}
              className="rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-95"
            >
              Обновить
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4 mb-6">
          <StatCard
            title="Всего заказов"
            value={String(stats.total)}
            subtitle="Полный список заказов в системе"
            gradient="linear-gradient(135deg, #1bc5bd 0%, #0bb783 100%)"
          />
          <StatCard
            title="Доставлено"
            value={String(stats.delivered)}
            subtitle={`Средний чек: ${formatMoney(stats.avg)}`}
            gradient="linear-gradient(135deg, #3699ff 0%, #3f51f7 100%)"
          />
          <StatCard
            title="Выручка"
            value={formatMoney(stats.revenue)}
            subtitle="Сумма total по доставленным заказам"
            gradient="linear-gradient(135deg, #8950fc 0%, #d65db1 100%)"
          />
          <StatCard
            title="Активные / Отменённые"
            value={`${stats.active} / ${stats.cancelled}`}
            subtitle="Текущая картина по статусам"
            gradient="linear-gradient(135deg, #ff6b6b 0%, #f64e60 100%)"
          />
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.2fr_0.8fr] mb-6">
          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-bold text-slate-900">Фильтр и поиск</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Номер заказа, UUID, статус, телефон, ресторан или курьер
                </p>
              </div>

              <button
                className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100"
                onClick={() => setQ("")}
              >
                Сброс
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4">
              <div>
                <label className="mb-2 block text-sm font-semibold text-slate-700">
                  Поиск
                </label>
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Например: 21 / delivered / +7707 / ВМЫ / Парвиз"
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                />
              </div>

              <div className="rounded-2xl border border-blue-100 bg-blue-50 px-4 py-4">
                <div className="text-sm font-semibold text-slate-900 mb-1">Подсказка</div>
                <div className="text-sm text-slate-600">
                  Лучше всего искать по номеру заказа. UUID оставлен как техническое поле.
                </div>
              </div>
            </div>
          </div>

          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold text-slate-900 mb-5">Быстрая сводка</h2>

            <div className="grid grid-cols-2 gap-4">
              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Найдено</div>
                <div className="mt-1 text-3xl font-bold text-slate-900">{filtered.length}</div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Всего</div>
                <div className="mt-1 text-3xl font-bold text-slate-900">{rows.length}</div>
              </div>

              <div className="rounded-2xl bg-emerald-50 p-4">
                <div className="text-xs font-medium text-emerald-700">Доставлено</div>
                <div className="mt-1 text-3xl font-bold text-emerald-700">{stats.delivered}</div>
              </div>

              <div className="rounded-2xl bg-rose-50 p-4">
                <div className="text-xs font-medium text-rose-700">Отменено</div>
                <div className="mt-1 text-3xl font-bold text-rose-700">{stats.cancelled}</div>
              </div>
            </div>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
          <div className="border-b border-slate-200 px-6 py-5">
            <h2 className="text-2xl font-bold text-slate-900">Список заказов</h2>
            <p className="mt-1 text-sm text-slate-500">
              Нажми на строку, чтобы открыть карточку заказа
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/80">
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    №
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Заказ
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Дата
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Статус
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Сумма
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Ресторан
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Курьер
                  </th>
                </tr>
              </thead>

              <tbody>
                {filtered.map((o) => {
                  const ui = getStatusUi(o.status);
                  const orderNo = o.number ?? null;

                  return (
                    <tr
                      key={o.id}
                      onClick={() => router.push(`/layout-20/orders/${o.id}`)}
                      className="cursor-pointer border-b border-slate-100 transition hover:bg-slate-50"
                      title="Открыть заказ"
                    >
                      <td className="px-6 py-5 align-top">
                        <div className="text-base font-bold text-blue-600">
                          {orderNo != null ? `#${orderNo}` : "—"}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="flex items-start gap-4">
                          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-slate-900 text-sm font-bold text-white shadow-sm">
                            {orderNo != null ? String(orderNo).slice(-2) : "ID"}
                          </div>

                          <div className="min-w-0">
                            <div className="truncate text-sm font-bold text-slate-900">
                              {formatRestaurant(o.restaurant)}
                            </div>
                            <div className="mt-1 truncate text-xs text-slate-500">{o.id}</div>
                            {o.phone ? (
                              <div className="mt-1 text-xs text-slate-400">{o.phone}</div>
                            ) : null}
                          </div>
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {formatDate(o.createdAt)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <span
                          className={`inline-flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${ui.pill}`}
                        >
                          <span className={`h-2 w-2 rounded-full ${ui.dot}`} />
                          {ui.label}
                        </span>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-bold text-slate-900">
                          {formatMoney(o.total)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {formatRestaurant(o.restaurant)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {formatCourier(o.courier)}
                        </div>
                        {!o.courier && (
                          <div className="mt-1 text-xs text-slate-400">
                            Курьер ещё не назначен
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}

                {!filtered.length && (
                  <tr>
                    <td colSpan={7} className="px-6 py-16 text-center">
                      <div className="text-5xl mb-3">📦</div>
                      <div className="text-xl font-bold text-slate-900 mb-2">
                        Ничего не найдено
                      </div>
                      <div className="text-sm text-slate-500">
                        Измени запрос поиска или сбрось фильтр
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap gap-3 border-t border-slate-200 px-6 py-4 bg-slate-50/60">
            <span className="rounded-full bg-emerald-50 px-4 py-2 text-xs font-semibold text-emerald-700">
              Доставлено: {stats.delivered}
            </span>
            <span className="rounded-full bg-blue-50 px-4 py-2 text-xs font-semibold text-blue-700">
              Активные: {stats.active}
            </span>
            <span className="rounded-full bg-rose-50 px-4 py-2 text-xs font-semibold text-rose-700">
              Отменённые: {stats.cancelled}
            </span>
            <span className="rounded-full bg-amber-50 px-4 py-2 text-xs font-semibold text-amber-700">
              Средний чек: {formatMoney(stats.avg)}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}