import { useState, useEffect } from "react";
import { TestResultsService, TestResult } from "../services/TestResultsService";

export function useTestResults(sid: string | undefined, refreshTrigger?: any) {
  const [results, setResults] = useState<TestResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!sid) {
      setResults([]);
      setLoading(false);
      setError(null);
      return;
    }
    setLoading(true);
    setError(null);
    TestResultsService.fetchBySid(sid)
      .then(setResults)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [sid, refreshTrigger]);  // Now depends on refreshTrigger

  return { results, loading, error };
}
