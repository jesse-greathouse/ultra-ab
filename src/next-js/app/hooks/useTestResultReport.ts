import { useState, useEffect } from "react";
import { TestResultsService, TestResultReport } from "../services/TestResultsService";

export function useTestResultReport(refreshCount = 0) {
  const [report, setReport] = useState<TestResultReport>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    setError(null);

    TestResultsService.getReport()
      .then(setReport)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [refreshCount]);

  return { report, loading, error };
}
