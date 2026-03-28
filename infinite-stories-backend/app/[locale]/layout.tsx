import { isValidLocale, type Locale } from "@/lib/i18n";
import { notFound } from "next/navigation";

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!isValidLocale(locale)) {
    notFound();
  }

  return (
    <div lang={locale as Locale} data-locale={locale}>
      {children}
    </div>
  );
}
