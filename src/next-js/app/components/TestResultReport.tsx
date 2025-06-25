import type { TestResultReport } from "../services/TestResultsService";
import TestResultReportLine from "./TestResultReportLine";

export default function TestResultReport({ report }: { report: TestResultReport }) {
  return (
    <div>
      <div className="grid grid-cols-3 gap-2 px-2 py-2 bg-slate-800 font-semibold text-xs sm:text-sm border-b">
        <div>Bucket</div>
        <div>Total Sessions</div>
        <div>Total Conversions</div>
      </div>
      {report.map((line) => (
        <TestResultReportLine key={line.bucket} line={line} />
      ))}
    </div>
  );
}
