'use client';

import { ChangeEvent, FormEvent, useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';

type PromoCode = {
  id: string;
  code: string;
  type: 'PERCENT' | 'FIXED' | 'FREE_DELIVERY';
  value: number;
  minOrderAmount?: number | null;
  usageLimit?: number | null;
  perUserLimit?: number | null;
  maxDiscountAmount?: number | null;
  firstOrderOnly?: boolean | null;
  restaurantId?: string | null;
  startsAt?: string | null;
  expiresAt?: string | null;
  isActive: boolean;
};

type CreatePromoCodeForm = {
  code: string;
  type: 'PERCENT' | 'FIXED' | 'FREE_DELIVERY';
  value: string;
  minOrderAmount: string;
  usageLimit: string;
  perUserLimit: string;
  maxDiscountAmount: string;
  startsAt: string;
  expiresAt: string;
  firstOrderOnly: boolean;
  restaurantId: string;
  isActive: boolean;
  autoGenerate: boolean;
};

const initialForm: CreatePromoCodeForm = {
  code: '',
  type: 'PERCENT',
  value: '',
  minOrderAmount: '',
  usageLimit: '',
  perUserLimit: '1',
  maxDiscountAmount: '',
  startsAt: '',
  expiresAt: '',
  firstOrderOnly: false,
  restaurantId: '',
  isActive: true,
  autoGenerate: false,
};

function formatDate(value?: string | null) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString();
}

function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return fallback;
}

