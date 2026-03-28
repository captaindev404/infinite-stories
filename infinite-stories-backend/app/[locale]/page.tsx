import FaqAccordion from "../components/FaqAccordion";
import { t, isValidLocale, type Locale } from "@/lib/i18n";
import { notFound } from "next/navigation";

const APP_STORE_URL =
  "https://apps.apple.com/app/infinite-stories/id6740043512";

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

function AppStoreBadge({
  className,
  locale,
}: {
  className?: string;
  locale: Locale;
}) {
  return (
    <a
      href={APP_STORE_URL}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex items-center gap-3 bg-black text-white px-7 py-4 rounded-xl hover:bg-gray-900 transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-purple-500/20 ${className || ""}`}
    >
      <svg
        viewBox="0 0 24 24"
        className="w-7 h-7"
        fill="currentColor"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 22 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.1 22C7.79 22.05 6.8 20.68 5.96 19.47C4.25 16.56 2.93 11.3 4.7 7.72C5.57 5.94 7.36 4.86 9.28 4.84C10.56 4.81 11.78 5.72 12.57 5.72C13.36 5.72 14.85 4.62 16.4 4.8C17.07 4.83 18.89 5.07 20.03 6.83C19.93 6.89 17.66 8.24 17.69 11.02C17.72 14.34 20.58 15.43 20.62 15.44C20.59 15.54 20.14 17.12 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
      </svg>
      <div className="flex flex-col">
        <span className="text-xs font-light leading-tight">
          {t(locale, "hero.downloadOn")}
        </span>
        <span className="text-lg font-semibold leading-tight -mt-0.5">
          {t(locale, "hero.appStore")}
        </span>
      </div>
    </a>
  );
}

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: localeParam } = await params;
  if (!isValidLocale(localeParam)) {
    notFound();
  }
  const locale = localeParam as Locale;
  const altLocale = locale === "en" ? "fr" : "en";

  const faqItems = [
    { question: t(locale, "faq.1.q"), answer: t(locale, "faq.1.a") },
    { question: t(locale, "faq.2.q"), answer: t(locale, "faq.2.a") },
    { question: t(locale, "faq.3.q"), answer: t(locale, "faq.3.a") },
    { question: t(locale, "faq.4.q"), answer: t(locale, "faq.4.a") },
    { question: t(locale, "faq.5.q"), answer: t(locale, "faq.5.a") },
  ];

  return (
    <div className="min-h-screen">
      {/* Navigation */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#1e1b4b]/90 backdrop-blur-md border-b border-purple-500/10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <a href={`/${locale}`} className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center">
                <StarIcon className="w-5 h-5 text-white" />
              </div>
              <span className="text-white font-bold text-lg">
                InfiniteStories
              </span>
            </a>
            <div className="hidden md:flex items-center gap-8">
              <a
                href="#features"
                className="text-purple-200/80 hover:text-white transition-colors text-sm"
              >
                {t(locale, "nav.features")}
              </a>
              <a
                href="#how-it-works"
                className="text-purple-200/80 hover:text-white transition-colors text-sm"
              >
                {t(locale, "nav.howItWorks")}
              </a>
              <a
                href="#testimonials"
                className="text-purple-200/80 hover:text-white transition-colors text-sm"
              >
                {t(locale, "nav.stories")}
              </a>
              <a
                href="#faq"
                className="text-purple-200/80 hover:text-white transition-colors text-sm"
              >
                {t(locale, "nav.faq")}
              </a>
              <a
                href={`/${altLocale}`}
                className="text-purple-200/80 hover:text-white transition-colors text-sm font-medium border border-purple-400/30 rounded-full px-3 py-1"
              >
                {t(locale, "nav.language")}
              </a>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="bg-[#7c3aed] text-white px-5 py-2 rounded-full text-sm font-medium hover:bg-[#6d28d9] transition-colors"
              >
                {t(locale, "nav.getApp")}
              </a>
            </div>
            {/* Mobile nav */}
            <div className="flex md:hidden items-center gap-3">
              <a
                href={`/${altLocale}`}
                className="text-purple-200/80 hover:text-white transition-colors text-sm font-medium border border-purple-400/30 rounded-full px-3 py-1"
              >
                {t(locale, "nav.language")}
              </a>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="bg-[#7c3aed] text-white px-4 py-2 rounded-full text-sm font-medium hover:bg-[#6d28d9] transition-colors"
              >
                {t(locale, "nav.getApp")}
              </a>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative bg-gradient-hero min-h-screen flex items-center overflow-hidden pt-16">
        {/* Decorative elements */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-20 left-10 w-72 h-72 bg-purple-500/10 rounded-full blur-3xl animate-float" />
          <div className="absolute bottom-20 right-10 w-96 h-96 bg-[#f59e0b]/8 rounded-full blur-3xl animate-float-delayed" />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-purple-600/5 rounded-full blur-3xl" />

          {/* Stars */}
          <div className="absolute top-32 right-[20%] w-2 h-2 bg-[#fcd34d] rounded-full animate-pulse" />
          <div className="absolute top-48 left-[15%] w-1.5 h-1.5 bg-purple-300 rounded-full animate-pulse delay-700" />
          <div className="absolute bottom-40 left-[30%] w-2 h-2 bg-[#fbbf24] rounded-full animate-pulse delay-1000" />
          <div className="absolute top-60 right-[35%] w-1 h-1 bg-white rounded-full animate-pulse delay-500" />
          <div className="absolute bottom-60 right-[25%] w-1.5 h-1.5 bg-purple-200 rounded-full animate-pulse delay-300" />
        </div>

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 md:py-32">
          <div className="max-w-4xl mx-auto text-center">
            <div className="animate-fade-in-up">
              <div className="inline-flex items-center gap-2 bg-white/10 backdrop-blur-sm border border-purple-400/20 rounded-full px-5 py-2 mb-8">
                <StarIcon className="w-4 h-4 text-[#fbbf24]" />
                <span className="text-purple-200 text-sm font-medium">
                  {t(locale, "hero.badge")}
                </span>
              </div>
            </div>

            <h1 className="animate-fade-in-up-delay-1 text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold text-white leading-tight tracking-tight mb-6">
              {t(locale, "hero.title")}{" "}
              <span className="text-gradient-gold">
                {t(locale, "hero.titleHighlight")}
              </span>{" "}
              {t(locale, "hero.titleEnd")}
            </h1>

            <p className="animate-fade-in-up-delay-2 text-lg sm:text-xl md:text-2xl text-purple-200/90 max-w-2xl mx-auto mb-10 leading-relaxed">
              {t(locale, "hero.subtitle")}
            </p>

            <div className="animate-fade-in-up-delay-3 flex flex-col sm:flex-row items-center justify-center gap-4">
              <AppStoreBadge locale={locale} />
              <a
                href="#how-it-works"
                className="inline-flex items-center gap-2 text-purple-200 hover:text-white transition-colors group"
              >
                <span className="text-base font-medium">
                  {t(locale, "hero.seeHow")}
                </span>
                <svg
                  className="w-5 h-5 group-hover:translate-x-1 transition-transform"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M17 8l4 4m0 0l-4 4m4-4H3"
                  />
                </svg>
              </a>
            </div>
          </div>

          {/* Hero illustration: floating book/stars composition */}
          <div className="mt-16 md:mt-24 flex justify-center">
            <div className="relative w-80 h-56 md:w-[480px] md:h-72">
              {/* Open book shape */}
              <div className="absolute inset-x-4 bottom-0 h-36 md:h-44 bg-gradient-to-b from-purple-900/40 to-purple-950/60 rounded-t-3xl border border-purple-500/20 backdrop-blur-sm flex items-end justify-center pb-6">
                <div className="flex gap-4 md:gap-6">
                  <div className="w-20 md:w-28 h-24 md:h-32 bg-purple-800/30 rounded-lg border border-purple-400/10" />
                  <div className="w-20 md:w-28 h-24 md:h-32 bg-purple-800/30 rounded-lg border border-purple-400/10" />
                </div>
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-px h-full bg-purple-500/20" />
              </div>
              {/* Floating elements above the book */}
              <div className="absolute top-0 left-1/2 -translate-x-1/2">
                <div className="relative">
                  <div className="w-16 h-16 md:w-20 md:h-20 bg-gradient-to-br from-[#f59e0b] to-[#fcd34d] rounded-full flex items-center justify-center animate-float shadow-lg shadow-amber-500/30">
                    <StarIcon className="w-8 h-8 md:w-10 md:h-10 text-white" />
                  </div>
                </div>
              </div>
              <div className="absolute top-6 left-8 md:left-12 animate-float-delayed">
                <div className="w-10 h-10 md:w-12 md:h-12 bg-gradient-to-br from-purple-500 to-purple-700 rounded-full flex items-center justify-center shadow-lg shadow-purple-500/30">
                  <svg
                    viewBox="0 0 24 24"
                    className="w-5 h-5 md:w-6 md:h-6 text-white"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                  >
                    <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                </div>
              </div>
              <div className="absolute top-8 right-8 md:right-12 animate-float">
                <div className="w-10 h-10 md:w-12 md:h-12 bg-gradient-to-br from-pink-400 to-rose-500 rounded-full flex items-center justify-center shadow-lg shadow-pink-500/30">
                  <svg
                    viewBox="0 0 24 24"
                    className="w-5 h-5 md:w-6 md:h-6 text-white"
                    fill="currentColor"
                  >
                    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Bottom wave */}
        <div className="absolute bottom-0 left-0 right-0">
          <svg
            viewBox="0 0 1440 120"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            className="w-full"
            preserveAspectRatio="none"
          >
            <path
              d="M0 120L60 110C120 100 240 80 360 70C480 60 600 60 720 65C840 70 960 80 1080 85C1200 90 1320 90 1380 90L1440 90V120H1380C1320 120 1200 120 1080 120C960 120 840 120 720 120C600 120 480 120 360 120C240 120 120 120 60 120H0Z"
              fill="#f5f3ff"
            />
          </svg>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="bg-gradient-section py-24 md:py-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 md:mb-20">
            <span className="inline-block text-[#7c3aed] font-semibold text-sm uppercase tracking-wider mb-4">
              {t(locale, "features.label")}
            </span>
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#1e1b4b] mb-6">
              {t(locale, "features.title")}
            </h2>
            <p className="text-lg text-[#4b5563] max-w-2xl mx-auto">
              {t(locale, "features.subtitle")}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 md:gap-8">
            {/* Feature 1: Custom Hero Characters */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.hero.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.hero.desc")}
              </p>
            </div>

            {/* Feature 2: AI-Generated Stories */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#f59e0b] to-[#fcd34d] flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.stories.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.stories.desc")}
              </p>
            </div>

            {/* Feature 3: Warm Audio Narration */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-pink-400 to-rose-500 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M19.114 5.636a9 9 0 0 1 0 12.728M16.463 8.288a5.25 5.25 0 0 1 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.audio.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.audio.desc")}
              </p>
            </div>

            {/* Feature 4: Beautiful Illustrations */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-cyan-400 to-blue-500 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.illustrations.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.illustrations.desc")}
              </p>
            </div>

            {/* Feature 5: Special Occasion Stories */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.occasions.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.occasions.desc")}
              </p>
            </div>

            {/* Feature 6: Reading Journey Tracker */}
            <div className="group relative bg-white rounded-2xl p-8 border border-purple-100 hover:border-purple-300/50 transition-all duration-300 hover:shadow-xl hover:shadow-purple-500/10 hover:-translate-y-1">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                <svg
                  viewBox="0 0 24 24"
                  className="w-7 h-7 text-white"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.5"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 0 1 3 19.875v-6.75ZM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V8.625ZM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 0 1-1.125-1.125V4.125Z"
                  />
                </svg>
              </div>
              <h3 className="text-xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "features.journey.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed">
                {t(locale, "features.journey.desc")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="bg-white py-24 md:py-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 md:mb-20">
            <span className="inline-block text-[#7c3aed] font-semibold text-sm uppercase tracking-wider mb-4">
              {t(locale, "how.label")}
            </span>
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#1e1b4b] mb-6">
              {t(locale, "how.title")}
            </h2>
            <p className="text-lg text-[#4b5563] max-w-2xl mx-auto">
              {t(locale, "how.subtitle")}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-12">
            {/* Step 1 */}
            <div className="relative text-center group">
              <div className="relative w-24 h-24 mx-auto mb-8">
                <div className="absolute inset-0 bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] rounded-3xl rotate-6 group-hover:rotate-12 transition-transform duration-300" />
                <div className="relative w-full h-full bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] rounded-3xl flex items-center justify-center shadow-lg shadow-purple-500/25">
                  <svg
                    viewBox="0 0 24 24"
                    className="w-10 h-10 text-white"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z"
                    />
                  </svg>
                </div>
                <div className="absolute -top-2 -right-2 w-8 h-8 bg-[#f59e0b] rounded-full flex items-center justify-center text-white font-bold text-sm shadow-md">
                  1
                </div>
              </div>
              <h3 className="text-2xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "how.step1.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed max-w-xs mx-auto">
                {t(locale, "how.step1.desc")}
              </p>
              {/* Connector arrow */}
              <div className="hidden md:block absolute top-12 -right-6 lg:-right-4">
                <svg
                  width="48"
                  height="24"
                  viewBox="0 0 48 24"
                  fill="none"
                  className="text-purple-300"
                >
                  <path
                    d="M0 12H40M40 12L32 4M40 12L32 20"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeDasharray="4 4"
                  />
                </svg>
              </div>
            </div>

            {/* Step 2 */}
            <div className="relative text-center group">
              <div className="relative w-24 h-24 mx-auto mb-8">
                <div className="absolute inset-0 bg-gradient-to-br from-[#f59e0b] to-[#fcd34d] rounded-3xl rotate-6 group-hover:rotate-12 transition-transform duration-300" />
                <div className="relative w-full h-full bg-gradient-to-br from-[#f59e0b] to-[#fcd34d] rounded-3xl flex items-center justify-center shadow-lg shadow-amber-500/25">
                  <svg
                    viewBox="0 0 24 24"
                    className="w-10 h-10 text-white"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456Z"
                    />
                  </svg>
                </div>
                <div className="absolute -top-2 -right-2 w-8 h-8 bg-[#7c3aed] rounded-full flex items-center justify-center text-white font-bold text-sm shadow-md">
                  2
                </div>
              </div>
              <h3 className="text-2xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "how.step2.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed max-w-xs mx-auto">
                {t(locale, "how.step2.desc")}
              </p>
              {/* Connector arrow */}
              <div className="hidden md:block absolute top-12 -right-6 lg:-right-4">
                <svg
                  width="48"
                  height="24"
                  viewBox="0 0 48 24"
                  fill="none"
                  className="text-amber-300"
                >
                  <path
                    d="M0 12H40M40 12L32 4M40 12L32 20"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeDasharray="4 4"
                  />
                </svg>
              </div>
            </div>

            {/* Step 3 */}
            <div className="relative text-center group">
              <div className="relative w-24 h-24 mx-auto mb-8">
                <div className="absolute inset-0 bg-gradient-to-br from-pink-400 to-rose-500 rounded-3xl rotate-6 group-hover:rotate-12 transition-transform duration-300" />
                <div className="relative w-full h-full bg-gradient-to-br from-pink-400 to-rose-500 rounded-3xl flex items-center justify-center shadow-lg shadow-pink-500/25">
                  <svg
                    viewBox="0 0 24 24"
                    className="w-10 h-10 text-white"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z"
                    />
                  </svg>
                </div>
                <div className="absolute -top-2 -right-2 w-8 h-8 bg-pink-500 rounded-full flex items-center justify-center text-white font-bold text-sm shadow-md">
                  3
                </div>
              </div>
              <h3 className="text-2xl font-bold text-[#1e1b4b] mb-3">
                {t(locale, "how.step3.title")}
              </h3>
              <p className="text-[#6b7280] leading-relaxed max-w-xs mx-auto">
                {t(locale, "how.step3.desc")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section
        id="testimonials"
        className="bg-gradient-dark-section py-24 md:py-32 relative overflow-hidden"
      >
        {/* Decorative stars */}
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-16 left-[10%] w-1.5 h-1.5 bg-[#fcd34d] rounded-full animate-pulse" />
          <div className="absolute top-32 right-[15%] w-1 h-1 bg-purple-300 rounded-full animate-pulse delay-300" />
          <div className="absolute bottom-24 left-[25%] w-2 h-2 bg-[#fbbf24] rounded-full animate-pulse delay-700" />
          <div className="absolute bottom-40 right-[30%] w-1 h-1 bg-white rounded-full animate-pulse delay-1000" />
        </div>

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 md:mb-20">
            <span className="inline-block text-[#fbbf24] font-semibold text-sm uppercase tracking-wider mb-4">
              {t(locale, "testimonials.label")}
            </span>
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-white mb-6">
              {t(locale, "testimonials.title")}
            </h2>
            <p className="text-lg text-purple-200/80 max-w-2xl mx-auto">
              {t(locale, "testimonials.subtitle")}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 md:gap-8">
            {/* Testimonial 1 */}
            <div className="bg-white/5 backdrop-blur-sm border border-purple-500/20 rounded-2xl p-8 hover:bg-white/10 transition-all duration-300">
              <div className="flex gap-1 mb-5">
                {[1, 2, 3, 4, 5].map((i) => (
                  <StarIcon key={i} className="w-5 h-5 text-[#fbbf24]" />
                ))}
              </div>
              <p className="text-purple-100/90 leading-relaxed mb-6 italic">
                &ldquo;{t(locale, "testimonials.1.text")}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-400 to-purple-600 flex items-center justify-center text-white font-semibold text-sm">
                  S
                </div>
                <div>
                  <p className="text-white font-semibold text-sm">
                    {t(locale, "testimonials.1.name")}
                  </p>
                  <p className="text-purple-300/60 text-xs">
                    {t(locale, "testimonials.1.role")}
                  </p>
                </div>
              </div>
            </div>

            {/* Testimonial 2 */}
            <div className="bg-white/5 backdrop-blur-sm border border-purple-500/20 rounded-2xl p-8 hover:bg-white/10 transition-all duration-300">
              <div className="flex gap-1 mb-5">
                {[1, 2, 3, 4, 5].map((i) => (
                  <StarIcon key={i} className="w-5 h-5 text-[#fbbf24]" />
                ))}
              </div>
              <p className="text-purple-100/90 leading-relaxed mb-6 italic">
                &ldquo;{t(locale, "testimonials.2.text")}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-white font-semibold text-sm">
                  J
                </div>
                <div>
                  <p className="text-white font-semibold text-sm">
                    {t(locale, "testimonials.2.name")}
                  </p>
                  <p className="text-purple-300/60 text-xs">
                    {t(locale, "testimonials.2.role")}
                  </p>
                </div>
              </div>
            </div>

            {/* Testimonial 3 */}
            <div className="bg-white/5 backdrop-blur-sm border border-purple-500/20 rounded-2xl p-8 hover:bg-white/10 transition-all duration-300">
              <div className="flex gap-1 mb-5">
                {[1, 2, 3, 4, 5].map((i) => (
                  <StarIcon key={i} className="w-5 h-5 text-[#fbbf24]" />
                ))}
              </div>
              <p className="text-purple-100/90 leading-relaxed mb-6 italic">
                &ldquo;{t(locale, "testimonials.3.text")}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-gradient-to-br from-pink-400 to-rose-500 flex items-center justify-center text-white font-semibold text-sm">
                  L
                </div>
                <div>
                  <p className="text-white font-semibold text-sm">
                    {t(locale, "testimonials.3.name")}
                  </p>
                  <p className="text-purple-300/60 text-xs">
                    {t(locale, "testimonials.3.role")}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section id="faq" className="bg-[#f5f3ff] py-24 md:py-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <span className="inline-block text-[#7c3aed] font-semibold text-sm uppercase tracking-wider mb-4">
              {t(locale, "faq.label")}
            </span>
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#1e1b4b] mb-6">
              {t(locale, "faq.title")}
            </h2>
            <p className="text-lg text-[#4b5563] max-w-2xl mx-auto">
              {t(locale, "faq.subtitle")}
            </p>
          </div>

          <FaqAccordion items={faqItems} />
        </div>
      </section>

      {/* CTA Section */}
      <section className="bg-gradient-hero py-24 md:py-32 relative overflow-hidden">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-10 left-[20%] w-2 h-2 bg-[#fcd34d] rounded-full animate-pulse" />
          <div className="absolute bottom-16 right-[15%] w-1.5 h-1.5 bg-purple-300 rounded-full animate-pulse delay-500" />
          <div className="absolute top-1/2 left-[8%] w-1 h-1 bg-white rounded-full animate-pulse delay-300" />
        </div>

        <div className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-white mb-6">
            {t(locale, "cta.title")}
          </h2>
          <p className="text-lg sm:text-xl text-purple-200/90 max-w-2xl mx-auto mb-10 leading-relaxed">
            {t(locale, "cta.subtitle")}
          </p>
          <AppStoreBadge locale={locale} />
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-[#09071d] border-t border-purple-900/30 py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-12 md:gap-8">
            {/* Brand */}
            <div className="md:col-span-2">
              <div className="flex items-center gap-2 mb-4">
                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center">
                  <StarIcon className="w-5 h-5 text-white" />
                </div>
                <span className="text-white font-bold text-lg">
                  InfiniteStories
                </span>
              </div>
              <p className="text-purple-300/60 text-sm leading-relaxed max-w-sm mb-6">
                {t(locale, "footer.desc")}
              </p>
              <AppStoreBadge locale={locale} className="!px-5 !py-3" />
            </div>

            {/* Links */}
            <div>
              <h4 className="text-white font-semibold text-sm uppercase tracking-wider mb-4">
                {t(locale, "footer.legal")}
              </h4>
              <ul className="space-y-3">
                <li>
                  <a
                    href={`/${locale}/privacy`}
                    className="text-purple-300/60 hover:text-purple-200 transition-colors text-sm"
                  >
                    {t(locale, "footer.privacy")}
                  </a>
                </li>
                <li>
                  <a
                    href={`/${locale}/terms`}
                    className="text-purple-300/60 hover:text-purple-200 transition-colors text-sm"
                  >
                    {t(locale, "footer.terms")}
                  </a>
                </li>
              </ul>
            </div>

            {/* Support */}
            <div>
              <h4 className="text-white font-semibold text-sm uppercase tracking-wider mb-4">
                {t(locale, "footer.support")}
              </h4>
              <ul className="space-y-3">
                <li>
                  <a
                    href={`/${locale}/support`}
                    className="text-purple-300/60 hover:text-purple-200 transition-colors text-sm"
                  >
                    {t(locale, "footer.helpCenter")}
                  </a>
                </li>
                <li>
                  <a
                    href="mailto:support@infinitestories.app"
                    className="text-purple-300/60 hover:text-purple-200 transition-colors text-sm"
                  >
                    support@infinitestories.app
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <div className="border-t border-purple-900/30 mt-12 pt-8 text-center">
            <p className="text-purple-300/40 text-sm">
              &copy; {t(locale, "footer.copyright")}
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
