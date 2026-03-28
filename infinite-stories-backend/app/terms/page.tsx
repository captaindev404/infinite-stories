import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service — InfiniteStories",
  description:
    "Terms of Service for InfiniteStories, the personalized bedtime story app for families.",
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

export default function TermsOfService() {
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
            Terms of Service
          </h1>
          <p className="text-purple-200/70 text-sm">
            Effective Date: March 28, 2026
          </p>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-12 shadow-sm space-y-10">
          {/* Agreement */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Agreement to Terms
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              By downloading, installing, or using InfiniteStories (the
              &ldquo;App&rdquo;), operated by Captain Dev (&ldquo;we,&rdquo;
              &ldquo;us,&rdquo; or &ldquo;our&rdquo;), you agree to be bound by
              these Terms of Service (&ldquo;Terms&rdquo;). If you do not agree
              to these Terms, do not use the App. These Terms apply to all users
              of the App, including parents, guardians, and any other visitors or
              contributors.
            </p>
          </section>

          {/* Service Description */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Service Description
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              InfiniteStories is an AI-powered bedtime story generation platform
              that allows parents and caregivers to:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                Create personalized hero characters featuring their child&apos;s
                name, personality traits, and appearance.
              </li>
              <li>
                Generate unique bedtime stories tailored to specific events and
                occasions.
              </li>
              <li>
                Listen to AI-generated audio narration of each story.
              </li>
              <li>
                View AI-generated illustrations synchronized with the story
                narration.
              </li>
              <li>
                Track reading habits and milestones through the Reading Journey
                feature.
              </li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              The App requires an active internet connection to function.
              Story generation, audio narration, and illustration creation all
              require connectivity to our servers.
            </p>
          </section>

          {/* User Accounts */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              User Accounts
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                You must create an account to use InfiniteStories. You are
                responsible for maintaining the confidentiality of your account
                credentials.
              </li>
              <li>
                You must be at least 18 years of age (or the age of majority in
                your jurisdiction) to create an account.
              </li>
              <li>
                You are responsible for all activity that occurs under your
                account.
              </li>
              <li>
                You agree to provide accurate and complete information when
                creating your account and to update your information as needed.
              </li>
              <li>
                You must notify us immediately of any unauthorized use of your
                account.
              </li>
            </ul>
          </section>

          {/* Acceptable Use */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Acceptable Use
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              You agree to use InfiniteStories only for its intended purpose:
              creating personalized bedtime stories for children. You agree not
              to:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                Use the App to generate harmful, abusive, threatening, or
                inappropriate content.
              </li>
              <li>
                Attempt to bypass the App&apos;s content safety filters.
              </li>
              <li>
                Use the App in any way that violates applicable laws or
                regulations.
              </li>
              <li>
                Reverse engineer, decompile, or attempt to extract the source
                code of the App.
              </li>
              <li>
                Use automated systems or bots to access or interact with the
                App.
              </li>
              <li>
                Share your account credentials with third parties.
              </li>
              <li>
                Use the App to infringe upon the intellectual property rights of
                others.
              </li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              <strong>Parental Responsibility:</strong> As a parent or guardian,
              you are responsible for supervising your child&apos;s interaction
              with stories generated by the App and ensuring the content is
              appropriate for your child&apos;s age and sensitivities.
            </p>
          </section>

          {/* AI-Generated Content */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              AI-Generated Content
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              Stories, audio narration, and illustrations in InfiniteStories are
              generated using artificial intelligence. Please understand that:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                AI-generated content may occasionally contain unexpected or
                imperfect elements despite our content safety measures.
              </li>
              <li>
                We implement multi-language content safety filters to ensure
                age-appropriate material, but no automated system is perfect.
              </li>
              <li>
                Generated stories, audio, and illustrations are provided
                &ldquo;as is&rdquo; and may vary in quality.
              </li>
              <li>
                We do not guarantee that AI-generated content will be free from
                errors, inconsistencies, or inaccuracies.
              </li>
              <li>
                If you encounter any content you consider inappropriate, please
                report it immediately to{" "}
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
              Intellectual Property
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              The App, including its design, code, features, and branding, is
              owned by Captain Dev and is protected by intellectual property
              laws.
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                You retain ownership of the character names and personal
                information you input into the App.
              </li>
              <li>
                AI-generated stories, illustrations, and audio created through
                the App are provided for your personal, non-commercial use.
              </li>
              <li>
                You may not reproduce, distribute, or commercially exploit
                AI-generated content outside of personal family use without our
                written permission.
              </li>
              <li>
                The InfiniteStories name, logo, and related trademarks are the
                property of Captain Dev.
              </li>
            </ul>
          </section>

          {/* Subscriptions */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Subscriptions and Payments
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              InfiniteStories may offer auto-renewable subscription plans
              through the Apple App Store. If applicable:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                Payment will be charged to your Apple ID account at
                confirmation of purchase.
              </li>
              <li>
                Subscriptions automatically renew unless auto-renew is turned
                off at least 24 hours before the end of the current billing
                period.
              </li>
              <li>
                Your account will be charged for renewal within 24 hours prior
                to the end of the current period at the rate of your selected
                plan.
              </li>
              <li>
                You can manage and cancel your subscriptions through your Apple
                ID account settings on your device.
              </li>
              <li>
                Any unused portion of a free trial period will be forfeited when
                you purchase a subscription.
              </li>
              <li>
                Prices are subject to change. We will notify you of any price
                changes before they take effect.
              </li>
            </ul>
          </section>

          {/* Limitation of Liability */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Limitation of Liability
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              To the maximum extent permitted by applicable law:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                InfiniteStories is provided &ldquo;as is&rdquo; and &ldquo;as
                available&rdquo; without warranties of any kind, whether express
                or implied.
              </li>
              <li>
                We do not warrant that the App will be uninterrupted, error-free,
                or secure.
              </li>
              <li>
                Captain Dev shall not be liable for any indirect, incidental,
                special, consequential, or punitive damages arising from your
                use of the App.
              </li>
              <li>
                Our total liability for any claims related to the App shall not
                exceed the amount you paid to us in the twelve months preceding
                the claim.
              </li>
              <li>
                We are not responsible for the actions, content, or data of
                third-party services, including AI model providers.
              </li>
            </ul>
          </section>

          {/* Termination */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Termination
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              We reserve the right to suspend or terminate your account and
              access to the App at our sole discretion, without prior notice, for
              conduct that we believe violates these Terms or is harmful to other
              users, us, or third parties, or for any other reason. You may
              terminate your account at any time by deleting your account through
              the App or by contacting us. Upon termination, your right to use
              the App will immediately cease, and we may delete your data in
              accordance with our Privacy Policy.
            </p>
          </section>

          {/* Indemnification */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Indemnification
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              You agree to indemnify, defend, and hold harmless Captain Dev and
              its officers, directors, employees, and agents from and against any
              claims, damages, obligations, losses, liabilities, costs, or debt,
              and expenses arising from your use of the App, your violation of
              these Terms, or your violation of any third-party rights.
            </p>
          </section>

          {/* Governing Law */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Governing Law
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              These Terms shall be governed by and construed in accordance with
              the laws of the jurisdiction in which Captain Dev is established,
              without regard to conflict of law principles. Any disputes arising
              under these Terms shall be resolved in the competent courts of that
              jurisdiction.
            </p>
          </section>

          {/* Changes to Terms */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Changes to These Terms
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              We reserve the right to modify these Terms at any time. We will
              provide notice of material changes by posting the updated Terms in
              the App and updating the &ldquo;Effective Date.&rdquo; Your
              continued use of the App after the effective date of any changes
              constitutes your acceptance of the revised Terms.
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Contact Us
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              If you have any questions about these Terms of Service, please
              contact us:
            </p>
            <div className="mt-4 bg-[#f5f3ff] rounded-xl p-6 border border-purple-100">
              <p className="text-[#1e1b4b] font-semibold">Captain Dev</p>
              <p className="text-[#4b5563] mt-1">InfiniteStories</p>
              <p className="text-[#4b5563] mt-1">
                Email:{" "}
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
            &copy; 2026 Captain Dev. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