export default function PromocodesPage() {
  const [items, setItems] = useState<PromoCode[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [showCreateForm, setShowCreateForm] = useState(false);
  const [form, setForm] = useState<CreatePromoCodeForm>(initialForm);
  const [submitting, setSubmitting] = useState(false);
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);

  const loadPromoCodes = async () => {
    try {
      setLoading(true);
      setError(null);

      const data = await apiFetch('/promo-codes', {
        method: 'GET',
        cache: 'no-store',
      });

      setItems(Array.isArray(data) ? data : []);
    } catch (e) {
      setError(getErrorMessage(e, 'Ошибка загрузки'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPromoCodes();
  }, []);

  const handleInputChange = (
    e: ChangeEvent<HTMLInputElement | HTMLSelectElement>
  ) => {
    const { name, value, type } = e.target;
    const checked = 'checked' in e.target ? e.target.checked : false;

    setForm((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
    }));
  };

  const handleCreate = async (e: FormEvent) => {
    e.preventDefault();

    try {
      setSubmitting(true);
      setError(null);

      const payload = {
        code: form.code.trim() || undefined,
        type: form.type,
        value: Number(form.value),
        isActive: form.isActive,
        startsAt: form.startsAt ? new Date(form.startsAt).toISOString() : undefined,
        expiresAt: form.expiresAt ? new Date(form.expiresAt).toISOString() : undefined,
        usageLimit: form.usageLimit ? Number(form.usageLimit) : undefined,
        perUserLimit: form.perUserLimit ? Number(form.perUserLimit) : undefined,
        minOrderAmount: form.minOrderAmount ? Number(form.minOrderAmount) : undefined,
        maxDiscountAmount: form.maxDiscountAmount
          ? Number(form.maxDiscountAmount)
          : undefined,
        firstOrderOnly: form.firstOrderOnly,
        restaurantId: form.restaurantId.trim() || undefined,
        autoGenerate: form.autoGenerate,
      };

      if (!Number.isInteger(payload.value) || payload.value < 0) {
        throw new Error('value должен быть целым числом и не меньше 0');
      }

      await apiFetch('/promo-codes', {
        method: 'POST',
        body: JSON.stringify(payload),
      });

      setForm(initialForm);
      setShowCreateForm(false);
      await loadPromoCodes();
    } catch (e) {
      setError(getErrorMessage(e, 'Ошибка создания'));
    } finally {
      setSubmitting(false);
    }
  };

  const handleToggle = async (promoId: string) => {
    try {
      setActionLoadingId(promoId);
      setError(null);

      await apiFetch(`/promo-codes/${promoId}/toggle`, {
        method: 'PATCH',
      });

      await loadPromoCodes();
    } catch (e) {
      setError(getErrorMessage(e, 'Ошибка переключения'));
    } finally {
      setActionLoadingId(null);
    }
  };

  const sortedItems = [...items].sort((a, b) => {
    if (a.isActive === b.isActive) {
      return a.code.localeCompare(b.code);
    }

    return a.isActive ? -1 : 1;
  });

  return (
    <div className="space-y-6 p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Промокоды</h1>
          <p className="text-sm text-gray-500">
            Управление промокодами для backend и будущих приложений
          </p>
        </div>

        <button
          type="button"
          className="rounded-lg border px-4 py-2 text-sm font-medium"
          onClick={() => setShowCreateForm((prev) => !prev)}
        >
          {showCreateForm ? 'Закрыть форму' : 'Создать промокод'}
        </button>
      </div>

      {error ? (
        <div className="rounded-lg border border-red-300 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      ) : null}

      {showCreateForm ? (
        <form
          onSubmit={handleCreate}
          className="grid grid-cols-1 gap-4 rounded-xl border p-4 md:grid-cols-2"
        >
          <div>
            <label className="mb-1 block text-sm font-medium">Код</label>
            <input
              name="code"
              value={form.code}
              onChange={handleInputChange}
              placeholder="WELCOME20"
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Тип скидки</label>
            <select
              name="type"
              value={form.type}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            >
              <option value="PERCENT">PERCENT</option>
              <option value="FIXED">FIXED</option>
              <option value="FREE_DELIVERY">FREE_DELIVERY</option>
            </select>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Значение</label>
            <input
              name="value"
              type="number"
              min="0"
              value={form.value}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">
              Мин. сумма заказа
            </label>
            <input
              name="minOrderAmount"
              type="number"
              min="0"
              value={form.minOrderAmount}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Лимит использований</label>
            <input
              name="usageLimit"
              type="number"
              min="0"
              value={form.usageLimit}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">
              Лимит на пользователя
            </label>
            <input
              name="perUserLimit"
              type="number"
              min="0"
              value={form.perUserLimit}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">
              Макс. размер скидки
            </label>
            <input
              name="maxDiscountAmount"
              type="number"
              min="0"
              value={form.maxDiscountAmount}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Restaurant ID</label>
            <input
              name="restaurantId"
              value={form.restaurantId}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">Дата старта</label>
            <input
              name="startsAt"
              type="datetime-local"
              value={form.startsAt}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium">
              Дата окончания
            </label>
            <input
              name="expiresAt"
              type="datetime-local"
              value={form.expiresAt}
              onChange={handleInputChange}
              className="w-full rounded-lg border px-3 py-2"
            />
          </div>

          <div className="flex items-center gap-2">
            <input
              id="isActive"
              name="isActive"
              type="checkbox"
              checked={form.isActive}
              onChange={handleInputChange}
            />
            <label htmlFor="isActive" className="text-sm font-medium">
              Активен
            </label>
          </div>

          <div className="flex items-center gap-2">
            <input
              id="firstOrderOnly"
              name="firstOrderOnly"
              type="checkbox"
              checked={form.firstOrderOnly}
              onChange={handleInputChange}
            />
            <label htmlFor="firstOrderOnly" className="text-sm font-medium">
              Только первый заказ
            </label>
          </div>

          <div className="flex items-center gap-2 md:col-span-2">
            <input
              id="autoGenerate"
              name="autoGenerate"
              type="checkbox"
              checked={form.autoGenerate}
              onChange={handleInputChange}
            />
            <label htmlFor="autoGenerate" className="text-sm font-medium">
              Автогенерация кода
            </label>
          </div>

          <div className="flex gap-3 md:col-span-2">
            <button
              type="submit"
              disabled={submitting}
              className="rounded-lg border px-4 py-2 text-sm font-medium disabled:opacity-50"
            >
              {submitting ? 'Создание...' : 'Сохранить'}
            </button>

            <button
              type="button"
              className="rounded-lg border px-4 py-2 text-sm"
              onClick={() => {
                setForm(initialForm);
                setShowCreateForm(false);
              }}
            >
              Отмена
            </button>
          </div>
        </form>
      ) : null}

      <div className="overflow-x-auto rounded-xl border">
        {loading ? (
          <div className="p-4">Загрузка промокодов...</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="p-3 text-left">Код</th>
                <th className="p-3 text-left">Тип</th>
                <th className="p-3 text-left">Значение</th>
                <th className="p-3 text-left">Мин. сумма</th>
                <th className="p-3 text-left">Лимит</th>
                <th className="p-3 text-left">На пользователя</th>
                <th className="p-3 text-left">Restaurant ID</th>
                <th className="p-3 text-left">Старт</th>
                <th className="p-3 text-left">Окончание</th>
                <th className="p-3 text-left">Статус</th>
                <th className="p-3 text-left">Действия</th>
              </tr>
            </thead>

            <tbody>
              {sortedItems.length === 0 ? (
                <tr>
                  <td colSpan={11} className="p-4 text-center text-gray-500">
                    Промокоды не найдены
                  </td>
                </tr>
              ) : (
                sortedItems.map((item) => (
                  <tr key={item.id} className="border-b">
                    <td className="p-3 font-medium">{item.code}</td>
                    <td className="p-3">{item.type}</td>
                    <td className="p-3">{item.value}</td>
                    <td className="p-3">{item.minOrderAmount ?? '-'}</td>
                    <td className="p-3">{item.usageLimit ?? '-'}</td>
                    <td className="p-3">{item.perUserLimit ?? '-'}</td>
                    <td className="p-3">{item.restaurantId ?? '-'}</td>
                    <td className="p-3">{formatDate(item.startsAt)}</td>
                    <td className="p-3">{formatDate(item.expiresAt)}</td>
                    <td className="p-3">
                      <span
                        className={`inline-flex rounded-full px-2 py-1 text-xs font-medium ${
                          item.isActive
                            ? 'bg-green-100 text-green-700'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {item.isActive ? 'Активен' : 'Выключен'}
                      </span>
                    </td>
                    <td className="p-3">
                      <button
                        type="button"
                        disabled={actionLoadingId === item.id}
                        className="rounded-lg border px-3 py-1.5 text-xs font-medium disabled:opacity-50"
                        onClick={() => handleToggle(item.id)}
                      >
                        {actionLoadingId === item.id
                          ? 'Сохраняем...'
                          : item.isActive
                            ? 'Выключить'
                            : 'Включить'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}