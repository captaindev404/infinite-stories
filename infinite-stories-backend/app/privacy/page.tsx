import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — InfiniteStories",
  description:
    "Privacy Policy for InfiniteStories, the personalized bedtime story app for families.",
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

export default function PrivacyPolicy() {
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
            Privacy Policy
          </h1>
          <p className="text-purple-200/70 text-sm">
            Effective Date: March 28, 2026
          </p>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="bg-white rounded-2xl border border-purple-100 p-8 md:p-12 shadow-sm space-y-10">
          {/* Introduction */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Introduction
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              Captain Dev (&ldquo;we,&rdquo; &ldquo;us,&rdquo; or
              &ldquo;our&rdquo;) operates InfiniteStories (the
              &ldquo;App&rdquo;), a personalized bedtime story application
              available on iOS. This Privacy Policy explains how we collect, use,
              disclose, and safeguard your information when you use our App. By
              using InfiniteStories, you agree to the collection and use of
              information in accordance with this policy.
            </p>
          </section>

          {/* Children's Privacy / COPPA */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Children&apos;s Privacy and COPPA Compliance
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              InfiniteStories is designed for parents and caregivers to create
              personalized bedtime stories for their children (ages 2 to 10).
              The App is operated by parents on behalf of their children.
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                We do not knowingly collect personal information directly from
                children under 13 years of age.
              </li>
              <li>
                All account creation and data input is performed by the parent or
                legal guardian.
              </li>
              <li>
                Character names, traits, and appearance data entered by parents
                are used solely for story personalization.
              </li>
              <li>
                We do not require or encourage children to disclose more
                information than is reasonably necessary for story generation.
              </li>
              <li>
                If we become aware that we have collected personal information
                from a child under 13 without parental consent, we will delete
                that information promptly.
              </li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              If you believe your child has provided us with personal information
              without your consent, please contact us immediately at{" "}
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
              Information We Collect
            </h2>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              Account Information
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              When you create an account, we collect your email address for
              authentication, account recovery, and communication purposes.
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              Hero Character Data
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              To personalize stories, we collect the hero character information
              you provide, including character names, personality traits, and
              appearance details (such as hair color, eye color, and clothing
              preferences).
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              Story Preferences and Content
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              We store story event selections, custom story scenarios you create,
              and generated story content to enable playback and your reading
              journey history.
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              Listening Analytics
            </h3>
            <p className="text-[#4b5563] leading-relaxed">
              We collect basic usage metrics such as story listen counts,
              listening duration, and completion rates. This data is used to
              power the Reading Journey feature and improve the service.
            </p>

            <h3 className="text-lg font-semibold text-[#1e1b4b] mb-2 mt-6">
              Information We Do Not Collect
            </h3>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>We do not collect location data.</li>
              <li>
                We do not collect contacts, photos, or other device data.
              </li>
              <li>
                We do not use cookies for tracking or advertising purposes.
              </li>
              <li>
                We do not collect any biometric or health data.
              </li>
            </ul>
          </section>

          {/* How We Use Your Information */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              How We Use Your Information
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                <strong>Story Generation:</strong> Hero character data and event
                selections are used to generate personalized stories, audio
                narration, and illustrations through AI processing.
              </li>
              <li>
                <strong>Account Management:</strong> Email addresses are used for
                authentication, password recovery, and important service
                communications.
              </li>
              <li>
                <strong>Service Improvement:</strong> Aggregated, anonymized
                usage analytics help us improve story quality and app
                performance.
              </li>
              <li>
                <strong>Reading Journey:</strong> Listening metrics are used to
                provide you with personalized statistics and progress tracking.
              </li>
            </ul>
          </section>

          {/* AI Processing */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              AI Processing and Third-Party Services
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              InfiniteStories uses OpenAI&apos;s API services to generate story
              content, audio narration, and illustrations. When a story is
              generated:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                Hero character data (name, traits, appearance) is sent to
                OpenAI&apos;s API for content generation.
              </li>
              <li>
                Story text is processed by OpenAI for audio narration synthesis.
              </li>
              <li>
                Visual descriptions are processed by OpenAI for illustration
                generation.
              </li>
              <li>
                All content passes through our content safety filter to ensure
                age-appropriate, child-safe material.
              </li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              OpenAI processes this data in accordance with their API data usage
              policy. As of our effective date, OpenAI does not use API-submitted
              data to train their models. We encourage you to review{" "}
              <a
                href="https://openai.com/policies/privacy-policy"
                target="_blank"
                rel="noopener noreferrer"
                className="text-[#7c3aed] hover:underline font-medium"
              >
                OpenAI&apos;s Privacy Policy
              </a>{" "}
              for the most current information.
            </p>
          </section>

          {/* Data Storage and Security */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Data Storage and Security
            </h2>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                Account data and story content are stored on secured servers with
                encryption in transit and at rest.
              </li>
              <li>
                Generated media files (audio and illustrations) are stored on
                Cloudflare R2 cloud storage with secure access controls.
              </li>
              <li>
                API keys and sensitive credentials are stored securely and are
                never exposed to the client application.
              </li>
              <li>
                We implement industry-standard security measures to protect your
                data from unauthorized access, alteration, or destruction.
              </li>
            </ul>
          </section>

          {/* Third-Party Tracking and Advertising */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Third-Party Tracking and Advertising
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              InfiniteStories does not contain any third-party advertising. We do
              not use third-party analytics or tracking services. We do not share
              your data with advertisers or data brokers. We do not sell, rent,
              or trade your personal information to any third party.
            </p>
          </section>

          {/* Data Retention and Deletion */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Data Retention and Deletion
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              We retain your data for as long as your account is active and as
              needed to provide you with the service. You can request deletion of
              your data at any time:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                <strong>In-App Deletion:</strong> You can delete your account and
                all associated data directly from the app&apos;s account
                settings.
              </li>
              <li>
                <strong>Email Request:</strong> You can email{" "}
                <a
                  href="mailto:support@infinitestories.app"
                  className="text-[#7c3aed] hover:underline font-medium"
                >
                  support@infinitestories.app
                </a>{" "}
                to request complete data deletion.
              </li>
              <li>
                Upon deletion, all personal data, hero characters, story
                history, and associated media files will be permanently removed
                from our servers within 30 days.
              </li>
            </ul>
          </section>

          {/* Your Rights */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Your Rights
            </h2>
            <p className="text-[#4b5563] leading-relaxed mb-4">
              Depending on your jurisdiction, you may have the following rights
              regarding your personal data:
            </p>
            <ul className="list-disc list-inside space-y-2 text-[#4b5563] leading-relaxed">
              <li>
                The right to access the personal information we hold about you.
              </li>
              <li>
                The right to request correction of inaccurate personal
                information.
              </li>
              <li>
                The right to request deletion of your personal information.
              </li>
              <li>
                The right to data portability where technically feasible.
              </li>
              <li>
                The right to withdraw consent at any time where processing is
                based on consent.
              </li>
            </ul>
            <p className="text-[#4b5563] leading-relaxed mt-4">
              To exercise any of these rights, please contact us at{" "}
              <a
                href="mailto:support@infinitestories.app"
                className="text-[#7c3aed] hover:underline font-medium"
              >
                support@infinitestories.app
              </a>
              .
            </p>
          </section>

          {/* Changes to This Policy */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Changes to This Privacy Policy
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              We may update this Privacy Policy from time to time. We will notify
              you of any material changes by posting the updated policy in the
              App and updating the &ldquo;Effective Date&rdquo; at the top of
              this page. Your continued use of the App after any changes
              constitutes your acceptance of the revised Privacy Policy.
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2 className="text-2xl font-bold text-[#1e1b4b] mb-4">
              Contact Us
            </h2>
            <p className="text-[#4b5563] leading-relaxed">
              If you have any questions or concerns about this Privacy Policy or
              our data practices, please contact us:
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
