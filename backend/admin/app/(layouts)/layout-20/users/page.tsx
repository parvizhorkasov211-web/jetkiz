"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

type Segment = "NEW" | "REGULAR" | "VIP";

type Row = {
  id: string;
  phone: string;
  name: string | null;
  ordersCount: number;
  lastOrderAt: string | null;
  lastOrderStatus: string | null;
  lastOrderTotal: number | null;
  segment: Segment;
};

function segmentLabel(s: Segment) {
  if (s === "NEW") return "Первичный";
  if (s === "VIP") return "VIP";
  return "Постоянный";
}

function segmentClass(s: Segment) {
  if (s === "NEW") {
    return "bg-amber-50 text-amber-700 border-amber-200";
  }
  if (s === "VIP") {
    return "bg-emerald-50 text-emerald-700 border-emerald-200";
  }
  return "bg-blue-50 text-blue-700 border-blue-200";
}

function formatDate(value: string | null) {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString("ru-RU");
}

function formatMoney(value: number | null) {
  if (value == null) return "-";
  return `${Number(value).toLocaleString("ru-RU")} ₸`;
}

function getStatusUi(status?: string | null) {
  const s = (status ?? "").toUpperCase();

  if (["DELIVERED", "COMPLETED"].includes(s)) {
    return {
      label: "Доставлен",
      cls: "bg-emerald-50 text-emerald-700 border-emerald-200",
      dot: "bg-emerald-500",
    };
  }

  if (["CANCELLED", "CANCELED", "REJECTED"].includes(s)) {
    return {
      label: "Отменён",
      cls: "bg-rose-50 text-rose-700 border-rose-200",
      dot: "bg-rose-500",
    };
  }

  if (
    ["COURIER_ASSIGNED", "ASSIGNED", "ON_THE_WAY", "IN_DELIVERY", "PICKED_UP"].includes(s)
  ) {
    return {
      label: "В доставке",
      cls: "bg-blue-50 text-blue-700 border-blue-200",
      dot: "bg-blue-500",
    };
  }

  if (["CREATED", "NEW", "PENDING", "PREPARING"].includes(s)) {
    return {
      label: "Новый",
      cls: "bg-amber-50 text-amber-700 border-amber-200",
      dot: "bg-amber-500",
    };
  }

  return {
    label: status || "-",
    cls: "bg-slate-50 text-slate-700 border-slate-200",
    dot: "bg-slate-400",
  };
}

