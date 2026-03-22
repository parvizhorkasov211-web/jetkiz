"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

type Segment = "NEW" | "REGULAR" | "VIP";

type Customer = {
  id: string;
  phone: string;
  firstName: string | null;
  lastName: string | null;
  email: string | null;
  avatarUrl: string | null;
  createdAt?: string;
};

type Address = {
  id: string;
  userId: string;
  title: string;
  address: string;
  floor: string | null;
  door: string | null;
  entrance: string | null;
  intercom: string | null;
  contactPhone: string | null;
  comment: string | null;
  createdAt: string;
  updatedAt: string;
};

type AddressResponse = {
  items: Address[];
};

type RestaurantMini = {
  id: string;
  title?: string;
  name?: string;
  nameRu?: string;
  nameKk?: string;
};

type OrderRow = {
  id: string;
  createdAt: string;
  status: string;
  paymentStatus: string;
  paymentMethod: string;
  total: number;
  restaurantId?: string | null;
  restaurant?: Partial<RestaurantMini> | null;
  ratingGiven: boolean;
};

type Metrics = {
  userId: string;
  segment: Segment;

  totalOrders: number;
  deliveredCount: number;
  canceledCount: number;

  paidCount: number;
  totalPaid: number;
  totalDelivered?: number;
  avgCheckPaid?: number;
  avgCheckDelivered?: number;

  totalSpent: number;
  avgCheck?: number;

  firstOrderDate?: string | null;
  lastOrderDate?: string | null;
  daysSinceLastOrder: number | null;

  lastOrder?: null | {
    id: string;
    createdAt: string;
    total: number;
    status: string;
    restaurantId: string;
    paymentStatus: string;
    paymentMethod: string;
  };

  loyalty?: { score: number; level: string };

  favoriteRestaurants?: { restaurantId: string; ordersCount: number }[];
  preferredTimeRange?: string | null;

  reviewsCount?: number;
  avgRating?: number | null;

  rates?: {
    cancelRatePercent?: number;
    paidRatePercent?: number;
    deliveredRatePercent?: number;
  };

  frequency?: {
    ordersPerWeek?: number;
    ordersPerMonth?: number;
  };

  customerTenureDays?: number;

  activity?: {
    isActive7?: boolean;
    isActive30?: boolean;
  };

  rfm?: {
    status?: string;
    totalSpent?: number;
    totalOrders?: number;
    recencyDays?: number | null;
  };
};

type ReviewItem = {
  id: string;
  orderId: string;
  restaurantId: string;
  productId: string | null;
  rating: number;
  text: string | null;
  createdAt: string;
};

type ReviewsResponse = {
  items: ReviewItem[];
  meta: { total: number; page: number; limit: number };
};

function fullName(c: Customer) {
  const fn = (c.firstName || "").trim();
  const ln = (c.lastName || "").trim();
  const s = `${fn} ${ln}`.trim();
  return s || "Без имени";
}

function segmentLabel(s: Segment) {
  if (s === "NEW") return "Первичный";
  if (s === "VIP") return "VIP";
  return "Постоянный";
}

function segmentClass(s: Segment) {
  if (s === "NEW") return "bg-amber-50 text-amber-700 border-amber-200";
  if (s === "VIP") return "bg-emerald-50 text-emerald-700 border-emerald-200";
  return "bg-blue-50 text-blue-700 border-blue-200";
}

function orderStatusRu(s: string) {
  switch ((s || "").toUpperCase()) {
    case "CREATED":
      return "Создан";
    case "PAID":
      return "Оплачен";
    case "ACCEPTED":
      return "Принят";
    case "COOKING":
      return "Готовится";
    case "READY":
      return "Готов";
    case "ON_THE_WAY":
      return "В пути";
    case "DELIVERED":
      return "Доставлен";
    case "CANCELED":
    case "CANCELLED":
      return "Отменён";
    default:
      return s || "-";
  }
}

