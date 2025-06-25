'use client';

import Image from "next/image";
import { useState } from "react";
import { useEffect } from "react";
import { useAbSid } from "./hooks/useAbSid";
import { TestResultsService } from "./services/TestResultsService";

import Conversion from "./components/Conversion";
import TestResultList from "./components/TestResultList";
import TestResultReport from "./components/TestResultReport";
import { useTestResults } from "./hooks/useTestResults";
import { useTestResultReport } from "./hooks/useTestResultReport";

export default function Home() {
  const sid = useAbSid();
  const [converted, setConverted] = useState(false);
  const [refreshCount, setRefreshCount] = useState(0);
  const [testResult, setTestResult] = useState<{ id: number } | null>(null);
  const { report, loading: reportLoading, error: reportError } = useTestResultReport(refreshCount);

  useEffect(() => {
    if (!sid) return;
    // Only call once per mount and sid
    TestResultsService.create({
      sid,
      bucket: "A",
      url: window.location.pathname,
      did_convert: 0,
    })
      .then((res) => {
        // Store the returned id for updating later
        setTestResult(res);
      })
      .catch((e) => {
        if (process.env.NODE_ENV === "development") {
          // eslint-disable-next-line no-console
          console.warn("Failed to record test result:", e);
        }
      });
  }, [sid]);

  const { results, loading, error } = useTestResults(sid, refreshCount);

  return (
    <div className="grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20 font-[family-name:var(--font-geist-sans)]">
      <main className="flex flex-col gap-[32px] row-start-2 items-center">
        <Image
          className="dark:invert"
          src="/_next/next.svg"
          alt="Next.js logo"
          width={180}
          height={38}
          priority
        />
        <Conversion
          label={converted ? "Conversion recorded!" : "Buy Me"}
          disabled={converted}
          onConvert={async () => {
            if (!sid) {
              alert("No session ID found.");
              return;
            }
            if (!testResult || !testResult.id) {
              alert("No test result record found to update.");
              return;
            }
            try {
              const updated = await TestResultsService.updateById(testResult.id, {
                sid,
                bucket: "A",
                url: window.location.pathname,
                did_convert: 1,
              });
              setTestResult(updated);  // Store the updated record
              setConverted(true);
              setRefreshCount((c) => c + 1); // trigger a refresh
            } catch (e) {
              alert("Failed to record conversion.");
              console.error(e);
            }
          }}
        />

        <div className="w-full max-w-2xl">
          <h3 className="text-lg font-bold mb-2 mt-8 text-gray-700">Test Result Report</h3>
          {reportLoading && <div className="text-gray-500">Loading summary…</div>}
          {reportError && <div className="text-red-500">Error: {reportError}</div>}
          {!reportLoading && !reportError && <TestResultReport report={report} />}
        </div>

        <div className="w-full max-w-2xl mt-8 border-t border-gray-300 pt-8">
          <h2 className="text-xl font-semibold mb-4 text-gray-700">Test Result Records</h2>
          {loading && <div className="text-gray-500">Loading test results…</div>}
          {error && <div className="text-red-500">Error: {error}</div>}
          {!loading && !error && <TestResultList results={results} />}
        </div>
      </main>
      <footer className="row-start-3 flex gap-[24px] flex-wrap items-center justify-center">
        <a
          className="flex items-center gap-2 hover:underline hover:underline-offset-4"
          href="https://nextjs.org/learn?utm_source=create-next-app&utm_medium=appdir-template-tw&utm_campaign=create-next-app"
          target="_blank"
          rel="noopener noreferrer"
        >
          <Image
            aria-hidden
            src="/_next/file.svg"
            alt="File icon"
            width={16}
            height={16}
          />
          Learn
        </a>
        <a
          className="flex items-center gap-2 hover:underline hover:underline-offset-4"
          href="https://vercel.com/templates?framework=next.js&utm_source=create-next-app&utm_medium=appdir-template-tw&utm_campaign=create-next-app"
          target="_blank"
          rel="noopener noreferrer"
        >
          <Image
            aria-hidden
            src="/_next/window.svg"
            alt="Window icon"
            width={16}
            height={16}
          />
          Examples
        </a>
        <a
          className="flex items-center gap-2 hover:underline hover:underline-offset-4"
          href="https://nextjs.org?utm_source=create-next-app&utm_medium=appdir-template-tw&utm_campaign=create-next-app"
          target="_blank"
          rel="noopener noreferrer"
        >
          <Image
            aria-hidden
            src="/_next/globe.svg"
            alt="Globe icon"
            width={16}
            height={16}
          />
          Go to nextjs.org →
        </a>
      </footer>
    </div>
  );
}
