import type { Metadata } from "next";
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
    title: t(loc, "terms.meta.title"),
    description: t(loc, "terms.meta.desc"),
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

export default async function TermsOfService({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeParam } = await params;
  if (!isValidLocale(localeParam)) {
    notFound();
  }
  const locale = localeParam as Locale;

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
            {t(locale, "terms.title")}
          </h1>
          <p className="text-purple-200/70 text-sm">
            {t(locale, "common.effectiveDate")}
          </p>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-12 shadow-sm space-y-10">
          {/* Agreement */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.agreement.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "terms.agreement.text")}
            </p>
          </section>

          {/* Service Description */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.service.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.service.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.service.1")}</li>
              <li>{t(locale, "terms.service.2")}</li>
              <li>{t(locale, "terms.service.3")}</li>
              <li>{t(locale, "terms.service.4")}</li>
              <li>{t(locale, "terms.service.5")}</li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              {t(locale, "terms.service.note")}
            </p>
          </section>

          {/* User Accounts */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.accounts.title")}
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.accounts.1")}</li>
              <li>{t(locale, "terms.accounts.2")}</li>
              <li>{t(locale, "terms.accounts.3")}</li>
              <li>{t(locale, "terms.accounts.4")}</li>
              <li>{t(locale, "terms.accounts.5")}</li>
            </ul>
          </section>

          {/* Acceptable Use */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.acceptable.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.acceptable.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.acceptable.1")}</li>
              <li>{t(locale, "terms.acceptable.2")}</li>
              <li>{t(locale, "terms.acceptable.3")}</li>
              <li>{t(locale, "terms.acceptable.4")}</li>
              <li>{t(locale, "terms.acceptable.5")}</li>
              <li>{t(locale, "terms.acceptable.6")}</li>
              <li>{t(locale, "terms.acceptable.7")}</li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              <strong>{t(locale, "terms.acceptable.parental")}</strong>
            </p>
          </section>

          {/* AI-Generated Content */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.ai.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.ai.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.ai.1")}</li>
              <li>{t(locale, "terms.ai.2")}</li>
              <li>{t(locale, "terms.ai.3")}</li>
              <li>{t(locale, "terms.ai.4")}</li>
              <li>
                {t(locale, "terms.ai.5")}{" "}
                <a
                  href="mailto:support@infinitestories.app"
                  className="text-[#7c3aed] hover:underline font-medium"
                >
                  support@infinitestories.app
                </a>
                .
              </li>
            </ul>
          </section>

          {/* Intellectual Property */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.ip.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.ip.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.ip.1")}</li>
              <li>{t(locale, "terms.ip.2")}</li>
              <li>{t(locale, "terms.ip.3")}</li>
              <li>{t(locale, "terms.ip.4")}</li>
            </ul>
          </section>

          {/* Subscriptions */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.subscriptions.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.subscriptions.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.subscriptions.1")}</li>
              <li>{t(locale, "terms.subscriptions.2")}</li>
              <li>{t(locale, "terms.subscriptions.3")}</li>
              <li>{t(locale, "terms.subscriptions.4")}</li>
              <li>{t(locale, "terms.subscriptions.5")}</li>
              <li>{t(locale, "terms.subscriptions.6")}</li>
            </ul>
          </section>

          {/* Limitation of Liability */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.liability.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "terms.liability.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "terms.liability.1")}</li>
              <li>{t(locale, "terms.liability.2")}</li>
              <li>{t(locale, "terms.liability.3")}</li>
              <li>{t(locale, "terms.liability.4")}</li>
              <li>{t(locale, "terms.liability.5")}</li>
            </ul>
          </section>

          {/* Termination */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.termination.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "terms.termination.text")}
            </p>
          </section>

          {/* Indemnification */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.indemnification.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "terms.indemnification.text")}
            </p>
          </section>

          {/* Governing Law */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.governing.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "terms.governing.text")}
            </p>
          </section>

          {/* Changes */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "terms.changes.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "terms.changes.text")}
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "common.contactTitle")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {locale === "fr"
                ? "Si vous avez des questions concernant ces conditions d'utilisation, veuillez nous contacter :"
                : "If you have any questions about these Terms of Service, please contact us:"}
            </p>
            <div className="mt-4 bg-[#f5f3ff] rounded-xl p-6 border border-purple-100">
              <p className="text-[#1e1b4b] font-semibold">
                {t(locale, "common.contactCompany")}
              </p>
              <p className="text-[#4b5563] mt-1">
                {t(locale, "common.contactProduct")}
              </p>
              <p className="text-[#4b5563] mt-1">
                {t(locale, "common.contactEmail")}{" "}
                <a
                  href="mailto:support@infinitestories.app"
                  className="text-[#7c3aed] hover:underline font-medium"
                >
                  support@infinitestories.app
                </a>
              </p>
            </div>
          </section>
        </div>
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
