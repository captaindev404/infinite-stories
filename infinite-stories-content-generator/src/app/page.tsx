import Link from "next/link"

export default function Home() {
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b">
        <div className="container mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold">Content Generator</h1>
          <p className="text-muted-foreground">TikTok ad content generation platform</p>
        </div>
      </header>

      {/* Main */}
      <main className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Briefs */}
          <Link
            href="/briefs"
            className="bg-card rounded-lg border p-6 hover:border-primary transition-colors"
          >
            <h2 className="text-xl font-semibold mb-2">Briefs</h2>
            <p className="text-muted-foreground mb-4">
              Create and manage ad briefs. Write natural language descriptions and
              let AI parse them into structured content.
            </p>
            <span className="text-primary text-sm font-medium">
              Create New Brief →
            </span>
          </Link>

          {/* Videos */}
          <Link
            href="/videos"
            className="bg-card rounded-lg border p-6 hover:border-primary transition-colors"
          >
            <h2 className="text-xl font-semibold mb-2">Video Library</h2>
            <p className="text-muted-foreground mb-4">
              Browse, review, and manage all generated videos. Approve quality,
              flag issues, and download for TikTok.
            </p>
            <span className="text-primary text-sm font-medium">
              View Videos →
            </span>
          </Link>

          {/* Costs */}
          <Link
            href="/costs"
            className="bg-card rounded-lg border p-6 hover:border-primary transition-colors"
          >
            <h2 className="text-xl font-semibold mb-2">Cost Dashboard</h2>
            <p className="text-muted-foreground mb-4">
              Track spending in real-time. View cost breakdowns by service type,
              daily trends, and aggregate statistics.
            </p>
            <span className="text-primary text-sm font-medium">
              View Costs →
            </span>
          </Link>
        </div>

        {/* Quick Start */}
        <section className="mt-12 bg-card rounded-lg border p-6">
          <h2 className="text-xl font-semibold mb-4">Quick Start</h2>
          <ol className="space-y-4 text-muted-foreground">
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-medium">
                1
              </span>
              <div>
                <p className="font-medium text-foreground">Create a Brief</p>
                <p>
                  Describe your TikTok ad concept in natural language. Include target
                  audience, emotional hook, and key messages.
                </p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-medium">
                2
              </span>
              <div>
                <p className="font-medium text-foreground">Generate Videos</p>
                <p>
                  Generate 1-10 video variations from your parsed brief. Watch
                  progress in real-time as AI creates unique content.
                </p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-medium">
                3
              </span>
              <div>
                <p className="font-medium text-foreground">Review & Iterate</p>
                <p>
                  Preview videos, approve winners, flag issues. Select top performers
                  and generate variations to scale success.
                </p>
              </div>
            </li>
            <li className="flex gap-4">
              <span className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-medium">
                4
              </span>
              <div>
                <p className="font-medium text-foreground">Download & Deploy</p>
                <p>
                  Download approved videos in TikTok-ready format. Track costs and
                  optimize your content strategy.
                </p>
              </div>
            </li>
          </ol>
        </section>
      </main>
    </div>
  )
}
