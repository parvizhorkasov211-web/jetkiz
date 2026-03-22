"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

type OrderItem = {
  id: string;
  title: string;
  price: number;
  quantity: number;
};

type CourierShort = {
  userId: string;
  firstName: string;
  lastName: string;
  iin?: string;
  isOnline?: boolean;
  personalFeeOverride?: number | null;
  user?: { phone?: string };
};

type OrderDetails = {
  id: string;
  status: string;

  subtotal: number;
  deliveryFee: number;
  total: number;

  phone: string;
  comment?: string | null;
  leaveAtDoor?: boolean;

  paymentMethod?: string;
  paymentStatus?: string;

  createdAt: string;

  restaurant?: { id: string; nameRu: string };
  items?: OrderItem[];

  courierId?: string | null;
  courierFee?: number;
  assignedAt?: string | null;
  pickedUpAt?: string | null;
  deliveredAt?: string | null;

  courier?: {
    userId: string;
    firstName: string;
    lastName: string;
    isOnline?: boolean;
    user?: { phone?: string };
  } | null;
};

type CouriersListResponse = {
  items: CourierShort[];
  total?: number;
};

function courierLabel(
  c?: { firstName?: string; lastName?: string; user?: { phone?: string } } | null
) {
  if (!c) return "Не назначен";
  const name = `${c.firstName ?? ""} ${c.lastName ?? ""}`.trim() || "Курьер";
  const phone = c.user?.phone ? ` (${c.user.phone})` : "";
  return `${name}${phone}`;
}

function formatMoney(value: number | null | undefined) {
  return `${Number(value ?? 0).toLocaleString("ru-RU")} ₸`;
}

