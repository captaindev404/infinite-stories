import type { Metadata } from "next";
import FaqAccordion from "../../components/FaqAccordion";
import { t, isValidLocale, type Locale } from "@/lib/i18n";
import { notFound } from "next/navigation";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const loc = isValidLocale(locale) ? locale : "en";
  return {
    title: t(loc, "support.meta.title"),
    description: t(loc, "support.meta.desc"),
  };
}

function StarIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M12 2L14.09 8.26L20.18 8.97L15.54 13.14L16.82 19.17L12 16.27L7.18 19.17L8.46 13.14L3.82 8.97L9.91 8.26L12 2Z" />
    </svg>
  );
}

export default async function Support({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeParam } = await params;
  if (!isValidLocale(localeParam)) {
    notFound();
  }
  const locale = localeParam as Locale;

  const faqItems = [
    { question: t(locale, "faq.1.q"), answer: t(locale, "faq.1.a") },
    { question: t(locale, "faq.2.q"), answer: t(locale, "faq.2.a") },
    { question: t(locale, "faq.3.q"), answer: t(locale, "faq.3.a") },
    { question: t(locale, "faq.4.q"), answer: t(locale, "faq.4.a") },
    { question: t(locale, "faq.5.q"), answer: t(locale, "faq.5.a") },
  ];

  const troubleshootingItems = [
    {
      question: t(locale, "support.troubleshooting.1.q"),
      answer: t(locale, "support.troubleshooting.1.a"),
    },
    {
      question: t(locale, "support.troubleshooting.2.q"),
      answer: t(locale, "support.troubleshooting.2.a"),
    },
    {
      question: t(locale, "support.troubleshooting.3.q"),
      answer: t(locale, "support.troubleshooting.3.a"),
    },
    {
      question: t(locale, "support.troubleshooting.4.q"),
      answer: t(locale, "support.troubleshooting.4.a"),
    },
    {
      question: t(locale, "support.troubleshooting.5.q"),
      answer: t(locale, "support.troubleshooting.5.a"),
    },
  ];

  return (
    <div className="min-h-screen bg-[#f5f3ff]">
      {/* Header */}
      <header className="bg-gradient-to-br from-[#1e1b4b] to-[#2e1065] py-16 md:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <a
            href={`/${locale}`}
            className="inline-flex items-center gap-2 text-purple-300/70 hover:text-purple-200 transition-colors text-sm mb-8"
          >
            <svg
              className="w-4 h-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 19l-7-7 7-7"
              />
            </svg>
            {t(locale, "common.backToHome")}
          </a>
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center">
              <StarIcon className="w-6 h-6 text-white" />
            </div>
            <span className="text-white font-bold text-xl">
              InfiniteStories
            </span>
          </div>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold text-white mb-4">
            {t(locale, "support.title")}
          </h1>
          <p className="text-purple-200/70 text-lg max-w-2xl">
            {t(locale, "support.subtitle")}
          </p>
        </div>
      </header>

      {/* Contact Card */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-10 shadow-sm mb-12">
          <div className="flex flex-col md:flex-row md:items-center gap-6 md:gap-10">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center shrink-0">
              <svg
                viewBox="0 0 24 24"
                className="w-8 h-8 text-white"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"
                />
              </svg>
            </div>
            <div className="flex-1">
              <h2 className="text-xl font-bold text-[#1e1b4b] mb-2">
                {t(locale, "support.contact.title")}
              </h2>
              <p className="text-[#4b5563] leading-relaxed mb-3">
                {t(locale, "support.contact.desc")}
              </p>
              <a
                href="mailto:support@infinitestories.app"
                className="inline-flex items-center gap-2 bg-[#7c3aed] text-white px-6 py-3 rounded-xl hover:bg-[#6d28d9] transition-colors font-medium text-sm"
              >
                <svg
                  viewBox="0 0 24 24"
                  className="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75"
                  />
                </svg>
                support@infinitestories.app
              </a>
            </div>
          </div>
        </div>

        {/* FAQ Section */}
        <section className="mb-16">
          <div className="text-center mb-10">
            <span className="inline-block text-[#7c3aed] font-semibold text-sm uppercase tracking-wider mb-3">
              {t(locale, "support.faq.label")}
            </span>
            <h2 className="text-2xl sm:text-3xl font-bold text-[#1e1b4b]">
              {t(locale, "support.faq.title")}
            </h2>
          </div>
          <FaqAccordion items={faqItems} />
        </section>

        {/* Troubleshooting Section */}
        <section>
          <div className="text-center mb-10">
            <span className="inline-block text-[#f59e0b] font-semibold text-sm uppercase tracking-wider mb-3">
              {t(locale, "support.troubleshooting.label")}
            </span>
            <h2 className="text-2xl sm:text-3xl font-bold text-[#1e1b4b]">
              {t(locale, "support.troubleshooting.title")}
            </h2>
            <p className="text-[#4b5563] mt-3 max-w-xl mx-auto">
              {t(locale, "support.troubleshooting.subtitle")}
            </p>
          </div>
          <FaqAccordion items={troubleshootingItems} />
        </section>
      </main>

      {/* Footer */}
      <footer className="bg-[#09071d] border-t border-purple-900/30 py-8">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-purple-300/40 text-sm">
            &copy; {t(locale, "common.footerCopyright")}
          </p>
        </div>
      </footer>
    </div>
  );
}
