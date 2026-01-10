"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"

const NAV_ITEMS = [
  { href: "/briefs", label: "Briefs" },
  { href: "/videos", label: "Videos" },
  { href: "/costs", label: "Costs" },
]

export function Nav() {
  const pathname = usePathname()

  return (
    <nav className="border-b bg-background">
      <div className="container mx-auto px-4">
        <div className="flex items-center h-14 gap-8">
          <Link href="/" className="font-bold text-lg">
            ContentGen
          </Link>

          <div className="flex gap-6">
            {NAV_ITEMS.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={`text-sm transition-colors ${
                  pathname.startsWith(item.href)
                    ? "text-foreground font-medium"
                    : "text-muted-foreground hover:text-foreground"
                }`}
              >
                {item.label}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </nav>
  )
}
