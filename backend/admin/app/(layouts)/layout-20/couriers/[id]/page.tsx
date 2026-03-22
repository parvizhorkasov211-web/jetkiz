"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";
import { CourierFinancePanel } from "@/components/ui/widgets/CourierFinancePanel";
import {
  CourierOnTimeRateMetric,
  CourierOnTimeRateWidget,
} from "@/components/ui/widgets/CourierOnTimeRateWidget";

type ActiveOrder = {
  id: string;
  status: string;
  total: number;
  createdAt: string;
  assignedAt?: string | null;
  phone?: string;
  addressId?: string;
  restaurant?: { id: string; nameRu: string };
};

type Courier = {
  id: string;
  userId: string;
  phone: string;

  isActive: boolean;

  avatarUrl?: string | null;

  firstName: string;
  lastName: string;
  iin: string;

  addressText?: string | null;
  comment?: string | null;

  blockedAt?: string | null;
  blockReason?: string | null;

  isOnline: boolean;
  personalFeeOverride?: number | null;
  payoutBonusAdd?: number | null;

  activeOrders?: ActiveOrder[];
  activeTariff?: any;
};

function str(v: any) {
  return v == null ? "" : String(v);
}

function fmtDate(d: any) {
  try {
    if (!d) return "—";
    const dt = new Date(d);
    if (Number.isNaN(dt.getTime())) return String(d);
    return dt.toLocaleString("ru-RU");
  } catch {
    return String(d ?? "");
  }
}

