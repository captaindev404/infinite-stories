import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"

// GET /api/cost-logs/stats - Get aggregated cost statistics
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const period = searchParams.get("period") ?? "daily"

    // Calculate date ranges
    const now = new Date()
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const weekStart = new Date(todayStart)
    weekStart.setDate(weekStart.getDate() - 7)
    const monthStart = new Date(todayStart)
    monthStart.setDate(monthStart.getDate() - 30)

    // Get totals for different periods
    const [todayLogs, weekLogs, monthLogs, allLogs] = await Promise.all([
      prisma.costLog.aggregate({
        where: { createdAt: { gte: todayStart } },
        _sum: { cost: true },
      }),
      prisma.costLog.aggregate({
        where: { createdAt: { gte: weekStart } },
        _sum: { cost: true },
      }),
      prisma.costLog.aggregate({
        where: { createdAt: { gte: monthStart } },
        _sum: { cost: true },
      }),
      prisma.costLog.aggregate({
        _sum: { cost: true },
      }),
    ])

    // Get breakdown by service type (last 30 days)
    const byServiceType = await prisma.costLog.groupBy({
      by: ["serviceType"],
      where: { createdAt: { gte: monthStart } },
      _sum: { cost: true },
    })

    const serviceTypeCosts: Record<string, string> = {
      script: "0",
      avatar: "0",
      video: "0",
      storage: "0",
    }
    byServiceType.forEach((item) => {
      if (item.serviceType in serviceTypeCosts) {
        serviceTypeCosts[item.serviceType] = (item._sum.cost?.toNumber() ?? 0).toFixed(6)
      }
    })

    // Get daily breakdown for chart
    let daily: { date: string; totalCost: string; videoCount: number }[] = []

    if (period === "daily") {
      // Get daily totals for the last 30 days
      const dailyLogs = await prisma.$queryRaw<
        { date: Date; total: number; video_count: number }[]
      >`
        SELECT
          DATE(created_at) as date,
          SUM(cost) as total,
          COUNT(DISTINCT video_id) as video_count
        FROM cost_logs
        WHERE created_at >= ${monthStart}
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        LIMIT 30
      `

      daily = dailyLogs.map((d) => ({
        date: d.date.toISOString().split("T")[0],
        totalCost: (d.total ?? 0).toFixed(6),
        videoCount: Number(d.video_count) ?? 0,
      }))
    }

    return successToNextResponse({
      today: (todayLogs._sum.cost?.toNumber() ?? 0).toFixed(6),
      thisWeek: (weekLogs._sum.cost?.toNumber() ?? 0).toFixed(6),
      thisMonth: (monthLogs._sum.cost?.toNumber() ?? 0).toFixed(6),
      allTime: (allLogs._sum.cost?.toNumber() ?? 0).toFixed(6),
      byServiceType: serviceTypeCosts,
      daily,
    })
  } catch (error) {
    console.error("Get cost stats error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
