import type { Metadata } from "next";
import FaqAccordion from "../components/FaqAccordion";

export const metadata: Metadata = {
  title: "Support — InfiniteStories",
  description:
    "Get help with InfiniteStories. Find answers to common questions and contact our support team.",
};

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

const faqItems = [
  {
    question: "What age range is InfiniteStories designed for?",
    answer:
      "InfiniteStories is designed for children ages 2 to 10. Parents create and manage the experience, choosing themes and characters that are perfectly suited to their child's age, interests, and developmental stage.",
  },
  {
    question: "How does the AI create personalized stories?",
    answer:
      "You start by creating a hero character with your child's name, personality traits, and appearance. Our AI then weaves these details into original bedtime stories, complete with warm audio narration and beautiful illustrations. Every story is unique and tailored to your child.",
  },
  {
    question: "Is the content safe for children?",
    answer:
      "Absolutely. Every story passes through our multi-language content safety filter before reaching your child. We generate only age-appropriate, positive content. There is no advertising, no third-party tracking, and no social features. The app is designed to be a safe, private space for your family.",
  },
  {
    question: "Can I use InfiniteStories without an internet connection?",
    answer:
      "InfiniteStories requires an internet connection to generate new stories, audio narration, and illustrations. Previously played audio and viewed images may be available from your device's cache, but creating new content requires connectivity.",
  },
  {
    question: "How do I delete my account and data?",
    answer:
      "You can delete your account directly within the app through the account settings. This will permanently remove all your data including hero characters, story history, and personal information from our servers. You can also contact us at support@infinitestories.app for assistance.",
  },
];

const troubleshootingItems = [
  {
    question: "I can't sign in to my account",
    answer:
      "First, make sure you have a stable internet connection. If you forgot your password, use the password reset option on the sign-in screen. If you are using Sign in with Apple, make sure you are using the same Apple ID you originally registered with. If the problem persists, try closing and reopening the app, or reinstalling it from the App Store. Contact support@infinitestories.app if you still cannot access your account.",
  },
  {
    question: "My story is not generating",
    answer:
      "Story generation requires an active internet connection and may take up to a minute depending on your connection speed. If a story fails to generate, check your internet connection and try again. If the issue persists, try selecting a different story event or restarting the app. The app will display an error message with a retry option if the generation fails. If you see repeated errors, please contact our support team.",
  },
  {
    question: "Audio is not playing or sounds distorted",
    answer:
      "Make sure your device is not in silent mode and the volume is turned up. Check that no other apps are using audio in the background. If audio playback fails, the app will show an error with a retry button. Try closing other audio-heavy apps and restarting playback. For persistent audio issues, try clearing your device's cache by offloading and reinstalling the app (your data is stored on our servers and will not be lost).",
  },
  {
    question: "Illustrations are not loading",
    answer:
      "Illustrations are generated alongside stories and require a stable internet connection. If illustrations appear as placeholders, check your connection and wait a moment for them to load. You can also try scrolling away and back to trigger a reload. If the problem persists, the story can still be enjoyed via audio narration while we work on resolving the illustration display.",
  },
  {
    question: "The app is running slowly or crashing",
    answer:
      "Make sure you are running the latest version of InfiniteStories from the App Store. Try closing and reopening the app. If the issue continues, restart your device. Ensure you have sufficient storage space available on your device. If crashes persist, please contact support@infinitestories.app with your device model and iOS version so we can investigate.",
  },
];

export default function Support() {
  return (
    <div className="min-h-screen bg-[#f5f3ff]">
      {/* Header */}
      <header className="bg-gradient-to-br from-[#1e1b4b] to-[#2e1065] py-16 md:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <a
            href="/"
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
            Back to Home
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
            Help &amp; Support
          </h1>
          <p className="text-purple-200/70 text-lg max-w-2xl">
            Find answers to common questions or reach out to our support team.
            We are here to help make bedtime magical.
          </p>
        </div>
      </header>

      {/* Contact Card */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-10 shadow-sm mb-12">
          <div className="flex flex-col md:flex-row md:items-center gap-6 md:gap-10">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#7c3aed] to-[#a78bfa] flex items-center justify-center flex-shrink-0">
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
                Contact Our Support Team
              </h2>
              <p className="text-[#4b5563] leading-relaxed mb-3">
                Can&apos;t find what you are looking for? Our team is happy to
                help. Send us an email and we will get back to you as soon as
                possible.
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
              Common questions
            </span>
            <h2 className="text-2xl sm:text-3xl font-bold text-[#1e1b4b]">
              Frequently Asked Questions
            </h2>
          </div>
          <FaqAccordion items={faqItems} />
        </section>

        {/* Troubleshooting Section */}
        <section>
          <div className="text-center mb-10">
            <span className="inline-block text-[#f59e0b] font-semibold text-sm uppercase tracking-wider mb-3">
              Troubleshooting
            </span>
            <h2 className="text-2xl sm:text-3xl font-bold text-[#1e1b4b]">
              Common Issues
            </h2>
            <p className="text-[#4b5563] mt-3 max-w-xl mx-auto">
              Having trouble? Here are solutions to the most common issues our
              users encounter.
            </p>
          </div>
          <FaqAccordion items={troubleshootingItems} />
        </section>
      </main>

      {/* Footer */}
      <footer className="bg-[#09071d] border-t border-purple-900/30 py-8">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-purple-300/40 text-sm">
            &copy; 2026 Captain Dev. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