export default function UsersPage() {
  const router = useRouter();

  const [q, setQ] = useState("");
  const [segment, setSegment] = useState("");
  const [page, setPage] = useState(1);

  const [items, setItems] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const limit = 20;

  const query = useMemo(() => {
    const sp = new URLSearchParams();
    if (q) sp.set("q", q);
    if (segment) sp.set("segment", segment);
    sp.set("page", String(page));
    sp.set("limit", String(limit));
    return sp.toString();
  }, [q, segment, page]);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setErr(null);

    apiFetch(`/users/customers?${query}`)
      .then((data: any) => {
        if (!alive) return;

        const list = Array.isArray(data)
          ? data
          : Array.isArray(data?.items)
          ? data.items
          : Array.isArray(data?.data)
          ? data.data
          : [];

        const totalValue =
          Number(data?.meta?.total ?? data?.total ?? list.length) || 0;

        setItems(list);
        setTotal(totalValue);
      })
      .catch((e: any) => {
        if (!alive) return;
        setItems([]);
        setTotal(0);
        setErr(e?.message || "Ошибка загрузки пользователей");
        console.error("UsersPage load error:", e);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });

    return () => {
      alive = false;
    };
  }, [query]);

  const pages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="p-6 bg-[#f5f7fb] min-h-screen">
      <div className="max-w-none">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <h1 className="text-4xl font-bold tracking-tight text-slate-900">
              Пользователи
            </h1>
            <p className="mt-2 text-sm text-slate-500">
              Клиенты сервиса, история активности и сегментация
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <div className="text-xs font-medium text-slate-500">Всего клиентов</div>
              <div className="text-2xl font-bold text-slate-900">{total}</div>
            </div>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm mb-6">
          <div className="mb-5 flex items-start justify-between gap-4">
            <div>
              <h2 className="text-2xl font-bold text-slate-900">Фильтр и поиск</h2>
              <p className="mt-1 text-sm text-slate-500">
                Поиск по телефону и имени, фильтр по сегменту
              </p>
            </div>

            <button
              className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-100"
              onClick={() => {
                setQ("");
                setSegment("");
                setPage(1);
              }}
            >
              Сброс
            </button>
          </div>

          <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_260px_180px]">
            <div>
              <label className="mb-2 block text-sm font-semibold text-slate-700">
                Поиск
              </label>
              <input
                className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                placeholder="Поиск: телефон / имя"
                value={q}
                onChange={(e) => {
                  setQ(e.target.value);
                  setPage(1);
                }}
              />
            </div>

            <div>
              <label className="mb-2 block text-sm font-semibold text-slate-700">
                Сегмент
              </label>
              <select
                className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                value={segment}
                onChange={(e) => {
                  setSegment(e.target.value);
                  setPage(1);
                }}
              >
                <option value="">Все</option>
                <option value="NEW">Первичный</option>
                <option value="REGULAR">Постоянный</option>
                <option value="VIP">VIP</option>
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3 xl:grid-cols-1">
              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Найдено</div>
                <div className="mt-1 text-3xl font-bold text-slate-900">
                  {items.length}
                </div>
              </div>
            </div>
          </div>

          {loading && (
            <div className="mt-4 rounded-2xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm text-blue-700">
              Загрузка пользователей...
            </div>
          )}

          {err && (
            <div className="mt-4 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
              Ошибка загрузки пользователей
            </div>
          )}
        </div>

        <div className="rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
          <div className="border-b border-slate-200 px-6 py-5">
            <h2 className="text-2xl font-bold text-slate-900">Список клиентов</h2>
            <p className="mt-1 text-sm text-slate-500">
              Нажми на строку, чтобы открыть карточку клиента
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/80">
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Телефон
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Имя
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Заказов
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Последний заказ
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Статус
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Сумма
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Сегмент
                  </th>
                </tr>
              </thead>

              <tbody>
                {items.map((x) => {
                  const statusUi = getStatusUi(x.lastOrderStatus);

                  return (
                    <tr
                      key={x.id}
                      className="cursor-pointer border-b border-slate-100 transition hover:bg-slate-50"
                      onClick={() => router.push(`/layout-20/users/${x.id}`)}
                    >
                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-bold text-slate-900">{x.phone}</div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {x.name || "-"}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="inline-flex min-w-[44px] items-center justify-center rounded-xl bg-slate-100 px-3 py-2 text-sm font-bold text-slate-700">
                          {x.ordersCount}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {formatDate(x.lastOrderAt)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <span
                          className={`inline-flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${statusUi.cls}`}
                        >
                          <span className={`h-2 w-2 rounded-full ${statusUi.dot}`} />
                          {statusUi.label}
                        </span>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-bold text-slate-900">
                          {formatMoney(x.lastOrderTotal)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <span
                          className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${segmentClass(
                            x.segment
                          )}`}
                        >
                          {segmentLabel(x.segment)}
                        </span>
                      </td>
                    </tr>
                  );
                })}

                {!loading && items.length === 0 && (
                  <tr>
                    <td colSpan={7} className="px-6 py-16 text-center">
                      <div className="text-5xl mb-3">👤</div>
                      <div className="text-xl font-bold text-slate-900 mb-2">
                        Ничего не найдено
                      </div>
                      <div className="text-sm text-slate-500">
                        Попробуй изменить поиск или фильтр сегмента
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-4 border-t border-slate-200 px-6 py-4 bg-slate-50/60">
            <div className="text-sm text-slate-500">
              Страница {page} из {pages}
            </div>

            <div className="flex items-center gap-2">
              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Назад
              </button>

              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={page >= pages}
                onClick={() => setPage((p) => p + 1)}
              >
                Вперёд
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}