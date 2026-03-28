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
    title: t(loc, "privacy.meta.title"),
    description: t(loc, "privacy.meta.desc"),
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

export default async function PrivacyPolicy({
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
            {t(locale, "privacy.title")}
          </h1>
          <p className="text-purple-200/70 text-sm">
            {t(locale, "common.effectiveDate")}
          </p>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-12 shadow-sm space-y-10">
          {/* Introduction */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.intro.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.intro.text")}
            </p>
          </section>

          {/* Children's Privacy / COPPA */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.coppa.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "privacy.coppa.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.coppa.1")}</li>
              <li>{t(locale, "privacy.coppa.2")}</li>
              <li>{t(locale, "privacy.coppa.3")}</li>
              <li>{t(locale, "privacy.coppa.4")}</li>
              <li>{t(locale, "privacy.coppa.5")}</li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              {t(locale, "privacy.coppa.contact")}{" "}
              <a
                href="mailto:support@infinitestories.app"
                className="text-[#7c3aed] hover:underline font-medium"
              >
                support@infinitestories.app
              </a>
              .
            </p>
          </section>

          {/* Information We Collect */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.collect.title")}
            </h2>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              {t(locale, "privacy.collect.account.title")}
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.collect.account.text")}
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              {t(locale, "privacy.collect.hero.title")}
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.collect.hero.text")}
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              {t(locale, "privacy.collect.story.title")}
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.collect.story.text")}
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              {t(locale, "privacy.collect.analytics.title")}
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.collect.analytics.text")}
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              {t(locale, "privacy.collect.not.title")}
            </h3>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.collect.not.1")}</li>
              <li>{t(locale, "privacy.collect.not.2")}</li>
              <li>{t(locale, "privacy.collect.not.3")}</li>
              <li>{t(locale, "privacy.collect.not.4")}</li>
            </ul>
          </section>

          {/* How We Use Your Information */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.use.title")}
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.use.1")}</li>
              <li>{t(locale, "privacy.use.2")}</li>
              <li>{t(locale, "privacy.use.3")}</li>
              <li>{t(locale, "privacy.use.4")}</li>
            </ul>
          </section>

          {/* AI Processing */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.ai.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "privacy.ai.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.ai.1")}</li>
              <li>{t(locale, "privacy.ai.2")}</li>
              <li>{t(locale, "privacy.ai.3")}</li>
              <li>{t(locale, "privacy.ai.4")}</li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              {t(locale, "privacy.ai.note")}{" "}
              <a
                href="https://openai.com/policies/privacy-policy"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[#7c3aed] hover:underline font-medium"
              >
                {t(locale, "privacy.ai.linkText")}
              </a>{" "}
              {t(locale, "privacy.ai.noteEnd")}
            </p>
          </section>

          {/* Data Storage and Security */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.storage.title")}
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.storage.1")}</li>
              <li>{t(locale, "privacy.storage.2")}</li>
              <li>{t(locale, "privacy.storage.3")}</li>
              <li>{t(locale, "privacy.storage.4")}</li>
            </ul>
          </section>

          {/* Third-Party Tracking */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.tracking.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.tracking.text")}
            </p>
          </section>

          {/* Data Retention */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.retention.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "privacy.retention.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.retention.1")}</li>
              <li>{t(locale, "privacy.retention.2")}</li>
              <li>{t(locale, "privacy.retention.3")}</li>
            </ul>
          </section>

          {/* Your Rights */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.rights.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              {t(locale, "privacy.rights.intro")}
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>{t(locale, "privacy.rights.1")}</li>
              <li>{t(locale, "privacy.rights.2")}</li>
              <li>{t(locale, "privacy.rights.3")}</li>
              <li>{t(locale, "privacy.rights.4")}</li>
              <li>{t(locale, "privacy.rights.5")}</li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              {t(locale, "privacy.rights.contact")}{" "}
              <a
                href="mailto:support@infinitestories.app"
                className="text-[#7c3aed] hover:underline font-medium"
              >
                support@infinitestories.app
              </a>
              .
            </p>
          </section>

          {/* Changes */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "privacy.changes.title")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {t(locale, "privacy.changes.text")}
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              {t(locale, "common.contactTitle")}
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              {locale === "fr"
                ? "Si vous avez des questions ou des preoccupations concernant cette politique de confidentialite ou nos pratiques en matiere de donnees, veuillez nous contacter :"
                : "If you have any questions or concerns about this Privacy Policy or our data practices, please contact us:"}
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
