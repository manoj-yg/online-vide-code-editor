import { NextResponse } from "next/server";
import { db } from "@/lib/db";

export async function GET() {
  try {
    await db.$runCommandRaw({ ping: 1 });
    return NextResponse.json(
      {
        status: "healthy",
        database: "connected",
        timestamp: new Date().toISOString(),
      },
      { status: 200 }
    );
  } catch (error) {
    return NextResponse.json(
      {
        status: "degraded",
        database: "disconnected",
        error: error instanceof Error ? error.message : "Database ping failed",
        timestamp: new Date().toISOString(),
      },
      { status: 503 }
    );
  }
}
