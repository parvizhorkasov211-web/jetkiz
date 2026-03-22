"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/lib/api";

type FinanceConfig = {
  id: string;
  clientDeliveryFeeDefault: number;
  clientDeliveryFeeWeather: number;
  courierPayoutDefault: number;
  courierPayoutWeather: number;
  weatherEnabled: boolean;
};

function toStr(v: unknown) {
  return v == null ? "" : String(v);
}

function parseRequiredNumber(value: string, label: string) {
  const normalized = value.trim();

  if (!normalized) {
    throw new Error(`Поле "${label}" обязательно`);
  }

  const parsed = Number(normalized);

  if (!Number.isFinite(parsed)) {
    throw new Error(`Поле "${label}" должно быть числом`);
  }

  if (parsed < 0) {
    throw new Error(`Поле "${label}" не может быть меньше 0`);
  }

  return parsed;
}

export default function FinancePage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const [weatherEnabled, setWeatherEnabled] = useState(false);

  const [clientDeliveryFeeDefault, setClientDeliveryFeeDefault] = useState("");
  const [clientDeliveryFeeWeather, setClientDeliveryFeeWeather] = useState("");
  const [courierPayoutDefault, setCourierPayoutDefault] = useState("");
  const [courierPayoutWeather, setCourierPayoutWeather] = useState("");

  const load = async () => {
    try {
      setLoading(true);
      setError(null);

      const json = await apiFetch("/restaurants/finance/config", {
        method: "GET",
        cache: "no-store",
      });

      const cfg: FinanceConfig = (json?.config ?? json) as FinanceConfig;

      setWeatherEnabled(Boolean(cfg.weatherEnabled));
      setClientDeliveryFeeDefault(toStr(cfg.clientDeliveryFeeDefault));
      setClientDeliveryFeeWeather(toStr(cfg.clientDeliveryFeeWeather));
      setCourierPayoutDefault(toStr(cfg.courierPayoutDefault));
      setCourierPayoutWeather(toStr(cfg.courierPayoutWeather));
    } catch (e: any) {
      setError(e?.message || "Ошибка загрузки");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const save = async () => {
    try {
      setSaving(true);
      setError(null);
      setInfo(null);

      const payload = {
        weatherEnabled,
        clientDeliveryFeeDefault: parseRequiredNumber(
          clientDeliveryFeeDefault,
          "Доставка для клиента (обычно)"
        ),
        clientDeliveryFeeWeather: parseRequiredNumber(
          clientDeliveryFeeWeather,
          "Доставка для клиента (в режиме)"
        ),
        courierPayoutDefault: parseRequiredNumber(
          courierPayoutDefault,
          "Выплата курьеру (обычно)"
        ),
        courierPayoutWeather: parseRequiredNumber(
          courierPayoutWeather,
          "Выплата курьеру (в режиме)"
        ),
      };

      await apiFetch("/restaurants/finance/config", {
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

  if (loading) {
    return (
      <div className="p-6">
        <div className="text-sm text-gray-600">Загрузка…</div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6 flex items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold">Финансы доставки</h1>
          <div className="text-sm text-gray-600">
            Глобальные тарифы и массовый режим. Курьерские бонусы
            настраиваются отдельно в карточке курьера.
          </div>
        </div>

        <button
          className="rounded bg-black px-4 py-2 text-white disabled:opacity-60"
          onClick={save}
          disabled={saving}
        >
          {saving ? "Сохранение…" : "Сохранить"}
        </button>
      </div>

      {error && (
        <div className="mb-4 rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {info && (
        <div className="mb-4 rounded border border-green-200 bg-green-50 p-3 text-sm text-green-700">
          {info}
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="rounded border p-4">
          <div className="mb-3 text-base font-semibold">Глобальные тарифы</div>

          <div className="text-sm text-gray-600">
            Доставка для клиента (обычно)
          </div>
          <input
            className="mt-1 w-full rounded border px-3 py-2"
            value={clientDeliveryFeeDefault}
            onChange={(e) => setClientDeliveryFeeDefault(e.target.value)}
            placeholder="Напр. 1200"
            inputMode="numeric"
          />

          <div className="mt-4 text-sm text-gray-600">
            Выплата курьеру (обычно)
          </div>
          <input
            className="mt-1 w-full rounded border px-3 py-2"
            value={courierPayoutDefault}
            onChange={(e) => setCourierPayoutDefault(e.target.value)}
            placeholder="Напр. 1100"
            inputMode="numeric"
          />

          <div className="mt-4 text-xs text-gray-500">
            Цена доставки для клиента не зависит от конкретного курьера.
            Индивидуальные бонусы курьера добавляются отдельно.
          </div>
        </div>

        <div className="rounded border p-4">
          <div className="mb-3 flex items-center justify-between">
            <div className="text-base font-semibold">
              Массовый режим (погода / пик)
            </div>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={weatherEnabled}
                onChange={(e) => setWeatherEnabled(e.target.checked)}
              />
              Включено
            </label>
          </div>

          <div className="text-sm text-gray-600">
            Доставка для клиента (в режиме)
          </div>
          <input
            className="mt-1 w-full rounded border px-3 py-2"
            value={clientDeliveryFeeWeather}
            onChange={(e) => setClientDeliveryFeeWeather(e.target.value)}
            placeholder="Напр. 1500"
            inputMode="numeric"
          />

          <div className="mt-4 text-sm text-gray-600">
            Выплата курьеру (в режиме)
          </div>
          <input
            className="mt-1 w-full rounded border px-3 py-2"
            value={courierPayoutWeather}
            onChange={(e) => setCourierPayoutWeather(e.target.value)}
            placeholder="Напр. 1500"
            inputMode="numeric"
          />

          <div className="mt-4 text-xs text-gray-500">
            При включении режима его значения имеют приоритет глобально.
            Индивидуальные бонусы курьера прибавляются поверх базы или режима.
          </div>
        </div>
      </div>

      <div className="mt-6 rounded border p-4">
        <div className="mb-2 text-base font-semibold">Что будет применяться</div>

        <div className="text-sm text-gray-700">
          <div>
            Клиент платит:{" "}
            <b>
              {weatherEnabled
                ? clientDeliveryFeeWeather || "—"
                : clientDeliveryFeeDefault || "—"}
            </b>
          </div>

          <div>
            Курьер получает базу:{" "}
            <b>
              {weatherEnabled
                ? courierPayoutWeather || "—"
                : courierPayoutDefault || "—"}
            </b>{" "}
            + бонус, если он задан у курьера.
          </div>
        </div>
      </div>
    </div>
  );
}