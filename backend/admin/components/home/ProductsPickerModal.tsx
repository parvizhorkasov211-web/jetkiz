'use client';

import { useEffect, useMemo, useState } from 'react';
import { apiFetch, API_URL } from '@/lib/api';
import { Check, Loader2, Package, Search, Store, X } from 'lucide-react';

type PickerRestaurant = {
  id: string;
  nameRu: string;
  nameKk: string;
  coverImageUrl?: string | null;
  productsCount: number;
  matchedProductsCount: number;
};

type PickerItem = {
  id: string;
  titleRu: string;
  titleKk: string;
  price: number;
  imageUrl?: string | null;
  isAvailable: boolean;
  restaurantId: string;
  restaurantNameRu: string;
  restaurantNameKk: string;
  isSelected: boolean;
};

type ProductsPickerResponse = {
  q: string;
  restaurantId: string | null;
  categoryId: string | null;
  selectedProductIds: string[];
  restaurants: PickerRestaurant[];
  items: PickerItem[];
};

type CategoryProductDraft = {
  productId: string;
  sortOrder: number;
  isActive: boolean;
  product: {
    id: string;
    titleRu: string;
    titleKk: string;
    price: number;
    imageUrl: string | null;
    isAvailable: boolean;
    restaurantId: string;
    restaurant: {
      id: string;
      nameRu: string;
      nameKk: string;
    };
  };
};


const API_BASE = API_URL;

function resolveImageUrl(url?: string | null) {
  if (!url) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `${API_BASE}${url.startsWith('/') ? url : `/${url}`}`;
}