function getOrderStatusUi(status?: string | null) {
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

  if (["CREATED", "NEW", "PENDING", "PREPARING", "PAID", "ACCEPTED", "COOKING", "READY"].includes(s)) {
    return {
      label: orderStatusRu(s),
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

function paymentMethodRu(v?: string | null) {
  const x = (v || "").toUpperCase();
  if (!x) return "-";
  if (x === "CASH") return "Наличные";
  if (x === "CARD") return "Карта";
  return v || "-";
}

function paymentStatusRu(v?: string | null) {
  const x = (v || "").toUpperCase();
  if (!x) return "-";
  if (x === "PENDING") return "Ожидает";
  if (x === "PAID") return "Оплачено";
  if (x === "FAILED") return "Ошибка";
  return v || "-";
}

function stars(n: number) {
  const x = Math.max(0, Math.min(5, Math.floor(n || 0)));
  return "★★★★★".slice(0, x) + "☆☆☆☆☆".slice(0, 5 - x);
}

function clampText(s: string, max = 70) {
  const t = (s || "").trim();
  if (!t) return "";
  return t.length > max ? t.slice(0, max - 1) + "…" : t;
}

function rfmClass(status?: string) {
  switch (status) {
    case "Топ-клиент":
      return "bg-emerald-50 text-emerald-700 border-emerald-200";
    case "Постоянный":
      return "bg-blue-50 text-blue-700 border-blue-200";
    case "Перспективный":
      return "bg-cyan-50 text-cyan-700 border-cyan-200";
    case "Рискуем потерять":
      return "bg-amber-50 text-amber-700 border-amber-200";
    case "Спящий":
      return "bg-rose-50 text-rose-700 border-rose-200";
    default:
      return "bg-slate-50 text-slate-700 border-slate-200";
  }
}

function formatDate(value?: string | null) {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString("ru-RU");
}

function formatMoney(value?: number | null) {
  return `${Number(value ?? 0).toLocaleString("ru-RU")} ₸`;
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

function AddressInfoItem({
  label,
  value,
}: {
  label: string;
  value: string | null | undefined;
}) {
  return (
    <div className="rounded-2xl bg-white px-4 py-3 border border-slate-200">
      <div className="text-xs font-medium text-slate-500">{label}</div>
      <div className="mt-1 text-sm font-bold text-slate-900">{value || "-"}</div>
    </div>
  );
}

export default function UserDetailsPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [customer, setCustomer] = useState<Customer | null>(null);
  const [metrics, setMetrics] = useState<Metrics | null>(null);
  const [addresses, setAddresses] = useState<Address[]>([]);

  const [orders, setOrders] = useState<OrderRow[]>([]);
  const [ordersTotal, setOrdersTotal] = useState(0);
  const [ordersPage, setOrdersPage] = useState(1);
  const ordersLimit = 20;

  const [favRestaurants, setFavRestaurants] = useState<
    { restaurantId: string; title: string; ordersCount: number }[]
  >([]);

  const [restaurantsMap, setRestaurantsMap] = useState<Record<string, string>>({});
  const [reviewsByOrderId, setReviewsByOrderId] = useState<Record<string, ReviewItem>>({});

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const ordersQuery = useMemo(() => {
    const sp = new URLSearchParams();
    sp.set("page", String(ordersPage));
    sp.set("limit", String(ordersLimit));
    return sp.toString();
  }, [ordersPage]);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setErr(null);

    Promise.all([
      apiFetch(`/users/customers/${id}`) as Promise<Customer>,
      apiFetch(`/users/customers/${id}/orders?${ordersQuery}`) as Promise<{
        items: OrderRow[];
        meta: { total: number };
      }>,
      apiFetch(`/users/customers/${id}/metrics`) as Promise<Metrics>,
      apiFetch(`/users/customers/${id}/reviews?page=1&limit=200`) as Promise<ReviewsResponse>,
      apiFetch(`/users/customers/${id}/addresses`) as Promise<AddressResponse>,
    ])
      .then(async ([c, o, m, rv, addr]) => {
        if (!alive) return;

        setCustomer(c);

        const orderItems = o.items || [];
        setOrders(orderItems);
        setOrdersTotal(o.meta?.total || 0);
        setMetrics(m);
        setAddresses(addr.items || []);

        const map: Record<string, ReviewItem> = {};
        for (const it of rv.items || []) {
          if (it.orderId) map[it.orderId] = it;
        }
        setReviewsByOrderId(map);

        const orderRestaurantIds = Array.from(
          new Set(
            orderItems
              .map((x) => (x.restaurantId || x.restaurant?.id || "") as string)
              .filter(Boolean)
          )
        );

        const fav = m.favoriteRestaurants || [];
        const favIds = fav.map((x) => x.restaurantId).filter(Boolean);
        const allRestaurantIds = Array.from(new Set([...orderRestaurantIds, ...favIds]));

        if (allRestaurantIds.length > 0) {
          const results = await Promise.all(
            allRestaurantIds.map(async (rid) => {
              try {
                const r = (await apiFetch(`/restaurants/${rid}`)) as RestaurantMini;
                const title = (r.title || r.nameRu || r.name || r.nameKk || r.id || rid).toString();
                return { rid, title };
              } catch {
                return { rid, title: rid };
              }
            })
          );

          if (!alive) return;

          const dict: Record<string, string> = {};
          for (const x of results) dict[x.rid] = x.title;

          setRestaurantsMap(dict);

          const favView = fav.slice(0, 3).map((x) => ({
            restaurantId: x.restaurantId,
            title: dict[x.restaurantId] || x.restaurantId,
            ordersCount: x.ordersCount,
          }));

          setFavRestaurants(favView);
        } else {
          setRestaurantsMap({});
          setFavRestaurants([]);
        }
      })
      .catch((e: any) => {
        if (!alive) return;
        setErr(e?.message || "Ошибка загрузки");
      })
      .finally(() => {
        if (alive) setLoading(false);
      });

    return () => {
      alive = false;
    };
  }, [id, ordersQuery]);

  const ordersPages = Math.max(1, Math.ceil(ordersTotal / ordersLimit));

  if (loading && !customer && !metrics) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="text-slate-900 text-lg font-semibold mb-2">Загрузка клиента</div>
          <div className="text-slate-500">Подготавливаем профиль, метрики, адреса и историю заказов...</div>
        </div>
      </div>
    );
  }

  if (err && !customer && !metrics) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-rose-200 bg-white p-8 shadow-sm">
          <div className="text-rose-700 text-lg font-semibold mb-2">Ошибка загрузки</div>
          <div className="text-slate-700 mb-4">{err}</div>
          <button
            className="rounded-xl bg-slate-900 px-4 py-2 text-white"
            onClick={() => router.back()}
          >
            Назад
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
            <button
              className="mb-4 inline-flex items-center gap-2 rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50"
              onClick={() => router.back()}
            >
              ← Назад
            </button>

            <div className="flex flex-wrap items-center gap-3">
              <h1 className="text-4xl font-bold tracking-tight text-slate-900">Клиент</h1>

              {metrics?.segment ? (
                <span
                  className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${segmentClass(
                    metrics.segment
                  )}`}
                >
                  {segmentLabel(metrics.segment)}
                </span>
              ) : null}

              {metrics?.rfm?.status ? (
                <span
                  className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${rfmClass(
                    metrics.rfm.status
                  )}`}
                >
                  {metrics.rfm.status}
                </span>
              ) : null}
            </div>

            {customer ? (
              <p className="mt-2 text-sm text-slate-500 break-all">{customer.id}</p>
            ) : null}
          </div>

          {customer?.createdAt ? (
            <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <div className="text-xs font-medium text-slate-500">Регистрация</div>
              <div className="text-sm font-bold text-slate-900">{formatDate(customer.createdAt)}</div>
            </div>
          ) : null}
        </div>

        {err && (
          <div className="mb-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 text-sm text-rose-700">
            {err}
          </div>
        )}

        {customer && metrics && (
          <>
            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm mb-6">
              <div className="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
                <div className="flex items-center gap-4">
                  <div className="h-20 w-20 shrink-0 overflow-hidden rounded-3xl bg-slate-100 border border-slate-200 flex items-center justify-center text-2xl font-extrabold text-slate-700">
                    {customer.avatarUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={customer.avatarUrl} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <span>{(customer.firstName?.[0] || customer.phone?.[0] || "C").toUpperCase()}</span>
                    )}
                  </div>

                  <div>
                    <div className="text-3xl font-extrabold tracking-tight text-slate-900">
                      {fullName(customer)}
                    </div>

                    <div className="mt-2 text-base font-bold text-slate-800">
                      Телефон: <span className="font-extrabold text-slate-900">{customer.phone || "-"}</span>
                    </div>

                    <div className="mt-1 text-base font-bold text-slate-800">
                      Email: <span className="font-extrabold text-slate-900">{customer.email || "-"}</span>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-semibold text-slate-500">Последний заказ</div>
                    <div className="mt-2 text-base font-extrabold text-slate-900">
                      {formatDate(metrics.lastOrderDate)}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-semibold text-slate-500">С последнего</div>
                    <div className="mt-2 text-base font-extrabold text-slate-900">
                      {metrics.daysSinceLastOrder ?? "-"} дн.
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-semibold text-slate-500">Активен 7 дней</div>
                    <div className="mt-2 text-base font-extrabold text-slate-900">
                      {metrics.activity?.isActive7 ? "Да" : "Нет"}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-semibold text-slate-500">Активен 30 дней</div>
                    <div className="mt-2 text-base font-extrabold text-slate-900">
                      {metrics.activity?.isActive30 ? "Да" : "Нет"}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4 mb-6">
              <StatCard
                title="Всего заказов"
                value={String(metrics.totalOrders ?? 0)}
                subtitle={`Доставлено: ${metrics.deliveredCount ?? 0} · Отменено: ${metrics.canceledCount ?? 0}`}
                gradient="linear-gradient(135deg, #1bc5bd 0%, #0bb783 100%)"
              />
              <StatCard
                title="Потрачено"
                value={formatMoney(metrics.totalSpent ?? 0)}
                subtitle={`Оплачено: ${metrics.paidCount ?? 0} заказ(ов)`}
                gradient="linear-gradient(135deg, #3699ff 0%, #3f51f7 100%)"
              />
              <StatCard
                title="Средний чек"
                value={formatMoney(metrics.avgCheckPaid ?? metrics.avgCheck ?? 0)}
                subtitle={`По доставленным: ${formatMoney(metrics.avgCheckDelivered ?? 0)}`}
                gradient="linear-gradient(135deg, #8950fc 0%, #d65db1 100%)"
              />
              <StatCard
                title="Рейтинг"
                value={
                  metrics.avgRating == null
                    ? "—"
                    : `${metrics.avgRating.toFixed(1)}`
                }
                subtitle={`Отзывов: ${metrics.reviewsCount ?? 0}`}
                gradient="linear-gradient(135deg, #ff6b6b 0%, #f64e60 100%)"
              />
            </div>

            <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.05fr_0.95fr] mb-6">
              <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 className="text-2xl font-bold text-slate-900 mb-5">Профиль и лояльность</h2>

                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Сегмент</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {segmentLabel(metrics.segment)}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">RFM статус</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.rfm?.status ?? "—"}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Лояльность</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.loyalty?.level ?? "—"} ({metrics.loyalty?.score ?? 0})
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Стаж клиента</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.customerTenureDays ?? 0} дн.
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Заказов в неделю</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.frequency?.ordersPerWeek ?? 0}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Заказов в месяц</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.frequency?.ordersPerMonth ?? 0}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4 md:col-span-2">
                    <div className="text-xs font-medium text-slate-500">Предпочтительное время заказов</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.preferredTimeRange || "Появится после 3 заказов"}
                    </div>
                  </div>
                </div>
              </div>

              <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 className="text-2xl font-bold text-slate-900 mb-5">Качество и поведение</h2>

                <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                  <div className="rounded-2xl bg-emerald-50 p-4">
                    <div className="text-xs font-medium text-emerald-700">Доставлено</div>
                    <div className="mt-1 text-xl font-bold text-emerald-700">
                      {metrics.deliveredCount ?? 0}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-rose-50 p-4">
                    <div className="text-xs font-medium text-rose-700">Отменено</div>
                    <div className="mt-1 text-xl font-bold text-rose-700">
                      {metrics.canceledCount ?? 0}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-blue-50 p-4">
                    <div className="text-xs font-medium text-blue-700">Оплачено</div>
                    <div className="mt-1 text-xl font-bold text-blue-700">
                      {metrics.paidCount ?? 0}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-amber-50 p-4">
                    <div className="text-xs font-medium text-amber-700">Рейтинг</div>
                    <div className="mt-1 text-lg font-bold text-amber-700">
                      {metrics.avgRating == null
                        ? "—"
                        : `${stars(metrics.avgRating)} (${metrics.avgRating.toFixed(1)})`}
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Cancel rate</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.rates?.cancelRatePercent ?? 0}%
                    </div>
                  </div>

                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="text-xs font-medium text-slate-500">Delivered rate</div>
                    <div className="mt-1 text-sm font-bold text-slate-900">
                      {metrics.rates?.deliveredRatePercent ?? 0}%
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm mb-6">
              <div className="mb-5 flex items-start justify-between gap-4">
                <div>
                  <h2 className="text-2xl font-bold text-slate-900">Сохранённые адреса</h2>
                  <p className="mt-1 text-sm text-slate-500">
                    Адреса клиента, которые используются при оформлении заказов и передаются курьеру
                  </p>
                </div>

                <div className="rounded-2xl bg-slate-50 px-4 py-3">
                  <div className="text-xs font-medium text-slate-500">Всего адресов</div>
                  <div className="text-xl font-bold text-slate-900">{addresses.length}</div>
                </div>
              </div>

              {addresses.length === 0 ? (
                <div className="rounded-2xl bg-slate-50 p-5 text-sm text-slate-500">
                  Клиент ещё не сохранил адреса
                </div>
              ) : (
                <div className="space-y-4">
                  {addresses.map((address) => (
                    <div
                      key={address.id}
                      className="rounded-3xl border border-slate-200 bg-slate-50 p-5"
                    >
                      <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                        <div>
                          <div className="text-lg font-bold text-slate-900">
                            {address.title}
                          </div>
                          <div className="mt-1 text-sm font-medium text-slate-700">
                            {address.address}
                          </div>
                        </div>

                        <div className="text-xs text-slate-500">
                          Обновлён: {formatDate(address.updatedAt)}
                        </div>
                      </div>

                      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5">
                        <AddressInfoItem label="Подъезд" value={address.entrance} />
                        <AddressInfoItem label="Этаж" value={address.floor} />
                        <AddressInfoItem label="Квартира / офис" value={address.door} />
                        <AddressInfoItem label="Домофон" value={address.intercom} />
                        <AddressInfoItem label="Телефон для связи" value={address.contactPhone} />
                      </div>

                      {address.comment ? (
                        <div className="mt-4 rounded-2xl border border-slate-200 bg-white px-4 py-3">
                          <div className="text-xs font-medium text-slate-500">Комментарий</div>
                          <div className="mt-1 text-sm font-semibold text-slate-900">
                            {address.comment}
                          </div>
                        </div>
                      ) : null}
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="grid grid-cols-1 gap-6 xl:grid-cols-[0.95fr_1.05fr] mb-6">
              <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 className="text-2xl font-bold text-slate-900 mb-5">Любимые рестораны</h2>

                {favRestaurants.length === 0 ? (
                  <div className="rounded-2xl bg-slate-50 p-5 text-sm text-slate-500">
                    Пока нет данных
                  </div>
                ) : (
                  <div className="space-y-3">
                    {favRestaurants.map((x, index) => (
                      <div
                        key={x.restaurantId}
                        className="flex items-center justify-between rounded-2xl bg-slate-50 px-4 py-4"
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-slate-900 text-sm font-bold text-white">
                            {index + 1}
                          </div>
                          <div className="truncate text-sm font-semibold text-slate-900">
                            {x.title}
                          </div>
                        </div>

                        <div className="text-sm font-bold text-slate-700">
                          {x.ordersCount} заказ(а)
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 className="text-2xl font-bold text-slate-900 mb-5">Последний заказ</h2>

                {metrics.lastOrder ? (
                  <div className="grid grid-cols-1 gap-4">
                    <div className="rounded-2xl bg-slate-50 p-4">
                      <div className="text-xs font-medium text-slate-500">Дата</div>
                      <div className="mt-1 text-sm font-bold text-slate-900">
                        {formatDate(metrics.lastOrder.createdAt)}
                      </div>
                    </div>

                    <div className="rounded-2xl bg-slate-50 p-4">
                      <div className="text-xs font-medium text-slate-500">Сумма</div>
                      <div className="mt-1 text-sm font-bold text-slate-900">
                        {formatMoney(metrics.lastOrder.total)}
                      </div>
                    </div>

                    <div className="rounded-2xl bg-slate-50 p-4">
                      <div className="text-xs font-medium text-slate-500">Статус</div>
                      <div className="mt-1 text-sm font-bold text-slate-900">
                        {orderStatusRu(metrics.lastOrder.status)}
                      </div>
                    </div>

                    <div className="rounded-2xl bg-slate-50 p-4">
                      <div className="text-xs font-medium text-slate-500">Оплата</div>
                      <div className="mt-1 text-sm font-bold text-slate-900">
                        {paymentStatusRu(metrics.lastOrder.paymentStatus)} /{" "}
                        {paymentMethodRu(metrics.lastOrder.paymentMethod)}
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="rounded-2xl bg-slate-50 p-5 text-sm text-slate-500">
                    Нет данных по последнему заказу
                  </div>
                )}
              </div>
            </div>
          </>
        )}

        <div className="rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
          <div className="border-b border-slate-200 px-6 py-5">
            <h2 className="text-2xl font-bold text-slate-900">Заказы клиента</h2>
            <p className="mt-1 text-sm text-slate-500">
              История заказов с оплатой, рестораном и отзывами
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/80">
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    ID
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Дата
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Статус
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Оплата
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Сумма
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Ресторан
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Отзыв
                  </th>
                </tr>
              </thead>

              <tbody>
                {orders.map((o) => {
                  const rv = reviewsByOrderId[o.id];
                  const ui = getOrderStatusUi(o.status);

                  const rid = (o.restaurantId || o.restaurant?.id || "") as string;
                  const restaurantTitle =
                    (rid && restaurantsMap[rid]) ||
                    (o.restaurant?.nameRu || o.restaurant?.name || o.restaurant?.nameKk || "") ||
                    rid ||
                    "-";

                  return (
                    <tr
                      key={o.id}
                      className="cursor-pointer border-b border-slate-100 transition hover:bg-slate-50"
                      onClick={() => router.push(`/layout-20/orders/${o.id}`)}
                      title="Открыть заказ"
                    >
                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800 break-all">{o.id}</div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {formatDate(o.createdAt)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <span
                          className={`inline-flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${ui.cls}`}
                        >
                          <span className={`h-2 w-2 rounded-full ${ui.dot}`} />
                          {ui.label}
                        </span>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">
                          {paymentStatusRu(o.paymentStatus)} / {paymentMethodRu(o.paymentMethod)}
                        </div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-bold text-slate-900">{formatMoney(o.total)}</div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        <div className="text-sm font-semibold text-slate-800">{restaurantTitle}</div>
                      </td>

                      <td className="px-6 py-5 align-top">
                        {o.status !== "DELIVERED" ? (
                          <span className="text-sm text-slate-400">—</span>
                        ) : rv ? (
                          <div className="space-y-1">
                            <div className="text-sm font-bold text-slate-900">
                              {stars(rv.rating)}{" "}
                              <span className="text-slate-500 font-medium">({rv.rating})</span>
                            </div>
                            {rv.text ? (
                              <div className="text-xs text-slate-500">{clampText(rv.text, 80)}</div>
                            ) : (
                              <div className="text-xs text-slate-400">Без текста</div>
                            )}
                          </div>
                        ) : (
                          <span className="text-sm text-slate-400">Нет</span>
                        )}
                      </td>
                    </tr>
                  );
                })}

                {orders.length === 0 && (
                  <tr>
                    <td colSpan={7} className="px-6 py-16 text-center">
                      <div className="text-5xl mb-3">🧾</div>
                      <div className="text-xl font-bold text-slate-900 mb-2">Нет заказов</div>
                      <div className="text-sm text-slate-500">
                        У этого клиента пока нет заказов в истории
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-4 border-t border-slate-200 px-6 py-4 bg-slate-50/60">
            <div className="text-sm text-slate-500">
              Страница {ordersPage} из {ordersPages}
            </div>

            <div className="flex items-center gap-2">
              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={ordersPage <= 1}
                onClick={() => setOrdersPage((p) => p - 1)}
              >
                Назад
              </button>

              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 transition hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-50"
                disabled={ordersPage >= ordersPages}
                onClick={() => setOrdersPage((p) => p + 1)}
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