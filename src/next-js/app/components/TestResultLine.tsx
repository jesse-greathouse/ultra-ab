import type { TestResult } from "../services/TestResultsService";

export default function TestResultLine({ result }: { result: TestResult }) {
  // Accepts 1 (number) or "1" (string) as true
  const didConvert = result.did_convert === 1;
  return (
    <div className="grid grid-cols-6 gap-2 px-2 py-1 border-b text-xs sm:text-sm">
      <div>{result.id}</div>
      <div>{result.sid}</div>
      <div>{result.bucket}</div>
      <div>{result.url}</div>
      <div>{didConvert ? "Yes" : "No"}</div>
      <div>{result.created_at ? new Date(result.created_at).toLocaleString() : ""}</div>
    </div>
  );
}