export default function ProductsPickerModal({
  categoryId,
  categoryTitle,
  existingProductIds,
  nextSortOrder,
  onClose,
  onApply,
}: {
  categoryId?: string;
  categoryTitle: string;
  existingProductIds: string[];
  nextSortOrder: number;
  onClose: () => void;
  onApply: (items: CategoryProductDraft[]) => void;
}) {
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [query, setQuery] = useState('');
  const [selectedRestaurantId, setSelectedRestaurantId] = useState('');
  const [restaurants, setRestaurants] = useState<PickerRestaurant[]>([]);
  const [items, setItems] = useState<PickerItem[]>([]);
  const [checkedIds, setCheckedIds] = useState<Record<string, boolean>>({});

  async function loadPicker(params?: {
    q?: string;
    restaurantId?: string;
  }) {
    try {
      setLoading(true);
      setError(null);

      const search = new URLSearchParams();

      if (categoryId) {
        search.set('categoryId', categoryId);
      }

      if (params?.q?.trim()) {
        search.set('q', params.q.trim());
      }

      if (params?.restaurantId?.trim()) {
        search.set('restaurantId', params.restaurantId.trim());
      }

      const path = `/home-cms/admin/products-picker?${search.toString()}`;
      const data = (await apiFetch(path)) as ProductsPickerResponse;

      setRestaurants(Array.isArray(data.restaurants) ? data.restaurants : []);
      setItems(Array.isArray(data.items) ? data.items : []);

      const nextChecked: Record<string, boolean> = {};

      for (const item of data.items || []) {
        if (existingProductIds.includes(item.id) || item.isSelected) {
          nextChecked[item.id] = true;
        }
      }

      setCheckedIds((prev) => ({
        ...prev,
        ...nextChecked,
      }));
    } catch (e: any) {
      setError(e?.message || 'Не удалось загрузить список блюд');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadPicker();
  }, [categoryId]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadPicker({
        q: query,
        restaurantId: selectedRestaurantId,
      });
    }, 250);

    return () => clearTimeout(timer);
  }, [query, selectedRestaurantId, categoryId]);

  function toggleItem(id: string) {
    setCheckedIds((prev) => ({
      ...prev,
      [id]: !prev[id],
    }));
  }

  const selectedCount = useMemo(() => {
    return Object.values(checkedIds).filter(Boolean).length;
  }, [checkedIds]);

  const newSelectedCount = useMemo(() => {
    return Object.entries(checkedIds).filter(
      ([id, checked]) => checked && !existingProductIds.includes(id),
    ).length;
  }, [checkedIds, existingProductIds]);

  function applySelection() {
    try {
      setSubmitting(true);

      const newIds = Object.entries(checkedIds)
        .filter(([id, checked]) => checked && !existingProductIds.includes(id))
        .map(([id]) => id);

      const payload: CategoryProductDraft[] = items
  .filter((item) => checkedIds[item.id] && !existingProductIds.includes(item.id))
  .map((item, index) => ({
    productId: item.id,
    sortOrder: nextSortOrder + index,
    isActive: true,
    product: {
      id: item.id,
      titleRu: item.titleRu,
      titleKk: item.titleKk,
      price: item.price,
      imageUrl: item.imageUrl || null,
      isAvailable: item.isAvailable,
      restaurantId: item.restaurantId,
      restaurant: {
        id: item.restaurantId,
        nameRu: item.restaurantNameRu,
        nameKk: item.restaurantNameKk,
      },
    },
  }));


      onApply(payload);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center bg-slate-950/55 p-4 backdrop-blur-sm">
      <div className="flex max-h-[90vh] w-full max-w-7xl flex-col overflow-hidden rounded-[28px] border border-slate-200 bg-white shadow-2xl">
        <div className="flex items-center justify-between border-b border-slate-200 px-6 py-5">
          <div>
            <div className="text-2xl font-extrabold text-slate-900">
              Добавить блюда в категорию
            </div>
            <div className="mt-1 text-sm font-medium text-slate-500">
              Категория: <span className="font-bold text-slate-800">{categoryTitle || 'Без названия'}</span>
            </div>
          </div>

          <button
            onClick={onClose}
            className="inline-flex h-11 w-11 items-center justify-center rounded-2xl border border-slate-300 bg-white text-slate-700 shadow-sm transition hover:bg-slate-50"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="border-b border-slate-200 px-6 py-5">
          <div className="grid gap-4 xl:grid-cols-[1.2fr_0.8fr_auto]">
            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-800">
                Поиск по блюдам и ресторанам
              </span>
              <div className="flex h-12 items-center gap-3 rounded-2xl border border-slate-300 bg-white px-4 shadow-sm focus-within:border-blue-500">
                <Search className="h-4 w-4 text-slate-400" />
                <input
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Например: суши, ролл, бургер, Ак-желкен"
                  className="h-full w-full bg-transparent text-sm font-medium text-slate-900 outline-none"
                />
              </div>
            </label>

            <label className="grid gap-2">
              <span className="text-sm font-semibold text-slate-800">
                Ресторан
              </span>
              <select
                value={selectedRestaurantId}
                onChange={(e) => setSelectedRestaurantId(e.target.value)}
                className="h-12 rounded-2xl border border-slate-300 bg-white px-4 text-sm font-medium text-slate-900 shadow-sm outline-none"
              >
                <option value="">Все рестораны</option>
                {restaurants.map((restaurant) => (
                  <option key={restaurant.id} value={restaurant.id}>
                    {restaurant.nameRu || restaurant.nameKk}
                  </option>
                ))}
              </select>
            </label>

            <div className="flex items-end">
              <div className="flex h-12 min-w-[180px] items-center justify-center rounded-2xl bg-slate-900 px-4 text-sm font-bold text-white shadow-md">
                Выбрано: {selectedCount}
              </div>
            </div>
          </div>
        </div>

        <div className="grid min-h-0 flex-1 xl:grid-cols-[320px_1fr]">
          <div className="border-r border-slate-200 bg-slate-50/70 p-5">
            <div className="mb-4 text-sm font-extrabold uppercase tracking-wide text-slate-700">
              Рестораны
            </div>

            <div className="space-y-3 overflow-auto pr-1">
              <button
                onClick={() => setSelectedRestaurantId('')}
                className={`w-full rounded-2xl border px-4 py-3 text-left shadow-sm transition ${
                  selectedRestaurantId === ''
                    ? 'border-slate-900 bg-slate-900 text-white'
                    : 'border-slate-200 bg-white text-slate-900 hover:bg-slate-50'
                }`}
              >
                <div className="font-extrabold">Все рестораны</div>
                <div
                  className={`mt-1 text-xs font-medium ${
                    selectedRestaurantId === '' ? 'text-white/80' : 'text-slate-500'
                  }`}
                >
                  Общий список по всем ресторанам
                </div>
              </button>

              {restaurants.map((restaurant) => {
                const active = selectedRestaurantId === restaurant.id;

                return (
                  <button
                    key={restaurant.id}
                    onClick={() => setSelectedRestaurantId(restaurant.id)}
                    className={`w-full rounded-2xl border px-4 py-3 text-left shadow-sm transition ${
                      active
                        ? 'border-slate-900 bg-slate-900 text-white'
                        : 'border-slate-200 bg-white text-slate-900 hover:bg-slate-50'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div
                        className={`mt-0.5 flex h-9 w-9 items-center justify-center rounded-2xl ${
                          active ? 'bg-white/15' : 'bg-slate-100'
                        }`}
                      >
                        <Store
                          className={`h-4 w-4 ${
                            active ? 'text-white' : 'text-slate-600'
                          }`}
                        />
                      </div>

                      <div className="min-w-0 flex-1">
                        <div className="truncate font-extrabold">
                          {restaurant.nameRu || restaurant.nameKk}
                        </div>
                        <div
                          className={`mt-1 text-xs font-medium ${
                            active ? 'text-white/80' : 'text-slate-500'
                          }`}
                        >
                          Всего блюд: {restaurant.productsCount}
                        </div>
                        {query.trim() ? (
                          <div
                            className={`mt-1 text-xs font-medium ${
                              active ? 'text-white/80' : 'text-slate-500'
                            }`}
                          >
                            Найдено: {restaurant.matchedProductsCount}
                          </div>
                        ) : null}
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="min-h-0 overflow-auto p-5">
            {error ? (
              <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">
                {error}
              </div>
            ) : null}

            {loading ? (
              <div className="flex min-h-[320px] items-center justify-center rounded-3xl border border-slate-200 bg-white">
                <div className="flex items-center gap-3 text-sm font-semibold text-slate-600">
                  <Loader2 className="h-5 w-5 animate-spin" />
                  Загрузка блюд...
                </div>
              </div>
            ) : items.length === 0 ? (
              <div className="flex min-h-[320px] flex-col items-center justify-center rounded-3xl border border-dashed border-slate-300 bg-slate-50 text-center">
                <Package className="mb-3 h-8 w-8 text-slate-400" />
                <div className="text-sm font-semibold text-slate-700">
                  Ничего не найдено
                </div>
                <div className="mt-1 text-xs font-medium text-slate-500">
                  Попробуй изменить поиск или выбрать другой ресторан
                </div>
              </div>
            ) : (
              <div className="grid gap-4 xl:grid-cols-2">
                {items.map((item) => {
                  const checked = Boolean(checkedIds[item.id]);
                  const alreadyInCategory = existingProductIds.includes(item.id);

                  return (
                    <label
                      key={item.id}
                      className={`cursor-pointer rounded-3xl border p-4 shadow-sm transition ${
                        checked
                          ? 'border-slate-900 bg-slate-900 text-white'
                          : 'border-slate-200 bg-white hover:shadow-md'
                      }`}
                    >
                      <div className="flex gap-4">
                        <div className="h-20 w-20 flex-shrink-0 overflow-hidden rounded-2xl bg-slate-100">
                          {item.imageUrl ? (
                            <img
                              src={resolveImageUrl(item.imageUrl)}
                              alt={item.titleRu || item.titleKk}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <div className="flex h-full w-full items-center justify-center text-slate-400">
                              <Package className="h-6 w-6" />
                            </div>
                          )}
                        </div>

                        <div className="min-w-0 flex-1">
                          <div className="flex items-start justify-between gap-3">
                            <div className="min-w-0">
                              <div className="truncate text-base font-extrabold">
                                {item.titleRu || item.titleKk || 'Без названия'}
                              </div>
                              <div
                                className={`mt-1 text-sm font-medium ${
                                  checked ? 'text-white/80' : 'text-slate-500'
                                }`}
                              >
                                {item.restaurantNameRu || item.restaurantNameKk}
                              </div>
                            </div>

                            <input
                              type="checkbox"
                              checked={checked}
                              onChange={() => toggleItem(item.id)}
                              className="mt-1 h-5 w-5"
                            />
                          </div>

                          <div className="mt-3 flex flex-wrap gap-2">
                            <span
                              className={`rounded-full px-3 py-1 text-xs font-bold ${
                                checked
                                  ? 'bg-white/15 text-white'
                                  : 'bg-slate-100 text-slate-700'
                              }`}
                            >
                              {item.price} ₸
                            </span>

                            <span
                              className={`rounded-full px-3 py-1 text-xs font-bold ${
                                item.isAvailable
                                  ? checked
                                    ? 'bg-emerald-500/20 text-emerald-100'
                                    : 'bg-emerald-100 text-emerald-700'
                                  : checked
                                  ? 'bg-red-500/20 text-red-100'
                                  : 'bg-red-100 text-red-700'
                              }`}
                            >
                              {item.isAvailable ? 'Доступен' : 'Недоступен'}
                            </span>

                            {alreadyInCategory ? (
                              <span
                                className={`rounded-full px-3 py-1 text-xs font-bold ${
                                  checked
                                    ? 'bg-amber-500/20 text-amber-100'
                                    : 'bg-amber-100 text-amber-700'
                                }`}
                              >
                                Уже в категории
                              </span>
                            ) : null}
                          </div>
                        </div>
                      </div>
                    </label>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        <div className="flex items-center justify-between border-t border-slate-200 px-6 py-5">
          <div className="text-sm font-medium text-slate-500">
            Новых блюд для добавления: {newSelectedCount}
          </div>

          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="inline-flex h-11 items-center gap-2 rounded-2xl border border-slate-300 bg-white px-4 text-sm font-bold text-slate-800 shadow-sm transition hover:bg-slate-50"
            >
              Отмена
            </button>

            <button
              onClick={applySelection}
              disabled={submitting}
              className="inline-flex h-11 items-center gap-2 rounded-2xl bg-slate-900 px-5 text-sm font-bold text-white shadow-md transition hover:opacity-90 disabled:opacity-50"
            >
              <Check className="h-4 w-4" />
              Добавить выбранные
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
