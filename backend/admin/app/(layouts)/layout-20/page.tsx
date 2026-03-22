'use client';

import { useEffect, useMemo, useState } from 'react';
import { useLayout } from '@/components/layouts/layout-20/components/context';
import { HeaderTitle } from '@/components/layouts/layout-20/components/header-title';
import { apiFetch, API_URL } from '@/lib/api';
import ProductsPickerModal from '@/components/home/ProductsPickerModal';
import {
  ImagePlus,
  Save,
  Trash2,
  Plus,
  LayoutGrid,
  Megaphone,
  Eye,
  Loader2,
  Package,
} from 'lucide-react';

type HomeCmsCategoryProduct = {
  id?: string;
  productId: string;
  sortOrder: number;
  isActive: boolean;
  product?: {
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

type HomeCmsCategory = {
  id?: string;
  titleRu: string;
  titleKk: string;
  imageUrl: string;
  sortOrder: number;
  isActive: boolean;
  products: HomeCmsCategoryProduct[];
};

type HomeCmsAdminResponse = {
  id: string;
  promoTitleRu: string;
  promoTitleKk: string;
  promoImageUrl: string;
  promoIsActive: boolean;
  categories: HomeCmsCategory[];
  updatedAt?: string | null;
};

type UploadResponse = {
  url: string;
};

const API_BASE = API_URL;

function resolveImageUrl(url?: string | null) {
  if (!url) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return `${API_BASE}${url.startsWith('/') ? url : `/${url}`}`;
}

async function uploadImage(file: File): Promise<string> {
  const formData = new FormData();
  formData.append('file', file);

  const res = await fetch(`${API_BASE}/home-cms/upload`, {
    method: 'POST',
    body: formData,
    credentials: 'include',
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || 'Ошибка загрузки изображения');
  }

  const data = (await res.json()) as UploadResponse;

  if (!data?.url) {
    throw new Error('Сервер не вернул ссылку на изображение');
  }

  return data.url;
}

function StatsCard({
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
    <div className={`rounded-3xl p-5 text-white shadow-md ${gradient}`}>
      <div className="text-sm font-semibold text-white/90">{title}</div>
      <div className="mt-3 text-4xl font-extrabold leading-none">{value}</div>
      <div className="mt-2 text-sm text-white/85">{subtitle}</div>
    </div>
  );
}

function SectionTitle({
  title,
  description,
  action,
}: {
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
      <div>
        <h2 className="text-2xl font-extrabold text-slate-900">{title}</h2>
        <p className="mt-1 text-sm font-medium text-slate-500">{description}</p>
      </div>
      {action}
    </div>
  );
}

function Input({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
}: {
  label: string;
  value: string | number;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
}) {
  return (
    <label className="grid gap-2">
      <span className="text-sm font-semibold text-slate-800">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-12 rounded-2xl border border-slate-300 bg-white px-4 text-sm font-medium text-slate-900 shadow-md outline-none transition focus:border-blue-500 focus:shadow-lg"
      />
    </label>
  );
}

function Switch({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
}) {
  return (
    <label className="flex items-center gap-3 rounded-2xl border border-slate-300 bg-white px-4 py-3 shadow-md">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="h-4 w-4"
      />
      <span className="text-sm font-semibold text-slate-800">{label}</span>
    </label>
  );
}

function UploadBox({
  label,
  imageUrl,
  onUploaded,
  loading,
}: {
  label: string;
  imageUrl: string;
  onUploaded: (file: File) => Promise<void> | void;
  loading: boolean;
}) {
  async function handleFileChange(file?: File | null) {
    if (!file) return;
    await onUploaded(file);
  }

  return (
    <div className="grid gap-2">
      <span className="text-sm font-semibold text-slate-800">{label}</span>

      <label className="group flex cursor-pointer flex-col items-center justify-center rounded-3xl border border-dashed border-slate-300 bg-slate-50 p-5 text-center shadow-md transition hover:border-blue-400 hover:bg-blue-50 hover:shadow-lg">
        <input
          type="file"
          accept="image/*"
          className="hidden"
          disabled={loading}
          onChange={async (e) => {
            const input = e.currentTarget;
            const file = input.files?.[0];

            try {
              await handleFileChange(file);
            } finally {
              input.value = '';
            }
          }}
        />

        {loading ? (
          <Loader2 className="mb-3 h-8 w-8 animate-spin text-slate-500" />
        ) : imageUrl ? (
          <img
            src={resolveImageUrl(imageUrl)}
            alt="preview"
            className="mb-3 h-28 w-full rounded-2xl object-cover shadow-md"
          />
        ) : (
          <div className="mb-3 flex h-16 w-16 items-center justify-center rounded-2xl bg-white shadow-md">
            <ImagePlus className="h-8 w-8 text-slate-500" />
          </div>
        )}

        <div className="text-sm font-bold text-slate-800">
          {loading ? 'Загрузка...' : 'Нажмите для загрузки фото'}
        </div>
        <div className="mt-1 text-xs font-medium text-slate-500">
          JPG, PNG, WEBP
        </div>
      </label>

      {imageUrl ? (
        <div className="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2 text-xs font-medium break-all text-slate-600 shadow-sm">
          {imageUrl}
        </div>
      ) : null}
    </div>
  );
}

export default function Page() {
  const { isMobile } = useLayout();

  const [loading, setLoading] = useState(true);
  const [savingPromo, setSavingPromo] = useState(false);
  const [savingCategories, setSavingCategories] = useState(false);
  const [uploadingPromo, setUploadingPromo] = useState(false);
  const [uploadingCategories, setUploadingCategories] = useState<
    Record<number, boolean>
  >({});
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  const [promoTitleRu, setPromoTitleRu] = useState('');
  const [promoTitleKk, setPromoTitleKk] = useState('');
  const [promoImageUrl, setPromoImageUrl] = useState('');
  const [promoIsActive, setPromoIsActive] = useState(false);

  const [categories, setCategories] = useState<HomeCmsCategory[]>([]);
  const [updatedAt, setUpdatedAt] = useState<string | null>(null);

  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickerCategoryIndex, setPickerCategoryIndex] = useState<number | null>(null);

  async function loadData() {
    try {
      setLoading(true);
      setError(null);

      const data = (await apiFetch('/home-cms/admin')) as HomeCmsAdminResponse;

      setPromoTitleRu(data.promoTitleRu || '');
      setPromoTitleKk(data.promoTitleKk || '');
      setPromoImageUrl(data.promoImageUrl || '');
      setPromoIsActive(Boolean(data.promoIsActive));
      setUpdatedAt(data.updatedAt || null);

      setCategories(
        Array.isArray(data.categories)
          ? data.categories.map((item, index) => ({
              id: item.id,
              titleRu: item.titleRu || '',
              titleKk: item.titleKk || '',
              imageUrl: item.imageUrl || '',
              sortOrder:
                typeof item.sortOrder === 'number' ? item.sortOrder : index,
              isActive: item.isActive !== false,
              products: Array.isArray(item.products)
                ? item.products.map((product, productIndex) => ({
                    id: product.id,
                    productId: product.productId || '',
                    sortOrder:
                      typeof product.sortOrder === 'number'
                        ? product.sortOrder
                        : productIndex,
                    isActive: product.isActive !== false,
                    product: product.product,
                  }))
                : [],
            }))
          : [],
      );
    } catch (e: any) {
      setError(e?.message || 'Не удалось загрузить данные');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  function updateCategory(index: number, patch: Partial<HomeCmsCategory>) {
    setCategories((prev) =>
      prev.map((item, i) => (i === index ? { ...item, ...patch } : item)),
    );
  }

  function addCategory() {
    setCategories((prev) => [
      ...prev,
      {
        titleRu: '',
        titleKk: '',
        imageUrl: '',
        sortOrder: prev.length,
        isActive: true,
        products: [],
      },
    ]);
  }

  function removeCategory(index: number) {
    setCategories((prev) => prev.filter((_, i) => i !== index));
  }

  function removeCategoryProduct(categoryIndex: number, productIndex: number) {
    setCategories((prev) =>
      prev.map((category, i) =>
        i === categoryIndex
          ? {
              ...category,
              products: category.products.filter((_, j) => j !== productIndex),
            }
          : category,
      ),
    );
  }

  function toggleCategoryProductActive(
    categoryIndex: number,
    productIndex: number,
    checked: boolean,
  ) {
    setCategories((prev) =>
      prev.map((category, i) =>
        i === categoryIndex
          ? {
              ...category,
              products: category.products.map((product, j) =>
                j === productIndex ? { ...product, isActive: checked } : product,
              ),
            }
          : category,
      ),
    );
  }

  function updateCategoryProductSortOrder(
    categoryIndex: number,
    productIndex: number,
    value: number,
  ) {
    setCategories((prev) =>
      prev.map((category, i) =>
        i === categoryIndex
          ? {
              ...category,
              products: category.products.map((product, j) =>
                j === productIndex ? { ...product, sortOrder: value } : product,
              ),
            }
          : category,
      ),
    );
  }

  async function handlePromoUpload(file: File) {
    try {
      setUploadingPromo(true);
      setError(null);
      const fileUrl = await uploadImage(file);
      setPromoImageUrl(fileUrl);
    } catch (e: any) {
      setError(e?.message || 'Ошибка загрузки изображения');
    } finally {
      setUploadingPromo(false);
    }
  }

  async function handleCategoryUpload(index: number, file: File) {
    try {
      setUploadingCategories((prev) => ({ ...prev, [index]: true }));
      setError(null);
      const fileUrl = await uploadImage(file);
      updateCategory(index, { imageUrl: fileUrl });
    } catch (e: any) {
      setError(e?.message || 'Ошибка загрузки изображения');
    } finally {
      setUploadingCategories((prev) => ({ ...prev, [index]: false }));
    }
  }

  async function savePromo() {
    try {
      setSavingPromo(true);
      setError(null);
      setOk(null);

      await apiFetch('/home-cms/admin/promo', {
        method: 'PUT',
        body: JSON.stringify({
          promoTitleRu,
          promoTitleKk,
          promoImageUrl,
          promoIsActive,
        }),
      });

      setOk('Акция дня сохранена');
      await loadData();
    } catch (e: any) {
      setError(e?.message || 'Ошибка сохранения акции');
    } finally {
      setSavingPromo(false);
    }
  }

  async function saveCategories() {
    try {
      setSavingCategories(true);
      setError(null);
      setOk(null);

      await apiFetch('/home-cms/admin/categories', {
        method: 'PUT',
        body: JSON.stringify({
          categories: categories.map((item, index) => ({
            id: item.id,
            titleRu: item.titleRu,
            titleKk: item.titleKk,
            imageUrl: item.imageUrl,
            sortOrder:
              Number.isFinite(Number(item.sortOrder))
                ? Number(item.sortOrder)
                : index,
            isActive: item.isActive,
            products: item.products.map((product, productIndex) => ({
              id: product.id,
              productId: product.productId,
              sortOrder:
                Number.isFinite(Number(product.sortOrder))
                  ? Number(product.sortOrder)
                  : productIndex,
              isActive: product.isActive,
            })),
          })),
        }),
      });

      setOk('Категории и блюда сохранены');
      await loadData();
    } catch (e: any) {
      setError(e?.message || 'Ошибка сохранения категорий');
    } finally {
      setSavingCategories(false);
    }
  }

  const activeCategoriesCount = useMemo(
    () => categories.filter((item) => item.isActive).length,
    [categories],
  );

  const totalCategoryProductsCount = useMemo(
    () => categories.reduce((sum, category) => sum + category.products.length, 0),
    [categories],
  );

  const promoPreviewVisible = useMemo(() => {
    return (
      promoIsActive &&
      (promoTitleRu.trim() || promoTitleKk.trim() || promoImageUrl.trim())
        .length > 0
    );
  }, [promoIsActive, promoTitleRu, promoTitleKk, promoImageUrl]);

  const formattedUpdatedAt = updatedAt
    ? new Date(updatedAt).toLocaleString('ru-RU')
    : 'Нет данных';

  const pickerCategory =
    pickerCategoryIndex !== null ? categories[pickerCategoryIndex] : null;

  return (
    <div className="container-fluid py-6">
      {isMobile && <HeaderTitle />}

      <div className="mb-6">
        <h1 className="text-4xl font-extrabold text-slate-900">
          Главная страница
        </h1>
        <p className="mt-2 text-sm font-medium text-slate-500">
          Управление промо-блоком и категориями главной страницы. Внутри каждой категории можно добавлять собственный список блюд.
        </p>
      </div>

      {loading ? (
        <div className="rounded-3xl border border-slate-200 bg-white p-6 shadow-md">
          Загрузка...
        </div>
      ) : (
        <div className="space-y-6">
          <div className="grid gap-4 xl:grid-cols-5">
            <StatsCard
              title="Акция дня"
              value={promoIsActive ? 'ON' : 'OFF'}
              subtitle="Статус показа на главной"
              gradient="bg-gradient-to-r from-emerald-400 to-teal-500"
            />
            <StatsCard
              title="Категории"
              value={String(categories.length)}
              subtitle="Всего категорий на главной"
              gradient="bg-gradient-to-r from-blue-400 to-indigo-500"
            />
            <StatsCard
              title="Активные"
              value={String(activeCategoriesCount)}
              subtitle="Категории видны в приложении"
              gradient="bg-gradient-to-r from-violet-400 to-fuchsia-500"
            />
            <StatsCard
              title="Блюд в категориях"
              value={String(totalCategoryProductsCount)}
              subtitle="Всего привязанных блюд"
              gradient="bg-gradient-to-r from-amber-400 to-orange-500"
            />
            <StatsCard
              title="Обновлено"
              value={
                updatedAt
                  ? new Date(updatedAt).toLocaleDateString('ru-RU')
                  : '—'
              }
              subtitle={formattedUpdatedAt}
              gradient="bg-gradient-to-r from-rose-400 to-pink-500"
            />
          </div>

          {error ? (
            <div className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700 shadow-sm">
              {error}
            </div>
          ) : null}

          {ok ? (
            <div className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-700 shadow-sm">
              {ok}
            </div>
          ) : null}

          <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
            <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-md">
              <SectionTitle
                title="Акция дня"
                description="Промо блок в верхней части главной страницы"
                action={
                  <button
                    onClick={savePromo}
                    disabled={savingPromo}
                    className="inline-flex h-11 items-center gap-2 rounded-2xl bg-slate-900 px-4 text-sm font-bold text-white shadow-md transition hover:opacity-90 disabled:opacity-50"
                  >
                    <Save className="h-4 w-4" />
                    {savingPromo ? 'Сохранение...' : 'Сохранить'}
                  </button>
                }
              />

              <div className="grid gap-4 md:grid-cols-2">
                <Input
                  label="Заголовок RU"
                  value={promoTitleRu}
                  onChange={setPromoTitleRu}
                  placeholder="Акция дня"
                />
                <Input
                  label="Заголовок KK"
                  value={promoTitleKk}
                  onChange={setPromoTitleKk}
                  placeholder="Күн акциясы"
                />

                <div className="md:col-span-2">
                  <Switch
                    checked={promoIsActive}
                    onChange={setPromoIsActive}
                    label="Показывать блок акции на главной"
                  />
                </div>

                <div className="md:col-span-2">
                  <UploadBox
                    label="Изображение акции"
                    imageUrl={promoImageUrl}
                    loading={uploadingPromo}
                    onUploaded={handlePromoUpload}
                  />
                </div>
              </div>
            </section>

            <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-md">
              <SectionTitle
                title="Предпросмотр"
                description="Как это будет выглядеть в приложении"
              />

              {promoPreviewVisible ? (
                <div className="overflow-hidden rounded-3xl border border-slate-200 bg-slate-950 shadow-md">
                  <div className="relative h-[280px]">
                    {promoImageUrl ? (
                      <img
                        src={resolveImageUrl(promoImageUrl)}
                        alt="promo"
                        className="h-full w-full object-cover"
                      />
                    ) : (
                      <div className="h-full w-full bg-gradient-to-r from-emerald-500 to-lime-500" />
                    )}
                    <div className="absolute inset-0 bg-black/35" />
                    <div className="absolute inset-x-0 bottom-0 p-6">
                      <div className="inline-flex items-center gap-2 rounded-full bg-white/15 px-3 py-1 text-xs font-semibold text-white backdrop-blur">
                        <Megaphone className="h-3.5 w-3.5" />
                        Промо блок
                      </div>
                      <div className="mt-3 text-3xl font-extrabold uppercase tracking-wide text-white">
                        {promoTitleRu || promoTitleKk || 'Акция дня'}
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="flex min-h-[280px] flex-col items-center justify-center rounded-3xl border border-dashed border-slate-300 bg-slate-50 text-center shadow-sm">
                  <Eye className="mb-3 h-8 w-8 text-slate-400" />
                  <div className="text-sm font-semibold text-slate-700">
                    Предпросмотр скрыт
                  </div>
                  <div className="mt-1 max-w-sm text-xs font-medium text-slate-500">
                    Включите акцию и загрузите изображение, чтобы увидеть итоговый блок.
                  </div>
                </div>
              )}
            </section>
          </div>

          <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-md">
            <SectionTitle
              title="Категории главной"
              description="Каждая категория — это отдельная подборка блюд для главной страницы"
              action={
                <div className="flex gap-3">
                  <button
                    onClick={addCategory}
                    className="inline-flex h-11 items-center gap-2 rounded-2xl border border-slate-300 bg-white px-4 text-sm font-bold text-slate-800 shadow-md transition hover:bg-slate-50"
                  >
                    <Plus className="h-4 w-4" />
                    Добавить категорию
                  </button>

                  <button
                    onClick={saveCategories}
                    disabled={savingCategories}
                    className="inline-flex h-11 items-center gap-2 rounded-2xl bg-slate-900 px-4 text-sm font-bold text-white shadow-md transition hover:opacity-90 disabled:opacity-50"
                  >
                    <Save className="h-4 w-4" />
                    {savingCategories ? 'Сохранение...' : 'Сохранить'}
                  </button>
                </div>
              }
            />

            {categories.length === 0 ? (
              <div className="rounded-3xl border border-dashed border-slate-300 bg-slate-50 px-4 py-10 text-center text-sm font-medium text-slate-500 shadow-sm">
                Категорий пока нет
              </div>
            ) : (
              <div className="grid gap-5 xl:grid-cols-2">
                {categories.map((item, index) => (
                  <div
                    key={item.id || `new-${index}`}
                    className="rounded-3xl border border-slate-200 bg-white p-5 shadow-md transition hover:shadow-lg"
                  >
                    <div className="mb-5 flex items-start justify-between gap-3">
                      <div>
                        <div className="inline-flex h-10 w-10 items-center justify-center rounded-2xl bg-blue-50 text-blue-600 shadow-sm">
                          <LayoutGrid className="h-5 w-5" />
                        </div>
                        <div className="mt-3 text-lg font-extrabold text-slate-900">
                          Категория #{index + 1}
                        </div>
                        <div className="mt-1 text-xs font-medium text-slate-500">
                          Названия, изображение и список блюд категории
                        </div>
                      </div>

                      <button
                        onClick={() => removeCategory(index)}
                        className="inline-flex h-10 items-center gap-2 rounded-2xl border border-red-200 px-3 text-sm font-bold text-red-600 shadow-sm transition hover:bg-red-50"
                      >
                        <Trash2 className="h-4 w-4" />
                        Удалить
                      </button>
                    </div>

                    <div className="grid gap-4">
                      <div className="grid gap-4 md:grid-cols-2">
                        <Input
                          label="Название RU"
                          value={item.titleRu}
                          onChange={(value) =>
                            updateCategory(index, { titleRu: value })
                          }
                          placeholder="Бургеры"
                        />

                        <Input
                          label="Название KK"
                          value={item.titleKk}
                          onChange={(value) =>
                            updateCategory(index, { titleKk: value })
                          }
                          placeholder="Бургерлер"
                        />
                      </div>

                      <UploadBox
                        label="Фото категории"
                        imageUrl={item.imageUrl}
                        loading={Boolean(uploadingCategories[index])}
                        onUploaded={(file) => handleCategoryUpload(index, file)}
                      />

                      <div className="grid gap-4 md:grid-cols-2">
                        <Input
                          label="Порядок сортировки"
                          type="number"
                          value={item.sortOrder}
                          onChange={(value) =>
                            updateCategory(index, {
                              sortOrder: Number(value),
                            })
                          }
                        />

                        <div className="flex items-end">
                          <div className="w-full">
                            <Switch
                              checked={item.isActive}
                              onChange={(checked) =>
                                updateCategory(index, { isActive: checked })
                              }
                              label="Категория активна"
                            />
                          </div>
                        </div>
                      </div>

                      <div className="rounded-3xl border border-slate-200 bg-slate-50 p-4 shadow-sm">
                        <div className="mb-3 flex items-center justify-between gap-3">
                          <div>
                            <div className="text-sm font-extrabold text-slate-900">
                              Блюда в категории
                            </div>
                            <div className="mt-1 text-xs font-medium text-slate-500">
                              Эта категория является подборкой блюд для главной страницы
                            </div>
                          </div>

                          <button
                            onClick={() => {
                              setPickerCategoryIndex(index);
                              setPickerOpen(true);
                            }}
                            className="inline-flex h-10 items-center gap-2 rounded-2xl border border-slate-300 bg-white px-3 text-sm font-bold text-slate-800 shadow-sm transition hover:bg-slate-100"
                          >
                            <Plus className="h-4 w-4" />
                            Добавить блюда
                          </button>
                        </div>

                        {item.products.length === 0 ? (
                          <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-4 text-sm font-medium text-slate-500">
                            В этой категории пока нет блюд
                          </div>
                        ) : (
                          <div className="space-y-2">
                            {item.products.map((productRow, productIndex) => (
                              <div
                                key={productRow.id || `${productRow.productId}-${productIndex}`}
                                className="rounded-2xl border border-slate-200 bg-white px-3 py-3 shadow-sm"
                              >
                                <div className="flex gap-3">
                                  <div className="h-14 w-14 flex-shrink-0 overflow-hidden rounded-2xl bg-slate-100">
                                    {productRow.product?.imageUrl ? (
                                      <img
                                        src={resolveImageUrl(productRow.product.imageUrl)}
                                        alt={
                                          productRow.product.titleRu ||
                                          productRow.product.titleKk ||
                                          'product'
                                        }
                                        className="h-full w-full object-cover"
                                      />
                                    ) : (
                                      <div className="flex h-full w-full items-center justify-center text-slate-400">
                                        <Package className="h-5 w-5" />
                                      </div>
                                    )}
                                  </div>

                                  <div className="min-w-0 flex-1">
                                    <div className="flex items-start justify-between gap-3">
                                      <div className="min-w-0">
                                        <div className="truncate text-sm font-extrabold text-slate-900">
                                          {productRow.product?.titleRu ||
                                            productRow.product?.titleKk ||
                                            'Без названия'}
                                        </div>
                                        <div className="truncate text-xs font-medium text-slate-500">
                                          {productRow.product?.restaurant?.nameRu ||
                                            productRow.product?.restaurant?.nameKk ||
                                            'Ресторан не указан'}
                                        </div>
                                      </div>

                                      <button
                                        onClick={() =>
                                          removeCategoryProduct(index, productIndex)
                                        }
                                        className="inline-flex h-8 items-center gap-1 rounded-xl border border-red-200 px-2 text-xs font-bold text-red-600 transition hover:bg-red-50"
                                      >
                                        <Trash2 className="h-3.5 w-3.5" />
                                        Удалить
                                      </button>
                                    </div>

                                    <div className="mt-2 flex flex-wrap items-center gap-2">
                                      <span className="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-bold text-slate-700">
                                        {productRow.product?.price ?? 0} ₸
                                      </span>

                                      <span
                                        className={`rounded-full px-2.5 py-1 text-[11px] font-bold ${
                                          productRow.product?.isAvailable
                                            ? 'bg-emerald-100 text-emerald-700'
                                            : 'bg-red-100 text-red-700'
                                        }`}
                                      >
                                        {productRow.product?.isAvailable
                                          ? 'Доступен'
                                          : 'Недоступен'}
                                      </span>

                                      <div className="min-w-[120px]">
                                        <Input
                                          label=""
                                          type="number"
                                          value={productRow.sortOrder}
                                          onChange={(value) =>
                                            updateCategoryProductSortOrder(
                                              index,
                                              productIndex,
                                              Number(value),
                                            )
                                          }
                                          placeholder="Сортировка"
                                        />
                                      </div>

                                      <div className="min-w-[190px]">
                                        <Switch
                                          checked={productRow.isActive}
                                          onChange={(checked) =>
                                            toggleCategoryProductActive(
                                              index,
                                              productIndex,
                                              checked,
                                            )
                                          }
                                          label="Активно"
                                        />
                                      </div>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>
      )}

      {pickerOpen && pickerCategoryIndex !== null && pickerCategory ? (
        <ProductsPickerModal
          categoryId={pickerCategory.id}
          categoryTitle={pickerCategory.titleRu || pickerCategory.titleKk || `Категория #${pickerCategoryIndex + 1}`}
          existingProductIds={pickerCategory.products.map((item) => item.productId)}
          nextSortOrder={pickerCategory.products.length}
          onClose={() => {
            setPickerOpen(false);
            setPickerCategoryIndex(null);
          }}
          onApply={(items) => {
            setCategories((prev) =>
              prev.map((category, index) => {
                if (index !== pickerCategoryIndex) return category;

                const nextProducts = [...category.products];

                for (const item of items) {
                  const exists = nextProducts.some(
                    (row) => row.productId === item.productId,
                  );

                  if (!exists) {
                    nextProducts.push({
  productId: item.productId,
  sortOrder: item.sortOrder,
  isActive: item.isActive,
  product: item.product,
});

                  }
                }

                return {
                  ...category,
                  products: nextProducts,
                };
              }),
            );

            setPickerOpen(false);
            setPickerCategoryIndex(null);
          }}
        />
      ) : null}
    </div>
  );
}