function formatDate(value?: string | null) {
  if (!value) return "—";
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

function paymentMethodLabel(value?: string) {
  if (!value) return "—";
  const v = value.toUpperCase();

  if (v === "CASH") return "Наличные";
  if (v === "CARD") return "Карта";
  return value;
}

function paymentStatusLabel(value?: string) {
  if (!value) return "—";
  const v = value.toUpperCase();

  if (v === "PENDING") return "Ожидает";
  if (v === "PAID") return "Оплачено";
  if (v === "FAILED") return "Ошибка";
  return value;
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

export default function OrderDetailsPage() {
  const params = useParams();
  const router = useRouter();
  const id = (params?.id as string) || "";

  const [order, setOrder] = useState<OrderDetails | null>(null);
  const [couriers, setCouriers] = useState<CourierShort[]>([]);

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [assigning, setAssigning] = useState(false);
  const [selectedCourierUserId, setSelectedCourierUserId] = useState<string>("");

  const fullCourierName = useMemo(() => {
    if (!order?.courier) return "Не назначен";
    return courierLabel(order.courier);
  }, [order?.courier]);

  const statusUi = useMemo(() => getStatusUi(order?.status), [order?.status]);

  const itemsTotal = useMemo(() => {
    return (order?.items || []).reduce((sum, it) => sum + it.price * it.quantity, 0);
  }, [order?.items]);

  useEffect(() => {
    if (!id) return;

    let alive = true;
    setLoading(true);
    setErr(null);

    Promise.all([
      apiFetch(`/orders/${id}`) as Promise<OrderDetails>,
      apiFetch(`/couriers?page=1&limit=300`) as Promise<CouriersListResponse>,
    ])
      .then(([o, c]) => {
        if (!alive) return;
        setOrder(o);
        setCouriers(c?.items || []);
        setSelectedCourierUserId(o?.courierId || "");
      })
      .catch((e: any) => {
        if (!alive) return;
        setErr(e?.message || "Ошибка загрузки");
        setOrder(null);
        setCouriers([]);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });

    return () => {
      alive = false;
    };
  }, [id]);

  async function refreshOrder() {
    const o = (await apiFetch(`/orders/${id}`)) as OrderDetails;
    setOrder(o);
    setSelectedCourierUserId(o?.courierId || "");
  }

  async function assignCourier(courierUserId: string) {
    if (!id) return;
    setAssigning(true);
    setErr(null);

    try {
      await apiFetch(`/orders/${id}/assign-courier`, {
        method: "PATCH",
        body: JSON.stringify({ courierUserId }),
      });
      await refreshOrder();
    } catch (e: any) {
      setErr(e?.message || "Ошибка назначения курьера");
    } finally {
      setAssigning(false);
    }
  }

  async function autoAssign() {
    if (!id) return;
    setAssigning(true);
    setErr(null);

    try {
      await apiFetch(`/orders/${id}/auto-assign`, { method: "PATCH" });
      await refreshOrder();
    } catch (e: any) {
      setErr(e?.message || "Ошибка автоназначения");
    } finally {
      setAssigning(false);
    }
  }

  async function unassign() {
    if (!id) return;
    setAssigning(true);
    setErr(null);

    try {
      await apiFetch(`/orders/${id}/assign-courier`, {
        method: "PATCH",
        body: JSON.stringify({ courierUserId: null }),
      });
      await refreshOrder();
    } catch {
      try {
        await apiFetch(`/orders/${id}/assign-courier`, {
          method: "PATCH",
          body: JSON.stringify({ courierUserId: "" }),
        });
        await refreshOrder();
      } catch (e2: any) {
        setErr(e2?.message || "Не удалось снять курьера");
      }
    } finally {
      setAssigning(false);
    }
  }

  if (loading) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="text-slate-900 text-lg font-semibold mb-2">Загрузка заказа</div>
          <div className="text-slate-500">Подготавливаем данные и список курьеров...</div>
        </div>
      </div>
    );
  }

  if (err && !order) {
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

  if (!order) return null;

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
              <h1 className="text-4xl font-bold tracking-tight text-slate-900">
                Заказ
              </h1>

              <span
                className={`inline-flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${statusUi.pill}`}
              >
                <span className={`h-2 w-2 rounded-full ${statusUi.dot}`} />
                {statusUi.label}
              </span>
            </div>

            <p className="mt-2 text-sm text-slate-500 break-all">{order.id}</p>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <div className="text-xs font-medium text-slate-500">Создан</div>
              <div className="text-sm font-bold text-slate-900">{formatDate(order.createdAt)}</div>
            </div>

            <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 shadow-sm">
              <div className="text-xs font-medium text-slate-500">Ресторан</div>
              <div className="text-sm font-bold text-slate-900">
                {order.restaurant?.nameRu || "—"}
              </div>
            </div>
          </div>
        </div>

        {err && (
          <div className="mb-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 text-sm text-rose-700">
            {err}
          </div>
        )}

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4 mb-6">
          <StatCard
            title="Сумма заказа"
            value={formatMoney(order.total)}
            subtitle={`${formatMoney(order.subtotal)} + ${formatMoney(order.deliveryFee)}`}
            gradient="linear-gradient(135deg, #1bc5bd 0%, #0bb783 100%)"
          />
          <StatCard
            title="Оплата"
            value={paymentStatusLabel(order.paymentStatus)}
            subtitle={paymentMethodLabel(order.paymentMethod)}
            gradient="linear-gradient(135deg, #3699ff 0%, #3f51f7 100%)"
          />
          <StatCard
            title="Курьеру начислено"
            value={formatMoney(order.courierFee ?? 0)}
            subtitle={order.courier ? "Курьер назначен" : "Пока не назначен"}
            gradient="linear-gradient(135deg, #8950fc 0%, #d65db1 100%)"
          />
          <StatCard
            title="Позиции"
            value={String(order.items?.length ?? 0)}
            subtitle={`Сумма позиций: ${formatMoney(itemsTotal)}`}
            gradient="linear-gradient(135deg, #ff6b6b 0%, #f64e60 100%)"
          />
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.05fr_0.95fr] mb-6">
          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-bold text-slate-900">Курьер</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Назначение, автоназначение и снятие курьера с заказа
                </p>
              </div>

              <div
                className={`inline-flex items-center gap-2 rounded-full px-3 py-2 text-xs font-semibold ${
                  order.courier?.isOnline
                    ? "bg-emerald-50 text-emerald-700"
                    : "bg-slate-100 text-slate-600"
                }`}
              >
                <span
                  className={`h-2 w-2 rounded-full ${
                    order.courier?.isOnline ? "bg-emerald-500" : "bg-slate-400"
                  }`}
                />
                {order.courier?.isOnline ? "Онлайн" : "Офлайн"}
              </div>
            </div>

            <div className="rounded-2xl bg-slate-50 p-5 mb-5">
              <div className="text-xs font-medium text-slate-500 mb-1">Текущий курьер</div>
              <div className="text-xl font-bold text-slate-900">{fullCourierName}</div>
              <div className="mt-2 text-sm text-slate-500">
                courierFee: <span className="font-semibold text-slate-800">{formatMoney(order.courierFee ?? 0)}</span>
                {order.assignedAt ? (
                  <>
                    {" "}
                    · назначен:{" "}
                    <span className="font-semibold text-slate-800">
                      {formatDate(order.assignedAt)}
                    </span>
                  </>
                ) : null}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4">
              <div>
                <label className="mb-2 block text-sm font-semibold text-slate-700">
                  Выбрать курьера
                </label>
                <select
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none transition focus:border-blue-400 focus:bg-white"
                  value={selectedCourierUserId}
                  onChange={(e) => setSelectedCourierUserId(e.target.value)}
                  disabled={assigning}
                >
                  <option value="">— выбрать курьера —</option>
                  {couriers.map((c) => {
                    const label = `${c.isOnline ? "🟢" : "🔴"} ${c.firstName} ${c.lastName} (${
                      c.user?.phone || "-"
                    })`;
                    return (
                      <option key={c.userId} value={c.userId}>
                        {label}
                      </option>
                    );
                  })}
                </select>
              </div>

              <div className="flex flex-wrap gap-3">
                <button
                  className="rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-95 disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={assigning || !selectedCourierUserId}
                  onClick={() => assignCourier(selectedCourierUserId)}
                >
                  {assigning ? "Назначение..." : "Назначить"}
                </button>

                <button
                  className="rounded-2xl bg-blue-600 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={assigning}
                  onClick={autoAssign}
                >
                  {assigning ? "Подождите..." : "Автоназначить"}
                </button>

                <button
                  className="rounded-2xl border border-rose-200 bg-rose-50 px-5 py-3 text-sm font-semibold text-rose-700 transition hover:bg-rose-100 disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={assigning || !order.courierId}
                  onClick={unassign}
                >
                  Снять
                </button>
              </div>
            </div>
          </div>

          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold text-slate-900 mb-5">Таймлайн заказа</h2>

            <div className="space-y-4">
              <div className="flex items-start gap-4">
                <div className="mt-1 h-3 w-3 rounded-full bg-slate-900" />
                <div>
                  <div className="text-sm font-semibold text-slate-900">Создан</div>
                  <div className="text-sm text-slate-500">{formatDate(order.createdAt)}</div>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div
                  className={`mt-1 h-3 w-3 rounded-full ${
                    order.assignedAt ? "bg-blue-500" : "bg-slate-300"
                  }`}
                />
                <div>
                  <div className="text-sm font-semibold text-slate-900">Курьер назначен</div>
                  <div className="text-sm text-slate-500">{formatDate(order.assignedAt)}</div>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div
                  className={`mt-1 h-3 w-3 rounded-full ${
                    order.pickedUpAt ? "bg-amber-500" : "bg-slate-300"
                  }`}
                />
                <div>
                  <div className="text-sm font-semibold text-slate-900">Заказ забран</div>
                  <div className="text-sm text-slate-500">{formatDate(order.pickedUpAt)}</div>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div
                  className={`mt-1 h-3 w-3 rounded-full ${
                    order.deliveredAt ? "bg-emerald-500" : "bg-slate-300"
                  }`}
                />
                <div>
                  <div className="text-sm font-semibold text-slate-900">Доставлен</div>
                  <div className="text-sm text-slate-500">{formatDate(order.deliveredAt)}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[0.95fr_1.05fr] mb-6">
          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold text-slate-900 mb-5">Основная информация</h2>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Статус</div>
                <div className="mt-1 text-sm font-bold text-slate-900">{statusUi.label}</div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Телефон</div>
                <div className="mt-1 text-sm font-bold text-slate-900">{order.phone || "—"}</div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Ресторан</div>
                <div className="mt-1 text-sm font-bold text-slate-900">
                  {order.restaurant?.nameRu || "—"}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Оставить у двери</div>
                <div className="mt-1 text-sm font-bold text-slate-900">
                  {order.leaveAtDoor ? "Да" : "Нет"}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4 md:col-span-2">
                <div className="text-xs font-medium text-slate-500">Комментарий</div>
                <div className="mt-1 text-sm font-bold text-slate-900 whitespace-pre-wrap">
                  {order.comment || "—"}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4 md:col-span-2">
                <div className="text-xs font-medium text-slate-500">UUID заказа</div>
                <div className="mt-1 break-all text-sm font-semibold text-slate-800">
                  {order.id}
                </div>
              </div>
            </div>
          </div>

          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 className="text-2xl font-bold text-slate-900 mb-5">Финансы и оплата</h2>

            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <div className="rounded-2xl bg-emerald-50 p-4">
                <div className="text-xs font-medium text-emerald-700">Subtotal</div>
                <div className="mt-1 text-xl font-bold text-emerald-700">
                  {formatMoney(order.subtotal)}
                </div>
              </div>

              <div className="rounded-2xl bg-blue-50 p-4">
                <div className="text-xs font-medium text-blue-700">Доставка</div>
                <div className="mt-1 text-xl font-bold text-blue-700">
                  {formatMoney(order.deliveryFee)}
                </div>
              </div>

              <div className="rounded-2xl bg-violet-50 p-4">
                <div className="text-xs font-medium text-violet-700">Итого</div>
                <div className="mt-1 text-xl font-bold text-violet-700">
                  {formatMoney(order.total)}
                </div>
              </div>

              <div className="rounded-2xl bg-amber-50 p-4">
                <div className="text-xs font-medium text-amber-700">Курьеру</div>
                <div className="mt-1 text-xl font-bold text-amber-700">
                  {formatMoney(order.courierFee ?? 0)}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Способ оплаты</div>
                <div className="mt-1 text-sm font-bold text-slate-900">
                  {paymentMethodLabel(order.paymentMethod)}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-medium text-slate-500">Статус оплаты</div>
                <div className="mt-1 text-sm font-bold text-slate-900">
                  {paymentStatusLabel(order.paymentStatus)}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
          <div className="border-b border-slate-200 px-6 py-5">
            <h2 className="text-2xl font-bold text-slate-900">Позиции заказа</h2>
            <p className="mt-1 text-sm text-slate-500">
              Состав заказа, цена, количество и сумма по каждой позиции
            </p>
          </div>

          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/80">
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Позиция
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Цена
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Кол-во
                  </th>
                  <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                    Итого
                  </th>
                </tr>
              </thead>

              <tbody>
                {(order.items || []).map((it) => (
                  <tr
                    key={it.id}
                    className="border-b border-slate-100 transition hover:bg-slate-50"
                  >
                    <td className="px-6 py-5">
                      <div className="text-sm font-bold text-slate-900">{it.title}</div>
                      <div className="mt-1 text-xs text-slate-400">{it.id}</div>
                    </td>

                    <td className="px-6 py-5">
                      <div className="text-sm font-semibold text-slate-800">
                        {formatMoney(it.price)}
                      </div>
                    </td>

                    <td className="px-6 py-5">
                      <div className="inline-flex min-w-[44px] items-center justify-center rounded-xl bg-slate-100 px-3 py-2 text-sm font-bold text-slate-700">
                        {it.quantity}
                      </div>
                    </td>

                    <td className="px-6 py-5">
                      <div className="text-sm font-bold text-slate-900">
                        {formatMoney(it.price * it.quantity)}
                      </div>
                    </td>
                  </tr>
                ))}

                {!loading && (!order.items || order.items.length === 0) && (
                  <tr>
                    <td colSpan={4} className="px-6 py-16 text-center">
                      <div className="text-5xl mb-3">📦</div>
                      <div className="text-xl font-bold text-slate-900 mb-2">
                        Позиции не найдены
                      </div>
                      <div className="text-sm text-slate-500">
                        У этого заказа пока нет элементов в списке
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="flex flex-wrap gap-3 border-t border-slate-200 px-6 py-4 bg-slate-50/60">
            <span className="rounded-full bg-emerald-50 px-4 py-2 text-xs font-semibold text-emerald-700">
              Subtotal: {formatMoney(order.subtotal)}
            </span>
            <span className="rounded-full bg-blue-50 px-4 py-2 text-xs font-semibold text-blue-700">
              Доставка: {formatMoney(order.deliveryFee)}
            </span>
            <span className="rounded-full bg-violet-50 px-4 py-2 text-xs font-semibold text-violet-700">
              Итого: {formatMoney(order.total)}
            </span>
            <span className="rounded-full bg-amber-50 px-4 py-2 text-xs font-semibold text-amber-700">
              Позиции: {order.items?.length ?? 0}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}