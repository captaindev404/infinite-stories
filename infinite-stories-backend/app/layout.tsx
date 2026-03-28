import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "InfiniteStories -- Personalized Bedtime Stories for Kids",
  description:
    "Create magical bedtime moments with personalized stories featuring your child as the hero. AI-powered adventures that strengthen the parent-child bond.",
  metadataBase: new URL("https://infinitestories.app"),
  openGraph: {
    title: "InfiniteStories -- Personalized Bedtime Stories for Kids",
    description:
      "Create magical bedtime moments with personalized stories featuring your child as the hero. AI-powered adventures that strengthen the parent-child bond.",
    url: "https://infinitestories.app",
    siteName: "InfiniteStories",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "InfiniteStories -- Personalized Bedtime Stories for Kids",
    description:
      "Create magical bedtime moments with personalized stories featuring your child as the hero. AI-powered adventures that strengthen the parent-child bond.",
  },
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