function resolveAvatarSrc(avatarUrl?: string | null) {
  if (!avatarUrl) return "";
  if (/^https?:\/\//i.test(avatarUrl)) return avatarUrl;

  const base = (process.env.NEXT_PUBLIC_API_URL || "").trim().replace(/\/+$/, "");
  if (!base) return avatarUrl;

  return `${base}${avatarUrl.startsWith("/") ? "" : "/"}${avatarUrl}`;
}

function formatMoney(v: number | string | null | undefined) {
  const n = Number(v ?? 0);
  if (!Number.isFinite(n)) return "—";
  return `${Math.round(n).toLocaleString("ru-RU")} ₸`;
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

  if (["CREATED", "NEW", "PENDING", "PREPARING", "ACCEPTED", "COOKING", "READY", "PAID"].includes(s)) {
    return {
      label: status || "Новый",
      cls: "bg-amber-50 text-amber-700 border-amber-200",
      dot: "bg-amber-500",
    };
  }

  return {
    label: status || "—",
    cls: "bg-slate-50 text-slate-700 border-slate-200",
    dot: "bg-slate-400",
  };
}

type CompletedRange = "lifetime" | "day" | "month" | "year" | "custom";

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

export default function CourierDetailsPage() {
  const params = useParams();
  const router = useRouter();
  const courierId = (params as any)?.id as string;

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const [courier, setCourier] = useState<Courier | null>(null);

  const [otdLoading, setOtdLoading] = useState(false);
  const [otd, setOtd] = useState<CourierOnTimeRateMetric | null>(null);

  const [completedLoading, setCompletedLoading] = useState(false);
  const [completedCount, setCompletedCount] = useState<number | null>(null);
  const [completedRange, setCompletedRange] = useState<CompletedRange>("month");
  const [completedFrom, setCompletedFrom] = useState<string>("");
  const [completedTo, setCompletedTo] = useState<string>("");

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [iin, setIin] = useState("");
  const [addressText, setAddressText] = useState("");
  const [comment, setComment] = useState("");
  const [personalFeeOverride, setPersonalFeeOverride] = useState<string>("");
  const [payoutBonusAdd, setPayoutBonusAdd] = useState<string>("");

  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string>("");
  const [avatarUploading, setAvatarUploading] = useState(false);

  const [showAvatarViewer, setShowAvatarViewer] = useState(false);

  const [blockReason, setBlockReason] = useState("");

  const [orderIdToAssign, setOrderIdToAssign] = useState("");

  const buildCompletedQuery = (courierUserId: string) => {
    const id = (courierUserId || "").trim();
    const p: string[] = [`courierUserId=${encodeURIComponent(id)}`];

    if (completedRange === "day") p.push(`range=day`);
    else if (completedRange === "month") p.push(`range=month`);
    else if (completedRange === "year") p.push(`range=year`);
    else if (completedRange === "custom") {
      const f = completedFrom.trim();
      const t = completedTo.trim();
      if (f) p.push(`from=${encodeURIComponent(f)}`);
      if (t) p.push(`to=${encodeURIComponent(t)}`);
    }

    return `/couriers/metrics/completed-count?${p.join("&")}`;
  };

  const loadCompleted = async (courierUserId?: string) => {
    const id = (courierUserId || courierId || "").trim();
    if (!id) return;

    try {
      setCompletedLoading(true);

      const url = buildCompletedQuery(id);
      const json = await apiFetch(url);

      setCompletedCount(typeof json?.totalCompleted === "number" ? json.totalCompleted : 0);
    } catch {
      setCompletedCount(null);
    } finally {
      setCompletedLoading(false);
    }
  };

  const loadOtd = async (courierUserId?: string) => {
    const id = (courierUserId || courierId || "").trim();
    if (!id) return;

    try {
      setOtdLoading(true);

      const json = await apiFetch(
        `/couriers/metrics/on-time-rate?courierUserId=${encodeURIComponent(id)}&slaMin=45`
      );

      setOtd(json);
    } catch {
      setOtd(null);
    } finally {
      setOtdLoading(false);
    }
  };

  const load = async () => {
    if (!courierId) return;
    try {
      setLoading(true);
      setError(null);

      const [courierJson] = await Promise.all([apiFetch(`/couriers/${courierId}`)]);

      setCourier(courierJson);

      setFirstName(str(courierJson.firstName));
      setLastName(str(courierJson.lastName));
      setIin(str(courierJson.iin));
      setAddressText(str(courierJson.addressText ?? ""));
      setComment(str(courierJson.comment ?? ""));
      setPersonalFeeOverride(
        courierJson.personalFeeOverride == null ? "" : String(courierJson.personalFeeOverride)
      );
      setPayoutBonusAdd(
        courierJson.payoutBonusAdd == null ? "" : String(courierJson.payoutBonusAdd)
      );
      setBlockReason(str(courierJson.blockReason ?? ""));

      if (!avatarFile) {
        setAvatarPreview(resolveAvatarSrc(courierJson.avatarUrl ?? null));
      }

      loadOtd(courierJson.userId || courierId);
      loadCompleted(courierJson.userId || courierId);
    } catch (e: any) {
      setError(e?.message || "Ошибка загрузки");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [courierId]);

  useEffect(() => {
    if (!courier) return;
    loadCompleted(courier.userId || courierId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [completedRange, completedFrom, completedTo]);

  useEffect(() => {
    return () => {
      try {
        if (avatarPreview && avatarPreview.startsWith("blob:")) {
          URL.revokeObjectURL(avatarPreview);
        }
      } catch {}
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!showAvatarViewer) return;

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setShowAvatarViewer(false);
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [showAvatarViewer]);

  const onPickAvatar = (file?: File | null) => {
    setError(null);
    setInfo(null);

    if (!file) {
      setAvatarFile(null);
      setAvatarPreview(resolveAvatarSrc(courier?.avatarUrl ?? null));
      return;
    }

    const okType =
      file.type === "image/jpeg" || file.type === "image/png" || file.type === "image/webp";
    if (!okType) {
      setError("Только jpeg/png/webp");
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      setError("Файл слишком большой (макс 5MB)");
      return;
    }

    setAvatarFile(file);

    try {
      if (avatarPreview && avatarPreview.startsWith("blob:")) {
        URL.revokeObjectURL(avatarPreview);
      }
    } catch {}
    const url = URL.createObjectURL(file);
    setAvatarPreview(url);
  };

  const uploadAvatar = async () => {
    if (!courierId) return;
    if (!avatarFile) {
      setError("Выбери файл");
      return;
    }

    try {
      setAvatarUploading(true);
      setError(null);
      setInfo(null);

      const fd = new FormData();
      fd.append("file", avatarFile);

      await apiFetch(`/couriers/${courierId}/avatar`, {
        method: "POST",
        body: fd,
      });

      setInfo("Фото загружено");
      setAvatarFile(null);
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка загрузки фото");
    } finally {
      setAvatarUploading(false);
    }
  };

  const saveProfile = async () => {
    if (!courierId) return;
    try {
      setSaving(true);
      setError(null);
      setInfo(null);

      const payload = {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        iin: iin.trim(),
        addressText: addressText.trim() || null,
        comment: comment.trim() || null,
        personalFeeOverride:
          personalFeeOverride.trim() === "" ? null : Number(personalFeeOverride),
        payoutBonusAdd: payoutBonusAdd.trim() === "" ? null : Number(payoutBonusAdd),
      };

      await apiFetch(`/couriers/${courierId}/profile`, {
        method: "PATCH",
        body: JSON.stringify(payload),
      });

      setInfo("Сохранено");
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка сохранения");
    } finally {
      setSaving(false);
    }
  };

  const toggleBlock = async (nextBlocked: boolean) => {
    if (!courierId) return;
    try {
      setActionLoading(true);
      setError(null);
      setInfo(null);

      await apiFetch(`/couriers/${courierId}/blocked`, {
        method: "PATCH",
        body: JSON.stringify({
          blocked: nextBlocked,
          reason: nextBlocked ? blockReason?.trim() || null : null,
        }),
      });

      setInfo(nextBlocked ? "Курьер заблокирован" : "Курьер разблокирован");
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка");
    } finally {
      setActionLoading(false);
    }
  };

  const toggleOnline = async (nextOnline: boolean) => {
    if (!courierId) return;
    try {
      setActionLoading(true);
      setError(null);
      setInfo(null);

      await apiFetch(`/couriers/${courierId}/online`, {
        method: "PATCH",
        body: JSON.stringify({ isOnline: nextOnline, source: "admin" }),
      });

      setInfo(nextOnline ? "Онлайн включен" : "Онлайн выключен");
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка");
    } finally {
      setActionLoading(false);
    }
  };

  const assignOrder = async () => {
    if (!courierId) return;
    try {
      setActionLoading(true);
      setError(null);
      setInfo(null);

      const orderId = orderIdToAssign.trim();
      if (!orderId) {
        setError("Укажи orderId");
        return;
      }

      await apiFetch(`/couriers/${courierId}/assign-order`, {
        method: "POST",
        body: JSON.stringify({ orderId }),
      });

      setInfo("Заказ назначен");
      setOrderIdToAssign("");
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка");
    } finally {
      setActionLoading(false);
    }
  };

  const unassignOrder = async (orderId: string) => {
    if (!courierId) return;
    try {
      setActionLoading(true);
      setError(null);
      setInfo(null);

      await apiFetch(`/couriers/${courierId}/unassign-order`, {
        method: "POST",
        body: JSON.stringify({ orderId }),
      });

      setInfo("Заказ снят");
      await load();
    } catch (e: any) {
      setError(e?.message || "Ошибка");
    } finally {
      setActionLoading(false);
    }
  };

  const title = useMemo(() => {
    if (!courier) return "Курьер";
    return `${courier.firstName} ${courier.lastName}`.trim() || courier.phone;
  }, [courier]);

  if (loading) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="text-slate-900 text-lg font-semibold mb-2">Загрузка курьера</div>
          <div className="text-slate-500">Подготавливаем профиль, метрики и активные заказы...</div>
        </div>
      </div>
    );
  }

  if (!courier) {
    return (
      <div className="p-6 bg-[#f5f7fb] min-h-screen">
        <div className="rounded-3xl border border-slate-200 bg-white p-8 shadow-sm">
          <div className="mb-3 text-lg font-semibold text-slate-900">Курьер не найден</div>
          <button
            className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
            onClick={() => router.back()}
          >
            Назад
          </button>
        </div>
      </div>
    );
  }

  const blocked = !courier.isActive;
  const avatarSrc = avatarPreview || resolveAvatarSrc(courier.avatarUrl ?? null);
  const canOpenViewer = !!avatarSrc;

  return (
    <div className="p-6 bg-[#f5f7fb] min-h-screen courier-details-page">
      <div className="max-w-none">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
          <div>
            <button
              className="mb-4 inline-flex items-center gap-2 rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 shadow-sm transition hover:bg-slate-50"
              onClick={() => router.push("/layout-20/couriers")}
            >
              ← Назад
            </button>

            <div className="flex flex-wrap items-center gap-3">
              <h1 className="text-4xl font-bold tracking-tight text-slate-900">Курьер</h1>

              <span
                className={`inline-flex rounded-full border px-3 py-2 text-xs font-semibold ${
                  blocked
                    ? "bg-rose-50 text-rose-700 border-rose-200"
                    : "bg-emerald-50 text-emerald-700 border-emerald-200"
                }`}
              >
                {blocked ? "Заблокирован" : "Активен"}
              </span>

              <span
                className={`inline-flex items-center gap-2 rounded-full border px-3 py-2 text-xs font-semibold ${
                  courier.isOnline
                    ? "bg-blue-50 text-blue-700 border-blue-200"
                    : "bg-slate-50 text-slate-700 border-slate-200"
                }`}
              >
                <span
                  className={`h-2 w-2 rounded-full ${
                    courier.isOnline ? "bg-emerald-500" : "bg-slate-400"
                  }`}
                />
                {courier.isOnline ? "Онлайн" : "Оффлайн"}
              </span>
            </div>

            <p className="mt-2 text-sm text-slate-500">{courier.phone}</p>
          </div>

          <button
            className="rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-95 disabled:opacity-50"
            onClick={saveProfile}
            disabled={saving}
          >
            {saving ? "Сохранение…" : "Сохранить"}
          </button>
        </div>

        {error && (
          <div className="mb-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 text-sm text-rose-700">
            {error}
          </div>
        )}

        {info && (
          <div className="mb-6 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-700">
            {info}
          </div>
        )}

        <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm mb-6">
          <div className="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
            <div className="flex items-center gap-4">
              <button
                type="button"
                className={`h-24 w-24 shrink-0 overflow-hidden rounded-3xl border border-slate-200 bg-slate-100 flex items-center justify-center text-xl font-extrabold text-slate-700 ${
                  canOpenViewer ? "cursor-pointer" : "cursor-default"
                }`}
                onClick={() => {
                  if (canOpenViewer) setShowAvatarViewer(true);
                }}
                title={canOpenViewer ? "Открыть фото" : ""}
              >
                {avatarSrc ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={avatarSrc} alt="avatar" className="h-full w-full object-cover" />
                ) : (
                  <span>{(courier.firstName?.[0] || courier.phone?.[0] || "C").toUpperCase()}</span>
                )}
              </button>

              <div>
                <div className="text-3xl font-extrabold tracking-tight text-slate-900">{title}</div>
                <div className="mt-2 text-base font-bold text-slate-800">
                  Телефон: <span className="font-extrabold text-slate-900">{courier.phone}</span>
                </div>
                <div className="mt-1 text-base font-bold text-slate-800">
                  ИИН: <span className="font-extrabold text-slate-900">{courier.iin || "—"}</span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-semibold text-slate-500">Активные заказы</div>
                <div className="mt-2 text-base font-extrabold text-slate-900">
                  {courier.activeOrders?.length ?? 0}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-semibold text-slate-500">Legacy тариф</div>
                <div className="mt-2 text-base font-extrabold text-slate-900">
                  {personalFeeOverride.trim() === "" ? "—" : formatMoney(personalFeeOverride)}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-semibold text-slate-500">Бонус</div>
                <div className="mt-2 text-base font-extrabold text-slate-900">
                  {payoutBonusAdd.trim() === "" ? "—" : formatMoney(payoutBonusAdd)}
                </div>
              </div>

              <div className="rounded-2xl bg-slate-50 p-4">
                <div className="text-xs font-semibold text-slate-500">Последняя активность</div>
                <div className="mt-2 text-base font-extrabold text-slate-900">
                  {fmtDate(courier?.activeTariff?.lastActiveAt ?? (courier as any)?.lastActiveAt)}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-4 mb-6">
          <StatCard
            title="Выполнено заказов"
            value={completedLoading ? "…" : String(completedCount ?? "—")}
            subtitle="Метрика по выбранному периоду"
            gradient="linear-gradient(135deg, #1bc5bd 0%, #0bb783 100%)"
          />
          <StatCard
            title="Активные заказы"
            value={String(courier.activeOrders?.length ?? 0)}
            subtitle="Текущие назначения"
            gradient="linear-gradient(135deg, #3699ff 0%, #3f51f7 100%)"
          />
          <StatCard
            title="Legacy override"
            value={personalFeeOverride.trim() === "" ? "—" : formatMoney(personalFeeOverride)}
            subtitle="Персональный тариф"
            gradient="linear-gradient(135deg, #8950fc 0%, #d65db1 100%)"
          />
          <StatCard
            title="Бонус к выплате"
            value={payoutBonusAdd.trim() === "" ? "—" : formatMoney(payoutBonusAdd)}
            subtitle="Надбавка курьеру"
            gradient="linear-gradient(135deg, #ff6b6b 0%, #f64e60 100%)"
          />
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.05fr_0.95fr] mb-6">
          <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <h2 className="text-2xl font-bold text-slate-900">Профиль</h2>
                <p className="mt-1 text-sm text-slate-500">
                  Основные данные курьера и фото профиля
                </p>
              </div>
            </div>

            <div className="mb-6 rounded-2xl bg-slate-50 p-5">
              <div className="text-sm font-semibold text-slate-700 mb-3">Фото курьера</div>

              <div className="flex flex-col lg:flex-row items-start lg:items-center gap-4">
                <button
                  type="button"
                  className={`h-36 w-36 overflow-hidden rounded-3xl border border-slate-200 bg-white flex items-center justify-center ${
                    canOpenViewer ? "cursor-pointer" : "cursor-default"
                  }`}
                  onClick={() => {
                    if (canOpenViewer) setShowAvatarViewer(true);
                  }}
                >
                  {avatarSrc ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={avatarSrc} alt="avatar" className="h-full w-full object-cover" />
                  ) : (
                    <div className="text-xs text-slate-400">Нет фото</div>
                  )}
                </button>

                <div className="flex flex-col gap-3 w-full">
                  <div>
                    <input
                      className="block w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900"
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      onChange={(e) => onPickAvatar(e.target.files?.[0] ?? null)}
                    />
                    <div className="text-xs text-slate-500 mt-2">
                      Форматы: jpeg/png/webp, до 5MB
                    </div>
                  </div>

                  <div className="flex flex-wrap gap-2">
                    <button
                      className="rounded-xl bg-slate-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
                      onClick={uploadAvatar}
                      disabled={avatarUploading}
                    >
                      {avatarUploading ? "Загрузка…" : "Загрузить фото"}
                    </button>

                    <button
                      className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50"
                      onClick={() => onPickAvatar(null)}
                      disabled={avatarUploading}
                      type="button"
                    >
                      Сбросить выбор
                    </button>

                    {canOpenViewer ? (
                      <button
                        className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
                        onClick={() => setShowAvatarViewer(true)}
                        type="button"
                      >
                        Открыть
                      </button>
                    ) : null}
                  </div>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <div className="mb-2 text-sm font-semibold text-slate-700">Имя</div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                />
              </div>

              <div>
                <div className="mb-2 text-sm font-semibold text-slate-700">Фамилия</div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                />
              </div>

              <div>
                <div className="mb-2 text-sm font-semibold text-slate-700">ИИН</div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={iin}
                  onChange={(e) => setIin(e.target.value)}
                />
              </div>

              <div>
                <div className="mb-2 text-sm font-semibold text-slate-700">Адрес</div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={addressText}
                  onChange={(e) => setAddressText(e.target.value)}
                />
              </div>

              <div className="md:col-span-2">
                <div className="mb-2 text-sm font-semibold text-slate-700">Комментарий</div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                />
              </div>

              <div className="md:col-span-2 rounded-2xl bg-slate-50 p-4">
                <div className="mb-2 text-sm font-semibold text-slate-700">
                  Персональный тариф (legacy override, работает только когда погода выключена)
                </div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none"
                  value={personalFeeOverride}
                  onChange={(e) => setPersonalFeeOverride(e.target.value)}
                  placeholder="Напр. 1100"
                />

                <div className="mt-4 mb-2 text-sm font-semibold text-slate-700">
                  Бонус к выплате курьеру (надбавка, тг)
                </div>
                <input
                  className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none"
                  value={payoutBonusAdd}
                  onChange={(e) => setPayoutBonusAdd(e.target.value)}
                  placeholder="Напр. 200"
                />
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="text-2xl font-bold text-slate-900 mb-5">Метрики</div>

              <div className="mb-4">
                <div className="text-sm font-semibold text-slate-700 mb-2">Период выполненных заказов</div>
                <select
                  className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                  value={completedRange}
                  onChange={(e) => setCompletedRange(e.target.value as CompletedRange)}
                >
                  <option value="day">За день (сегодня)</option>
                  <option value="month">За месяц (с начала месяца)</option>
                  <option value="year">За год (с начала года)</option>
                  <option value="custom">Произвольно (from/to)</option>
                  <option value="lifetime">За всё время</option>
                </select>
              </div>

              {completedRange === "custom" ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <div className="mb-2 text-sm font-semibold text-slate-700">From</div>
                    <input
                      type="date"
                      className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                      value={completedFrom}
                      onChange={(e) => setCompletedFrom(e.target.value)}
                    />
                  </div>
                  <div>
                    <div className="mb-2 text-sm font-semibold text-slate-700">To</div>
                    <input
                      type="date"
                      className="w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-900 outline-none"
                      value={completedTo}
                      onChange={(e) => setCompletedTo(e.target.value)}
                    />
                  </div>
                </div>
              ) : null}

              <div className="rounded-2xl bg-slate-50 p-4 mb-4">
                <div className="text-xs font-medium text-slate-500">Выполнено заказов</div>
                <div className="mt-1 text-3xl font-bold text-slate-900">
                  {completedLoading ? "…" : completedCount ?? "—"}
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 bg-white p-4">
                <CourierOnTimeRateWidget metric={otd} loading={otdLoading} />
              </div>
            </div>

            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="text-2xl font-bold text-slate-900 mb-5">Финансы</div>
              <CourierFinancePanel courierId={courierId} />
            </div>

            <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="text-2xl font-bold text-slate-900 mb-5">Статус</div>

              <div className="grid grid-cols-1 gap-4">
                <div className="rounded-2xl bg-slate-50 p-4">
                  <div className="text-xs font-medium text-slate-500">Активен</div>
                  <div className="mt-1 text-lg font-bold text-slate-900">{blocked ? "Нет" : "Да"}</div>
                </div>

                <div className="rounded-2xl bg-slate-50 p-4">
                  <div className="text-xs font-medium text-slate-500">Онлайн</div>
                  <div className="mt-1 text-lg font-bold text-slate-900">
                    {courier.isOnline ? "Да" : "Нет"}
                  </div>
                </div>

                <div className="rounded-2xl bg-slate-50 p-4">
                  <div className="text-xs font-medium text-slate-500">Последняя активность</div>
                  <div className="mt-1 text-sm font-bold text-slate-900">
                    {fmtDate(courier?.activeTariff?.lastActiveAt ?? (courier as any)?.lastActiveAt)}
                  </div>
                </div>
              </div>

              <div className="mt-5 flex flex-col gap-3">
                <button
                  className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 disabled:opacity-50"
                  onClick={() => toggleOnline(!courier.isOnline)}
                  disabled={actionLoading || blocked}
                >
                  {courier.isOnline ? "Сделать оффлайн" : "Сделать онлайн"}
                </button>

                <button
                  className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 disabled:opacity-50"
                  onClick={() => toggleBlock(!blocked)}
                  disabled={actionLoading}
                >
                  {blocked ? "Разблокировать" : "Заблокировать"}
                </button>

                {!blocked && (
                  <div className="rounded-2xl bg-slate-50 p-4">
                    <div className="mb-2 text-sm font-semibold text-slate-700">
                      Причина блокировки (если блокируешь)
                    </div>
                    <input
                      className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none"
                      value={blockReason}
                      onChange={(e) => setBlockReason(e.target.value)}
                    />
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 rounded-3xl border border-slate-200 bg-white shadow-sm overflow-hidden">
          <div className="border-b border-slate-200 px-6 py-5">
            <h2 className="text-2xl font-bold text-slate-900">Активные заказы</h2>
            <p className="mt-1 text-sm text-slate-500">
              Назначение и снятие заказов с курьера
            </p>
          </div>

          <div className="px-6 py-5 border-b border-slate-200 bg-slate-50/60">
            <div className="flex flex-col md:flex-row gap-3">
              <input
                className="w-full md:w-80 rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm text-slate-900 outline-none"
                value={orderIdToAssign}
                onChange={(e) => setOrderIdToAssign(e.target.value)}
                placeholder="orderId"
              />
              <button
                className="rounded-2xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white disabled:opacity-50"
                onClick={assignOrder}
                disabled={actionLoading}
              >
                Назначить
              </button>
            </div>
          </div>

          {!courier.activeOrders?.length ? (
            <div className="px-6 py-16 text-center">
              <div className="text-5xl mb-3">📦</div>
              <div className="text-xl font-bold text-slate-900 mb-2">Нет активных заказов</div>
              <div className="text-sm text-slate-500">У курьера сейчас нет активных назначений</div>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/80">
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      ID
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Статус
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Сумма
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Создан
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Назначен
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider text-slate-500">
                      Ресторан
                    </th>
                    <th className="px-6 py-4 text-right text-xs font-bold uppercase tracking-wider text-slate-500">
                      Действия
                    </th>
                  </tr>
                </thead>

                <tbody>
                  {courier.activeOrders.map((o) => {
                    const ui = getOrderStatusUi(o.status);

                    return (
                      <tr key={o.id} className="border-b border-slate-100 transition hover:bg-slate-50">
                        <td className="px-6 py-5 align-top">
                          <div className="text-sm font-semibold text-slate-800 break-all">{o.id}</div>
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
                          <div className="text-sm font-bold text-slate-900">{formatMoney(o.total)}</div>
                        </td>
                        <td className="px-6 py-5 align-top">
                          <div className="text-sm font-semibold text-slate-800">{fmtDate(o.createdAt)}</div>
                        </td>
                        <td className="px-6 py-5 align-top">
                          <div className="text-sm font-semibold text-slate-800">{fmtDate(o.assignedAt)}</div>
                        </td>
                        <td className="px-6 py-5 align-top">
                          <div className="text-sm font-semibold text-slate-800">{o.restaurant?.nameRu ?? "—"}</div>
                        </td>
                        <td className="px-6 py-5 align-top text-right">
                          <button
                            className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700 disabled:opacity-50"
                            onClick={() => unassignOrder(o.id)}
                            disabled={actionLoading}
                          >
                            Снять
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {showAvatarViewer ? (
        <div
          className="fixed inset-0 z-[99999] bg-black/65 flex items-center justify-center p-4"
          onClick={() => setShowAvatarViewer(false)}
          role="dialog"
          aria-modal="true"
        >
          <div
            className="w-full max-w-6xl h-[min(820px,calc(100vh-24px))] bg-white rounded-3xl border border-slate-200 shadow-2xl overflow-hidden flex flex-col"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="px-5 py-4 border-b border-slate-200 flex items-center justify-between gap-3">
              <div className="text-xl font-bold text-slate-900">Фото курьера</div>
              <button
                className="h-10 w-10 rounded-xl border border-slate-200 bg-white text-slate-700 font-bold"
                onClick={() => setShowAvatarViewer(false)}
                type="button"
              >
                ✕
              </button>
            </div>

            <div className="flex-1 min-h-0 p-4 flex items-center justify-center bg-black">
              {avatarSrc ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={avatarSrc} alt="avatar-full" className="max-w-full max-h-full object-contain" />
              ) : (
                <div className="text-sm text-slate-300">Нет фото</div>
              )}
            </div>

            <div className="px-5 py-4 border-t border-slate-200 flex justify-end gap-3 bg-white">
              <button
                className="rounded-xl border border-slate-200 bg-white px-4 py-2 text-sm font-semibold text-slate-700"
                onClick={() => setShowAvatarViewer(false)}
                type="button"
              >
                Закрыть
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}